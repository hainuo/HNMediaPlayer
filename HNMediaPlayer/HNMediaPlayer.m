//
//  HNMediaPlayer.m
//  HNMediaPlayer
//
//  Created by hainuo on 2021/3/8.
//
#ifndef DEBUG
#define DEBUG YES
#endif

#import <UIKit/UIKit.h>
#import "HNMediaPlayer.h"
#import <SJBaseVideoPlayer/SJBaseVideoPlayerConst.h>
#import <SJVideoPlayer/SJVideoPlayer.h>
#import "UZEngine/NSDictionaryUtils.h"
#import <SJBaseVideoPlayer/SJIJKMediaPlaybackController.h>
#import <IJKMediaFrameworkWithSSL/IJKMediaFrameworkWithSSL.h>
#import <IJKMediaFrameworkWithSSL/IJKFFOptions.h>
#import <Masonry/Masonry.h>
#import <SJMediaCacheServer/MCSAssetExporterDefines.h>
#import <SJMediaCacheServer/SJMediaCacheServer.h>
#import <SJUIKit/SJSQLite3.h>
#import <SJUIKit/SJSQLite3+Private.h>
#import <SJUIKit/SJSQLite3Logger.h>
#import <SJUIKit/SJSQLite3+QueryExtended.h>
#import <SJUIKit/SJSQLite3+FoundationExtended.h>
#import "HNVideoList.h"
#import "HNVideoItem.h"
#import <SJUIKit/NSAttributedString+SJMake.h>

static SJEdgeControlButtonItemTag const SJNextPlayItemTag = 100;
static NSInteger const buttonItemDefaultSize = 50;
static SJEdgeControlButtonItemTag const SJEdgeControlLayerTopItem_MoreItem = 104;
@interface HNMediaPlayer ()<MCSAssetExportObserver>
@property (nonatomic, strong) SJVideoPlayer *player;
@property (nonatomic, strong) SJBaseVideoPlayer *sjbPlayer;
@property (nonatomic, strong) SJSQLite3 *sqlite3;
@property (nonatomic,strong) NSTimer *timer;
@property (nonatomic,strong) NSString *preUrl;
@property (nonatomic) BOOL isLandscape;
@property (nonatomic) BOOL isFullScreen;
@property (nonatomic) BOOL needDoSeekStatus;
@property (nonatomic,strong) SJEdgeControlButtonItem *playItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *nextItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *liveItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *currentTimeItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *separatorItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *durationTimeItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *progressItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *fullItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *moreItem;
@end

@implementation HNMediaPlayer


#pragma mark - APICLOOUD DEFAULT METHOD Override
+ (void)onAppLaunch:(NSDictionary *)launchOptions {
	// 方法在应用启动时被调用
	NSLog(@"HNMediaPlay 模块应用启动回调被调用了");

//    SJMediaCacheServer.shared.maxDiskAgeForCache=0; //设置为0 是不是表示 不限制缓存时间？
//    SJMediaCacheServer.shared.cacheCountLimit = 0; //设置为0 是不是表示 不限制缓存文件数？



}
- (id)initWithUZWebView:(UZWebView *)webView {
	if (self = [super initWithUZWebView:webView]) {
		// 初始化方法
		NSLog(@"HNMediaPlay 模块 initWithUZWebView 方法被调用了");

	}

//    if(!_sqlite3){
//        NSLog(@"_sqlite3 is nil");
//        SJSQLite3Logger.shared.enabledConsoleLog = YES;
//        NSString *defaultPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"mydata.db"];
//        NSLog(@"defaultPath %@",defaultPath);
//        _sqlite3 = [[SJSQLite3 alloc] initWithDatabasePath:defaultPath];
//
//    }

	SJSQLite3Logger.shared.enabledConsoleLog = YES;
	SJMediaCacheServer.shared.enabledConsoleLog = YES;
	SJMediaCacheServer.shared.logOptions = MCSLogOptionPrefetcher;
	SJMediaCacheServer.shared.maxConcurrentPrefetchCount=1;

	[SJMediaCacheServer.shared registerExportObserver:self];
	if(!_timer) {

		_timer = [NSTimer timerWithTimeInterval:10 target:self selector:@selector(prefetchList) userInfo:nil repeats:YES];
		NSLog(@"timer %@",_timer);
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
		[_timer fire];
		//    [self checkFailedList];
	}
	return self;
}

- (void)dispose {
	// 方法在模块销毁之前被调用
	NSLog(@"HNMediaPlay 模块 dispose 方法被调用了 模块即将被销毁");
	[[NSNotificationCenter defaultCenter] removeObserver:@"m3u8CacheStatus"];
	_player = nil;
}

