//
// Created by hainuo on 2021/3/22.
//

#import "HNVideoList.h"
#if __has_include(<YYModel/YYModel.h>)
#import <YYModel/NSObject+YYModel.h>
#elif __has_include(<YYKit/YYKit.h>)
#import <YYKit/YYKit.h>
#endif

@implementation HNVideoList
+ (nullable NSString *)sql_primaryKey {
    return @"id";
}
+ (nullable NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

- (NSString *)description {
#if __has_include(<YYModel/YYModel.h>)
    return [self yy_modelDescription];
#elif __has_include(<YYKit/YYKit.h>)
    return [self modelDescription];
#endif
    return [super description];
}
@end