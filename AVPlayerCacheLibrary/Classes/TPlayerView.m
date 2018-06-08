//
//  TPlayerView.m
//  Pods
//
//  Created by hailong9 on 2017/9/19.
//
//

#import "TPlayerView.h"
#import "TVideoLoadManager.h"
#import "TVideoFileManager.h"
@interface TPlayerView()<VideoLoadManagerProtocol>
{
    NSUInteger _preSeekTime;
    TVideoLoadManager* _videoLoader;
}
@property (nonatomic, strong, nullable) AVPlayerItem *avPlayerItem;
@property (nonatomic, strong, nullable) AVPlayer *avPlayer;

@end
@implementation TPlayerView{
    BOOL _isObservered;
    BOOL _isReadyToPlay;
    NSString* _videoName;
    NSString* _videoUrl;
    id _timeObserver;
    id _playbackTimeObserver;
    BOOL _isMute;
    NSInteger _monitorTime;
    dispatch_queue_t _serial;
}
- (instancetype)initWithFrame:(CGRect)frame withDelegate:(id<PlayerDelegate>)delegate
{
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = delegate;
       _serial = dispatch_queue_create("com.weibo.videoViewQueue", DISPATCH_QUEUE_SERIAL);
        // 监听播放结束
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
         [self.layer addObserver:self forKeyPath:@"readyForDisplay" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}


- (void)loadVideoDataWithUrl:(NSString*)url withVideoName:(NSString*)videoName
{
    _videoUrl = url;
    _videoName = videoName;
    [self loadVideoData];
}

- (void)setVideoMonitorTime:(NSUInteger)seconds
{
    if (_avPlayerItem && _avPlayerItem.duration.timescale != 0) {
        [self addPlayerTimeObserve:seconds];
    }else{
        _monitorTime = seconds;
    }
}

- (void)addPlayerTimeObserve:(NSUInteger)seconds
{
    if (seconds ==0 || [self.delegate respondsToSelector:@selector(playerMonitorTimeCallBack:)] == NO || _timeObserver) {
        return;
    }
    NSUInteger value = _avPlayerItem.duration.value / _avPlayerItem.duration.timescale;
    if (value<seconds) {
        return;
    }
    __weak  TPlayerView* weak_self = self;
//    DefineWeak(self);
    CMTime interval = CMTimeMakeWithSeconds(value-seconds, NSEC_PER_SEC);
    NSValue * timeOb = [NSValue valueWithCMTime:interval];
    _timeObserver = [_avPlayer addBoundaryTimeObserverForTimes:@[timeOb]
                                                         queue:dispatch_get_main_queue()
                                                    usingBlock:^{
                                                        [weak_self.delegate playerMonitorTimeCallBack:4];
                                                    }];
}


- (void)initAVElements
{
    dispatch_async(_serial, ^{
        AVURLAsset *videoAsset = [self generateAVURLAsset];
        if (videoAsset == nil){
            [self playerStatusOccureError];
            return;
        }
        [self removeAVObservers];
        self.avPlayerItem = [AVPlayerItem playerItemWithAsset:videoAsset];
        [self setupAVObserver:self.avPlayerItem];
        __weak  TPlayerView* weak_self = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weak_self.avPlayer == nil) {
                weak_self.avPlayer = [AVPlayer playerWithPlayerItem:weak_self.avPlayerItem];
                weak_self.avPlayer.muted = _isMute;
                [(AVPlayerLayer*)[self layer] setPlayer:weak_self.avPlayer];
            }else{
                [weak_self.avPlayer replaceCurrentItemWithPlayerItem:weak_self.avPlayerItem];
            }
        });
    });
}

//- (UIViewContentMode)playerContentMode{
//    return _avView.contentMode;
//}