#pragma mark - MCSAssertExporter delegate
- (void)exporter:(id<MCSAssetExporter>)exporter statusDidChange:(MCSAssetExportStatus)status {
	NSLog(@"exporterStatus %@  %lu",exporter.URL,(unsigned long)status);
	[self _updateVideo:exporter];
};
- (void)exporter:(id<MCSAssetExporter>)exporter progressDidChange:(float)progress {
	NSLog(@"exporterProgress %@  %f",exporter.URL,progress);
	[self _updateVideo:exporter];
};
- (void)exporterManager:(id<MCSAssetExporterManager>)manager didRemoveAssetWithURL:(NSURL *)URL {
	SJSQLite3Logger.shared.enabledConsoleLog = YES;
	//得到item表数据
	__auto_type items = [self.sqlite3 objectsForClass:HNVideoItem.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"url" value:URL.absoluteString]] orderBy:nil error:nil];
	NSLog(@"得到要处理的视频数据shanchu  %@",items);
	if(items && items.count>0) {
		for (int i = 0; i < items.count; ++i) {
			HNVideoItem *videoItem = items[i];
			NSLog(@"正在处理的shanchu %@",videoItem);
			[self.sqlite3 removeObjectForClass:HNVideoItem.class primaryKeyValue:@(videoItem.id) error:nil];

			__auto_type items2 = [self.sqlite3 objectsForClass:HNVideoItem.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"list_id" value:@(videoItem.list_id)]] orderBy:nil error:nil];
			NSLog(@"得到要处理的视频数据shanchu 影片列表  %@",items2);
			if(!items2 ) {
				//删除视频列表数据；
				[self.sqlite3 removeObjectForClass:HNVideoList.class primaryKeyValue:@(videoItem.list_id) error:nil];
			}
		}
	}

};
- (void) _updateVideo:(id<MCSAssetExporter>)exporter {
	NSString *url = exporter.URL.absoluteString;
	SJSQLite3Logger.shared.enabledConsoleLog = YES;
	//得到item表数据
	__auto_type items = [self.sqlite3 objectsForClass:HNVideoItem.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"url" value:url]] orderBy:nil error:nil];
	if(items && items.count>0) {
		for (int i = 0; i < items.count; ++i) {
			HNVideoItem *videoItem = items[i];

			NSLog(@"得到要出黎的视频 %@",videoItem);
			videoItem.status = (int)exporter.status;
			videoItem.progress = exporter.progress;
			[self.sqlite3 update:videoItem forKeys:@[@"status",@"progress"] error:nil];
			HNVideoList *videoList = [_sqlite3 objectForClass:HNVideoList.class primaryKeyValue:@(videoItem.list_id) error:nil];
			NSLog(@"得到要处理的视频信息是 %@",videoList);
			if(videoList) {
				videoList.url = videoItem.url;
				videoList.status = videoItem.status;
				videoList.key = videoItem.key;
				videoList.progress = videoItem.progress;
				videoList.sort = videoItem.sort;
				[self.sqlite3 update:videoList forKeys:@[@"url",@"status",@"key",@"progress",@"sort"] error:nil];
			}

		}
	}else{
		NSLog(@"要处理状态的数据为空 %@",items);
	}

}
-(void) prefetchList {
	SJSQLite3Logger.shared.enabledConsoleLog = YES;
	//检查空间是否充足
	NSUInteger diskFreeSize = SJMediaCacheServer.shared.reservedFreeDiskSpace;

	NSLog(@"剩余空间 %@",[NSByteCountFormatter stringFromByteCount:diskFreeSize countStyle:NSByteCountFormatterCountStyleFile]);
	NSLog(@"文件缓存时间 %f",SJMediaCacheServer.shared.maxDiskAgeForCache);
	NSLog(@"文件缓存数量 %lu",(unsigned long)SJMediaCacheServer.shared.cacheCountLimit);
	NSLog(@"缓存空间大小 %@", [NSByteCountFormatter stringFromByteCount:SJMediaCacheServer.shared.countOfBytesAllExportedAssets countStyle:NSByteCountFormatterCountStyleFile] );

//	if(diskFreeSize<= 1024 * 1024 * 1024){
//		NSDictionary *object = @{@"code":@(0),@"type":@"needMoreDisk",@"msg":@"当前剩余空间不足,无法执行下载"};
//		[[NSNotificationCenter defaultCenter] postNotificationName:@"searchDevices" object:object];
//    }else{

//    __auto_type list = [self.sqlite3 objectsForClass:HNVideoList.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"vod_id" value:@(0)]] orderBy:nil error:nil];
//    NSMutableArray *listIds = [NSMutableArray array];
//    if(list && list.count>0){
//        for (int j=0; j<list.count; ++j) {
//            HNVideoList *videList = list[j];
//            [listIds addObject:@(videList.id)];
//        }
//        [self.sqlite3 removeObjectsForClass:HNVideoList.class primaryKeyValues:listIds error:nil];
//    }

	NSLog(@"开始处理队列");
	NSError *err = nil;
	__auto_type items = [self.sqlite3 objectsForClass:HNVideoItem.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"status" in:@[@(0),@(1),@(2)]]] orderBy:nil error:&err];
	NSLog(@"prefetchList list %@ ",items);
	if(err) {
		NSLog(@"%@",err);
	}
	if(items && items.count>0) {
		for (int i = 0; i < items.count; ++i) {
			HNVideoItem      *videoItem = items[i];
			if(!videoItem.url || videoItem.vod_id==0) {
				[self.sqlite3 removeObjectForClass:HNVideoItem.class primaryKeyValue:@(videoItem.id) error:nil];
				continue;
			}
			id<MCSAssetExporter> exporter =    [self _export:[NSURL URLWithString:videoItem.url]];
			NSLog(@"得到exporter %@",exporter.URL);
			[exporter synchronize];
			NSLog(@"exporter synchronize %@",exporter.URL);
			[exporter resume];
			NSLog(@"exporter resume %@",exporter.URL);

			NSLog(@"exporter resume %lu",(unsigned long)exporter.status);

			NSLog(@"查询到数据 %@",videoItem);
			videoItem.status = (int) exporter.status;

			videoItem.progress = (float) exporter.progress;

			[self.sqlite3 update:videoItem forKey:@"status" error:nil];
			HNVideoList *videoList = [_sqlite3 objectForClass:HNVideoList.class primaryKeyValue:@(videoItem.list_id) error:nil];
			NSLog(@"prefetchList videoList %@ ",videoList);
			if(videoList) {
				videoList.vod_id = videoItem.vod_id;
				videoList.url = videoItem.url;
				videoList.status = videoItem.status;
				videoList.key = videoItem.key;
				videoList.progress = videoItem.progress;
				videoList.sort = videoItem.sort;
				[self.sqlite3 update:videoList forKeys:@[@"url",@"status",@"key",@"progress",@"sort"] error:nil];
			}

		}
	}
//    }
}
-(id<MCSAssetExporter>) _export:(NSURL * _Nonnull)url {
	return [SJMediaCacheServer.shared exportAssetWithURL:url];
}



#pragma mark - HNMediaPlayer method
JS_METHOD_SYNC(init:(UZModuleMethodContext *)context){

	_player = SJVideoPlayer.player;

	if(_player) {
		_player = nil;
		return @YES;
	}
	return @NO;
}


