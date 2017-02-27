//
//  VideoFileManager.m
//  AVPlayerController
//
//  Created by hailong9 on 16/12/27.
//  Copyright © 2016年 hailong9. All rights reserved.
//

#import "TVideoFileManager.h"
#import <libkern/OSAtomic.h>
#import "pthread.h"
static NSString* VideoCachePath = nil;
@implementation TVideoFileManager
{
     NSFileHandle * _writeFileHandle;
     NSFileHandle * _readFileHandle;
     NSString* _fileName;
     NSUInteger _fileLength;
    NSMutableArray* _segmentArr;
    __block  OSSpinLock oslock;
}
 pthread_rwlock_t rwlock = PTHREAD_RWLOCK_INITIALIZER;
- (instancetype)initWithFileName:(NSString*)fileName
{
    self = [super init];
    _fileName = fileName;
     oslock = OS_SPINLOCK_INIT;
    
   NSString * path = [TVideoFileManager creatCacheDirectory];
    NSLog(@"document path %@",path);
    NSString* videoPath = [NSString stringWithFormat:@"%@/%@.mp4",path,fileName];
    NSString* segmentPath = [NSString stringWithFormat:@"%@/%@.plist",path,fileName];
    BOOL creatError = [self createTempFile:videoPath];
#if DEBUG
    if (creatError == false) {
        NSAssert(false, @"creat vide file error");
    }
#endif
    
    _segmentArr = [[NSMutableArray alloc]init];
    NSDictionary * dic = [NSDictionary dictionaryWithContentsOfFile:segmentPath];
    if (dic) {
        NSNumber* length = dic[@"fileLength"];
        _fileLength = [length unsignedIntegerValue];
        [_segmentArr addObjectsFromArray:dic[@"fileArr"]] ;
    }
    _writeFileHandle =  [NSFileHandle fileHandleForWritingAtPath:videoPath];
    _readFileHandle = [NSFileHandle fileHandleForReadingAtPath:videoPath];
    return self;
}

- (void)saveSegmentToPlist
{
    NSString * path = [TVideoFileManager cacheFolderPath];
    NSString* segmentPath = [NSString stringWithFormat:@"%@/%@.plist",path,_fileName];
    NSDictionary* dic = @{@"fileLength":@(_fileLength), @"fileArr":_segmentArr};
    [dic writeToFile:segmentPath atomically:YES];
}

- (void)setFileLength:(NSUInteger)length
{
    _fileLength = length;
}

- (NSUInteger)getFileLength
{
    return _fileLength;
}



- (void)writeTempFileData:(NSData *)data {
    
     pthread_rwlock_wrlock(&rwlock);
    [_writeFileHandle seekToEndOfFile];
    [_writeFileHandle writeData:data];
    pthread_rwlock_unlock(&rwlock);
}


- (void)writeFileData:(NSUInteger)offset data:(NSData *)data
{
    pthread_rwlock_wrlock(&rwlock);
    [_writeFileHandle seekToFileOffset:offset];
    [_writeFileHandle writeData:data];
    pthread_rwlock_unlock(&rwlock);
//    [self saveSegmentData:offset length:data.length];
}

- (void)writeFinish
{
    [_writeFileHandle closeFile];
    _writeFileHandle = nil;
}


- (NSData *)readTempFileDataWithOffset:(NSUInteger)offset length:(NSUInteger)length {
    
#if DEBUG
    if (length < 1 ) {
        NSAssert(false, @"videofile read data length error");
    }
#endif
    
    pthread_rwlock_rdlock(&rwlock);
    [_readFileHandle seekToFileOffset:offset];
    NSData* data = [_readFileHandle readDataOfLength:length];
    pthread_rwlock_unlock(&rwlock);
    return data;
}

- (NSData*)readToEndWithOffset:(NSUInteger)offset
{
      [_readFileHandle seekToFileOffset:offset];
    return [_readFileHandle readDataToEndOfFile];
}


- (void)dealloc
{
    [_writeFileHandle closeFile];
    [_readFileHandle closeFile];
}

#pragma mark------cache append 、subRange

