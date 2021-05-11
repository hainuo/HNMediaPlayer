//
//  SJSwitchPlayRateControlLayerViewController.h
//  HNMediaPlayer
//
//  Created by hainuo on 2021/5/11.
//

#import <UIKit/UIKit.h>
#import <SJVideoPlayer/SJControlLayerDefines.h>
@protocol SJSwitchPlayRateControlLayerViewControllerDelegate;


NS_ASSUME_NONNULL_BEGIN

@interface SJSwitchPlayRateControlLayerViewController : UIViewController<SJControlLayer>

@property (nonatomic, weak, nullable) id<SJSwitchPlayRateControlLayerViewControllerDelegate> delegate;
@end

@protocol SJSwitchPlayRateControlLayerViewControllerDelegate <NSObject>
///
/// 点击空白区域的回调
///
- (void)tappedBlankAreaOnTheControlLayer:(id<SJControlLayer>)controlLayer;
@end

NS_ASSUME_NONNULL_END