JS_METHOD(play:(UZModuleMethodContext *)context) {
	if(_player) {
		[_player stop];
	}else{
		_player = SJVideoPlayer.player;
	}
	SJVideoPlayerConfigurations.shared.resources.progressThumbSize= 12.0;
	SJVideoPlayerConfigurations.shared.resources.progressThumbColor = [UIColor colorWithRed:2 / 256.0 green:141 / 256.0 blue:140 / 256.0 alpha:1];
	SJVideoPlayerConfigurations.shared.resources.moreSliderMaxRateValue=3.0;
	SJVideoPlayerConfigurations.shared.resources.moreSliderMaxRateImage= [SJVideoPlayerResourceLoader imageNamed:@"sj_video_player_maxRate"];

	_player.defaultEdgeControlLayer.loadingView.showsNetworkSpeed=YES;
	_player.autoplayWhenSetNewAsset=NO;
	_player.resumePlaybackWhenAppDidEnterForeground = YES;
	_player.defaultEdgeControlLayer.fixesBackItem = NO;
	_player.defaultEdgeControlLayer.showsMoreItem = YES;
	_player.rotationManager.disabledAutorotation = NO;
	_player.defaultEdgeControlLayer.titleView.scrollEnabled = NO;
	//根据手机自动旋转
//    typedef enum : NSUInteger {
//        SJOrientationMaskPortrait = 1 << SJOrientation_Portrait,
//        SJOrientationMaskLandscapeLeft = 1 << SJOrientation_LandscapeLeft,
//        SJOrientationMaskLandscapeRight = 1 << SJOrientation_LandscapeRight,
//        SJOrientationMaskAll = SJOrientationMaskPortrait | SJOrientationMaskLandscapeLeft | SJOrientationMaskLandscapeRight,
//    } SJOrientationMask;

	_player.rotationManager.autorotationSupportedOrientations = NO;

	NSDictionary *param = context.param;
	NSString *url = [param stringValueForKey:@"url" defaultValue:nil];
	NSString *preUrl = [param stringValueForKey:@"preUrl" defaultValue:nil];
	NSString *title = [param stringValueForKey:@"title" defaultValue:nil];
	NSString *headers = [param stringValueForKey:@"headers" defaultValue:nil];
	NSString *fixedOn = [param stringValueForKey:@"fixedOn" defaultValue:nil];
	NSDictionary *rect = [param dictValueForKey:@"rect" defaultValue:@{}];
	NSString *referrer = [param stringValueForKey:@"referrer" defaultValue:nil];
	NSString *userAgent = [param stringValueForKey:@"userAgent" defaultValue:nil];
	BOOL isLandscape = [param boolValueForKey:@"isLandscape" defaultValue:NO];
	float seekTimeTo = [param floatValueForKey:@"seekTimeTo" defaultValue:0.0];
	NSLog(@"rect %@",rect);
	NSLog(@"seekTimeTo %f",seekTimeTo);
	if(seekTimeTo>0) {
		_needDoSeekStatus=YES;
	}else{
		_needDoSeekStatus=NO;
	}
	NSLog(@"_needDoSeekStatus %@",_needDoSeekStatus?@1:@0);
	_isLandscape = isLandscape;
	NSLog(@"初始headers %@",headers);
	//不再对url进行任何处理 所有传入的url必须是正常的url也就是 经过urlencode转移过 query参数的url
//    url = [url stringByRemovingPercentEncoding];
//    NSLog(@"url %@",url);
//    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet  URLQueryAllowedCharacterSet]];
//	NSLog(@"url %@",url);

	BOOL fixed = [param boolValueForKey:@"fixed" defaultValue:YES];

	float x = [rect floatValueForKey:@"x" defaultValue:0];
	float y = [rect floatValueForKey:@"y" defaultValue:0];
	float width = [rect floatValueForKey:@"width" defaultValue:[UIScreen mainScreen].bounds.size.width];
	float height = [rect floatValueForKey:@"height" defaultValue:300];

	_player.automaticallyPerformRotationOrFitOnScreen = NO;
	_player.usesFitOnScreenFirst = NO;

	_player.allowsRotationInFitOnScreen = NO;

	__weak typeof(self) _self = self;
	if(isLandscape) {
		NSLog(@"-90999-9-09-090-9-09-09-9-0");
		_player.automaticallyPerformRotationOrFitOnScreen = NO;
		_player.usesFitOnScreenFirst = YES;
		_player.onlyUsedFitOnScreen = YES;
		_player.allowsRotationInFitOnScreen = YES;
		_player.rotationManager.autorotationSupportedOrientations = NO;

		_player.fitOnScreenObserver.fitOnScreenDidEndExeBlock = ^(id<SJFitOnScreenManager>  _Nonnull mgr) {
		        __strong typeof(_self) self = _self;
		        [self sendCustomEvent:@"hnPlayEvent" extra:@{@"code":@1,@"type":@"fitOnScreen",@"status":mgr.isFitOnScreen?@1:@0,@"msg":@"满屏状态切换成功的回调"} ];
//		        [context callbackWithRet:@{@"code":@1,@"type":@"fitOnScreen",@"status":mgr.isFitOnScreen?@1:@0,@"msg":@"满屏状态切换成功的回调"} err:nil delete:NO];
		        if(self->_player.isFitOnScreen) {
				NSLog(@"fitOnScreen");
                    self->_isFullScreen=YES;
				SJEdgeControlButtonItem *customItem = [SJEdgeControlButtonItem.alloc initWithTag:SJEdgeControlLayerTopItem_MoreItem];
				customItem.image = SJVideoPlayerConfigurations.shared.resources.moreImage;
				[self->_player.defaultEdgeControlLayer.topAdapter addItem:customItem];
				SJEdgeControlButtonItem *moreItem = [self->_player.defaultEdgeControlLayer.topAdapter itemForTag:SJEdgeControlLayerTopItem_More];
				for ( SJEdgeControlButtonItemAction *action in moreItem.actions ) {
					[customItem addAction:action];
				}
				self->_player.allowsRotationInFitOnScreen = YES;

			}else{
                self->_isFullScreen=NO;
				NSLog(@"fitOnScreen nonono");
				[self->_player.defaultEdgeControlLayer.topAdapter removeItemForTag:SJEdgeControlLayerTopItem_MoreItem];
			}


            [self->_player.defaultEdgeControlLayer.topAdapter reload];
            
            [self setBottomButtons:false];
            NSLog(@"当前的mgr状态 _isFullScreen %@",self->_isFullScreen?@"是":@"否");
		};
	}


	if (@available(iOS 14.0, *)) {
		_player.defaultEdgeControlLayer.automaticallyShowsPictureInPictureItem = NO;
	} else {
		// Fallback on earlier versions
	}

	_player.rotationObserver.rotationDidEndExeBlock = ^(id<SJRotationManager>  _Nonnull mgr) {
	        __strong typeof(_self) self = _self;
	        NSLog(@"已经全平了");
	        [self sendCustomEvent:@"hnPlayEvent" extra:@{@"code":@1,@"type":@"rotationScreen",@"status":mgr.isFullscreen?@1:@0,@"msg":@"横(满)竖(小)屏状态切换成功的回调"} ];
//	        [context callbackWithRet:@{@"code":@1,@"type":@"rotationScreen",@"status":mgr.isFullscreen?@1:@0,@"msg":@"横(满)竖(小)屏状态切换成功的回调"} err:nil delete:NO];

	        if(self.player.isFullScreen) {
			self->_isFullScreen =YES;
			self->_player.automaticallyPerformRotationOrFitOnScreen = YES;
			self->_player.rotationManager.autorotationSupportedOrientations = SJOrientationMaskAll;
//                self->_player.defaultEdgeControlLayer.showsMoreItem = YES;

		}else{
			self->_isFullScreen=NO;
			self->_player.automaticallyPerformRotationOrFitOnScreen = NO;
			self->_player.rotationManager.autorotationSupportedOrientations = NO;
		}
        
        [self setBottomButtons:false];
        NSLog(@"当前的mgr状态 _isFullScreen %@",self->_isFullScreen?@"是":@"否");


	};
	_player.playbackObserver.currentTimeDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
//	        NSLog(@"currentTimeDidChangeExeBlock %@",player);
	        __strong typeof(_self) self = _self;
	        [self sendCustomEvent:@"hnPlayEvent" extra:@{@"code":@1,@"type":@"currentTimeChanged",@"currentTime":@(player.currentTime),@"duration":@(player.duration),@"durationWatched":@(player.durationWatched),@"":@(player.durationWatched),@"rate":[NSString stringWithFormat:@"%.2f",player.rate],@"msg":@"当前时间改变的回调"}];
//        [context callbackWithRet:@{@"code":@1,@"type":@"currentTimeChanged",@"currentTime":@(player.currentTime),@"duration":@(player.duration),@"durationWatched":@(player.durationWatched),@"":@(player.durationWatched),@"rate":[NSString stringWithFormat:@"%.2f",player.rate],@"msg":@"当前时间改变的回调"} err:nil delete:NO];
	};
	_player.playbackObserver.durationDidChangeExeBlock=^(__kindof SJBaseVideoPlayer *player){
	        __strong typeof(_self) self = _self;
//	        NSLog(@"durationDidChangeExeBlock %@",player);
	        [self sendCustomEvent:@"hnPlayEvent" extra:@{@"code":@1,@"type":@"durationChanged",@"duration":@(player.duration),@"msg":@"播放时长改变的回调"}];
//        [context callbackWithRet:@{@"code":@1,@"type":@"durationChanged",@"duration":@(player.duration),@"msg":@"播放时长改变的回调"} err:nil delete:NO];
	};

	_player.playbackObserver.assetStatusDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
	        __strong typeof(_self) self = _self;

	        NSLog(@"assetStatusDidChange %@ assetStatus %ld SJAssetStatusReadyToPlay %ld",player,player.assetStatus,SJAssetStatusReadyToPlay);

	        if(player.assetStatus == SJAssetStatusReadyToPlay) {

			[player play];
		}else if(player.assetStatus == SJAssetStatusFailed) {
			NSLog(@"当前链接加载失败，不能播放 %@",self->_player.assetURL);

			[self sendCustomEvent:@"failLoadUrl" extra:@{@"url":[NSString stringWithFormat:@"%@",self->_player.assetURL]}];

			self->_player.defaultLoadFailedControlLayer.reloadView.button.hidden = NO;
			[self->_player.defaultLoadFailedControlLayer.reloadView.button setTitle:@"已自动反馈" forState:UIControlStateNormal];
			[self->_player.defaultLoadFailedControlLayer.reloadView.button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
			self->_player.defaultLoadFailedControlLayer.promptLabel.text = @"视频加载失败，请切换视频源";
			self->_sjbPlayer = nil;
		}

	        [self sendCustomEvent:@"hnPlayEvent" extra:@{@"status":@(player.assetStatus),@"type":@"assetStatus",@"msg":@"资源状态改变的回调",@"code":@1}];
//        NSDictionary *ret =@{@"status":@(player.assetStatus),@"type":@"assetStatus",@"msg":@"资源状态改变的回调",@"code":@1} ;
//	        [context callbackWithRet:ret err:nil delete:NO];
	};

	_player.playbackObserver.playbackStatusDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
	        __strong typeof(_self) self = _self;
	        NSLog(@"playbackStatusDidChange %@ %ld 预加载状态 %ld %ld",player,(long)player.timeControlStatus,(long)SJPlaybackTimeControlStatusWaitingToPlay,(long)player.playbackType);
	        if(player.timeControlStatus == SJPlaybackTimeControlStatusPlaying) {
			self->_sjbPlayer = nil;
			if(self->_isLandscape) {
				self->_player.allowsRotationInFitOnScreen = YES;
			}

			[self seekTimeTo:seekTimeTo];

		}
	        [self sendCustomEvent:@"hnPlayEvent" extra:@{@"code":@1,@"msg":@"播放状态变化后的回调",@"type":@"playbackStatusDidChange",@"timeControlStatus":@(player.timeControlStatus)}];
