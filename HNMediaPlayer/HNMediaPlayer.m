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
@interface HNMediaPlayer ()<MCSAssetExportObserver>
@property (nonatomic, strong) SJVideoPlayer *player;
@property (nonatomic, strong) SJBaseVideoPlayer *sjbPlayer;
@property (nonatomic, strong) SJSQLite3 *sqlite3;
@property (nonatomic,strong) NSTimer *timer;
@property (nonatomic,strong) NSString *preUrl;
@property (nonatomic,strong) SJEdgeControlButtonItem *playItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *nextItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *liveItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *currentTimeItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *separatorItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *durationTimeItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *progressItem;
@property (nonatomic,strong) SJEdgeControlButtonItem *fullItem;
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
    SJVideoPlayerConfigurations.shared.resources.progressThumbSize= 8.0;
    SJVideoPlayerConfigurations.shared.resources.progressThumbColor = [UIColor colorWithRed:2 / 256.0 green:141 / 256.0 blue:140 / 256.0 alpha:1];
    SJVideoPlayerConfigurations.shared.resources.moreSliderMaxRateValue=2.0;
    SJVideoPlayerConfigurations.shared.resources.moreSliderMaxRateImage= [SJVideoPlayerResourceLoader imageNamed:@"sj_video_player_maxRate"];

    _player.defaultEdgeControlLayer.loadingView.showsNetworkSpeed=YES;
	_player.autoplayWhenSetNewAsset=NO;
	_player.resumePlaybackWhenAppDidEnterForeground = YES;
	_player.defaultEdgeControlLayer.fixesBackItem = NO;
	_player.defaultEdgeControlLayer.showsMoreItem = NO;
	_player.rotationManager.disabledAutorotation = YES;
	_player.defaultEdgeControlLayer.titleView.scrollEnabled = NO;

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
	NSLog(@"rect %@",rect);

	NSLog(@"初始headers %@",headers);
	//不再对url进行任何处理 所有传入的url必须是正常的url也就是 经过urlencode转移过 query参数的url
//    url = [url stringByRemovingPercentEncoding];
//    NSLog(@"url %@",url);
//    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet  URLQueryAllowedCharacterSet]];
	NSLog(@"url %@",url);

	BOOL fixed = [param boolValueForKey:@"fixed" defaultValue:YES];

	float x = [rect floatValueForKey:@"x" defaultValue:0];
	float y = [rect floatValueForKey:@"y" defaultValue:0];
	float width = [rect floatValueForKey:@"width" defaultValue:[UIScreen mainScreen].bounds.size.width];
	float height = [rect floatValueForKey:@"height" defaultValue:300];

	SJVideoPlayerURLAsset *asset;
	if(referrer) {
		NSMutableDictionary * MGheaders = [NSMutableDictionary dictionary];
		[MGheaders setObject:referrer forKey:@"referrer"];
		if(userAgent) {

			[MGheaders setObject:userAgent forKey:@"user-agent"];
		}
		AVURLAsset *avUrlAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:url] options:@{@"AVURLAssetHTTPHeaderFieldsKey" : MGheaders}];

		asset = [[SJVideoPlayerURLAsset alloc] initWithAVAsset:avUrlAsset];
//        if(!headers){
//            headers = [NSString stringWithFormat:@"referer:%@\r\nuser-agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.102 Safari/537.36\r\n" ,referrer];
//        }

	}else{
		asset = [SJVideoPlayerURLAsset.alloc initWithURL:[NSURL URLWithString:url]];
	}
	NSLog(@"当前使用referre %@",referrer);


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
	}
	NSLog(@"最终headers %@",headers);


	if(title) {
		asset.title = title;
	}

	if(isLandscape) {
		NSLog(@"-90999-9-09-090-9-09-09-9-0");
		_player.automaticallyPerformRotationOrFitOnScreen = NO;
		_player.usesFitOnScreenFirst = YES;
	}

	if (@available(iOS 14.0, *)) {
		_player.defaultEdgeControlLayer.automaticallyShowsPictureInPictureItem = NO;
	} else {
		// Fallback on earlier versions
	}
	_player.playbackObserver.currentTimeDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