- (void)saveSegmentData:(NSUInteger)offset length:(NSUInteger)length
{
    if (length == 0) {
        return;
    }
//    NSLog(@"download length %ld-%ld",offset,offset+length-1);
    NSNumber* start = [NSNumber numberWithUnsignedInteger:offset];
    NSNumber* end = [NSNumber numberWithUnsignedInteger:offset+length-1];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        OSSpinLockLock(&oslock);
        
        if (_segmentArr.count == 0) {
            
            NSArray* insertArr = @[start,end];
            [_segmentArr addObject:insertArr];
            OSSpinLockUnlock(&oslock);
            return ;
        }
        
        //这里是 对区间段start－1 、end ＋1 ，进行边界融合
        NSUInteger searchStart =  start.unsignedIntegerValue==0 ? 0 : start.unsignedIntegerValue-1;
        NSUInteger searchEnd = end.unsignedIntegerValue ==_fileLength-1?_fileLength-1: end.unsignedIntegerValue+1;
        
        float startIndex = [self searchSemgentIndex:searchStart withArr:_segmentArr];
        float endIndex = [self searchSemgentIndex:searchEnd withArr:_segmentArr];
        
        if (startIndex == endIndex) {  // 有两种情况 一个是在同一区间段 ，一个是在空白区域 ,不涉及跨区域
            
            NSArray* insertArr = @[start,end];
            if (startIndex<0) {
                startIndex = 0;
                [_segmentArr insertObject:insertArr atIndex:0];
            }
            else
            {
                if ( [self hasDecimal:startIndex]) {  // 没有小数部分说明 这个区间段处于别的包含中 不需要更新
                    [_segmentArr insertObject:insertArr atIndex:startIndex+0.5];
                }
            }
        }
        else
        {    //需要合并的区间段
            NSUInteger insertFileStart = 0;
            NSUInteger insertFileEnd = 0;
            
            if ( [self hasDecimal:startIndex] ) {
                insertFileStart = start.unsignedIntegerValue;
                startIndex = startIndex + 0.5;
            }
            else
            {
                int index = startIndex;
                NSArray* temp = _segmentArr[index];
                NSNumber* s = temp[0];
                insertFileStart = s.unsignedIntegerValue;
            }
            
            if ([self hasDecimal:endIndex]) {
                insertFileEnd = end.unsignedIntegerValue;
                endIndex = endIndex - 0.5;
            }
            else
            {
                int index = endIndex;
                NSArray* temp = _segmentArr[index];
                NSNumber* s = temp[1];
                insertFileEnd = s.unsignedIntegerValue;
            }
            
            NSArray* insertArr = @[[NSNumber numberWithUnsignedInteger:insertFileStart],[NSNumber numberWithUnsignedInteger:insertFileEnd]];
            
            NSMutableArray* removeArr = [NSMutableArray arrayWithCapacity:0];
            for (int i = startIndex ;  i <= endIndex ;i++) {
                [removeArr addObject:_segmentArr[i]];
            }
            [_segmentArr removeObjectsInArray:removeArr];
            [_segmentArr insertObject:insertArr atIndex:startIndex];
        }
        [self saveSegmentToPlist];
        OSSpinLockUnlock(&oslock);
    });
}

- (BOOL)hasDecimal:(float)number
{
    number = number * 10;
    int intNumber = number;
    int result = intNumber % 10;
    if ( result == 0) {
        return false;
    }
    return true;
}


- (float)searchSemgentIndex:(NSUInteger)fileIndex withArr:(NSArray*)segmentArr
{
    float searchIndex = 0;
    for (int index = 0; index<segmentArr.count; index++ ) {
        
        NSArray* currentSegment  = segmentArr[index];
        NSNumber* temp_start = currentSegment[0];
        NSNumber* temp_end = currentSegment[1];
        
        if (temp_start.unsignedIntegerValue > fileIndex ) {
            searchIndex = index - 0.5;
            break;
        }
        else if (temp_end.unsignedIntegerValue < fileIndex)
        {
            if (index == segmentArr.count - 1) {
                return index + 0.5;
            }// /循环到最后超出所有的区域 为最大数
        }
        else
        {
            searchIndex = index;
            break;
        }
    }
    return searchIndex;
    
}