//        [context callbackWithRet:@{@"code":@1,@"msg":@"播放状态变化后的回调",@"type":@"playbackStatusDidChange",@"timeControlStatus":@(player.timeControlStatus)} err:nil delete:NO];
	};

	_player.playbackObserver.rateDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
//        [context callbackWithRet:@{@"code":@1,@"msg":@"ok",@"type":@"rateDidChanged",@"rate":[NSString stringWithFormat:@"%.2f",player.rate]} err:nil delete:NO];
	        __strong typeof(_self) self = _self;
	        [self sendCustomEvent:@"hnPlayEvent" extra:@{@"code":@1,@"msg":@"ok",@"type":@"rateDidChanged",@"rate":[NSString stringWithFormat:@"%.2f",player.rate]}];
	};
	_player.view.backgroundColor = UIColor.blackColor;
	_player.view.frame = CGRectMake(x,y,width,height);
	[self addSubview:_player.view fixedOn:fixedOn fixed:fixed];


//    UIView *testView = [[UIView alloc] initWithFrame:CGRectMake(0,100, 100, 50)];
//    testView.backgroundColor=[UIColor grayColor];
//    [self addSubview:testView fixedOn:fixedOn fixed:fixed];


//    SJEdgeControlButtonItem *liveItem = [_player.defaultEdgeControlLayer.topAdapter itemForTag:SJEdgeControlLayerBottomItem_LIVEText];

	_player.defaultEdgeControlLayer.bottomProgressIndicatorHeight=3.0;

	if(preUrl) {
		NSLog(@"preUrl is %@",preUrl);
		_preUrl = preUrl;
		if(!_sjbPlayer) {
			[self showBaseVideoPlayer:preUrl];
		}
	}else{
		NSLog(@"no preUrl");
	}
	[self getBottomButtons];
	[self setBottomButtons:false];
	if(![url isEqualToString:preUrl]) {
		NSURL *nsUrl = [NSURL URLWithString:url];
		NSLog(@"nsurl %@",nsUrl);
		if(nsUrl == nil) {
			[_player.switcher switchControlLayerForIdentifier:SJControlLayer_LoadFailed];
			_player.defaultLoadFailedControlLayer.reloadView.button.hidden = NO;
			[_player.defaultLoadFailedControlLayer.reloadView.button setTitle:@"已自动反馈" forState:UIControlStateNormal];
			if(!_player.isFullScreen && !_player.isFitOnScreen) {
				SJEdgeControlButtonItem *backItem = [_player.defaultEdgeControlLayer.topAdapter itemForTag:SJEdgeControlLayerTopItem_Back];
				backItem.hidden = YES;
				[_player.defaultEdgeControlLayer.topAdapter reload];
			}
			[_player.defaultLoadFailedControlLayer.reloadView.button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
			_player.defaultLoadFailedControlLayer.promptLabel.text = @"视频加载失败，请切换视频源";
			_sjbPlayer = nil;
			[context callbackWithRet:@{@"code":@0,@"msg":@"播放设置失败，链接有误！",@"type":@"action"} err:nil delete:YES];
			return;
		}
		NSLog(@"url 和 preUrl 不同");
		SJVideoPlayerURLAsset *asset;
		NSLog(@"当前使用referre %@",referrer);
		if(referrer) {
			NSMutableDictionary * MGheaders = [NSMutableDictionary dictionary];
			[MGheaders setObject:referrer forKey:@"referrer"];
			if(userAgent) {

				[MGheaders setObject:userAgent forKey:@"user-agent"];
			}
			AVURLAsset *avUrlAsset = [AVURLAsset URLAssetWithURL:nsUrl options:@{@"AVURLAssetHTTPHeaderFieldsKey" : MGheaders}];

			asset = [[SJVideoPlayerURLAsset alloc] initWithAVAsset:avUrlAsset];
//        if(!headers){
//            headers = [NSString stringWithFormat:@"referer:%@\r\nuser-agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.102 Safari/537.36\r\n" ,referrer];
//        }

		}else{
			asset = [SJVideoPlayerURLAsset.alloc initWithURL:nsUrl];
		}
		NSLog(@"ret %@",asset);

//    NSRange rangeBilibili=[url rangeOfString:@"bilibili"];
		if(headers) {
			SJIJKMediaPlaybackController *controller = SJIJKMediaPlaybackController.new;
			IJKFFOptions *options = [IJKFFOptions optionsByDefault];
			if(headers) {
				[options setFormatOptionValue:headers forKey:@"headers"];
			}
			controller.options = options;

			_player.playbackController = controller;
			NSLog(@"当前使用的播放器为IJKPLayer");
		}else{
			NSLog(@"当前使用的播放器为SJVideoPlayer");
			_player.playbackController = nil;
		}
		NSLog(@"最终headers %@",headers);


		if(title) {
			asset.title = title;
		}
		_player.URLAsset = asset;
	}else{
		NSLog(@"url 和 preUrl 相同");
	}
	[context callbackWithRet:@{@"code":@1,@"msg":@"播放设置成功！",@"type":@"action"} err:nil delete:YES];

}
-(void) seekTimeTo:(float)seekTimeTo {
	if(seekTimeTo > 0 && self->_needDoSeekStatus) {
		if(seekTimeTo < self->_player.duration) {
			NSLog(@"seekTimeTo: %f",seekTimeTo);
			[self->_player seekToTime:(int)seekTimeTo completionHandler:^(BOOL finished) {
			         NSMutableDictionary *ret = @{}.mutableCopy;
			         [ret setValue:@"seekTimeStatus" forKey:@"type"];
			         [ret setValue:@1 forKey:@"code"];
			         if(finished) {
					 [ret setValue:@"操作成功" forKey:@"msg"];
					 [ret setValue:@1 forKey:@"status"];
					 self->_needDoSeekStatus=NO;
				 }else{
					 [ret setValue:@"操作失败" forKey:@"msg"];
					 [ret setValue:@0 forKey:@"status"];
				 }
			         NSLog(@"seekTimeStatus ret is %@",ret);
			         [self sendCustomEvent:@"hnPlayEvent" extra:ret];
			 }];
		}else{

			NSMutableDictionary *ret = @{}.mutableCopy;
			[ret setValue:@"seekTimeStatus" forKey:@"type"];
			[ret setValue:@"操作失败，时间超过最大播放时间" forKey:@"msg"];
			[ret setValue:@0 forKey:@"status"];
			[ret setValue:@0 forKey:@"code"];
			NSLog(@"不需要seektime");
			NSLog(@"seekTimeStatus ret is %@",ret);
			[self sendCustomEvent:@"hnPlayEvent" extra:ret];
		}
	}else{
		NSLog(@"不需要seektime");
	}
}
-(void) setTopButtons {
	//移除more按钮
//    SJEdgeControlButtonItem *moreItem = [_player.defaultEdgeControlLayer.topAdapter itemForTag:SJEdgeControlLayerTopItem_More];
//    if(moreItem){
//        [_player.defaultEdgeControlLayer.topAdapter removeItemForTag:SJEdgeControlLayerTopItem_More];
//    }

}
-(void) getBottomButtons {
	//播放暂停按钮
	if(!_playItem) {
		_playItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Play];
	}
	NSLog(@"playItem %@",_playItem);
	_playItem.size = buttonItemDefaultSize;
	//下一集按钮
	if(!_nextItem)
		_nextItem= [[SJEdgeControlButtonItem alloc] initWithImage:[SJVideoPlayerResourceLoader imageNamed:@"sj_video_player_next"] target:self action:@selector(nextPlayClick) tag:SJNextPlayItemTag];
	NSLog(@"nextItem %@",_nextItem);
	_nextItem.size = buttonItemDefaultSize;
	//直播按钮
	if(!_liveItem)
		_liveItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_LIVEText];
	NSLog(@"liveItem %@",_liveItem);
	if(_liveItem) {
		_liveItem.hidden = YES;
	}

	//当前进度时间
	if(!_currentTimeItem)
		_currentTimeItem= [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_CurrentTime];
	NSLog(@"currentTimeItem %@",_currentTimeItem);

	//时间间隔
	if(!_separatorItem)
		_separatorItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Separator];
	NSLog(@"_separatorItem %@",_separatorItem);


	//播放进度条
	if(!_progressItem)
		_progressItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Progress];

	NSLog(@"_progressItem %@",_progressItem);

	_progressItem.fill = YES;

	//总时间
	if(!_durationTimeItem)
		_durationTimeItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_DurationTime];

	NSLog(@"_durationTimeItem %@",_durationTimeItem);



	//播放进度条
	if(!_fullItem)
		_fullItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Full];
	NSLog(@"_fullItem %@",_fullItem);
	_fullItem.size = buttonItemDefaultSize;


	[_player.defaultEdgeControlLayer.bottomAdapter reload];
}
-(void) setBottomButtons:(BOOL)loading {

	if(loading) {
		_playItem.hidden = YES;
		_nextItem.hidden = YES;
		_currentTimeItem.hidden = YES;
		_separatorItem.hidden = YES;
		_durationTimeItem.hidden = YES;
		_progressItem.hidden = YES;
		_fullItem.hidden = YES;
	}else{
		_playItem.hidden = NO;

		if(_isFullScreen) {
			_nextItem.hidden = NO;
		}else{
			_nextItem.hidden = YES;
		}
		_currentTimeItem.hidden = NO;
		_separatorItem.hidden = NO;
		_durationTimeItem.hidden = NO;
		_progressItem.hidden = NO;
		_fullItem.hidden = NO;

	}

	SJEdgeControlButtonItem *nextButtonItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJNextPlayItemTag];
	if(!nextButtonItem) {
		NSLog(@"nextItem 没有 这个东西 %@",_nextItem.hidden?@"是":@"否");
		nextButtonItem = _nextItem;

		NSLog(@"nextItem  添加按钮");
		[_player.defaultEdgeControlLayer.bottomAdapter insertItem:nextButtonItem rearItem:SJEdgeControlLayerBottomItem_CurrentTime];

	}else{
		NSLog(@"nextItem 有这个东西 %@",_nextItem.hidden?@"是":@"否");

	}

	if(_isFullScreen) {
		nextButtonItem.hidden = NO;
		NSLog(@"nextItem  当前是全屏 %@",_nextItem.hidden?@"是":@"否");
	}else{
		nextButtonItem.hidden = YES;
		NSLog(@"nextItem  当前不是全屏 %@",_nextItem.hidden?@"是":@"否");
	}
	NSLog(@"nextItem hidden %@",_nextItem.hidden?@"是":@"否");
	NSLog(@"_fullScreeItem %@",_isFullScreen?@"是":@"否");

	[_player.defaultEdgeControlLayer.bottomAdapter reload];

}
- (void) nextPlayClick {
	if(_preUrl) {
		[_player pauseForUser];
	}

	[self sendCustomEvent:@"nextPlay" extra:@{@"code":@1,@"msg":@"播放下一集"}];

	NSLog(@"viviviviviiv");
	[self showBaseVideoPlayer:_preUrl];

}
- (void) showBaseVideoPlayer:(NSString *)preUrl {
	SJVideoPlayerURLAsset *asset = [[SJVideoPlayerURLAsset alloc] initWithURL:[NSURL URLWithString:preUrl]];

	if(_player.isFullScreen) {
		_player.URLAsset = asset;

//		[_player.defaultEdgeControlLayer.bottomAdapter removeAllItems];
		[self setBottomButtons:YES];
		_player.playbackObserver.playbackDidFinishExeBlock  = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
		        if(player.isPlaybackFinished) {
				[player play];
			}
		};

	}else{
		_sjbPlayer = SJBaseVideoPlayer.player;
		_sjbPlayer.rotationManager.disabledAutorotation=YES;
		_sjbPlayer.playbackObserver.playbackDidFinishExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull sjbPlayer) {
		        if(sjbPlayer.isPlaybackFinished) {
				[sjbPlayer play];
			}

		};
		_player.automaticallyPerformRotationOrFitOnScreen = NO;
		_player.rotationManager.autorotationSupportedOrientations = NO;
		_sjbPlayer.view.backgroundColor= [UIColor blackColor];
		[_player.view addSubview:_sjbPlayer.view];
		//    _sjbPlayer.view.frame = _player.view.bounds;
		[_sjbPlayer.view mas_makeConstraints:^(MASConstraintMaker *make) {
		         make.edges.equalTo(_player.view);
		 }];
		_sjbPlayer.URLAsset = asset;
		[_sjbPlayer play];
	}

}
JS_METHOD(seekTimeTo:(UZModuleMethodContext *)context){
	if(!_player || (_player.assetStatus != SJAssetStatusReadyToPlay)) {
		[context callbackWithRet:@{@"msg":@"没有找到播放器或者播放器资源没有准备好，跳转到指定时间操作失败",@"code":@0} err:nil delete:YES];
	}else{
		NSDictionary *param = context.param;
		float seekTimeTo = [param floatValueForKey:@"seekTimeTo" defaultValue:0.0];
		NSLog(@"seekTimeTo %f",seekTimeTo);
		if(seekTimeTo>0) {
			_needDoSeekStatus=YES;
		}else{
			_needDoSeekStatus=NO;
		}
		NSLog(@"_needDoSeekStatus %@",_needDoSeekStatus?@1:@0);
		[self  seekTimeTo:seekTimeTo];
		[context callbackWithRet:@{@"msg":@"操作设置成功！",@"code":@1} err:nil delete:YES];
	}
}
JS_METHOD(stop:(UZModuleMethodContext *)context){
	if(!_player) {
		[context callbackWithRet:@{@"msg":@"没有找到播放器，停止操作失败",@"code":@0} err:nil delete:YES];
	}else{
		NSDictionary *param = context.param;
		NSString *preUrl = [param stringValueForKey:@"preUrl" defaultValue:nil];

		BOOL showLoading = [param boolValueForKey:@"showLoading" defaultValue:NO];
		if(preUrl) {
			_preUrl = preUrl;
		}

		NSOperationQueue *waitQueue = [[NSOperationQueue alloc] init];
		[waitQueue addOperationWithBlock:^{
		         // 同步到主线程
		         dispatch_async(dispatch_get_main_queue(), ^{
						[self->_player stop];
						if(showLoading && self->_preUrl) {
							[self showBaseVideoPlayer:self->_preUrl];
						}else{
							[self->_player.view removeFromSuperview];
							if(self->_sjbPlayer) {
								self->_sjbPlayer = nil;
							}
							self->_player = nil;
						}


					});
		 }];
		[context callbackWithRet:@{@"msg":@"已停止",@"code":@1} err:nil delete:YES];
	}

}

