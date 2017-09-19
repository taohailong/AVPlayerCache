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
@interface TVideoDownQueue : NSObject
@property (nonatomic,assign) BOOL isNetworkError;
@property (nonatomic,copy) NSDictionary* httpHeader;
- (instancetype)initWithFileManager:(TVideoFileManager *)fileManager WithLoadingRequest:(AVAssetResourceLoadingRequest *)resource loadingUrl:(NSURL*)url;
- (AVAssetResourceLoadingRequest*)assetResource;
- (void)sychronizeProcessToConfigure;
- (void)cancelDownLoad;
- (void)reloadAssetResource:(AVAssetResourceLoadingRequest*)request;
@property(nonatomic,strong)AVAssetResourceLoadingRequest*assetResource;
@end
