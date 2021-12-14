//
//  Convert.m
//  DF
//
//  Created by 刘东旭 on 2021/12/12.
//

#import "Convert.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface Convert ()

@property (strong, nonatomic) AVAssetReader *reader;
@property (strong, nonatomic) AVAssetReaderTrackOutput *readerTrackOutput;
@property (strong, nonatomic) AVAssetWriter *writer;
@property (strong, nonatomic) AVAssetWriterInput *writerInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property (strong, nonatomic) dispatch_queue_t readerQueue;
@property (strong, nonatomic) dispatch_queue_t writerQueue;
@property (strong, nonatomic) NSString *filePath;
@property (strong, nonatomic) NSString *localString;
@property (strong, nonatomic) NSMutableArray *frameArray;

@end

@implementation Convert

- (instancetype)init:(NSString *)filePath {
    if (self = [super init]) {
        self.filePath = filePath;
        NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).lastObject;
        self.localString = [documents stringByAppendingPathComponent:@"Convert"];
        self.frameArray = [NSMutableArray array];
        self.readerQueue = dispatch_queue_create("readerQueue", DISPATCH_QUEUE_SERIAL);
        self.writerQueue = dispatch_queue_create("writerQueue", DISPATCH_QUEUE_SERIAL);
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:filePath]];
        self.reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
        AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        NSDictionary *readerAttr = @{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:(int)kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]};
        self.readerTrackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:readerAttr];
        if ([self.reader canAddOutput:self.readerTrackOutput]) {
            [self.reader addOutput:self.readerTrackOutput];
        }
        [self.reader startReading];
        
        NSString *output = [self.localString stringByAppendingPathComponent:@"output.mp4"];
        NSURL *outputUrl = [NSURL fileURLWithPath:output];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:self.localString]) {
            [fm createDirectoryAtPath:self.localString withIntermediateDirectories:true attributes:nil error:nil];
        }
        if ([fm fileExistsAtPath:output]) {
            [fm removeItemAtPath:output error:nil];
        }
        self.writer = [[AVAssetWriter alloc] initWithURL:outputUrl fileType:AVFileTypeMPEG4 error:nil];
        
        NSDictionary *writerAttr = @{AVVideoCodecKey:AVVideoCodecTypeH264,AVVideoWidthKey:@(videoTrack.naturalSize.width),AVVideoHeightKey:@(videoTrack.naturalSize.height)};
        self.writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:writerAttr];
        NSDictionary*sourcePixelBufferAttributesDictionary =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],kCVPixelBufferPixelFormatTypeKey,nil];
        self.pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
        if ([self.writer canAddInput:self.writerInput]) {
            [self.writer addInput:self.writerInput];
        }
        [self.writer startWriting];
        [self.writer startSessionAtSourceTime:kCMTimeZero];
        
    }
    return self;
}

- (void)convert {
    //解码写文件
    NSFileManager *fm = [NSFileManager defaultManager];
    __weak typeof(self)weakSelf = self;
    dispatch_async(self.readerQueue, ^{
        while ([weakSelf.reader status] == AVAssetReaderStatusReading) {
            @autoreleasepool {
                CMSampleBufferRef sampleBuffer = [weakSelf.readerTrackOutput copyNextSampleBuffer];
                CMTime pTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                if (CMTIME_IS_INVALID(pTimeStamp)) {
                    NSLog(@"数据无效");
                    break;
                }
                CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
                void* pxData = CVPixelBufferGetBaseAddress(imageBuffer);
                size_t size = CVPixelBufferGetDataSize(imageBuffer);
                NSLog(@"%zu",size);
                size_t width = CVPixelBufferGetWidth(imageBuffer);
                size_t height = CVPixelBufferGetHeight(imageBuffer);
                size_t bytesPreRow = CVPixelBufferGetBytesPerRow(imageBuffer);
                CFDictionaryRef dicAttributes = CVPixelBufferCopyCreationAttributes(imageBuffer);
                NSData *data = [NSData dataWithBytes:pxData length:size];
                if ([fm fileExistsAtPath:self.localString]) {
                    [fm createDirectoryAtPath:self.localString withIntermediateDirectories:true attributes:nil error:nil];
                }
                NSString *fileName = [NSString stringWithFormat:@"%d",(int)(CMTimeGetSeconds(pTimeStamp) * 1000000)];
                NSString *bufferFile = [weakSelf.localString stringByAppendingPathComponent:fileName];
                [data writeToFile:bufferFile atomically:true];
                NSDictionary *frameInfo = @{@"fileName":fileName,@"width":@(width),@"height":@(height),@"size":@(size)};
                [weakSelf.frameArray addObject:frameInfo];
                CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
                CVPixelBufferRelease(imageBuffer);
            }
        }
        //读编码
        [weakSelf.writerInput requestMediaDataWhenReadyOnQueue:weakSelf.writerQueue usingBlock:^{
            NSUInteger count = weakSelf.frameArray.count;
            NSDictionary *lastObj = weakSelf.frameArray.lastObject;
            NSString *lastFileName = [lastObj objectForKey:@"fileName"];
            for (NSUInteger i = 0; i < count; i++) {
                NSLog(@"frame index:%lu",(unsigned long)i);
                BOOL done = false;
                while (!done) {
                    if ([weakSelf.writerInput isReadyForMoreMediaData]) {
                        @autoreleasepool {
                        NSDictionary *frameObj = weakSelf.frameArray[count - 1 - i];
                        NSString *fileName = [frameObj objectForKey:@"fileName"];
                        NSNumber *widthObj = [frameObj objectForKey:@"width"];
                        NSNumber *heightObj = [frameObj objectForKey:@"height"];
                        NSNumber *sizeObj = [frameObj objectForKey:@"size"];
                        NSString *bufferFile = [weakSelf.localString stringByAppendingPathComponent:fileName];
                        NSData *data = [NSData dataWithContentsOfFile:bufferFile];
                        const void *pxData = data.bytes;
                       CMTime time = CMTimeMake(lastFileName.intValue - fileName.intValue, 1000000);
//                        CMTime time = CMTimeMake(fileName.intValue, 1000000);
                        if (pxData != NULL) {
                            CVPixelBufferRef pixelBuffer;
                            CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault, widthObj.intValue, heightObj.intValue, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,nil, &pixelBuffer);
                            NSLog(@"ret:%d",ret);
                            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                            void* pxDataDts = CVPixelBufferGetBaseAddress(pixelBuffer);
//                            pxDataDts = (void *)pxData;
                            memcpy(pxDataDts, pxData, sizeObj.intValue);
                            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                            NSLog(@"%f",CMTimeGetSeconds(time));
                            [weakSelf.pixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                            CVPixelBufferRelease(pixelBuffer);
                            [fm removeItemAtPath:bufferFile error:nil];
                        }
                        }
                    done = true;
                    }
                }
            }
            [weakSelf.writerInput markAsFinished];
            [weakSelf.writer finishWritingWithCompletionHandler:^{
                NSLog(@"ok：%@",weakSelf.localString);
                weakSelf.writer = nil;
            }];
        }];
    });
    
}

@end

