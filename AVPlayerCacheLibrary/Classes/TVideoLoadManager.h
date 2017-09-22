//
//  VideoLoadManager.h
//  AVPlayerController
//
//  Created by hailong9 on 16/12/27.
//  Copyright © 2016年 hailong9. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "TVideoLoader.h"
#import "TVideoDownQueue.h"
@protocol VideoLoadManagerProtocol <NSObject>
@optional
- (void)requestNetError;
@end

@interface TVideoLoadManager : NSObject<AVAssetResourceLoaderDelegate,TVideoDownQueueProtocol>
@property (nonatomic,weak) id<VideoLoadManagerProtocol>delegate;
+ (NSString*)encryptionDownLoadUrl:(NSString*)url;
- (instancetype)initWithFileName:(NSString*)fileName;
- (BOOL)netWorkError;
- (void)setHTTPHeaderField:(NSDictionary*)header;
- (void)cancelDownLoad;
//- (void)networkReachable;  //断网重连

@end
