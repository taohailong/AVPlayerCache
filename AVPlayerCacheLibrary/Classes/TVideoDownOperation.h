//
//  VideoDownOperation.h
//  AVPlayerController
//
//  Created by hailong9 on 17/1/2.
//  Copyright © 2017年 hailong9. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "TVideoLoader.h"
typedef void (^VideoOperationStartBk)(void);
@interface TVideoDownOperation : NSOperation<NSURLSessionDataDelegate>
@property (assign,nonatomic) BOOL netReachable;
- (instancetype)initWithUrl:(NSURL*)url withRange:(NSRange)range;

- (NSUInteger)requestOffset;
- (NSUInteger)cacheLength;
//- (NSUInteger)requestLength;
- (void)setOperationStartBk:(VideoOperationStartBk)bk;
- (void)setDownCompleteBk:(VideoLoaderCompleteBk)bk;
- (void)setDownProcessBk:(VideoLoaderProcessBk)bk;
- (void)setDownRespondBk:(VideoLoaderRespondBk)bk;
//- (void)done;
@end
