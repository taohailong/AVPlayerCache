//
//  VideoLoader.h
//  AVPlayerController
//
//  Created by hailong9 on 16/12/26.
//  Copyright © 2016年 hailong9. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "TVideoFileManager.h"
typedef void (^VideoLoaderProcessBk)(NSUInteger offset,NSData*data);
typedef void (^VideoLoaderCompleteBk)(NSError* error,NSUInteger offset,NSUInteger length);
typedef void(^VideoLoaderRespondBk)(NSUInteger length,NSString*meidaType);

@protocol VideoLoaderProtocol <NSObject>
@optional
- (void)videoLoaderConfigure:(NSMutableURLRequest*)request;
- (void)videoLoaderProcessOffset:(NSUInteger)offset  data:(NSData*)receiveData;
- (void)videoLoaderComplete:(NSError*)error;
- (void)videoLoaderRespond:(NSUInteger)length withMediaType:(NSString*)type;
@end

@interface TVideoLoader : NSObject<NSURLConnectionDataDelegate, NSURLSessionDataDelegate>
{
}
@property(nonatomic,strong) AVAssetResourceLoadingRequest*  assetResource;
@property(nonatomic,weak) TVideoFileManager* fileManager;

- (instancetype)initWithUrl:(NSURL*)url withRange:(NSRange)range WithDelegate:(id<VideoLoaderProtocol>)delegate;
- (instancetype)initWithUrl:(NSURL*)url withRange:(NSRange)range;

- (void)setCompleteBk:(VideoLoaderCompleteBk)bk;
- (void)setProcessBk:(VideoLoaderProcessBk)bk;
- (void)setRespondBk:(VideoLoaderRespondBk)bk;

- (NSUInteger)requestOffset;
- (NSUInteger)cacheLength;
- (NSUInteger)requestLength;

- (void)start;
- (void)cancel;
- (void)videoLoaderSychronizeProcessToConfigure;
@end