//	        NSLog(@"currentTimeDidChangeExeBlock %@",player);
	        NSDictionary *info =
			@{
	                @"type":@"currentTimeChanged",
	                MPNowPlayingInfoPropertyElapsedPlaybackTime:@(player.currentTime),
	                MPMediaItemPropertyPlaybackDuration:@(player.duration),
	                MPNowPlayingInfoPropertyPlaybackRate:@(player.rate)
		};
	        NSDictionary *ret = @{@"info":info};
	        [context callbackWithRet:ret err:nil delete:NO];
	};
	_player.playbackObserver.durationDidChangeExeBlock=^(__kindof SJBaseVideoPlayer *player){

//	        NSLog(@"durationDidChangeExeBlock %@",player);
	        NSDictionary *info =
			@{
	                @"type":@"durationChanged",
	                MPNowPlayingInfoPropertyElapsedPlaybackTime:@(player.currentTime),
	                MPMediaItemPropertyPlaybackDuration:@(player.duration),
	                MPNowPlayingInfoPropertyPlaybackRate:@(player.rate)
		};
	        NSDictionary *ret = @{@"info":info};
	        [context callbackWithRet:ret err:nil delete:NO];
	};
	_player.playbackObserver.timeControlStatusDidChangeExeBlock=^(__kindof SJBaseVideoPlayer *player){
	        NSLog(@"timeControlStatusChange %@",player);
	        NSDictionary *info =
			@{
	                @"type":@"timeControlStatusChanged",
	                MPNowPlayingInfoPropertyElapsedPlaybackTime:@(player.currentTime),
	                MPMediaItemPropertyPlaybackDuration:@(player.duration),
	                MPNowPlayingInfoPropertyPlaybackRate:@(player.rate),
	                @"timeWatched":@(player.durationWatched)
		};
	        NSDictionary *ret = @{@"info":info};
	        [context callbackWithRet:ret err:nil delete:NO];
	};
	_player.playbackObserver.assetStatusDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
	        NSLog(@"assetStatusDidChange %@ assetStatus %ld SJAssetStatusReadyToPlay %ld",player,player.assetStatus,SJAssetStatusReadyToPlay);

	        if(player.assetStatus == SJAssetStatusReadyToPlay) {
			[player play];
		}
	        if(player.assetStatus == SJAssetStatusFailed) {
			NSLog(@"当前链接加载失败，不能播放");
			self->_sjbPlayer = nil;
		}
	        NSDictionary *ret = @{@"status":@(player.assetStatus),@"type":@"assetStatus",@"msg":@"操作成功"};
	        [context callbackWithRet:ret err:nil delete:NO];
	};

	_player.playbackObserver.playbackStatusDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {

	        NSLog(@"playbackStatusDidChange %@ %ld 预加载状态 %ld %ld",player,(long)player.timeControlStatus,(long)SJPlaybackTimeControlStatusWaitingToPlay,(long)player.playbackType);
	        if(player.timeControlStatus == SJPlaybackTimeControlStatusPlaying) {
			self->_sjbPlayer = nil;
		}
	        [context callbackWithRet:@{@"code":@1,@"msg":@"ok",@"type":@"playbackStatus"} err:nil delete:NO];
	};
	_player.view.backgroundColor = UIColor.greenColor;
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
	_player.URLAsset = asset;
	[context callbackWithRet:@{@"code":@1,@"msg":@"播放设置成功！"} err:nil delete:YES];
    [self setBottomButtons];
}
-(void) setBottomButtons {
	[self setBottomButtons:false];
}
-(void) setTopButtons{
    //移除more按钮
//    SJEdgeControlButtonItem *moreItem = [_player.defaultEdgeControlLayer.topAdapter itemForTag:SJEdgeControlLayerTopItem_More];
//    if(moreItem){
//        [_player.defaultEdgeControlLayer.topAdapter removeItemForTag:SJEdgeControlLayerTopItem_More];
//    }
    
}
-(void) setBottomButtons:(BOOL)loading {

	//设置底部按钮等
	NSMutableArray<SJEdgeControlButtonItem *> *bottomButtonItems = [NSMutableArray arrayWithCapacity:2];
	NSLog(@" mutable Array %@",bottomButtonItems);
	//播放暂停按钮
    if(!_playItem){
        _playItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Play];
    }
	NSLog(@"playItem %@",_playItem);
	_playItem.size = 20;
	if(loading)
		_playItem.hidden=YES;
	else
		_playItem.hidden = NO;
    if(_playItem)
	[bottomButtonItems addObject:_playItem];

	//下一集按钮
	if(!_nextItem)
        _nextItem= [[SJEdgeControlButtonItem alloc] initWithImage:[SJVideoPlayerResourceLoader imageNamed:@"sj_video_player_next"] target:self action:@selector(nextPlayClick) tag:SJNextPlayItemTag];
	NSLog(@"nextItem %@",_nextItem);

	_nextItem.size=30;
	if(loading)
		_nextItem.hidden = YES;
	else
		_nextItem.hidden=NO;
    if(_nextItem)
	[bottomButtonItems addObject:_nextItem];


	//直播按钮
	if(!_liveItem)
        _liveItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_LIVEText];
	NSLog(@"liveItem %@",_liveItem);
	if(_liveItem) {
		_liveItem.hidden = YES;
		[bottomButtonItems addObject:_liveItem];
	}

	//当前进度时间
	if(!_currentTimeItem)
        _currentTimeItem= [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_CurrentTime];
	if(loading)
		_currentTimeItem.hidden = YES;
	else
		_currentTimeItem.hidden=NO;
    NSLog(@"currentTimeItem %@",_currentTimeItem);
    if(_currentTimeItem)
	[bottomButtonItems addObject:_currentTimeItem];

	//时间间隔
	if(!_separatorItem)
        _separatorItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Separator];
	if(loading)
		_currentTimeItem.hidden=YES;
	else
		_currentTimeItem.hidden = NO;
    NSLog(@"_separatorItem %@",_separatorItem);
    if(_separatorItem)
	[bottomButtonItems addObject:_separatorItem];



	//总时间
	if(!_durationTimeItem)
        _durationTimeItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_DurationTime];
	if(loading)
		_durationTimeItem.hidden=YES;
	else
		_durationTimeItem.hidden = NO;
    NSLog(@"_durationTimeItem %@",_durationTimeItem);
    if(_durationTimeItem)
	[bottomButtonItems addObject:_durationTimeItem];



	//播放进度条
	if(!_progressItem)
        _progressItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Progress];
	if(loading)
		_progressItem.hidden=YES;
	else
		_progressItem.hidden = NO;
    NSLog(@"_progressItem %@",_progressItem);
    if(_progressItem)
	[bottomButtonItems addObject:_progressItem];

	//调整播放速度


	//播放进度条
	if(!_fullItem)
        _fullItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Full];
	if(loading)
		_fullItem.hidden=YES;
	else
		_fullItem.hidden = NO;
    
    NSLog(@"_fullItem %@",_fullItem);
    if(_fullItem)
	[bottomButtonItems addObject:_fullItem];



	NSLog(@"bottomButtonItems %@",bottomButtonItems);
	if([bottomButtonItems count]>0) {
		[_player.defaultEdgeControlLayer.bottomAdapter removeAllItems];
		[_player.defaultEdgeControlLayer.bottomAdapter addItemsFromArray:bottomButtonItems];
		[_player.defaultEdgeControlLayer.bottomAdapter reload];
	}
}
- (void)reloadItemWasTappedForControlLayer:(id<SJControlLayer>)controlLayer {
	[self sendCustomEvent:@"" extra:_player.assetURL.absoluteURL];
	[_player refresh];
	[_player.switcher switchControlLayerForIdentifier:SJControlLayer_Edge];

}
- (void) nextPlayClick {
	if(_preUrl) {
		[_player pauseForUser];
	}

	[self sendCustomEvent:@"nextPlay" extra:@{@"code":@1,@"msg":@"播放下一集"}];
//	if(_player.isFullScreen) {
//		_player.rotationObserver.rotationDidEndExeBlock = ^(id<SJRotationManager>  _Nonnull mgr) {
//		        NSLog(@"界面切换了 全屏");
//		        if(!mgr.isFullscreen) {
//				[self showBaseVideoPlayer:self->_preUrl];
//			}
//		};
//		if ( _player.onlyUsedFitOnScreen ) {
//			[_player setFitOnScreen:!_player.isFitOnScreen];
//			return;
//		}
//
//		if ( _player.usesFitOnScreenFirst && !_player.isFitOnScreen ) {
//			[_player setFitOnScreen:YES];
//			return;
//		}
//
//		[_player rotate];
//        UIView *testView = [[UIView alloc] initWithFrame:CGRectMake(0,100, 100, 50)];
//        testView.backgroundColor=[UIColor yellowColor];
//        [_player.view addSubview:testView];
//	}else{
	NSLog(@"viviviviviiv");
	[self showBaseVideoPlayer:_preUrl];

//	}

}
- (void) showBaseVideoPlayer:(NSString *)preUrl {
	SJVideoPlayerURLAsset *asset = [[SJVideoPlayerURLAsset alloc] initWithURL:[NSURL URLWithString:preUrl]];

	if(_player.isFullScreen) {
		_player.URLAsset = asset;
		
        [_player.defaultEdgeControlLayer.bottomAdapter removeAllItems];
		_player.playbackObserver.playbackDidFinishExeBlock  = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
		        if(player.isPlaybackFinished) {
				[player play];
			}
		};

        //播放进度条
        SJEdgeControlButtonItem *progressItem = [_player.defaultEdgeControlLayer.bottomAdapter itemForTag:SJEdgeControlLayerBottomItem_Progress];
        progressItem.hidden=YES;

	}else{
		_sjbPlayer = SJBaseVideoPlayer.player;
		_sjbPlayer.rotationManager.autorotationSupportedOrientations=NO;
		_sjbPlayer.playbackObserver.playbackDidFinishExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull sjbPlayer) {
		        if(sjbPlayer.isPlaybackFinished) {
				[sjbPlayer play];
				//            if(self && self->_player){
				//                [self->_player play];
				//            }

			}

		};
		_sjbPlayer.view.backgroundColor= [UIColor blueColor];
		[_player.view addSubview:_sjbPlayer.view];
		//    _sjbPlayer.view.frame = _player.view.bounds;
		[_sjbPlayer.view mas_makeConstraints:^(MASConstraintMaker *make) {
		         make.edges.equalTo(_player.view);
		 }];
		_sjbPlayer.URLAsset = asset;
		[_sjbPlayer play];
	}

}

JS_METHOD(stop:(UZModuleMethodContext *)context){
	if(!_player) {
		[context callbackWithRet:@{@"msg":@"没有找到播放器",@"code":@0} err:nil delete:YES];
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
		return @{@"msg":@"没有找到播放器",@"code":@0};
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
		return @{@"msg":@"没有找到播放器",@"code":@0};
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
		return @{@"err":@{@"msg":@"没有找到播放器",@"code":@0}};
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
		return @{@"msg":@"没有找到播放器",@"code":@0};
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
		return @{@"msg":@"没有找到播放器",@"code":@0};
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
		return @{@"msg":@"没有找到播放器",@"code":@0};
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
	_player.rotationManager.autorotationSupportedOrientations = SJOrientationMaskPortrait;


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