JS_METHOD_SYNC(pause:(UZModuleMethodContext *)context){
	if(!_player) {
		return @{@"msg":@"没有找到播放器，暂停操作失败",@"code":@0};
	}
	[_player pauseForUser];

	if(_player.isUserPaused) {
		return @{@"status":@"success",@"msg":@"暂停成功！",@"code":@1};
	}
	if(_player.isPaused) {
		return @{@"msg":@"视频已是暂停状态！",@"code":@-1};
	}
	return @{@"msg":@"操作出错！",@"code":@-1};
}

JS_METHOD_SYNC(resumePlay:(UZModuleMethodContext *)context){
	if(!_player) {
		return @{@"msg":@"没有找到播放器，恢复播放操作失败",@"code":@0};
	}
	if(_player.isPlaying) {
		return @{@"msg":@"播放中！",@"type":@"playing",@"code":@1};
	}
	[_player play];


	if(_player.isPaused || _player.isUserPaused) {
		return @{@"msg":@"播放失败，视频暂停了！",@"type":@"paused",@"code":@-1};
	}

	if(_player.isPlaybackFinished) {
		return @{@"msg":@"播放失败，视频已经播放完了！",@"type":@"finished",@"code":@-1};
	}

	if(_player.isPlaying || _player.isBuffering || _player.isEvaluating) {
		return @{@"msg":@"播放中！",@"type":@"playing",@"code":@1};
	}
	return @{@"msg":@"播放成功！",@"type":@"played",@"code":@1};
}