- (void)setViewFillMode:(UIViewContentMode)mode
{
    AVPlayerLayer *playerLayer = (AVPlayerLayer*)[self layer];
    if (mode == UIViewContentModeScaleAspectFit) {
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    } else if (mode == UIViewContentModeScaleAspectFill) {
         playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
}


#pragma mark - Helper

- (AVURLAsset *)generateAVURLAsset
{
    AVURLAsset *videoAsset = nil;
    if ([_videoUrl hasSuffix:@".m3u8"]) {
        videoAsset = [AVURLAsset assetWithURL:[NSURL URLWithString:_videoUrl]];
        return videoAsset;
    }
    if ( [TVideoFileManager hasFinishedVideoCache:_videoName]) {  //区分 直播和 点播
       videoAsset = [AVURLAsset assetWithURL:[TVideoFileManager cacheFileExistsWithName:_videoName]];
    } else  {
        videoAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:[TVideoLoadManager encryptionDownLoadUrl:_videoUrl]]  options:nil];
        _videoLoader = [[TVideoLoadManager alloc]initWithFileName:_videoName];
        _videoLoader.delegate = self;
        [videoAsset.resourceLoader setDelegate:_videoLoader queue:dispatch_get_global_queue(0, 0)];
    }
    return videoAsset;
}

#pragma mark - Load manager

- (void)requestNetError{
    NSLog(@"downLoad net work error");
//    [_avPlayerItem.asset cancelLoading];
    [_videoLoader cancelDownLoad];
}


