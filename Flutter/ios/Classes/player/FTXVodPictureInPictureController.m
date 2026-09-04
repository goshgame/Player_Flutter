// Copyright (c) 2026 Tencent. All rights reserved.

#import "FTXVodPictureInPictureController.h"

#import <AVKit/AVKit.h>
#import <math.h>

#import "FTXEvent.h"

API_AVAILABLE(ios(15.0))
@interface FTXVodPictureInPictureController () <AVPictureInPictureControllerDelegate,
                                                AVPictureInPictureSampleBufferPlaybackDelegate>

@property (nonatomic, strong) AVSampleBufferDisplayLayer *displayLayer;
@property (nonatomic, strong) AVPictureInPictureController *controller;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDescription;
@property (nonatomic, assign) CMVideoDimensions formatDimensions;
@property (nonatomic, assign) BOOL hasVideoFrame;
@property (nonatomic, assign) BOOL wantsToStart;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) NSUInteger startAttempt;
@property (nonatomic, assign) BOOL willStopNotified;
@property (nonatomic, assign) NSTimeInterval lastPresentationTime;

@end

@implementation FTXVodPictureInPictureController

- (instancetype)initWithDelegate:(id<FTXVodPictureInPictureControllerDelegate>)delegate {
    self = [super init];
    if (!self) {
        return nil;
    }

    _delegate = delegate;
    _formatDimensions = (CMVideoDimensions){0, 0};
    _lastPresentationTime = -1.0;
    _displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _displayLayer.backgroundColor = UIColor.blackColor.CGColor;

    AVPictureInPictureControllerContentSource *contentSource =
        [[AVPictureInPictureControllerContentSource alloc]
            initWithSampleBufferDisplayLayer:_displayLayer
                            playbackDelegate:self];
    _controller = [[AVPictureInPictureController alloc] initWithContentSource:contentSource];
    _controller.delegate = self;
    return self;
}

- (void)dealloc {
    [self invalidate];
}

- (BOOL)isStarting {
    return self.wantsToStart;
}

- (void)setCanStartPictureInPictureAutomaticallyFromInline:(BOOL)canStartPictureInPictureAutomaticallyFromInline {
    _canStartPictureInPictureAutomaticallyFromInline = canStartPictureInPictureAutomaticallyFromInline;
    self.controller.canStartPictureInPictureAutomaticallyFromInline = canStartPictureInPictureAutomaticallyFromInline;
}

- (void)attachToHostView:(UIView *)hostView {
    if (!hostView) {
        return;
    }
    if (self.displayLayer.superlayer != hostView.layer) {
        [self.displayLayer removeFromSuperlayer];
        [hostView.layer addSublayer:self.displayLayer];
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.displayLayer.frame = hostView.bounds;
    [CATransaction commit];
}

- (void)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer atTime:(NSTimeInterval)time {
    if (!pixelBuffer || !self.controller) {
        return;
    }
    CFRetain(pixelBuffer);
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            CFRelease(pixelBuffer);
            return;
        }

        CMSampleBufferRef sampleBuffer = [strongSelf createSampleBufferForPixelBuffer:pixelBuffer atTime:time];
        CFRelease(pixelBuffer);
        if (!sampleBuffer) {
            return;
        }

        if (strongSelf.displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            NSLog(@"vod custom pip display layer failed, flush and continue");
            [strongSelf.displayLayer flush];
        }
        if (strongSelf.displayLayer.readyForMoreMediaData) {
            [strongSelf.displayLayer enqueueSampleBuffer:sampleBuffer];
            strongSelf.hasVideoFrame = YES;
            [strongSelf tryStartIfReady];
        }
        CFRelease(sampleBuffer);
    });
}

- (void)start {
    if (!self.controller || self.active || self.controller.isPictureInPictureActive) {
        return;
    }
    self.wantsToStart = YES;
    self.startAttempt = 0;
    self.willStopNotified = NO;
    [self tryStartIfReady];
}

- (void)tryStartIfReady {
    if (!self.wantsToStart || self.active || self.controller.isPictureInPictureActive) {
        return;
    }
    if (self.hasVideoFrame && self.controller.isPictureInPicturePossible) {
        self.wantsToStart = NO;
        [self.controller startPictureInPicture];
        return;
    }
    if (self.startAttempt >= 20) {
        self.wantsToStart = NO;
        [self.delegate vodPictureInPictureControllerDidFailWithErrorCode:ERROR_IOS_PIP_START_TIME_OUT];
        return;
    }

    self.startAttempt += 1;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf tryStartIfReady];
    });
}

- (void)stop {
    self.wantsToStart = NO;
    if (self.controller.isPictureInPictureActive) {
        [self.controller stopPictureInPicture];
    }
}

- (void)reset {
    self.hasVideoFrame = NO;
    self.lastPresentationTime = -1.0;
    [self.displayLayer flushAndRemoveImage];
    if (self.formatDescription) {
        CFRelease(self.formatDescription);
        self.formatDescription = NULL;
    }
    self.formatDimensions = (CMVideoDimensions){0, 0};
}

- (void)invalidatePlaybackState {
    [self.controller invalidatePlaybackState];
}