JS_METHOD_SYNC(isPaused:(UZModuleMethodContext *)context){
	if(!_player) {
		return @{@"err":@{@"msg":@"没有找到播放器，播放器暂停状态查询失败！",@"code":@0}};
	}

	if(_player.isUserPaused || _player.isPaused) {
		return @{@"ret":@{@"status":@"success",@"msg":@"暂停成功！",@"code":@1}};
	}
	return @{@"err":@{@"msg":@"播放器不是暂停状态",@"code":@-1}};
}

/**
   是否调用过play接口
 */
JS_METHOD_SYNC(isPlayed:(UZModuleMethodContext *)context){
	if(!_player) {
		return @{@"msg":@"没有找到播放器，获取播放状态失败",@"code":@0};
	}

	if(_player.isPlayed) {
		return @{@"status":@"success",@"msg":@"已经调用过play接口了！",@"code":@1};
	}
	return @{@"msg":@"播放器没有调用过play接口",@"code":@-1};
}

/**
   是否播放中
 */
JS_METHOD_SYNC(isPlaying:(UZModuleMethodContext *)context){
	if(!_player) {
		return @{@"msg":@"没有找到播放器，获取播放器正在播放状态失败",@"code":@0};
	}

	if(_player.isPlaying) {
		return @{@"status":@"success",@"msg":@"正在播放",@"code":@1};
	}
	return @{@"msg":@"影片没有播放",@"code":@-1};
}

/**
   是否播放结束
 */
JS_METHOD_SYNC(isPlaybackFinished:(UZModuleMethodContext *)context){
	if(!_player) {
		return @{@"msg":@"没有找到播放器，获取播放结束状态失败",@"code":@0};
	}

	if(_player.isPlaybackFinished) {
		return @{@"status":@"success",@"msg":@"播放结束",@"reason":_player.finishedReason,@"code":@1};
	}
	return @{@"msg":@"播放没有结束",@"code":@-1};
}


#pragma mark m3u8download