- (NSTimeInterval)availableDuration
{
    //  计算缓冲进度
    NSArray *loadedTimeRanges = [[self.avPlayer currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;
    return result;
}

- (NSURL *)schemeVideoUrl:(NSString*)url
{
    //  视频本地缓存URL格式化
    if (url) {
        NSString *scheme = [[NSURL URLWithString:url] scheme];
        NSRange mp4Range = [url rangeOfString:@".mp4"];
        NSRange httpRange = [url rangeOfString:@"http"];
        if (mp4Range.length != 0 && httpRange.length != 0) {
            url = [url stringByReplacingOccurrencesOfString:scheme withString:@"wkvdo"];
        }
    }
    return url ? [NSURL URLWithString:url] : nil;
}

#pragma mark - AVFoundation

- (void)removeAVObservers
{
    if (self.avPlayerItem == nil) {
        return;
    }
    
    if (self.avPlayerItem) {
        [self.avPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
        [self.avPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
        [self.avPlayerItem removeObserver:self forKeyPath:@"playbackBufferEmpty" context:nil];
        [self.avPlayerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp" context:nil];
        self.avPlayerItem = nil;
    }
    
    if (_playbackTimeObserver) {
        [_avPlayer removeTimeObserver:_playbackTimeObserver];
        _playbackTimeObserver = nil;
    }
    if (_timeObserver) {
        [_avPlayer removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
}

- (void)setupAVObserver:(AVPlayerItem*)item
{
    //  监听playbackLikelyToKeepUp
    if ([NSThread isMainThread] == NO) {
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
            [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
            [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
            [self.layer addObserver:self forKeyPath:@"readyForDisplay" options:NSKeyValueObservingOptionNew context:nil];
        });
    } else {
        [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
        [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
        [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state != UIApplicationStateActive) {
        return;
    }
    
    if ([keyPath isEqualToString:@"readyForDisplay"]) {
        AVPlayerLayer* layer = object;
        if ( layer.readyForDisplay) {
            if([self.delegate respondsToSelector:@selector(playerBeginDisplay)]){
                [self.delegate playerBeginDisplay];
            }
        }
        return;
    }
    
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        
        if ([playerItem status] == AVPlayerStatusReadyToPlay)
        {
            [self readyToPlay:playerItem];
        }else if ([playerItem status] == AVPlayerStatusFailed) {
            [self detectPlayerError:playerItem];
            NSLog(@"player error is %@",playerItem.error);
        }else{
            NSLog(@"AVPlayerStatusUnknown ");
        }
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        //  缓冲进度变化
        [self playerStatusLoadedTimeRangeChanged];
    }
    else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        return;
        
    }
    else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"])
    {
        BOOL isKeepup = playerItem.playbackLikelyToKeepUp;
        if (isKeepup == NO) {
            if ( [_videoLoader netWorkError]) {
                [playerItem.asset cancelLoading];
                [self playerStatusOccureError];
            } else {
                [self playerStatusStartLoading];
            }
        }
        else {
//            [self start];
        }
    }
}


- (BOOL)checkCacheIsCoverSeekTime:(NSUInteger)time
{
    NSArray *loadedTimeRanges = [[self.avPlayer currentItem] loadedTimeRanges];
    for (NSValue* temp in  loadedTimeRanges) {
        CMTimeRange timeRange = [temp CMTimeRangeValue];
        int startSeconds = CMTimeGetSeconds(timeRange.start);
        int durationSeconds = CMTimeGetSeconds(timeRange.duration);
        if (durationSeconds == 0) {
            return NO;
        }
        
        if (time > durationSeconds + startSeconds) {
            return NO;
        }
        return YES;
    }
    return NO;
}

#pragma mark- videoStatusChanged


- (void)playerStatusLoadedTimeRangeChanged
{
    NSTimeInterval timeInterval = [self availableDuration];
    if ([self.delegate respondsToSelector:@selector(playerCacheDataRangeChangedCallBack:)]) {
        [self.delegate playerCacheDataRangeChangedCallBack:timeInterval];
    }
}


- (void)playerStatusStartLoading
{
    if ([self.delegate respondsToSelector:@selector(playerStartLoadingCallBack)]) {
        [self.delegate playerStartLoadingCallBack];
    }
}

- (void)playerStatusOccureError
{
    if ([self.delegate respondsToSelector:@selector(playerOccureErrorCallBack)]) {
        [self.delegate playerOccureErrorCallBack];
    }
}


- (void)detectPlayerError:(AVPlayerItem*)playerItem
{
    [self playerStatusOccureError];
    return;
}

#pragma mark  - 对外回调接口

- (void)setPreSeekTime:(NSUInteger)processTime
{
    _preSeekTime = processTime;
}

- (BOOL)isMute
{
    return _isMute;
}

- (void)setVolume:(CGFloat)volume
{
    if (volume == 0) {
        self.avPlayer.muted = YES;
        _isMute = YES;
    }
    if (volume == 1) {
        self.avPlayer.muted = NO;
        _isMute = NO;
    }
}


- (BOOL)isAlreadyBegin
{
    return self.avPlayerItem.status == AVPlayerItemStatusReadyToPlay ? YES:NO;
}

- (int64_t)getPlayerTime
{
    if (self.avPlayerItem.duration.value == self.avPlayerItem.currentTime.value) {
        //已经播放到最后   返回时间为0
        return 0;
    }
    if (self.avPlayerItem.currentTime.timescale == 0) {
        return 0;
    }
    int64_t currentSecond = self.avPlayerItem.currentTime.value / self.avPlayerItem.currentTime.timescale;
    
    return currentSecond;
}

- (void)playerSeekToSecond:(float)value
{
    if (value < 0) {
        return;
    }
    if (self.avPlayerItem.status == AVPlayerItemStatusReadyToPlay) {
        //  跳至指定帧
        __weak typeof(self) blockSelf = self;
        
//        BOOL isPause = NO;
//        if (self.status == WKVideoViewStatusPause) {
//            isPause = YES;
//        }
        [_avPlayerItem cancelPendingSeeks];
        [self.avPlayer pause];
        __weak typeof(_videoLoader) weak__videoLoader = _videoLoader;
        [self playerStatusStartLoading];
        [_avPlayer seekToTime:CMTimeMakeWithSeconds(value, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
            
            if ([blockSelf.delegate respondsToSelector:@selector(playerSeekCallBack:)]) {
                [blockSelf.delegate playerSeekCallBack:value];
            }
            
            if (blockSelf.avPlayerItem.currentTime.timescale == 0 ||  finished == NO) {
                return ;
            }
            if ([weak__videoLoader netWorkError] == YES) {
                if ( [blockSelf checkCacheIsCoverSeekTime:value] == NO) {
                    [blockSelf playerStatusOccureError];
                    return;
                }
            }
            [blockSelf start];
        }];
    }
}

- (void)readyToPlay:(AVPlayerItem *)playerItem
{
    if (playerItem == nil || playerItem.duration.timescale == 0) {
        [self playerStatusOccureError];
        return;
    }
    if ([self.delegate respondsToSelector:@selector(playerAlreadToPlay)]) {
        [self.delegate playerAlreadToPlay];
    }
    [self start];
//    self.backgroundColor = [UIColor redColor];
//    self.layer.backgroundColor = [UIColor redColor].CGColor;
//    _status = WKVideoViewStatusReady;
    _isReadyToPlay = YES;
    
    CGFloat totalSecond = 0; //  计算视频时长
    if (playerItem.duration.timescale != 0) {
        totalSecond = playerItem.duration.value / playerItem.duration.timescale;
    }
    [self addPlayerTimeObserve:_monitorTime]; // 时间回调
    
    if (_preSeekTime) {
        [self playerSeekToSecond:_preSeekTime];
        _preSeekTime = 0;
    }
    if ( [self.delegate respondsToSelector:@selector(playerVideoTotalTime:)]) {
        [self.delegate playerVideoTotalTime:totalSecond];
    }

    //  添加定期观察者，更新播放进度UI
    [self monitoringPlayback:playerItem];
    
}

- (void)startLoadingInPlay
{
//    _status = WKVideoViewStatusLoadingInPlay;
    if ([self.delegate respondsToSelector:@selector(playerStartLoadingCallBack)]) {
        [self.delegate playerStartLoadingCallBack];
    }
}


- (void)monitoringPlayback:(AVPlayerItem *)playerItem
{
    if (!_playbackTimeObserver) {
        __weak typeof(self) blockSelf = self;
        _playbackTimeObserver = [self.avPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
            //  拖拽进度时，不更新播放进度
            if ([blockSelf.delegate respondsToSelector:@selector(playerTimeObserverCallBack:)]) {
                int64_t currentSecond = time.value / time.timescale;
                [blockSelf.delegate playerTimeObserverCallBack:currentSecond];
            }
        }];
    }
}

#pragma mark - VideoPlayer API

- (void)loadVideoData
{
//    if (_status != WKVideoViewStatusLoading) {
//        [self playerStatusStartLoading];
//    }
    [self initAVElements];
}


- (void)start
{
    if (self.avPlayerItem.status == AVPlayerStatusReadyToPlay) {
//        _status = WKVideoViewStatusPlay;
        if ([self.delegate respondsToSelector:@selector(playerPlayCallBack)]) {
            [self.delegate playerPlayCallBack];
        }
        [self.avPlayer play];
    }
}

- (void)pause
{
    if (self.avPlayerItem.status == AVPlayerStatusReadyToPlay) {
//        _status = WKVideoViewStatusPause;
        [self.avPlayer pause];
    }
}

- (void)reset
{
    dispatch_async(_serial, ^{
        [_videoLoader cancelDownLoad];
        _videoLoader = nil;
        [self.avPlayerItem.asset cancelLoading];
        AVURLAsset* temp = (AVURLAsset*)self.avPlayerItem.asset;
        [temp.resourceLoader setDelegate:nil queue:nil];
        if ([NSThread isMainThread] == NO) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                 AVPlayerLayer* layer =  (AVPlayerLayer* )self.layer;
                [layer setPlayer:nil];
            });
        }else{
            AVPlayerLayer* layer = (AVPlayerLayer* ) self.layer;
            [layer setPlayer:nil];
        }
        [self removeAVObservers];
        _isReadyToPlay = NO;
        self.avPlayer = nil;
    });
}

- (UIImage *)getVideoPlayerScreenshot {
    AVURLAsset *asset = (AVURLAsset *)self.avPlayerItem.asset;
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    CGImageRef thumb = [imageGenerator copyCGImageAtTime:self.avPlayerItem.currentTime
                                              actualTime:NULL
                                                   error:NULL];
    UIImage *videoImage = [UIImage imageWithCGImage:thumb];
    CGImageRelease(thumb);
    return videoImage;
}


- (void)dealloc
{
    [self removeAVObservers];
    [self.layer removeObserver:self forKeyPath:@"readyForDisplay" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)videoPlayDidEnd:(NSNotification *)notification
{
    if (self.avPlayerItem != notification.object) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(playerPlayOver)]) {
        [self.delegate playerPlayOver];
    }
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
