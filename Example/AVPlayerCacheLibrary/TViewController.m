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
//#import <AVPlayerCacheLibrary/TPlayerView.h>
@interface TViewController ()<PlayerDelegate>
{
//    AVPlayerItem* _playerItem;
//    AVPlayer* _player;
//    TVideoLoadManager* _downLoadManager;
    
    int _currentTime;
    UISlider* timeProgress;
    TPlayerView* _player;
}
@end

@implementation TViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

//    _playerItem = [AVPlayerItem playerItemWithAsset:[self generatePlayItem:@"http://gslb.miaopai.com/stream/p2H9cJpKXYlFCW9O93O0gw__.mp4?yx=&KID=unistore,video&Expires=1488963625&ssig=ygmImhzt%2FO"]];
    
//   BOOL finish =  [TVideoFileManager hasFinishedVideoCache:@"temp2"];
    
//    _playerItem = [AVPlayerItem playerItemWithAsset:[self generatePlayItem:@"http://gslb.miaopai.com/stream/QgZbuZjY70~LOyicMJz9NQ__.mp4?yx=&KID=unistore,video&Expires=1488340984&ssig=9xbm%2BqHngF"]];
//    http://us.sinaimg.cn/0042YuPwjx07fyprKe9101040100Wfxu0k01.mp4?label=mp4_hd&KID=unistore,video&Expires=1511351294&ssig=WqGRXnxe9w
    NSString* url = @"http://gslb.miaopai.com/stream/QgZbuZjY70~LOyicMJz9NQ__.mp4?yx=&KID=unistore,video&Expires=1488340984&ssig=9xbm%2BqHngF";
//    NSString* url = @"http://gslb.miaopai.com/stream/ju1fBfPs7mz0uDkzpxrmIX4Hyqum1-lHAbqiIw__.mp4?yx=&KID=unistore,video&Expires=1513065957&ssig=a6UoZ3%2BB2q";
    _player = [[TPlayerView alloc]initWithFrame:self.view.bounds videoUrl:url WithVideoName:@"temp" WithDelegate:self];
    [self.view addSubview:_player];
    
    
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
    [_player loadVideoData];
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
    [_player playerSeekToSecond:value];

}

- (void)sliderChange:(UISlider*)value
{
    [self playerSeekTo:value.value];
}

#pragma mark ---playerDelegate -

- (void)playerVideoTotalTime:(int64_t)seconds{
    timeProgress.maximumValue = seconds;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
