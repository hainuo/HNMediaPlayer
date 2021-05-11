//
//  SJSwitchVideoPlayRateControlLayer.h
//
//  Created by 海诺 on 2021/5/10.
//

#import "SJEdgeControlLayerAdapters.h"
#import <SJVideoPlayer/SJControlLayerDefines.h>
#import <SJVideoPlayer/SJEdgeControlLayerAdapters.h>
#import <SJVideoPlayer/SJVideoPlayerURLAsset+SJExtendedDefinition.h>
#import "HNRateListItem.h"

#pragma mark - 切换播放速率时的控制层

@protocol SJSwitchVideoPlayRateControlLayerDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface SJSwitchVideoPlayRateControlLayer : SJEdgeControlLayerAdapters<SJControlLayer>

@property (nonatomic, copy, nullable) NSArray<HNRateListItem *> *assets;

@property (nonatomic, weak, nullable) id<SJSwitchVideoPlayRateControlLayerDelegate> delegate;

@property (nonatomic, strong, null_resettable) UIColor *selectedTextColor;
@end

@protocol SJSwitchVideoPlayRateControlLayerDelegate <NSObject>

- (void)controlLayer:(SJSwitchVideoPlayRateControlLayer *)controlLayer didSelectAsset:(HNRateListItem *)asset;

- (void)tappedBlankAreaOnTheControlLayer:(id<SJControlLayer>)controlLayer;

@end
NS_ASSUME_NONNULL_END
