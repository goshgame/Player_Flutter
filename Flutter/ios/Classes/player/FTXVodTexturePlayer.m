// Copyright (c) 2022 Tencent. All rights reserved.
#import "FTXVodTexturePlayer.h"
#import "FTXBasePlayer.h"
#import "FTXVodPlayer.h"

#import <CoreVideo/CoreVideo.h>
#import <math.h>

@interface FTXVodTexture : NSObject<FlutterTexture>
@property (nonatomic, assign) int64_t textureId;
@property (atomic, assign) CVPixelBufferRef latestPixelBuffer;
@end

@implementation FTXVodTexture
- (CVPixelBufferRef)copyPixelBuffer {
    @synchronized (self) {
        if (_latestPixelBuffer) {
            CFRetain(_latestPixelBuffer);
        }
        return _latestPixelBuffer;
    }
}

- (void)dealloc {
    @synchronized (self) {
        if (_latestPixelBuffer) {
            CFRelease(_latestPixelBuffer);
            _latestPixelBuffer = NULL;
        }
    }
}
@end

@interface FTXTextureEntry : NSObject
@property (nonatomic, assign) int64_t textureId;
@property (nonatomic, strong) FTXVodTexture *texture;
@end

@implementation FTXTextureEntry
@end

@interface FTXVodTexturePlayer ()

@property (nonatomic, weak) NSObject<FlutterPluginRegistrar> *registrar;
@property (nonatomic, weak) NSMutableDictionary<NSNumber *, FTXBasePlayer *> *players;
@property (nonatomic, strong) FlutterMethodChannel *textureChannel;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FTXTextureEntry *> *textureEntries;

- (void)handleCreateTexture:(FlutterMethodCall *)call result:(FlutterResult)result;
- (void)handleUpdateTextureViewRect:(FlutterMethodCall *)call result:(FlutterResult)result;
- (void)handleDisposeTexture:(FlutterMethodCall *)call result:(FlutterResult)result;
- (nullable NSValue *)pipHostViewFrameFromArguments:(NSDictionary *)arguments;

@end

@implementation FTXVodTexturePlayer

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar
                          players:(NSMutableDictionary<NSNumber *, FTXBasePlayer *> *)players {
    self = [super init];
    if (self) {
        _registrar = registrar;
        _players = players;
        _textureEntries = @{}.mutableCopy;
        _textureChannel = [FlutterMethodChannel methodChannelWithName:@"com.tencent.vod.flutter/texture"
                                                       binaryMessenger:registrar.messenger];
        __weak typeof(self) weakSelf = self;
        [_textureChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
            if ([call.method isEqualToString:@"createTexture"]) {
                [weakSelf handleCreateTexture:call result:result];
            } else if ([call.method isEqualToString:@"updateTextureViewRect"]) {
                [weakSelf handleUpdateTextureViewRect:call result:result];
            } else if ([call.method isEqualToString:@"disposeTexture"]) {
                [weakSelf handleDisposeTexture:call result:result];
            } else {
                result(FlutterMethodNotImplemented);
            }
        }];
    }
    return self;
}

- (void)handleCreateTexture:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSNumber *playerId = call.arguments[@"playerId"];
    if (![playerId isKindOfClass:NSNumber.class]) {
        result([FlutterError errorWithCode:@"bad_args" message:@"playerId required" details:nil]);
        return;
    }
    FTXBasePlayer *basePlayer = self.players[playerId];
    if (![basePlayer isKindOfClass:FTXVodPlayer.class]) {
        result([FlutterError errorWithCode:@"no_player" message:@"VOD player not found" details:nil]);
        return;
    }

    NSValue *pipHostViewFrame = [self pipHostViewFrameFromArguments:call.arguments];
    if (pipHostViewFrame) {
        [(FTXVodPlayer *)basePlayer updateCustomPipHostViewFrame:pipHostViewFrame.CGRectValue];
    }

    [self disposeTextureForPlayerId:playerId];
    FTXVodTexture *texture = [FTXVodTexture new];
    int64_t textureId = [self.registrar.textures registerTexture:texture];
    texture.textureId = textureId;
    FTXTextureEntry *entry = [FTXTextureEntry new];
    entry.textureId = textureId;
    entry.texture = texture;
    self.textureEntries[playerId] = entry;

    BOOL renderWithTexture = [call.arguments[@"renderWithTexture"] boolValue];
    __weak typeof(self) weakSelf = self;
    __weak FTXVodTexture *weakTexture = texture;
    [(FTXVodPlayer *)basePlayer enableExternalTextureWithConsumer:^(CVPixelBufferRef pixelBuffer) {
        FTXVodTexture *strongTexture = weakTexture;
        if (!strongTexture) {
            return;
        }
        @synchronized (strongTexture) {
            if (strongTexture.latestPixelBuffer) {
                CFRelease(strongTexture.latestPixelBuffer);
            }
            strongTexture.latestPixelBuffer = pixelBuffer;
            if (pixelBuffer) {
                CFRetain(pixelBuffer);
            }
        }
        [weakSelf.registrar.textures textureFrameAvailable:textureId];
    } renderWithTexture:renderWithTexture];
    result(@(textureId));
}

