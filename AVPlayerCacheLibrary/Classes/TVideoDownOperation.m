//
//  VideoDownOperation.m
//  AVPlayerController
//
//  Created by hailong9 on 17/1/2.
//  Copyright © 2017年 hailong9. All rights reserved.
//

#import "TVideoDownOperation.h"
#import <libkern/OSAtomic.h>
@interface TVideoDownOperation ()

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@end
@implementation TVideoDownOperation
{
    VideoLoaderCompleteBk _completeBk;
    VideoLoaderProcessBk _processBk;
    VideoLoaderRespondBk _respondBk;
    VideoOperationStartBk _startBk;
    
    NSRange _range;
    NSUInteger _cacheLength;
    NSURLSession * _session;              //会话对象
    NSURLSessionDataTask * _task;
    NSURL* _downLoadUrl;
    OSSpinLock _oslock;
}
@synthesize executing = _executing;
@synthesize finished = _finished;
//@synthesize cancelled = _cancelled;
@synthesize netReachable;

- (instancetype)initWithUrl:(NSURL *)url withRange:(NSRange)range {
    self = [super init];

    _range = range;
    _executing = NO;
    _finished = NO;
    _downLoadUrl = url;
    self.netReachable = true;
     _oslock = OS_SPINLOCK_INIT;
#if DEBUG
    if (_range.length < 1 ) {
        NSAssert(false, @"video downOperation range error");
    }
#endif
//    NSLog(@"creat operation %@",self);
    return self;
}

//- (void)netWorkChangedNotic:(NSNotification*)notic
//{
//    self.netReachable = true;
//}

- (void)setOperationStartBk:(VideoOperationStartBk)bk
{
    _startBk = bk;
}

- (void)setDownCompleteBk:(VideoLoaderCompleteBk)bk
{
    _completeBk = bk;
}

- (void)setDownProcessBk:(VideoLoaderProcessBk)bk
{
    _processBk = bk;
}

- (void)setDownRespondBk:(VideoLoaderRespondBk)bk
{
    _respondBk = bk;
}

- (NSUInteger)requestOffset
{
    return _range.location;
}

- (NSUInteger)cacheLength
{
    return _cacheLength;
}

- (void)start
{
    OSSpinLockLock(&_oslock);
    if (self.isCancelled) {
        self.finished = YES;
        return;
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:_downLoadUrl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
 
    if (_startBk) {
        _startBk(request);
    }
//    if (_range.length != 2) {
        NSString* rangeStr = [NSString stringWithFormat:@"bytes=%ld-%ld", _range.location+_cacheLength, _range.length+_range.location-1];
        [request addValue:rangeStr forHTTPHeaderField:@"Range"];
//    }

//     NSLog(@"http setRang %@  ",request.allHTTPHeaderFields);
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPMaximumConnectionsPerHost = 6;
    _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    _task = [_session dataTaskWithRequest:request];
    [_task resume];
    
   
     OSSpinLockUnlock(&_oslock);
}


- (void)cancelInternal {
    
    if (self.isFinished) return;
    [super cancel];
    [self reset];
    if (self.isExecuting) self.executing = NO;
}

- (void)cancel {
    
   OSSpinLockLock(&_oslock);
    [self cancelInternal];
    OSSpinLockUnlock(&_oslock);
}


- (void)done {
    
    if (self.isFinished ) {
        return;
    }
    self.finished = YES;
    self.executing = NO;
    [self reset];
//    NSLog(@"done operaton %@ ",self);
}

- (void)reset {
       if (_session) {
        [_session invalidateAndCancel];
        _session = nil;
    }
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}


- (void)startRunLoop
{
    self.netReachable = false;
    if (self.isCancelled) {
        [self done];
        return;
    }
   
    NSRunLoop * runLoop = [NSRunLoop currentRunLoop];
    NSMachPort* port = [[NSMachPort alloc]init];
    [runLoop addPort:port forMode:NSRunLoopCommonModes];
    
    while(self.netReachable == false){
        
        if (self.isCancelled) {
            break;
        }
        [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
    }
    [runLoop removePort:port forMode:NSRunLoopCommonModes];
    [self start];
}


- (BOOL)isConcurrent {
    return YES;
}

#pragma mark - NSURLSessionDataDelegate
//服务器响应
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    NSUInteger code = ((NSHTTPURLResponse *)response).statusCode;
    if (code == 404) {
        [self cancelInternal];
        return;
    }
    
    if (_respondBk) {
        NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
        NSUInteger contentLength = [[[httpResponse allHeaderFields] objectForKey:@"Content-Length"] longLongValue];
        NSString* contentRange = [[httpResponse allHeaderFields] objectForKey:@"Content-Range"];
        NSUInteger  fileLength = [[[contentRange componentsSeparatedByString:@"/"] lastObject] longLongValue];
//        NSLog(@"contentLength %ld  %ld  ",contentLength,fileLength);
        _respondBk(contentLength>fileLength?contentLength:fileLength,response.MIMEType);
    }
    completionHandler(NSURLSessionResponseAllow);
}

//服务器返回数据 可能会调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    NSUInteger offset = _cacheLength + _range.location;
     _cacheLength = _cacheLength + data.length;
   
    if (_processBk) {
        _processBk(offset,data);
    }
}

//请求完成会调用该方法，请求失败则error有值
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
  
//    NSLog(@"alread down load %@ data from %ld-%ld  request %ld-%ld",self,_range.location,_range.location+_cacheLength-1,_range.location,_range.length-1);
//    if (error.code < 0 && error.code != -999) {
//   
//        if (_completeBk) {
//             _completeBk(error,_range.location,_cacheLength);
//        }
//        [_session finishTasksAndInvalidate]; //startRunLoop 注意顺序 否则 线程循环嵌套 导致内存无法释放
////        [self startRunLoop];
//        sleep(5);
//        [self start];
//        return;
//    }
    if (_completeBk) {
        _completeBk(nil,_range.location,_cacheLength);
    }
    
    [self done];
}

- (void)dealloc
{
//    NSLog(@"nsoperation dealloc %@",self);
}
@end
