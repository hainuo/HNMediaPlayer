//
//  SJCustomControlLayerViewController.m
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2019/10/11.
//  Copyright © 2019 changsanjiang. All rights reserved.
//

#import "SJSwitchPlayRateControlLayerViewController.h"
#import <WebKit/WebKit.h>
#import <Masonry/Masonry.h>
#import <SJBaseVideoPlayer/SJBaseVideoPlayer.h>
#import <SJVideoPlayer/UIView+SJAnimationAdded.h>
#import "HNPlayRateListItem.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJSwitchPlayRateControlLayerViewController ()<UITableViewDataSource,UITableViewDelegate>
@property (nonatomic, strong, readonly) UIView *rightContainerView;
@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, weak, nullable) SJBaseVideoPlayer *player;
@property (nonatomic, readwrite) float rate;
@property (nonatomic, copy, nullable) NSArray<HNPlayRateListItem *> *playRateList;
@end

@implementation SJSwitchPlayRateControlLayerViewController
@synthesize restarted = _restarted;

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}
- (instancetype)initWithRate:(NSString *)playRate
{
    self = [super init];
    if (self) {
        self.rate = [playRate floatValue];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NSMutableArray *playRateList = @[].mutableCopy;
    HNPlayRateListItem *playRateItem1= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"0.25",@"selected":@"NO"}];
    HNPlayRateListItem *playRateItem2= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"0.5",@"selected":@"NO"}];
    HNPlayRateListItem *playRateItem3= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"0.75",@"selected":@"NO"}];
    HNPlayRateListItem *playRateItem4= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"1.0",@"selected":@"NO"}];
    HNPlayRateListItem *playRateItem5= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"1.25",@"selected":@"NO"}];
    HNPlayRateListItem *playRateItem6= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"1.5",@"selected":@"NO"}];
    HNPlayRateListItem *playRateItem7= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"1.75",@"selected":@"NO"}];
    HNPlayRateListItem *playRateItem8= [[HNPlayRateListItem alloc] configWithDictionary:@{@"rate":@"2.0",@"selected":@"NO"}];
    
    [playRateList addObject:playRateItem1];
    [playRateList addObject:playRateItem2];
    [playRateList addObject:playRateItem3];
    [playRateList addObject:playRateItem4];
    [playRateList addObject:playRateItem5];
    [playRateList addObject:playRateItem6];
    [playRateList addObject:playRateItem7];
    [playRateList addObject:playRateItem8];
    
    
    //初始化数据
    _playRateList=playRateList.copy;
    
    [self.view addSubview:self.rightContainerView];
    [_rightContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.right.bottom.offset(0);
    }];
    
    [_rightContainerView addSubview:self.tableView];
    [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.offset(0);
        if (@available(iOS 11.0, *)) {
            make.right.equalTo(self.rightContainerView.mas_safeAreaLayoutGuideRight);
        } else {
            make.right.offset(0);
        }
        CGRect bounds = UIScreen.mainScreen.bounds;
        make.width.offset(MIN(bounds.size.width, bounds.size.height));
        make.width.offset(150);
    }];
}


///
/// 控制层入场
///     当播放器将要切换到此控制层时, 该方法将会被调用
///     可以在这里做入场的操作
///
- (void)restartControlLayer {
    _restarted = YES;
    if ( self.player.isFullScreen ) [self.player needHiddenStatusBar];
    sj_view_makeAppear(self.controlView, YES);
    sj_view_makeAppear(self.rightContainerView, YES);
}


///
/// 退出控制层
///     当播放器将要切换到其他控制层时, 该方法将会被调用
///     可以在这里处理退出控制层的操作
///
- (void)exitControlLayer {
    _restarted = NO;
    
    sj_view_makeDisappear(self.rightContainerView, YES);
    sj_view_makeDisappear(self.controlView, YES, ^{
        if ( !self->_restarted ) [self.controlView removeFromSuperview];
    });
}