- (void)handleUpdateTextureViewRect:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSNumber *playerId = call.arguments[@"playerId"];
    if (![playerId isKindOfClass:NSNumber.class]) {
        result([FlutterError errorWithCode:@"bad_args" message:@"playerId required" details:nil]);
        return;
    }
    FTXBasePlayer *basePlayer = self.players[playerId];
    if (![basePlayer isKindOfClass:FTXVodPlayer.class]) {
        result([FlutterError errorWithCode:@"no_player" message:@"VOD player not found" details:nil]);
        return;
    }
    NSValue *pipHostViewFrame = [self pipHostViewFrameFromArguments:call.arguments];
    if (!pipHostViewFrame) {
        result([FlutterError errorWithCode:@"bad_args" message:@"valid pipHostViewRect required" details:nil]);
        return;
    }
    [(FTXVodPlayer *)basePlayer updateCustomPipHostViewFrame:pipHostViewFrame.CGRectValue];
    result(nil);
}

- (nullable NSValue *)pipHostViewFrameFromArguments:(NSDictionary *)arguments {
    if (![arguments isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSDictionary *pipHostViewRect = arguments[@"pipHostViewRect"];
    if ([pipHostViewRect isKindOfClass:NSDictionary.class]) {
        NSNumber *x = pipHostViewRect[@"x"];
        NSNumber *y = pipHostViewRect[@"y"];
        NSNumber *width = pipHostViewRect[@"width"];
        NSNumber *height = pipHostViewRect[@"height"];
        if ([x isKindOfClass:NSNumber.class] &&
            [y isKindOfClass:NSNumber.class] &&
            [width isKindOfClass:NSNumber.class] &&
            [height isKindOfClass:NSNumber.class] &&
            isfinite(x.doubleValue) &&
            isfinite(y.doubleValue) &&
            isfinite(width.doubleValue) &&
            isfinite(height.doubleValue) &&
            width.doubleValue > 0.0 &&
            height.doubleValue > 0.0) {
            CGRect frame = CGRectMake(x.doubleValue,
                                      y.doubleValue,
                                      width.doubleValue,
                                      height.doubleValue);
            return [NSValue valueWithCGRect:frame];
        }
    }
    return nil;
}

- (void)handleDisposeTexture:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSNumber *playerId = call.arguments[@"playerId"];
    if (![playerId isKindOfClass:NSNumber.class]) {
        result([FlutterError errorWithCode:@"bad_args" message:@"playerId required" details:nil]);
        return;
    }
    [self disposeTextureForPlayerId:playerId];
    result(nil);
}

- (void)disposeTextureForPlayerId:(NSNumber *)playerId {
    FTXBasePlayer *player = self.players[playerId];
    if ([player isKindOfClass:FTXVodPlayer.class]) {
        [(FTXVodPlayer *)player disableExternalTexture];
    }
    FTXTextureEntry *entry = self.textureEntries[playerId];
    if (entry) {
        [self.registrar.textures unregisterTexture:entry.textureId];
        [self.textureEntries removeObjectForKey:playerId];
    }
}

- (void)destroy {
    for (NSNumber *playerId in self.textureEntries.allKeys) {
        [self disposeTextureForPlayerId:playerId];
    }
    [self.textureChannel setMethodCallHandler:nil];
    self.textureChannel = nil;
}

@end
