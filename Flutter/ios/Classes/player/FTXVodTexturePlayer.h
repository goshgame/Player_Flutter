// Copyright (c) 2022 Tencent. All rights reserved.
#ifndef SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODTEXTUREPLAYER_H_
#define SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODTEXTUREPLAYER_H_

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@class FTXBasePlayer;

NS_ASSUME_NONNULL_BEGIN

@interface FTXVodTexturePlayer : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar
                          players:(NSMutableDictionary<NSNumber *, FTXBasePlayer *> *)players NS_DESIGNATED_INITIALIZER;

- (void)disposeTextureForPlayerId:(NSNumber *)playerId;
- (void)destroy;

@end

NS_ASSUME_NONNULL_END

#endif  // SUPERPLAYER_FLUTTER_IOS_CLASSES_PLAYER_FTXVODTEXTUREPLAYER_H_
