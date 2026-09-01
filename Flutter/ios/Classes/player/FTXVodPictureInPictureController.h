// Copyright (c) 2026 Tencent. All rights reserved.

#ifndef SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODPICTUREINPICTURECONTROLLER_H_
#define SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODPICTUREINPICTURECONTROLLER_H_

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FTXVodPictureInPictureControllerDelegate <NSObject>

- (BOOL)vodPictureInPictureControllerIsPlaybackPaused;
- (NSTimeInterval)vodPictureInPictureControllerCurrentTime;
- (NSTimeInterval)vodPictureInPictureControllerDuration;
- (void)vodPictureInPictureControllerSetPlaying:(BOOL)playing;
- (void)vodPictureInPictureControllerSkipBySeconds:(NSTimeInterval)seconds;
- (void)vodPictureInPictureControllerDidStart;
- (void)vodPictureInPictureControllerWillStop;
- (void)vodPictureInPictureControllerDidStop;
- (void)vodPictureInPictureControllerRestoreUI;
- (void)vodPictureInPictureControllerDidFailWithErrorCode:(NSInteger)errorCode;

@end

API_AVAILABLE(ios(15.0))
@interface FTXVodPictureInPictureController : NSObject

@property (nonatomic, weak, nullable) id<FTXVodPictureInPictureControllerDelegate> delegate;
@property (nonatomic, assign) BOOL canStartPictureInPictureAutomaticallyFromInline;
@property (nonatomic, assign, readonly, getter=isActive) BOOL active;
@property (nonatomic, assign, readonly, getter=isStarting) BOOL starting;

- (instancetype)initWithDelegate:(id<FTXVodPictureInPictureControllerDelegate>)delegate;
- (void)attachToHostView:(UIView *)hostView;
- (void)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer atTime:(NSTimeInterval)time;
- (void)start;
- (void)stop;
- (void)reset;
- (void)invalidatePlaybackState;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END

#endif  // SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODPICTUREINPICTURECONTROLLER_H_
