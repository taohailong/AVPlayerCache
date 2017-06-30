//
//  TViewController.m
//  AVPlayerCacheLibrary
//
//  Created by hailong9 on 02/24/2017.
//  Copyright (c) 2017 hailong9. All rights reserved.
//

#import "TViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVPlayerCacheLibrary/AVPlayerCacheLibrary-umbrella.h>
@interface TViewController ()
{
    AVPlayerItem* _playerItem;
    AVPlayer* _player;
    TVideoLoadManager* _downLoadManager;
    int _currentTime;
    UISlider* timeProgress;

}
@end

@implementation TViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

//    _playerItem = [AVPlayerItem playerItemWithAsset:[self generatePlayItem:@"http://gslb.miaopai.com/stream/p2H9cJpKXYlFCW9O93O0gw__.mp4?yx=&KID=unistore,video&Expires=1488963625&ssig=ygmImhzt%2FO"]];
    
    _playerItem = [AVPlayerItem playerItemWithAsset:[self generatePlayItem:@"http://gslb.miaopai.com/stream/QgZbuZjY70~LOyicMJz9NQ__.mp4?yx=&KID=unistore,video&Expires=1488340984&ssig=9xbm%2BqHngF"]];
    UIButton* bt = [UIButton buttonWithType:UIButtonTypeCustom];
    [bt setTitle:@"清理缓存" forState:UIControlStateNormal];
    bt.frame = CGRectMake(50, self.view.frame.size.height - 60, 80, 30);
    [self.view addSubview:bt];
    bt.backgroundColor = [UIColor redColor];
    [bt addTarget:self action:@selector(playerSkip) forControlEvents:UIControlEventTouchUpInside];
    
    
    UIButton* bt1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [bt1 setTitle:@"start" forState:UIControlStateNormal];
    bt1.frame = CGRectMake(250, self.view.frame.size.height - 100, 80, 30);
    [self.view addSubview:bt1];
    bt1.backgroundColor = [UIColor redColor];
    [bt1 addTarget:self action:@selector(startPlay) forControlEvents:UIControlEventTouchUpInside];
    
    
    timeProgress = [[UISlider alloc]initWithFrame:CGRectMake(0, self.view.frame.size.height - 30, self.view.frame.size.width, 30)];
    timeProgress.minimumValue = 0;
    timeProgress.maximumValue = 0;
    [self.view addSubview:timeProgress];
    [timeProgress addTarget:self action:@selector(sliderChange:) forControlEvents:UIControlEventTouchUpInside];

	// Do any additional setup after loading the view, typically from a nib.
}
- (void)startPlay
{
    if (_player == nil) {
        _player = [AVPlayer playerWithPlayerItem:_playerItem];
        [self setupAVObserver];
        AVPlayerLayer* layer = [AVPlayerLayer playerLayerWithPlayer:_player];
        layer.frame = self.view.bounds;
        [self.view.layer addSublayer:layer];
    }
}


- (void)playerSkip
{
    [_player pause];
    [TVideoFileManager clearCache];
    UIAlertView* alert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"确定重新启动" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    exit(0);
}

- (void)playerSeekTo:(NSUInteger)value
{
    [_player pause];
    [_player seekToTime:CMTimeMakeWithSeconds(value, NSEC_PER_SEC)  completionHandler:^(BOOL finished) {
        [_player play];
    }];
}



- (void)sliderChange:(UISlider*)value
{
    [self playerSeekTo:value.value];
}


- (void)setupAVObserver
{
    NSLog(@"######## addAVObserver");
    [_playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        if ([playerItem status] == AVPlayerStatusReadyToPlay)
        {
            CGFloat totalSecond = 0;
            if (playerItem.duration.timescale != 0) {
                totalSecond = playerItem.duration.value / playerItem.duration.timescale;
            }
            timeProgress.maximumValue = totalSecond;
            NSLog(@"status is ok");
            [_player play];
        }
        else if ([playerItem status] == AVPlayerStatusFailed) {
            NSLog(@"AVPlayerStatusFailed ");
        }
        else
        {
            NSLog(@"AVPlayerStatusUnknown ");
        }
        
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"])
    {
        NSArray * array = playerItem.loadedTimeRanges;
        CMTimeRange timeRange = [array.firstObject CMTimeRangeValue]; //本次缓冲的时间范围
        NSTimeInterval totalBuffer = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration); //缓冲总长度
    }   else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        BOOL isKeepup = playerItem.playbackLikelyToKeepUp;
        NSLog(@"change %d playbackBufferEmpty  %@",isKeepup,playerItem.playbackBufferEmpty?@"YES":@"NO");
        if (isKeepup) {
            [_player play];
        }
        
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
    }
}


- (AVURLAsset*)generatePlayItem:(NSString*)url
{
    AVURLAsset *videoAsset = nil;
    videoAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:[TVideoLoadManager encryptionDownLoadUrl:url]]  options:nil];
    _downLoadManager = [[TVideoLoadManager alloc]initWithFileName:@"temp2"];
    [videoAsset.resourceLoader setDelegate:_downLoadManager queue:dispatch_get_global_queue(0, 0)];
    
    return videoAsset;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
