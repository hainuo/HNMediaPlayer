//
//  HNPlayRateListItem.m
//  HNMediaPlayer
//
//  Created by hainuo on 2021/5/11.
//

#import "HNPlayRateListItem.h"

@implementation HNPlayRateListItem

-(instancetype) configWithDictionary:(NSDictionary *)dictionary{
    self.rate = [NSString stringWithFormat:@"%0.2f", [[dictionary objectForKey:@"rate"] floatValue] ];
    self.selected = [[dictionary objectForKey:@"selected"] boolValue];
    
    return self;
}

@end