- (NSArray*)getSegmentsFromFile:(NSRange)range
{
    NSNumber* start = [NSNumber numberWithUnsignedInteger:range.location];
    NSNumber* end = [NSNumber numberWithUnsignedInteger:range.location+range.length-1];
    OSSpinLockLock(&oslock);
    
    if (_segmentArr.count == 0) {
        OSSpinLockUnlock(&oslock);
        return @[[self creatReadSegmentArr:start end:end isSave:NO]];
    }
    
    float startIndex = [self searchSemgentIndex:start.unsignedIntegerValue withArr:_segmentArr];
    float endIndex = [self searchSemgentIndex:end.unsignedIntegerValue withArr:_segmentArr];
    
    if (startIndex == endIndex) {  // 有两种情况 一个是在同一区间段 ，一个是在空白区域 ,不涉及跨区域
        OSSpinLockUnlock(&oslock);
        if ([self hasDecimal:startIndex]) {
            
            return @[[self creatReadSegmentArr:start end:end isSave:NO]];
        }
        else
        {
            // 没有小数部分说明 这个区间段处于别的包含中
            return @[[self creatReadSegmentArr:start end:end isSave:YES]];
        }
    }
    else{    //需要合并的区间段
        
        
        NSMutableArray* newSegmengArr = [NSMutableArray arrayWithCapacity:0];
        if ([self hasDecimal:startIndex]) {
            
            startIndex = startIndex + 0.5;
            NSArray* current = _segmentArr[(int)startIndex];
            NSNumber* current_start = current[0];
            [newSegmengArr addObject:[self creatReadSegmentArr:start end:@(current_start.unsignedIntegerValue-1) isSave:false]];
        }
        
        NSArray* endArr = nil;
        //
        if ([self hasDecimal:endIndex]) {
            
            endIndex = endIndex - 0.5;
            NSArray* current = _segmentArr[(int)endIndex];
            NSNumber* current_end = current[1];
            endArr = [self creatReadSegmentArr:@(current_end.unsignedIntegerValue+1)  end: end isSave:false];
        }
        
        NSUInteger lastOffset = 0;
        for (int i = startIndex ;i<=endIndex;i++) {
            
            NSArray* current = _segmentArr[i];
            NSNumber* s = current[0];
            NSNumber* e = current[1];
            
            if (lastOffset != 0) {
                [newSegmengArr addObject:[self creatReadSegmentArr:@(lastOffset+1) end: @(s.unsignedIntegerValue-1) isSave:NO]];
            }
            [newSegmengArr addObject:[self creatReadSegmentArr:s end:e isSave:YES]];
            lastOffset = e.unsignedIntegerValue;
        }
        if (endArr) {
            [newSegmengArr addObject:endArr];
        }
        
        
        //      newSegmengArr里 已经是填好的空白段和 数据段  只需要把头尾两端数据 重新一次判断 截取有用数据段
        
        NSArray* current = newSegmengArr.firstObject;
        
        BOOL isSave = [current[2] boolValue];
        if (isSave) {
            
            NSNumber* currentEnd = current[1];
            NSArray* replaceArr = [self creatReadSegmentArr:start end:currentEnd isSave:[current[2] boolValue]];
            [newSegmengArr replaceObjectAtIndex:0 withObject:replaceArr];
        }
        
        
        current = newSegmengArr.lastObject;
        isSave = [current[2] boolValue];
        if (isSave) {
            
            NSArray* replaceArr = [self creatReadSegmentArr:current[0] end:end isSave:[current[2] boolValue]];
            [newSegmengArr replaceObjectAtIndex:newSegmengArr.count-1 withObject:replaceArr];
            
        }
        OSSpinLockUnlock(&oslock);
        return newSegmengArr;
    }
}

- (NSArray*)creatReadSegmentArr:(NSNumber*)start end:(NSNumber*)end  isSave:(BOOL)save
{
    NSUInteger startInteger =  start.unsignedIntegerValue;
    NSUInteger endInteger = end.unsignedIntegerValue;
    NSArray* arr = @[@(startInteger),@(endInteger),@(save)];
    return arr;
}


#pragma mark--- FilePath

- (BOOL)createTempFile:(NSString*)path {
    
    NSFileManager * manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:path]) {
        return true;
    }
    return [manager createFileAtPath:path contents:nil attributes:nil];
}

+ (NSString*)creatCacheDirectory{
    
    NSFileManager * manager = [NSFileManager defaultManager];
    NSString * cacheFolderPath = [TVideoFileManager cacheFolderPath];
    if ([manager fileExistsAtPath:cacheFolderPath] == NO) {
        [manager createDirectoryAtPath:cacheFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return cacheFolderPath;
}


+ (NSURL *)cacheFileExistsWithName:(NSString *)fileName {
    
    NSFileManager * manager = [NSFileManager defaultManager];
    NSString * cacheFolderPath = [TVideoFileManager cacheFolderPath];
     NSString* videoPath = [NSString stringWithFormat:@"%@/%@.mp4",cacheFolderPath,fileName];
    if ([manager fileExistsAtPath:videoPath] == NO) {
        return nil;
    }
    NSURL *url = [[manager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *path = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"VideoCaches/%@.mp4",fileName]];
    return path;
}

+ (BOOL)clearCache {
    NSFileManager * manager = [NSFileManager defaultManager];
    return [manager removeItemAtPath:[TVideoFileManager cacheFolderPath] error:nil];
}

+ (void)setVideoCachePath:(NSString*)path
{
    VideoCachePath = path;
}

+ (NSString *)cacheFolderPath {
    
    if (VideoCachePath) {
        return VideoCachePath;
    }
    NSArray *allCachePaths =  NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                                  NSUserDomainMask, YES);
    NSString* cache = [[allCachePaths objectAtIndex:0] stringByAppendingPathComponent:@"video_cache"];
    return cache;
//    return [[NSHomeDirectory( ) stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"VideoCaches"];
}

@end
