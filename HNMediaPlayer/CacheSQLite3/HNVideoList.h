//
// Created by hainuo on 2021/3/22.
//

#import <Foundation/Foundation.h>

@interface HNVideoList : NSObject
@property (nonatomic) NSInteger id; //序号
@property (nonatomic) int vod_id; //电影ID
@property (nonatomic, copy, nullable) NSString *vod_pic;//图片
@property (nonatomic, copy, nullable) NSString *vod_name;//影片名称

@property (nonatomic, copy, nullable) NSString *url;//正在下载的url
@property (nonatomic) int sort;//当前正在下载的数据序号
@property (nonatomic, copy, nullable) NSString *key;//当前正在下载的剧集名称
@property (nonatomic) int status;//当前正在处理的剧集状态
@property (nonatomic) float progress;//进度条 当前正在处理的剧集下载进度

@end
