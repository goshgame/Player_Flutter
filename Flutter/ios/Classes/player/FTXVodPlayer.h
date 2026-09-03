// Copyright (c) 2022 Tencent. All rights reserved.
#ifndef SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODPLAYER_H_
#define SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODPLAYER_H_

#import <Foundation/Foundation.h>
#import "FTXBasePlayer.h"
#import "FTXVodPlayerDelegate.h"
#import "FTXRenderViewFactory.h"
#import <CoreVideo/CoreVideo.h>

@protocol FlutterPluginRegistrar;

NS_ASSUME_NONNULL_BEGIN

@interface FTXVodPlayer : FTXBasePlayer

@property(nonatomic, weak) id<FTXVodPlayerDelegate> delegate;

- (instancetype)initWithRegistrar:(id<FlutterPluginRegistrar>)registrar
                renderViewFactory:(FTXRenderViewFactory*)renderViewFactory
                        onlyAudio:(BOOL)onlyAudio;

- (void)notifyAppTerminate:(UIApplication *)application;

/// 启用/关闭外部纹理渲染（用于 Flutter Texture）
/// 仅支持 VOD；DRM、HDR 和内嵌字幕场景应继续使用 PlatformView
- (void)enableExternalTextureWithConsumer:(void (^)(CVPixelBufferRef _Nonnull pixelBuffer))consumer renderWithTexture:(BOOL)renderWithTexture;
- (void)disableExternalTexture;
- (void)updateCustomPipHostViewFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

#endif  // SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODPLAYER_H_
