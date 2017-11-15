

# AVPlayerCacheLibrary

[![CI Status](http://img.shields.io/travis/hailong9/AVPlayerCacheLibrary.svg?style=flat)](https://travis-ci.org/hailong9/AVPlayerCacheLibrary)
[![Version](https://img.shields.io/cocoapods/v/AVPlayerCacheLibrary.svg?style=flat)](http://cocoapods.org/pods/AVPlayerCacheLibrary)
[![License](https://img.shields.io/cocoapods/l/AVPlayerCacheLibrary.svg?style=flat)](http://cocoapods.org/pods/AVPlayerCacheLibrary)
[![Platform](https://img.shields.io/cocoapods/p/AVPlayerCacheLibrary.svg?style=flat)](http://cocoapods.org/pods/AVPlayerCacheLibrary)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

AVPlayerCacheLibrary is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:
使用pod构建项目添加方法

```ruby
pod 'AVPlayerCacheLibrary', :git => 'https://github.com/taohailong/AVPlayerCache.git'
```

## Author

hailong9, 邮箱地址： hailong9@staff.sina.com.cn

## License

AVPlayerCacheLibrary is available under the MIT license. See the LICENSE file for more info.



    在iOS系统中使用播放器有时候挺尴尬的，系统播放器功能不足，扩展性、可定制化程度很低，使用ijkplayer又很重。 权衡利弊，只能矬子里面找将军。本文讲解的就是对avplayer添加缓存。
    
    在系统播放器中，avplayer无疑是可定制化程度最高的，AVPlayer 创建时需要有一个数据源 AVPlayerItem，
    AVURLAsset *videoAsset = [self generateAVURLAsset];
    self.avPlayerItem = [AVPlayerItem playerItemWithAsset:videoAsset];
    self.avPlayer = [AVPlayer playerWithPlayerItem:weak_self.avPlayerItem];
    
    首先创建AVPlayer 需要使用AVPlayerItem ，而AVPlayerItem的创建需要使用AVURLAsset，这个类有代理
      - (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:  (AVAssetResourceLoadingRequest *)loadingRequest 
      
   这个代理的作用就是提供数据，然后把数据交给播放器。根据这个代理我们就可以自己做缓存，当播放器要数据时，如果没有就去下载，一边下载一边缓存。如果有就读取存储的数据交给播放器播放。这是avplayer 缓存的基本原理。
   
   那播放器怎样要数据，我们又怎么给它相应的数据呢？ 
    
     - (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:  (AVAssetResourceLoadingRequest *)loadingRequest {
     
  } 
loadingRequest是数据传输的载体，这里需要注意的是，在第一次传输数据时 需要填写 loadingRequest.contentInformationRequest 中的信息，以便播放器更好的处理， loadingRequest.contentInformationRequest.contentType = @"video/mp4";（视频类型）
loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;（是否支持分段获取）。loadingRequest.contentInformationRequest.contentLength = [_fileManager getFileLength];（视频的大小）

     用 loadingRequest.dataRequest传递数据， loadingRequest.dataRequest.currentOffset（当前的数据节点）loadingRequest.dataRequest.requestedLength（本次请求的数据长度）loadingRequest.dataRequest.requestedOffset（本次请求的数据节点）
根据以上的这几个区间段获取视频的data流，  赋值 [loadingRequest.dataRequest respondWithData:data]; 完成后结束掉  [loadingRequest finishLoading];

AVPlayerCacheLibrary 如何处理缓存的，loadingRequest.dataRequest 请求时，发起下载视频的请求，根据下载的区间段分段下载视频同时进行储存，如果视频是顺序播放理论上只需要一个线程下载就够了。但是如果播放器快进时会有不同的loadingRequest.dataRequest ，还会有请求数据段的交叉重叠，在频繁的快进后退时会产生大量的碎片化数据段，如何保证这些零碎的数据利用上是AVPlayerCacheLibrary解决的核心问题。

    【0-1000】{1001-1499} 【1500-2000】{2001-2499}【2500-4000】
    上面的是简单的数据段，【】表示已经下载的数据段，{}中代表是没有下载的空白数据段，如果loadingRequest.dataRequest 的请求是500-3000时数据应该如何请求处理，如果是800 - 1200 时又该如何处理呢？

    为了最大限度的利用已经下载过的数据，AVPlayerCacheLibrary下载数据后会有一个数据段的plist文件，里面记录了，有效的数据区间。比如loadingRequest.dataRequest请求的0 - 1000的数据，当下载完成后，plist文件中就会有【0 -1000】的数据记录。这里还有一套算法计算出请求区间内的有效区间段和无效区间段。处理完成后返回一个有顺序的数组。例如上面的区间请求500-3000时 算法会从plist 文件中查询计算出区间是【500-1000】{1001-1499} 【1500-2000】{2001-2499}【2500-3000】

    当拿到这样的一个数组后，交给 TVideoDownQueue 它是一个NSOperationQueue 串行，对数组中的每一个区间段创建相应的NSOperation，去执行有效区间内的直接去储存中读取，无效区间的直接下载，每一次读区或者下载后的数据要及时传递给 loadingRequest.dataRequest。

    以上就是AVPlayerCacheLibrary的缓存处理过程。开发过程中更多的是多线程的并发下载，文件的读取加锁，NSOperationQueue 取消 内存管理。



