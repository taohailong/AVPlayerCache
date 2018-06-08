//
//  TPlayerView.h
//  Pods
//
//  Created by hailong9 on 2017/9/19.
//
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
@protocol PlayerDelegate <NSObject>
@optional
- (void)playerVideoTotalTime:(int64_t)seconds;
- (void)playerTimeObserverCallBack:(int64_t)currentSeconds;
- (void)playerCacheDataRangeChangedCallBack:(int64_t)totalSeconds;
- (void)playerStartLoadingCallBack;
- (void)playerAlreadToPlay; // 可以获取到播放的视频信息了
- (void)playerBeginDisplay; //视频开始播放了
- (void)playerPlayCallBack;
- (void)playerOccureErrorCallBack;
- (void)playerPauseCallBack;
- (void)playerSeekCallBack:(int64_t)currentSeconds;
- (void)playerMonitorTimeCallBack:(int64_t)monitorTime;
- (void)playerPlayOver;
@end

@interface TPlayerView : UIView
@property (nonatomic, weak) id<PlayerDelegate> delegate;


- (instancetype)initWithFrame:(CGRect)frame withDelegate:(id<PlayerDelegate>)delegate;
- (void)loadVideoDataWithUrl:(NSString*)url withVideoName:(NSString*)videoName;

//  加载视频
- (void)loadVideoData;
- (void)setPreSeekTime:(NSUInteger)processTime;
- (int64_t)getPlayerTime;
- (BOOL)isAlreadyBegin;
//  视频播放控制
- (BOOL)isMute;
- (void)setVolume:(CGFloat)volume;
- (void)start;
- (void)pause;
//- (void)setViewFillMode:(UIViewContentMode)mode;
//- (UIViewContentMode)playerContentMode;
- (void)reset;
- (UIImage *)getVideoPlayerScreenshot;
- (void)playerSeekToSecond:(float)value;
- (void)setVideoMonitorTime:(NSUInteger)seconds;

//- (void)setVideoFillMode:(NSString *)fillMode;
@end