JS_METHOD_SYNC(download:(UZModuleMethodContext *)context){
	NSDictionary *param = context.param;
	NSString *url = [param stringValueForKey:@"url" defaultValue:nil];
	NSString *vod_id = [param stringValueForKey:@"vod_id" defaultValue:nil];
	NSString *vod_name = [param stringValueForKey:@"vod_name" defaultValue:nil];
	NSString *vod_pic = [param stringValueForKey:@"vod_pic" defaultValue:nil];
	NSString *key = [param stringValueForKey:@"key" defaultValue:nil];
	NSString *sort = [param stringValueForKey:@"sort" defaultValue:nil];

	if(!url) {
		return @{@"msg":@"数据有误",@"code":@-1};
	}

	NSError *err = nil;
	HNVideoList *videoList = [HNVideoList new];
	videoList.vod_id =   [vod_id intValue];
	videoList.vod_name = vod_name;
	videoList.status = 0;
	videoList.progress = 0;
	videoList.vod_pic = vod_pic;

	NSLog(@"VideoList download %@",videoList);
	__auto_type list = [self.sqlite3 objectsForClass:HNVideoList.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"vod_id" value:@(videoList.vod_id)]] orderBy:nil error:&err];
	NSLog(@"down list %@ ",list);
	if(err) {
		NSLog(@"err %@",err.userInfo);
		return @{@"msg":@"影片数据出错",@"code":@-1};
	}
	NSInteger list_id = 0;
	if(list && list.count>0) {
		HNVideoList *videoList1 = list[0];
		list_id = (long)videoList1.id;
		videoList.id = (long)list_id;
	}else{
		BOOL resultVideoList = [self.sqlite3 save:videoList error:&err];

		if(resultVideoList==NO) {
			return @{@"msg":@"影片写入出错",@"code":@-1};
		}
	}


	if(err) {
		NSLog(@"err %@",err);
		return @{@"msg":@"影片写入出错",@"code":@-1};
	}
	__auto_type list1 = [self.sqlite3 objectsForClass:HNVideoList.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"vod_id" value:@(videoList.vod_id)]] orderBy:nil error:&err];
	NSLog(@"down list1 %@ ",list1);
	if(err) {
		NSLog(@"err %@",err);
		return @{@"msg":@"影片信息有误！",@"code":@-1};
	}
	HNVideoItem *videoItem = [HNVideoItem new];
	if(list1 && list1.count>0) {
		HNVideoList *videoList1 = list1[0];
		list_id = (long )videoList1.id;
		videoItem.list_id = (long)list_id;
		if(list_id<0) {
			return @{@"msg":@"影片信息写入出错！",@"code":@-1};
		}
	}else{
		return @{@"msg":@"影片信息有误！",@"code":@-1};
	}
	videoItem.url = url;
	videoItem.sort =  [sort intValue];
	videoItem.key = key;
	videoItem.status = 0;
	videoItem.progress =0;
	videoItem.vod_id = [vod_id intValue];

	NSLog(@"videoItem download %@",videoItem);
	__auto_type items = [self.sqlite3 objectsForClass:HNVideoItem.class conditions:@[[SJSQLite3Condition conditionWithColumn:@"vod_id" value:@(videoItem.vod_id)], [SJSQLite3Condition conditionWithColumn:@"sort" value:@(videoItem.sort)],[SJSQLite3Condition conditionWithColumn:@"list_id" value:@(videoItem.list_id)]] orderBy:nil error:&err];
	NSLog(@"down items %@ ",items);
	if(err) {
		NSLog(@"err %@",err);
		return @{@"msg":@"缓存信息有误！",@"code":@-1};
	}
	NSInteger *item_id = nil;
	if(items && items.count>0) {
		HNVideoItem *item = items[0];
		item_id = (long *) item.id;
		videoItem.id = *(item_id);
	}else{
		if(videoItem.list_id>0) {
			[self.sqlite3 save:videoItem error:&err];
		}else{
			NSLog(@"list_id 有问题  %ld",(long)list_id);
			return @{@"msg":@"缓存写入出错",@"code":@-1};
		}
	}

	if(err) {
		NSLog(@"err %@",err);
		return @{@"msg":@"缓存写入出错",@"code":@-1};
	}
	return @{@"msg":@"添加成功",@"code":@0};
}

JS_METHOD(playDownloadUrl:(UZModuleMethodContext *)context){
	if(_player) {
		[_player stop];
	}
	if(!_player) {
		_player = SJVideoPlayer.player;
	}
	NSDictionary *param = context.param;
	NSString *url = [param stringValueForKey:@"url" defaultValue:nil];
	NSString *fixedOn = [param stringValueForKey:@"fixedOn" defaultValue:nil];
	NSDictionary *rect = [param dictValueForKey:@"rect" defaultValue:@{}];
	NSLog(@"rect %@",rect);
	url = [url stringByRemovingPercentEncoding];
	NSLog(@"url %@",url);
	url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
	NSLog(@"url %@",url);

	BOOL fixed = [param boolValueForKey:@"fixed" defaultValue:YES];
	float x = [rect floatValueForKey:@"x" defaultValue:0];
	float y = [rect floatValueForKey:@"y" defaultValue:0];
	float width = [rect floatValueForKey:@"width" defaultValue:(float) [UIScreen mainScreen].bounds.size.width];
	float height = [rect floatValueForKey:@"height" defaultValue:300];

	_player.view.frame = CGRectMake(x,y,width,height);

	_player.defaultEdgeControlLayer.loadingView.showsNetworkSpeed=YES;

	_player.resumePlaybackWhenAppDidEnterForeground = YES;
	_player.defaultEdgeControlLayer.fixesBackItem = NO;
	_player.defaultEdgeControlLayer.showsMoreItem = YES;


	NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLForExportedAssetWithURL:[NSURL URLWithString:url]];
	NSLog(@"ExporterUrl is %@",playbackURL);
	// play
	_player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];

	if (@available(iOS 14.0, *)) {
		_player.defaultEdgeControlLayer.automaticallyShowsPictureInPictureItem = NO;
	} else {
		// Fallback on earlier versions
	}
	_player.view.backgroundColor = UIColor.blackColor;

	NSString * bofangUrl = [NSString stringWithFormat:@"%@",playbackURL.absoluteURL];
	[context callbackWithRet:@{@"url":bofangUrl} err:nil delete:NO];


	//根据手机自动旋转
//    typedef enum : NSUInteger {
//        SJOrientationMaskPortrait = 1 << SJOrientation_Portrait,
//        SJOrientationMaskLandscapeLeft = 1 << SJOrientation_LandscapeLeft,
//        SJOrientationMaskLandscapeRight = 1 << SJOrientation_LandscapeRight,
//        SJOrientationMaskAll = SJOrientationMaskPortrait | SJOrientationMaskLandscapeLeft | SJOrientationMaskLandscapeRight,
//    } SJOrientationMask;
	_player.rotationManager.autorotationSupportedOrientations = SJOrientationMaskAll;

	[self addSubview:_player.view fixedOn:fixedOn fixed:fixed];

	[_player play];
	[context callbackWithRet:@{@"code":@(1),@"msg":@"操作成功！"} err:nil delete:YES];
}

JS_METHOD_SYNC(resumeDownUrl:(UZModuleMethodContext *)context){

	NSDictionary *param = context.param;
	NSString *url = [param stringValueForKey:@"url" defaultValue:nil];

	id<MCSAssetExporter> exporter = [SJMediaCacheServer.shared exportAssetWithURL:[NSURL URLWithString:url]];
	[exporter synchronize];
	[exporter resume];
	return @{@"msg":@"恢复成功",@"code":@1};
}

JS_METHOD_SYNC(pauseDownloadUrl:(UZModuleMethodContext *)context){
	NSDictionary *param = context.param;
	NSString *url = [param stringValueForKey:@"url" defaultValue:nil];
	id<MCSAssetExporter> exporter = [SJMediaCacheServer.shared exportAssetWithURL:[NSURL URLWithString:url]];
	[exporter suspend];
	if(exporter.status== MCSAssetExportStatusSuspended) {
		return @{@"msg":@"暂停成功",@"code":@1};
	}else{
		return @{@"msg":@"暂停失败",@"code":@0};
	}
}

