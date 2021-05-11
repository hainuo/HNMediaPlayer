//
//  HNPlayRateListItem.h
//  HNMediaPlayer
//
//  Created by hainuo on 2021/5/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HNPlayRateListItem : NSObject
@property (nonatomic,copy,readwrite) NSString *rate;
@property (nonatomic,readwrite) BOOL selected;

-(instancetype) configWithDictionary:(NSDictionary *)dictionary;
@end
NS_ASSUME_NONNULL_END
