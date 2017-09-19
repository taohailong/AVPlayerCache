//
//  VideoLoader.m
//  AVPlayerController
//
//  Created by hailong9 on 16/12/26.
//  Copyright © 2016年 hailong9. All rights reserved.
//

#import "TVideoLoader.h"

@implementation TVideoLoader
{
    VideoLoaderCompleteBk _completeBk;
    VideoLoaderProcessBk _processBk;
    VideoLoaderRespondBk _respondBk;
    NSRange _range;
    __weak id<VideoLoaderProtocol>_delegate;
    NSUInteger _cacheLength;
    NSURLSession * session;              //会话对象
    NSURLSessionDataTask * task;
    NSOperationQueue* _operateQueue;
    BOOL _cancel;
    NSMutableURLRequest* _request;
    NSError* _netError;
}
@synthesize fileManager;
@synthesize assetResource;
- (instancetype)initWithUrl:(NSURL *)url withRange:(NSRange)range WithDelegate:(id<VideoLoaderProtocol>)delegate
{
    self = [self initWithUrl:url withRange:range];
    _delegate = delegate;
      return self;
}


- (instancetype)initWithUrl:(NSURL *)url withRange:(NSRange)range withRespondBk:(VideoLoaderRespondBk)respond withProcessBk:(VideoLoaderProcessBk)processBk withCompleteBk:(VideoLoaderCompleteBk)bk
{
   self = [self initWithUrl:url withRange:range];
    return self;
}


- (instancetype)initWithUrl:(NSURL *)url withRange:(NSRange)range 
{
    self = [super init];
    _range = range;
  
    _request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];;
    
    if (range.length != 2 && range.location != 0) {
        
        NSString* rangeStr = [NSString stringWithFormat:@"bytes=%ld-%ld", range.location, range.length - 1 + range.location];
        [_request addValue:rangeStr forHTTPHeaderField:@"Range"];
//        NSLog(@"http setRang %@",rangeStr);
    }
    if ([_delegate respondsToSelector:@selector(videoLoaderConfigure:)]) {
        [_delegate videoLoaderConfigure:_request];
    }
    
    _operateQueue = [[NSOperationQueue alloc]init];
      return self;
}


- (void)start
{
    session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:_operateQueue];
    task = [session dataTaskWithRequest:_request];
    [task resume];
}

//- (void)startRunLoop
//{
//    NSRunLoop * runLoop = [NSRunLoop currentRunLoop];
//    NSMachPort* port = [[NSMachPort alloc]init];
//    [runLoop addPort:port forMode:NSRunLoopCommonModes];
//    
//    while(_netError.code == -1001){
//          NSLog(@"isrun ");
//        [self start];
//       [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
//    }
//    [runLoop removePort:port forMode:NSRunLoopCommonModes];
//    
//}


- (void)videoLoaderSychronizeProcessToConfigure
{
    if (_cacheLength < 1) {
        return;
    }
      [self.fileManager saveSegmentData:_range.location length:_cacheLength];
}

- (void)fillDataToAssetResource
{
//    NSLog(@"fillDataToAssetResource");
    if (self.assetResource == nil || self.assetResource.isFinished || self.assetResource.isCancelled) {
        return;
    }
    if (self.assetResource.dataRequest.requestedLength == 2 ) {
        return;
    }
    
    NSUInteger offset =  self.assetResource.dataRequest.currentOffset;
    if (_cacheLength+_range.location-1<=offset) {
        return;
    }
    
    if (_cacheLength<self.assetResource.dataRequest.requestedLength) {
        
        NSUInteger currentLength = _cacheLength - offset + self.assetResource.dataRequest.requestedOffset;
        NSData* data = [self.fileManager readTempFileDataWithOffset:offset length:currentLength];
        [self.assetResource.dataRequest respondWithData:data];
    }
    else
    {
        NSUInteger currentLength = self.assetResource.dataRequest.requestedLength - offset + self.assetResource.dataRequest.requestedOffset;
        NSData* data = [self.fileManager readTempFileDataWithOffset:offset length:currentLength];
        [self.assetResource.dataRequest respondWithData:data];
        [self.assetResource finishLoading];
        self.assetResource = nil;
    }
}

#pragma mark - NSURLSessionDataDelegate
//服务器响应
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    if (_cancel) {
        return;
    }
     completionHandler(NSURLSessionResponseAllow);
    if (_range.location !=0 || _range.length != 2 ) {
        return;
    }
   
//    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
//    NSString * contentRange = [[httpResponse allHeaderFields] objectForKey:@"Content-Range"];
//    NSString * fileLength = [[contentRange componentsSeparatedByString:@"/"] lastObject];
    [self.fileManager setFileLength:response.expectedContentLength];
   self.assetResource.contentInformationRequest.contentLength = response.expectedContentLength;
    [self.assetResource finishLoading];
    self.assetResource = nil;
    
    if (_respondBk ) {
        _respondBk(response.expectedContentLength,response.MIMEType);
    }

    if ([_delegate respondsToSelector:@selector(videoLoaderRespond:withMediaType:)]) {
        [_delegate videoLoaderRespond:response.expectedContentLength withMediaType:response.MIMEType];
    }
}

//服务器返回数据 可能会调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {

    if (_cancel) {
        return;
    }
      NSUInteger offset = _cacheLength + _range.location;
      _cacheLength = _cacheLength + data.length;
    if ([_delegate respondsToSelector:@selector(videoLoaderProcessOffset:data:)]) {
        [_delegate videoLoaderProcessOffset:offset data:data];
    }
    
    if (_processBk) {
        _processBk(offset,data);
    }
    [self.fileManager writeFileData:offset data:data];
    [self fillDataToAssetResource];
}

//请求完成会调用该方法，请求失败则error有值
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
//    NSLog(@"videoLoader net error %@",error);
     [self videoLoaderSychronizeProcessToConfigure];
    if (_cancel) {
        return;
    }
    if ([_delegate respondsToSelector:@selector(videoLoaderComplete:)]) {
        [_delegate videoLoaderComplete:nil];
    }
    if (_completeBk) {
        _completeBk(error,_range.location,_cacheLength);
    }
    [self cancel];
  }


- (void)setCompleteBk:(VideoLoaderCompleteBk)bk
{
    _completeBk = bk;
}

- (void)setProcessBk:(VideoLoaderProcessBk)bk
{
    _processBk = bk;
}

- (void)setRespondBk:(VideoLoaderRespondBk)bk
{
  _respondBk = bk;
}


- (NSUInteger)requestOffset
{
    return _range.location;
}


- (NSUInteger)requestLength
{
    return _range.length;
}

- (NSUInteger)cacheLength
{
    return _cacheLength;
}


- (void)cancel
{
    if (self.assetResource.isFinished != true && self.assetResource.isCancelled != true) {
        [self.assetResource finishLoadingWithError:nil];
    }
    
    _cancel = true;
    [task cancel];
    [session invalidateAndCancel];
}


- (void)dealloc
{
    [task cancel];
//    [_operateQueue cancelAllOperations];
   
}



@end