JS_METHOD_SYNC(deleteDownloadUrl:(UZModuleMethodContext *)context){
	NSDictionary *param = context.param;
	NSLog(@"deleteDownloadUrl %@",param);
	NSArray *ids = param[@"ids"];

	NSLog(@"deleteDownloadUrl ids  %@",ids);
	if (ids && ids.count>0) {

		for (int i = 0; i < ids.count; ++i) {
			HNVideoItem *videoItem = [_sqlite3 objectForClass:HNVideoItem.class primaryKeyValue:ids[i] error:nil];
			if(videoItem) {
				id<MCSAssetExporter> exporter = [SJMediaCacheServer.shared exportAssetWithURL:[NSURL URLWithString:videoItem.url]];
				[exporter cancel];
				[SJMediaCacheServer.shared removeExportAssetWithURL:[NSURL URLWithString:videoItem.url]];
			}
		}
		return @{@"msg":@"操作成功！",@"code":@1};

	}else{
		return @{@"msg":@"没有要删除的数据",@"code":@0};
	}

}

JS_METHOD_SYNC(getVideoList:(UZModuleMethodContext *)context){
	NSDictionary *param = context.param;
	NSString *pageStrint = [param stringValueForKey:@"page" defaultValue:nil];
	NSString *numString = [param stringValueForKey:@"num" defaultValue:nil];
	NSInteger nums = [numString intValue];
	NSInteger pageNums = [pageStrint intValue];

	if (pageNums && nums) {
		if(pageNums<1) {
			pageNums = 1;
		}
		if(nums<1) {
			nums = 10;
		}
		NSInteger startNum = (pageNums - 1)*nums;
		NSInteger endNum = pageNums * nums;
		NSRange range = NSMakeRange(startNum, endNum);
		__auto_type list = [self.sqlite3 queryDataForClass:HNVideoList.class resultColumns:@[@"id",@"vod_id",@"vod_name",@"vod_pic",@"url",@"sort",@"key",@"status",@"progress"] conditions:nil orderBy:@[[SJSQLite3ColumnOrder orderWithColumn:@"id" ascending:NO]] range:range error:nil];

		NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"msg":@"操作成功！",@"code":@1}];
		if(list && list.count>0) {
			[ret setObject:[list copy] forKey:@"data"];
		}else{
			[ret setObject:@[] forKey:@"data"];
		}
		return ret;

	}else{
		return @{@"msg":@"没有要删除的数据",@"code":@0};
	}
}
JS_METHOD_SYNC(getVideoItemList:(UZModuleMethodContext *)context){
	SJSQLite3Logger.shared.enabledConsoleLog = YES;
	NSDictionary *param = context.param;
	NSString *vod_id_string = [param stringValueForKey:@"vod_id" defaultValue:nil];
	NSString *pageStrint = [param stringValueForKey:@"page" defaultValue:nil];
	NSString *numString = [param stringValueForKey:@"num" defaultValue:nil];
	NSInteger nums = [numString intValue];
	NSInteger pageNums = [pageStrint intValue];
	NSInteger vod_id = [vod_id_string intValue];
	if(vod_id<0) {
		return @{@"msg":@"数据有误",@"code":@0};
	}else{
		NSLog(@"当前的vod_id %ld",vod_id);
	}
	if (pageNums && nums) {
		if(pageNums<1) {
			pageNums = 1;
		}
		if(nums<1) {
			nums = 10;
		}
		NSInteger startNum = (pageNums - 1)*nums;
		NSInteger endNum = pageNums * nums;
		NSRange range = NSMakeRange(startNum, endNum);
		NSLog(@"vod_id is %ld %ld %ld",(long)vod_id,(long)pageNums,(long)nums);
		NSError *err = nil;

		__auto_type items = [self.sqlite3 queryDataForClass:HNVideoItem.class resultColumns:@[@"id",@"key",@"vod_id",@"status",@"url",@"progress",@"list_id"] conditions:@[[SJSQLite3Condition conditionWithColumn:@"vod_id" value:@(vod_id)]] orderBy:@[[SJSQLite3ColumnOrder orderWithColumn:@"sort" ascending:NO]] range:range error:&err];
		NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"msg":@"操作成功！",@"code":@1}];
		if(err) {
			NSLog(@"err %@",err);
		}
		if(items && items.count>0) {
			[ret setObject:[items copy] forKey:@"data"];
		}else{
			[ret setObject:@[] forKey:@"data"];
		}


		return ret;
	}else{
		return @{@"msg":@"页码和列表数有误",@"code":@0};
	}

}
#pragma mark - sqlite3data
@synthesize sqlite3 = _sqlite3;
- (SJSQLite3 *)sqlite3 {
	SJSQLite3Logger.shared.enabledConsoleLog = YES;
	if ( !_sqlite3 ) {
		NSString *defaultPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"mydata.db"];
		NSLog(@"defaultPath %@",defaultPath);
		_sqlite3 = [[SJSQLite3 alloc] initWithDatabasePath:defaultPath];

		NSError *err = nil;
		HNVideoList *videoList = [_sqlite3 objectForClass:HNVideoList.class primaryKeyValue:@(1) error:&err];
		if(err) {
			NSLog(@"err %@",err.userInfo);
			//创建表
			HNVideoList *videoList = HNVideoList.new;
			videoList.id =1;
			videoList.vod_name=@"测试";
			BOOL resultHNVideoList = [_sqlite3 save:videoList error:&err];
			if(err) {
				NSLog(@"创建videoList表失败！%@",err.userInfo);
			}else{
				NSLog(@"创建videoList表成功！");
				[_sqlite3 removeObjectForClass:HNVideoList.class primaryKeyValue:@(1) error:&err];
			}
			if(resultHNVideoList==NO) {
				NSLog(@"添加数据HNVideoList出错！");
			}
		}else{
			NSLog(@"HNVideoList数据表存在 %@",videoList);
		}
		if(videoList && videoList.vod_id == 0) {
			[_sqlite3 removeObjectForClass:HNVideoList.class primaryKeyValue:@(1) error:&err];
		}
		HNVideoItem *videoItem = [_sqlite3 objectForClass:HNVideoItem.class primaryKeyValue:@(1) error:&err];
		if(err) {
			NSLog(@"videoItem err %@",err.userInfo);
			//创建表
			HNVideoItem *videoItem = HNVideoItem.new;
			videoItem.id = 1;
			[_sqlite3 save:videoItem error:&err];
			if(err) {
				NSLog(@"videoItem err %@",err.userInfo);
			}else{
				NSLog(@"创建videoItem表成功！");
				[_sqlite3 removeObjectForClass:HNVideoItem.class primaryKeyValue:@(1) error:&err];
			}

		}else{
			NSLog(@"HNVideoList数据表存在 %@",videoItem);
		}
		if(videoItem && videoItem.list_id == 0) {
			[_sqlite3 removeObjectForClass:HNVideoItem.class primaryKeyValue:@(1) error:&err];
		}
	}


	return _sqlite3;
}
@end
