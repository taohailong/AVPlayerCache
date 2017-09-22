//
//  VideoDownQueue.h
//  AVPlayerController
//
//  Created by hailong9 on 17/1/2.
//  Copyright © 2017年 hailong9. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "TVideoFileManager.h"
@class TVideoDownQueue;
@protocol TVideoDownQueueProtocol <NSObject>
@optional
- (void)loadNetError:(TVideoDownQueue*)downQueue;
@end

@interface TVideoDownQueue : NSObject
@property (nonatomic,assign) BOOL isNetworkError;
@property(nonatomic,strong)AVAssetResourceLoadingRequest*assetResource;
@property (nonatomic,weak) id<TVideoDownQueueProtocol>delegate;
- (instancetype)initWithFileManager:(TVideoFileManager *)fileManager WithLoadingRequest:(AVAssetResourceLoadingRequest *)resource loadingUrl:(NSURL*)url withHttpHead:(NSDictionary*)httpHead;
- (AVAssetResourceLoadingRequest*)assetResource;
- (void)sychronizeProcessToConfigure;
- (void)cancelDownLoad;
- (void)reloadAssetResource:(AVAssetResourceLoadingRequest*)request;

@end
