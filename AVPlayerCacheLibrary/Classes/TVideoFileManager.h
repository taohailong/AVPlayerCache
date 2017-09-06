//
//  VideoFileManager.h
//  AVPlayerController
//
//  Created by hailong9 on 16/12/27.
//  Copyright © 2016年 hailong9. All rights reserved.
//

#import <Foundation/Foundation.h>
@interface TVideoFileManager : NSObject

- (instancetype)initWithFileName:(NSString*)fileName;
- (void)writeFileData:(NSUInteger)offset data:(NSData*)data;
- (void)writeTempFileData:(NSData *)data ;
- (void)writeFinish;
- (NSData *)readTempFileDataWithOffset:(NSUInteger)offset length:(NSUInteger)length;
- (NSData*)readToEndWithOffset:(NSUInteger)offset;

- (void)setFileLength:(NSUInteger)length;
- (NSUInteger)getFileLength;

- (NSArray*)getSegmentsFromFile:(NSRange)range;
- (void)saveSegmentData:(NSUInteger)offset length:(NSUInteger)length;

+ (void)setVideoCachePath:(NSString*)path;
+ (NSURL *)cacheFileExistsWithName:(NSString *)fileName;
+ (BOOL)hasFinishedVideoCache:(NSString*)fileName;
+ (BOOL)clearCache;
@end
