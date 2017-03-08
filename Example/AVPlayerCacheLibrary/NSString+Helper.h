//
//  NSString+Helper.h
//  Test
//
//  Created by hailong9 on 17/3/7.
//  Copyright © 2017年 hailong9. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Helper)
+(NSString *) localWiFiIPAddress;
+ (NSString *) currentWifiSSID;
+ (NSString*)lookupHostIPAddressForURL:(NSURL*)url;
@end