///
/// 控制层视图
///     当切换为当前控制层时, 该视图将会被添加到播放器中
///
- (UIView *)controlView {
    return self.view;
}

///
/// 当controlView被添加到播放器时, 该方法将会被调用
///
- (void)installedControlViewToVideoPlayer:(__kindof SJBaseVideoPlayer *)videoPlayer {
    _player = videoPlayer;
    
    if ( self.view.layer.needsLayout ) {
        sj_view_initializes(self.rightContainerView);
    }
    
    sj_view_makeDisappear(self.rightContainerView, NO);
}

///
/// 当调用播放器的controlLayerNeedAppear时, 播放器将会回调该方法
///
- (void)controlLayerNeedAppear:(__kindof SJBaseVideoPlayer *)videoPlayer {}

///
/// 当调用播放器的controlLayerNeedDisappear时, 播放器将会回调该方法
///
- (void)controlLayerNeedDisappear:(__kindof SJBaseVideoPlayer *)videoPlayer {}

///
/// 当将要触发某个手势时, 该方法将会被调用. 返回NO, 将不触发该手势
///
- (BOOL)videoPlayer:(__kindof SJBaseVideoPlayer *)videoPlayer gestureRecognizerShouldTrigger:(SJPlayerGestureType)type location:(CGPoint)location {
    if ( type == SJPlayerGestureType_SingleTap ) {
        if ( !CGRectContainsPoint(self.rightContainerView.frame, location) ) {
            if ( [self.delegate respondsToSelector:@selector(tappedBlankAreaOnTheControlLayer:)] ) {
                [self.delegate tappedBlankAreaOnTheControlLayer:self];
            }
        }
    }
    return NO;
}


///
/// 当将要触发旋转时, 该方法将会被调用. 返回NO, 将不触发旋转
///
- (BOOL)canTriggerRotationOfVideoPlayer:(__kindof SJBaseVideoPlayer *)videoPlayer {
    return NO;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

#pragma mark -

@synthesize rightContainerView = _rightContainerView;
- (UIView *)rightContainerView {
    if ( _rightContainerView == nil ) {
        _rightContainerView = [UIView.alloc initWithFrame:CGRectZero];
        _rightContainerView.backgroundColor = UIColor.blackColor;
        _rightContainerView.sjv_disappearDirection = SJViewDisappearAnimation_Right;
    }
    return _rightContainerView;
}

@synthesize tableView = _tableView;
- (UITableView *)tableView {
    if ( _tableView == nil ) {
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        
    }
    return _tableView;
}

#pragma mark UITableViewDatasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.playRateList.count;
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *cellID = @"playRateItemCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if(!cell){
        cell =[[UITableViewCell alloc]  initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        HNPlayRateListItem *playRateItem = [self.playRateList objectAtIndex:indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"X %0.2f", [playRateItem.rate floatValue] ];
        if([playRateItem.rate isEqualToString:[NSString stringWithFormat:@"%0.2f",self.rate]]){
            cell.textLabel.highlighted = YES;
            cell.textLabel.highlightedTextColor =[UIColor colorWithRed:2 / 256.0 green:141 / 256.0 blue:140 / 256.0 alpha:1];
        }

    }
    
    
    return cell;
}

#pragma mark UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 30;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"当前选定 %@",indexPath);
    HNPlayRateListItem *playRateItem = [self.playRateList objectAtIndex:indexPath.row];
    self.rate = [playRateItem.rate floatValue];
    playRateItem.selected = YES;
    NSMutableArray *playRateList = self.playRateList.mutableCopy;
    [playRateList replaceObjectAtIndex:indexPath.row withObject:playRateItem];
    [tableView reloadData];
    //事件发送
    [[NSNotificationCenter defaultCenter] postNotificationName:@"playRatechanged" object:@{@"rate":playRateItem.rate}];
    NSLog(@"当前选定 %@",playRateItem);
}

@end
NS_ASSUME_NONNULL_END

