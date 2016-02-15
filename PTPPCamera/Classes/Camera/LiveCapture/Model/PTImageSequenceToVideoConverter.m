//
//  PTImageSequenceToVideoConverter.m
//  PTPaiPaiCamera
//
//  Created by CHEN KAIDI on 21/1/2016.
//  Copyright © 2016 putao. All rights reserved.
//

#import "PTImageSequenceToVideoConverter.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "NSObject+Swizzle.h"
#import "SOKit.h"
@implementation PTImageSequenceToVideoConverter

-(void)exportVideoWithImageSequence:(PTPPLiveStickerPreviewViewController *)baseVC exportSize:(CGSize)exportSize fps:(NSUInteger)fps totalFrame:(NSInteger)totalFrame{
    ///////////// setup OR function def if we move this to a separate function ////////////
    // this should be moved to its own function, that can take an imageArray, videoOutputPath, etc...
    //    - (void)exportImages:(NSMutableArray *)imageArray
    // asVideoToPath:(NSString *)videoOutputPath
    // withFrameSize:(CGSize)imageSize
    // framesPerSecond:(NSUInteger)fps {
    
    CGFloat ratio = exportSize.height/exportSize.width;
    NSInteger factorOf16 = exportSize.width/16;
    NSInteger newWidth = factorOf16*16;
    NSInteger newHeight = newWidth*ratio;
    exportSize = CGSizeMake(newWidth, newHeight);
    NSError *error = nil;
    
    
    // set up file manager, and file videoOutputPath, remove "test_output.mp4" if it exists...
    //NSString *videoOutputPath = @"/Users/someuser/Desktop/test_output.mp4";
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *documentsDirectory = [NSHomeDirectory()
                                    stringByAppendingPathComponent:@"Documents"];
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:@"output.mp4"];
    //NSLog(@"-->videoOutputPath= %@", videoOutputPath);
    // get rid of existing mp4 if exists...
    if ([fileMgr removeItemAtPath:videoOutputPath error:&error] != YES)
        NSLog(@"Unable to delete file: %@", [error localizedDescription]);
    
    
    CGSize imageSize = exportSize;
    // NSMutableArray *imageArray = [[NSMutableArray alloc] init];
    //imageArray = [[NSMutableArray alloc] initWithObjects:@"download.jpeg", @"download2.jpeg", nil];
    
    //    for (UIImage* image in imageSequence)
    //    {
    //        [imageArray addObject:image];
    //        //NSLog(@"-->image path= %@", path);
    //    }
    
    //////////////     end setup    ///////////////////////////////////
    
    NSLog(@"Start building video from defined frames.");
    
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:
                                  [NSURL fileURLWithPath:videoOutputPath] fileType:AVFileTypeQuickTimeMovie
                                                              error:&error];
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:imageSize.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:imageSize.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput
                                            assetWriterInputWithMediaType:AVMediaTypeVideo
                                            outputSettings:videoSettings];
    
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
                                                     sourcePixelBufferAttributes:nil];
    
    NSParameterAssert(videoWriterInput);
    NSParameterAssert([videoWriter canAddInput:videoWriterInput]);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    [videoWriter addInput:videoWriterInput];
    
    //Start a session:
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer = NULL;
    
    //convert uiimage to CGImage.
    int frameCount = 0;
    double numberOfSecondsPerFrame = (float)(1/(float)fps);
    double frameDuration = fps * numberOfSecondsPerFrame;
    
    //for(VideoFrame * frm in imageArray)
    NSLog(@"**************************************************");
    for (NSInteger x=0; x<2; x++) {
   
    for(NSInteger i=0;i<totalFrame;i++)
    {
        //UIImage * img = frm._imageFrame;
        baseVC.mouthSticker.image = [baseVC.mouthSticker.animationImages safeObjectAtIndex:i];
        baseVC.eyeSticker.image = [baseVC.eyeSticker.animationImages safeObjectAtIndex:i];
        baseVC.bottomSticker.image = [baseVC.bottomSticker.animationImages safeObjectAtIndex:i];
        UIGraphicsBeginImageContext(exportSize);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextConcatCTM(context, CGAffineTransformMakeTranslation(0,-baseVC.topCropMask.bottom));
        [baseVC.basedPhotoView.layer renderInContext:context];
        UIImage *screenShot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        buffer = [self pixelBufferFromCGImage:[screenShot CGImage] size:exportSize];
        
        BOOL append_ok = NO;
        int j = 0;
        while (!append_ok && j < 30) {
            if (adaptor.assetWriterInput.readyForMoreMediaData)  {
                //print out status:
                NSLog(@"Processing video frame (%d,%lu)",frameCount,(long)totalFrame);
                
                CMTime frameTime = CMTimeMake(frameCount*frameDuration,(int32_t) fps);
                append_ok = [adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
                if(!append_ok){
                    NSError *error = videoWriter.error;
                    if(error!=nil) {
                        NSLog(@"Unresolved error %@,%@.", error, [error userInfo]);
                    }
                }
            }
            else {
                printf("adaptor not ready %d, %d\n", frameCount, j);
                [NSThread sleepForTimeInterval:0.1];
            }
            j++;
        }
        
        if (!append_ok) {
            printf("error appending image %d times %d\n, with error.", frameCount, j);
        }
        frameCount++;
    }
        
    }
    NSLog(@"**************************************************");
    
    //Finish the session:
    [videoWriterInput markAsFinished];
    [videoWriter finishWriting];
    //    [videoWriter finishWritingWithCompletionHandler:^{
    //        NSLog(@"Write Ended");
    //    }];
    NSLog(@"Write Ended");
    
    
    
    ////////////////////////////////////////////////////////////////////////////
    //////////////  OK now add an audio file to move file  /////////////////////
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    //    NSString *bundleDirectory = [[NSBundle mainBundle] bundlePath];
    // audio input file...
    //    NSString *audio_inputFilePath = [bundleDirectory stringByAppendingPathComponent:@"30secs.mp3"];
    //    NSURL    *audio_inputFileUrl = [NSURL fileURLWithPath:audio_inputFilePath];
    
    // this is the video file that was just written above, full path to file is in --> videoOutputPath
    NSURL    *video_inputFileUrl = [NSURL fileURLWithPath:videoOutputPath];
    
    // create the final video output file as MOV file - may need to be MP4, but this works so far...
    NSString *outputFilePath = [documentsDirectory stringByAppendingPathComponent:@"final_video.mp4"];
    NSURL    *outputFileUrl = [NSURL fileURLWithPath:outputFilePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath])
        [[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:nil];
    
    CMTime nextClipStartTime = kCMTimeZero;
    
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
    CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,videoAsset.duration);
    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:nextClipStartTime error:nil];
    
    //nextClipStartTime = CMTimeAdd(nextClipStartTime, a_timeRange.duration);
    
    //    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audio_inputFileUrl options:nil];
    //    CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);
    //    AVMutableCompositionTrack *b_compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    //    [b_compositionAudioTrack insertTimeRange:audio_timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:nextClipStartTime error:nil];
    
    
    
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    //_assetExport.outputFileType = @"com.apple.quicktime-movie";
    _assetExport.outputFileType = @"public.mpeg-4";
    //NSLog(@"support file types= %@", [_assetExport supportedFileTypes]);
    _assetExport.outputURL = outputFileUrl;
    __weak typeof(self) weakSelf = self;
    [_assetExport exportAsynchronouslyWithCompletionHandler:
     ^(void ) {
         [weakSelf saveVideoToAlbum:outputFilePath];
         if (weakSelf.finishExport) {
             weakSelf.finishExport(outputFileUrl);
         }
     }
     ];
    
    ///// THAT IS IT DONE... the final video file will be written here...
    NSLog(@"DONE.....outputFilePath--->%@", outputFilePath);
    
    // the final video file will be located somewhere like here:
    // /Users/caferrara/Library/Application Support/iPhone Simulator/6.0/Applications/D4B12FEE-E09C-4B12-B772-7F1BD6011BE1/Documents/outputFile.mov
    
    
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
}

-(void)saveVideoToAlbum:(NSString *)sourcePath{
    UISaveVideoAtPathToSavedPhotosAlbum(sourcePath,nil,nil,nil);
}

////////////////////////
-(CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image size:(CGSize)size{
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          size.width,
                                          size.height,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    if (status != kCVReturnSuccess){
        NSLog(@"Failed to create pixel buffer");
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width,
                                                 size.height, 8, 4*size.width, rgbColorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
    //kCGImageAlphaNoneSkipFirst);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}


@end