- (void)invalidate {
    self.wantsToStart = NO;
    self.controller.delegate = nil;
    if (self.controller.isPictureInPictureActive) {
        [self.controller stopPictureInPicture];
    }
    self.controller = nil;
    [self.displayLayer flushAndRemoveImage];
    [self.displayLayer removeFromSuperlayer];
    if (self.formatDescription) {
        CFRelease(self.formatDescription);
        self.formatDescription = NULL;
    }
}

- (CMSampleBufferRef)createSampleBufferForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                               atTime:(NSTimeInterval)time CF_RETURNS_RETAINED {
    CMVideoDimensions dimensions = {
        (int32_t)CVPixelBufferGetWidth(pixelBuffer),
        (int32_t)CVPixelBufferGetHeight(pixelBuffer),
    };
    if (!self.formatDescription ||
        dimensions.width != self.formatDimensions.width ||
        dimensions.height != self.formatDimensions.height) {
        if (self.formatDescription) {
            CFRelease(self.formatDescription);
            self.formatDescription = NULL;
        }
        OSStatus formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                                             pixelBuffer,
                                                                             &_formatDescription);
        if (formatStatus != noErr || !self.formatDescription) {
            NSLog(@"vod custom pip create format description failed:%d", (int)formatStatus);
            return NULL;
        }
        self.formatDimensions = dimensions;
    }

    NSTimeInterval presentationTime = MAX(time, 0.0);
    if (presentationTime <= self.lastPresentationTime) {
        presentationTime = self.lastPresentationTime + (1.0 / 600.0);
    }
    self.lastPresentationTime = presentationTime;

    CMSampleTimingInfo timing = {
        .duration = kCMTimeInvalid,
        .presentationTimeStamp = CMTimeMakeWithSeconds(presentationTime, 600),
        .decodeTimeStamp = kCMTimeInvalid,
    };
    CMSampleBufferRef sampleBuffer = NULL;
    OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                                               pixelBuffer,
                                                               self.formatDescription,
                                                               &timing,
                                                               &sampleBuffer);
    if (status != noErr || !sampleBuffer) {
        NSLog(@"vod custom pip create sample buffer failed:%d", (int)status);
        return NULL;
    }

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    if (attachments && CFArrayGetCount(attachments) > 0) {
        CFMutableDictionaryRef attachment =
            (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(attachment,
                             kCMSampleAttachmentKey_DisplayImmediately,
                             kCFBooleanTrue);
    }
    return sampleBuffer;
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    self.active = YES;
    self.wantsToStart = NO;
    self.willStopNotified = NO;
    [self.delegate vodPictureInPictureControllerDidStart];
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    self.willStopNotified = YES;
    [self.delegate vodPictureInPictureControllerWillStop];
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    if (!self.willStopNotified) {
        [self.delegate vodPictureInPictureControllerWillStop];
    }
    self.active = NO;
    self.wantsToStart = NO;
    self.willStopNotified = NO;
    [self.delegate vodPictureInPictureControllerDidStop];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
 failedToStartPictureInPictureWithError:(NSError *)error {
    NSLog(@"vod custom pip failed to start:%@", error);
    self.active = NO;
    self.wantsToStart = NO;
    [self.delegate vodPictureInPictureControllerDidFailWithErrorCode:ERROR_IOS_PIP_FROM_SYSTEM];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    [self.delegate vodPictureInPictureControllerRestoreUI];
    if (completionHandler) {
        completionHandler(YES);
    }
}

#pragma mark - AVPictureInPictureSampleBufferPlaybackDelegate

- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController *)pictureInPictureController {
    return [self.delegate vodPictureInPictureControllerIsPlaybackPaused];
}

- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController *)pictureInPictureController {
    NSTimeInterval duration = [self.delegate vodPictureInPictureControllerDuration];
    NSTimeInterval currentTime = [self.delegate vodPictureInPictureControllerCurrentTime];
    if (!isfinite(duration) || duration <= 0.0) {
        return kCMTimeRangeInvalid;
    }

    currentTime = isfinite(currentTime) ? MIN(MAX(currentTime, 0.0), duration) : 0.0;
    CMTime hostTime = CMClockGetTime(CMClockGetHostTimeClock());
    CMTime playbackTime = CMTimeMakeWithSeconds(currentTime, 600);
    CMTime rangeStart = CMTimeSubtract(hostTime, playbackTime);
    return CMTimeRangeMake(rangeStart, CMTimeMakeWithSeconds(duration, 600));
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
                        setPlaying:(BOOL)playing {
    [self.delegate vodPictureInPictureControllerSetPlaying:playing];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
                    skipByInterval:(CMTime)skipInterval
                 completionHandler:(void (^)(void))completionHandler {
    NSTimeInterval seconds = CMTimeGetSeconds(skipInterval);
    if (isfinite(seconds)) {
        [self.delegate vodPictureInPictureControllerSkipBySeconds:seconds];
    }
    if (completionHandler) {
        completionHandler();
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
         didTransitionToRenderSize:(CMVideoDimensions)newRenderSize {
}

@end
