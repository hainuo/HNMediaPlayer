//
// Created by hainuo on 2021/3/22.
//

#import <Foundation/Foundation.h>


@interface HNVideoItem : NSObject
@property (nonatomic) NSInteger id; //序号
@property (nonatomic) NSInteger list_id; //影片序号
@property (nonatomic) int vod_id; //电影ID
@property (nonatomic, copy, nullable) NSString *url;//视频地址
@property (nonatomic) int sort;//第几集
@property (nonatomic, copy, nullable) NSString *key;//剧集名称
//typedef NS_ENUM(NSUInteger, MCSAssetExportStatus) {
//    MCSAssetExportStatusUnknown, 0 未知
//    MCSAssetExportStatusWaiting, 1 等待下载
//    MCSAssetExportStatusExporting, 2 下载中
//    MCSAssetExportStatusFinished, 3 完成
//    MCSAssetExportStatusFailed, 4 下载失败
//    MCSAssetExportStatusSuspended, 5 暂停
//    MCSAssetExportStatusCancelled, 6 取消
//};
@property (nonatomic) int status;//状态 0 1 2 3 4 5 6 见上面
@property (nonatomic) float progress;//进度条 仅当有过下载的时候有效
@end
