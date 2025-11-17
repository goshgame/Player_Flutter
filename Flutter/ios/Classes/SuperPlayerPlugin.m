// Copyright (c) 2022 Tencent. All rights reserved.
#import "SuperPlayerPlugin.h"
#import "FTXLivePlayer.h"
#import "FTXVodPlayer.h"
#import "FTXTransformation.h"
#import "FTXEvent.h"
#import <MediaPlayer/MediaPlayer.h>
#import "FTXLiteAVSDKHeader.h"
#import "FTXAudioManager.h"
#import "FTXDownloadManager.h"
#import "FtxMessages.h"
#import "FTXLog.h"
#import "FTXRenderViewFactory.h"
#import "FTXPiPKit/FTXPipConstants.h"
#import <CoreVideo/CoreVideo.h>

/// iOS VOD Texture 渲染实现相关类
///
/// FTXVodTexture：实现 FlutterTexture 协议，向 Flutter Engine 提供最新的一帧 CVPixelBuffer
@interface FTXVodTexture : NSObject<FlutterTexture>
@property (nonatomic, assign) int64_t textureId;
@property (atomic, assign) CVPixelBufferRef latestPixelBuffer; // 持有最新帧（需 CFRetain/CFRelease）
@end

@implementation FTXVodTexture
- (instancetype)init {
    if (self = [super init]) {
        _latestPixelBuffer = NULL;
    }
    return self;
}

/// Flutter Engine 拉取像素帧时回调，需返回已经 CFRetain 的像素缓冲
- (CVPixelBufferRef)copyPixelBuffer {
//    NSLog(@"copyPixelBuffer textureId: %ld", _textureId);
    CVPixelBufferRef pixel = NULL;
    @synchronized (self) {
        if (_latestPixelBuffer != NULL) {
            pixel = _latestPixelBuffer;
            CFRetain(pixel);
        }
    }
    return pixel;
}

- (void)dealloc {
    @synchronized (self) {
        if (_latestPixelBuffer != NULL) {
            CFRelease(_latestPixelBuffer);
            _latestPixelBuffer = NULL;
        }
    }
}
@end

/// 记录每个 playerId 对应的 Flutter Texture 实体
@interface FTXTextureEntry : NSObject
@property (nonatomic, assign) int64_t textureId;
@property (nonatomic, strong) FTXVodTexture *texture;
@end

@implementation FTXTextureEntry
@end

@interface SuperPlayerPlugin ()<FTXVodPlayerDelegate,TXFlutterSuperPlayerPluginAPI,TXFlutterNativeAPI, FlutterPlugin, TXLiveBaseDelegate>

@property (nonatomic, strong) NSObject<FlutterPluginRegistrar>* registrar;
@property (nonatomic, strong) NSMutableDictionary *players;
@property (nonatomic, strong) FTXDownloadManager* fTXDownloadManager;
@property (nonatomic, strong) FTXAudioManager* audioManager;
@property (nonatomic, strong) TXPluginFlutterAPI* pluginFlutterApi;
@property (nonatomic, strong) TXPipFlutterAPI* pipFlutterApi;
@property (nonatomic, strong) FTXRenderViewFactory* renderViewFactory;

// Texture 渲染支持：通道与缓存
@property (nonatomic, strong) FlutterMethodChannel *textureChannel;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, FTXTextureEntry*> *textureEntries; // key: playerId

@end

@implementation SuperPlayerPlugin {
    float orginBrightness;
    int mCurrentOrientation;
}

SuperPlayerPlugin* instance;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FTXLOGV(@"called registerWithRegistrar");
    instance = [[SuperPlayerPlugin alloc] initWithRegistrar:registrar];
    SetUpTXFlutterNativeAPI([registrar messenger], instance);
    SetUpTXFlutterSuperPlayerPluginAPI([registrar messenger], instance);
    [registrar addApplicationDelegate:instance];
    [TXLiveBase sharedInstance].delegate = instance;
}

- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FTXLOGV(@"called detachFromEngineForRegistrar");
    if(nil != instance) {
        [instance destory];
    }
    if (nil != _fTXDownloadManager) {
        [_fTXDownloadManager destroy];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    self = [super init];
    if (self) {
        [registrar publish:self];
        _registrar = registrar;
        _players = @{}.mutableCopy;
        self.pluginFlutterApi = [[TXPluginFlutterAPI alloc] initWithBinaryMessenger:[registrar messenger]];
        self.pipFlutterApi = [[TXPipFlutterAPI alloc] initWithBinaryMessenger:[registrar messenger]];
        // light componet init
        orginBrightness = [UIScreen mainScreen].brightness;
        
        // brightness event
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(brightnessDidChange:) name:UIScreenBrightnessDidChangeNotification object:[UIScreen mainScreen]];
        
        [self.audioManager registerVolumeChangeListener:self];
        _fTXDownloadManager = [[FTXDownloadManager alloc] initWithRegistrar:registrar];
        // orientation
        mCurrentOrientation = ORIENTATION_PORTRAIT_UP;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onDeviceOrientationChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        // renderView
        self.renderViewFactory = [[FTXRenderViewFactory alloc] initWithBinaryMessenger:registrar.messenger];
        [registrar registerViewFactory:self.renderViewFactory withId:VIEW_TYPE_FTX_RENDER_VIEW];

        // 注册 Texture 渲染后端通道（与 Android 保持一致），仅用于 VOD
        _textureEntries = @{}.mutableCopy;
        _textureChannel = [FlutterMethodChannel methodChannelWithName:@"com.tencent.vod.flutter/texture" binaryMessenger:[registrar messenger]];
        __weak typeof(self) wself = self;
        [_textureChannel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            if ([call.method isEqualToString:@"createTexture"]) {
                [wself handleCreateTexture:call result:result];
            } else if ([call.method isEqualToString:@"disposeTexture"]) {
                [wself handleDisposeTexture:call result:result];
            } else {
                result(FlutterMethodNotImplemented);
            }
        }];
    }
    return self;
}

/// 创建 Texture 并将 VOD 播放器切换为自定义渲染（外部纹理）
- (void)handleCreateTexture:(FlutterMethodCall *)call result:(FlutterResult)result {
    id pidObj = call.arguments[@"playerId"];
    if (![pidObj isKindOfClass:[NSNumber class]]) {
        FTXLOGE(@"createTexture bad_args: playerId required");
        result([FlutterError errorWithCode:@"bad_args" message:@"playerId required" details:nil]);
        return;
    }
    NSNumber *playerId = (NSNumber *)pidObj;
    
    BOOL renderWithTexture = NO;
    NSNumber *renderWithTextureValue = call.arguments[@"renderWithTexture"];
    if (renderWithTextureValue && [renderWithTextureValue isKindOfClass:NSNumber.class]) {
        renderWithTexture = [renderWithTextureValue boolValue];
    }
    
    FTXBasePlayer *base = self.players[playerId];
    if (base == nil || ![base isKindOfClass:[FTXVodPlayer class]]) {
        FTXLOGE(@"createTexture no vod player for id:%@", playerId);
        result([FlutterError errorWithCode:@"no_player" message:[NSString stringWithFormat:@"player not found or not vod: %@", playerId] details:nil]);
        return;
    }
    // 释放旧的 Texture（若存在）
    FTXTextureEntry *old = self.textureEntries[playerId];
    if (old) {
        @try { [self.registrar.textures unregisterTexture:old.textureId]; } @catch (__unused NSException *e) {}
        [self.textureEntries removeObjectForKey:playerId];
    }

    // 注册新的 FlutterTexture
    FTXVodTexture *texture = [FTXVodTexture new];
    int64_t tid = [self.registrar.textures registerTexture:texture];
    texture.textureId = tid;
    FTXTextureEntry *holder = [FTXTextureEntry new];
    holder.texture = texture;
    holder.textureId = tid;
    self.textureEntries[playerId] = holder;

    // 切换 VOD 播放器到自定义渲染：通过回调推送 CVPixelBuffer
    __weak typeof(self) wSelf = self;
    __weak FTXVodTexture *wTex = texture;
    FTXVodPlayer *vod = (FTXVodPlayer *)base;
    // 仅在 VOD 上支持 Texture，不涉及 DRM/HDR/PIP/字幕内嵌
    [vod enableExternalTextureWithConsumer:^(CVPixelBufferRef _Nonnull pixelBuffer) {
        if (!wTex) return;
        @synchronized (wTex) {
            if (wTex.latestPixelBuffer) {
                CFRelease(wTex.latestPixelBuffer);
                wTex.latestPixelBuffer = NULL;
            }
            if (pixelBuffer) {
                CFRetain(pixelBuffer);
                wTex.latestPixelBuffer = pixelBuffer;
            }
        }
        if (wSelf) {
            [wSelf.registrar.textures textureFrameAvailable:tid];
        }
    } renderWithTexture:renderWithTexture];

    FTXLOGI(@"createTexture success, playerId=%@, textureId=%lld", playerId, tid);
    result(@((int)tid));
}

/// 释放 Texture 资源（不强制恢复 PlatformView，交由上层控制）
- (void)handleDisposeTexture:(FlutterMethodCall *)call result:(FlutterResult)result {
    id pidObj = call.arguments[@"playerId"];
    if (![pidObj isKindOfClass:[NSNumber class]]) {
        FTXLOGE(@"disposeTexture bad_args: playerId required");
        result([FlutterError errorWithCode:@"bad_args" message:@"playerId required" details:nil]);
        return;
    }
    NSNumber *playerId = (NSNumber *)pidObj;
    FTXTextureEntry *entry = self.textureEntries[playerId];
    if (entry) {
        @try { [self.registrar.textures unregisterTexture:entry.textureId]; } @catch (__unused NSException *e) {}
        [self.textureEntries removeObjectForKey:playerId];
    }
    // 关闭 VOD 的自定义渲染
    FTXBasePlayer *base = self.players[playerId];
    if ([base isKindOfClass:[FTXVodPlayer class]]) {
        [(FTXVodPlayer *)base disableExternalTexture];
    }
    FTXLOGI(@"disposeTexture, playerId=%@", playerId);
    result(nil);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    [self.pluginFlutterApi onNativeEventEvent:[TXCommonUtil getParamsWithEvent:EVENT_VOLUME_CHANGED withParams:@{}] completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

-(void) destory
{
    [self.audioManager destory:self];
}

-(void) setSysBrightness:(NSNumber*)brightness {
    FTXLOGV(@"called setSysBrightness,%@", brightness);
    if(brightness.floatValue > 1.0) {
        brightness = [NSNumber numberWithFloat:1.0];
    }
    if(brightness.intValue != -1 && brightness.floatValue < 0) {
        brightness = [NSNumber numberWithFloat:0.01];
    }
    if(brightness.intValue == -1) {
        [[UIScreen mainScreen] setBrightness:orginBrightness];
    } else {
        [[UIScreen mainScreen] setBrightness:brightness.floatValue];
    }
}

-(void) releasePlayerInner:(NSNumber*)playerId {
    FTXLOGV(@"called releasePlayerInner,%@ is start release", playerId);
    FTXBasePlayer *player = [_players objectForKey:playerId];
    if (player != nil) {
        FTXLOGI(@"releasePlayer start destroy player :%@", playerId);
        [player destory];
        [_players removeObjectForKey:playerId];
    }
}

- (FTXAudioManager *)audioManager {
    if (!self->_audioManager) {
        self->_audioManager = [[FTXAudioManager alloc] init];
    }
    return self->_audioManager;
}

/**
 Brightness change.
 */
- (void)brightnessDidChange:(NSNotification *)notification
{
    [self.pluginFlutterApi onNativeEventEvent:[TXCommonUtil getParamsWithEvent:EVENT_BRIGHTNESS_CHANGED withParams:@{}] completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

#pragma mark - FlutterPlugin

- (void)applicationWillTerminate:(UIApplication *)application {
    FTXLOGV(@"called applicationWillTerminate");
    for(id key in self.players) {
        id player = self.players[key];
        if([player respondsToSelector:@selector(notifyAppTerminate:)]) {
            [player notifyAppTerminate:application];
        }
    }
    if (nil != _fTXDownloadManager) {
        [_fTXDownloadManager destroy];
    }
}




#pragma mark - FTXVodPlayerDelegate

- (void)onPlayerPipRequestStart {
    [self.pipFlutterApi onPipEventEvent:@{@"event" : @(EVENT_PIP_MODE_REQUEST_START)} completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

- (void)onPlayerPipStateDidStart {
    [self.pipFlutterApi onPipEventEvent:@{@"event" : @(EVENT_PIP_MODE_ALREADY_ENTER)} completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

- (void)onPlayerPipStateWillStop {
    [self.pipFlutterApi onPipEventEvent:@{@"event" : @(EVENT_PIP_MODE_WILL_EXIT)} completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

- (void)onPlayerPipStateDidStop {
    [self.pipFlutterApi onPipEventEvent:@{@"event" : @(EVENT_PIP_MODE_ALREADY_EXIT)} completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

- (void)onPlayerPipStateError:(NSInteger)errorId {
    [self.pipFlutterApi onPipEventEvent:@{@"event" : @(errorId)} completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

- (void)onPlayerPipStateRestoreUI:(double)playTime {
    [self.pipFlutterApi onPipEventEvent:@{@"event" : @(EVENT_PIP_MODE_RESTORE_UI), EVENT_PIP_PLAY_TIME : @(playTime)} completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

#pragma mark - orientation

- (void)onDeviceOrientationChange:(NSNotification *)notification {
    // For iOS, there is no need to check whether the auto screen rotation/vertical screen lock switch is turned on.
    // When the lock is turned on in iOS, the callback cannot be received by default.
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    int tempOrientationCode = mCurrentOrientation;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            // Battery bar on top.
            tempOrientationCode = ORIENTATION_PORTRAIT_UP;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            // Battery bar on the left.
            tempOrientationCode = ORIENTATION_LANDSCAPE_LEFT;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            // Battery bar on the bottom.
            tempOrientationCode = ORIENTATION_PORTRAIT_DOWN;
            break;
        case UIInterfaceOrientationLandscapeRight:
            // Battery bar on the right.
            tempOrientationCode = ORIENTATION_LANDSCAPE_RIGHT;
            break;
        default:
            break;
    }
    if(tempOrientationCode != mCurrentOrientation) {
        mCurrentOrientation = tempOrientationCode;
        [self.pluginFlutterApi onNativeEventEvent:@{
            @"event" : @(EVENT_ORIENTATION_CHANGED),
            EXTRA_NAME_ORIENTATION : @(tempOrientationCode)} completion:^(FlutterError * _Nullable error) {
            if (nil != error) {
                FTXLOGE(@"callback message error:%@", error);
            }
        }];
    }
}

#pragma mark - superPlayerPluginAPI

- (PlayerMsg *)createVodPlayerOnlyAudio:(BOOL)onlyAudio error:(FlutterError * _Nullable __autoreleasing *)error 
{
    
    FTXVodPlayer* player = [[FTXVodPlayer alloc] initWithRegistrar:self.registrar renderViewFactory:self.renderViewFactory onlyAudio:onlyAudio];
    player.delegate = self;
    NSNumber *playerId = player.playerId;
    _players[playerId] = player;
    FTXLOGI(@"createVodPlayer :%@", playerId);
    return [TXCommonUtil playerMsgWith:playerId];
}


- (PlayerMsg *)createLivePlayerOnlyAudio:(BOOL)onlyAudio error:(FlutterError * _Nullable __autoreleasing *)error {
    FTXLivePlayer* player = [[FTXLivePlayer alloc] initWithRegistrar:self.registrar renderViewFactory:self.renderViewFactory onlyAudio:onlyAudio];
    player.delegate = self;
    NSNumber *playerId = player.playerId;
    _players[playerId] = player;
    FTXLOGI(@"createLivePlayer :%@", playerId);
    return [TXCommonUtil playerMsgWith:playerId];
}

- (nullable StringMsg *)getLiteAVSDKVersionWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    return [TXCommonUtil stringMsgWith:[TXLiveBase getSDKVersionStr]];
}

- (nullable StringMsg *)getPlatformVersionWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    return [TXCommonUtil stringMsgWith:[@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]];
}

- (void)releasePlayerPlayerId:(nonnull PlayerMsg *)playerId error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    NSNumber *pid = playerId.playerId;
    [self releasePlayerInner:pid];
}

- (void)setConsoleEnabledEnabled:(nonnull BoolMsg *)enabled error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    [TXLiveBase setConsoleEnabled:enabled.value];
}

- (nullable BoolMsg *)setGlobalCacheFolderPathPostfixPath:(nonnull StringMsg *)postfixPath error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    NSString* postfixPathStr = postfixPath.value;
    if(postfixPathStr != nil && postfixPathStr.length > 0) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [[paths objectAtIndex:0] stringByAppendingString:@"/"];
        NSString *preloadDataPath = [documentDirectory stringByAppendingPathComponent:postfixPathStr];
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:preloadDataPath withIntermediateDirectories:NO attributes:nil error:&error];
        FTXLOGV(@"setGlobalCacheFolderPathPostfixPath:%@", preloadDataPath);
        [TXPlayerGlobalSetting setCacheFolderPath:preloadDataPath];
        return [TXCommonUtil boolMsgWith:YES];
    } else {
        return [TXCommonUtil boolMsgWith:NO];
    }
}

- (BoolMsg *)setGlobalCacheFolderCustomPathCacheMsg:(CachePathMsg *)cacheMsg error:(FlutterError * _Nullable __autoreleasing *)error {
    NSString* cachePath = cacheMsg.iOSAbsolutePath;
    if (cachePath && cachePath.length > 0) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:&error];
        FTXLOGV(@"setGlobalCacheFolderCustomPathCacheMsg:%@", cachePath);
        [TXPlayerGlobalSetting setCacheFolderPath:cachePath];
        return [TXCommonUtil boolMsgWith:YES];
    } else {
        return [TXCommonUtil boolMsgWith:NO];
    }
}

- (nullable IntMsg *)setGlobalEnvEnvConfig:(nonnull StringMsg *)envConfig error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    int setResult = [TXLiveBase setGlobalEnv:[envConfig.value UTF8String]];
    return [TXCommonUtil intMsgWith:@(setResult)];
}

- (void)setGlobalLicenseLicenseMsg:(nonnull LicenseMsg *)licenseMsg error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    [TXLiveBase setLicenceURL:licenseMsg.licenseUrl key:licenseMsg.licenseKey];
}

- (void)setGlobalMaxCacheSizeSize:(nonnull IntMsg *)size error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    if (size.value > 0) {
        [TXPlayerGlobalSetting setMaxCacheSize:size.value.intValue];
    }
}

- (void)setLogLevelLogLevel:(nonnull IntMsg *)logLevel error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    [TXLiveBase setLogLevel:logLevel.value.intValue];
    [FTXLog setLogLevel:logLevel.value.intValue];
}

- (nullable BoolMsg *)startVideoOrientationServiceWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    // only for android
    return [TXCommonUtil boolMsgWith:YES];
}

- (void)setUserIdMsg:(StringMsg *)msg error:(FlutterError * _Nullable __autoreleasing *)error {
    [TXLiveBase setUserId:msg.value];
}

- (void)setLicenseFlexibleValidMsg:(BoolMsg *)msg error:(FlutterError * _Nullable __autoreleasing *)error {
    [TXPlayerGlobalSetting setLicenseFlexibleValid:msg.value];
}

#pragma mark nativeAPI

- (void)abandonAudioFocusWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    // only for android
}

- (nullable DoubleMsg *)getBrightnessWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    NSNumber *brightness = [NSNumber numberWithFloat:[UIScreen mainScreen].brightness];
    return [TXCommonUtil doubleMsgWith:brightness.doubleValue];
}

- (DoubleMsg *)getSysBrightnessWithError:(FlutterError * _Nullable __autoreleasing *)error {
    NSNumber *brightness = [NSNumber numberWithFloat:[UIScreen mainScreen].brightness];
    return [TXCommonUtil doubleMsgWith:brightness.doubleValue];
}

- (nullable DoubleMsg *)getSystemVolumeWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    NSNumber *volume = [NSNumber numberWithFloat:[self.audioManager getVolume]];
    return [TXCommonUtil doubleMsgWith:volume.doubleValue];
}

- (nullable IntMsg *)isDeviceSupportPipWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    BOOL isSupport = [TXVodPlayer isSupportPictureInPicture];
    int pipSupportResult = isSupport ? 0 : ERROR_IOS_PIP_DEVICE_NOT_SUPPORT;
    return [TXCommonUtil intMsgWith:@(pipSupportResult)];
}

- (void)requestAudioFocusWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    // only for android
}

- (void)restorePageBrightnessWithError:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    [self setSysBrightness:@(-1)];
}

- (void)setBrightnessBrightness:(nonnull DoubleMsg *)brightness error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    [self setSysBrightness:brightness.value];
}

- (void)setSystemVolumeVolume:(nonnull DoubleMsg *)volume error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
    NSNumber *volumeNum = volume.value;
    if (volumeNum.floatValue < 0) {
        volumeNum = [NSNumber numberWithFloat:0];
    }
    if (volumeNum.floatValue > 1) {
        volumeNum = [NSNumber numberWithFloat:1];
    }
    [self.audioManager setVolume:volumeNum.floatValue];
}

- (void)registerSysBrightnessIsRegister:(BoolMsg *)isRegister error:(FlutterError * _Nullable __autoreleasing *)error {
    // only for android
}

- (void)setDrmProvisionEnvEnv:(NSInteger)env error:(FlutterError * _Nullable __autoreleasing *)error {
    // only for android
}

#pragma mark DataBridge

- (NSMutableDictionary *)getPlayers {
    return self.players;
}

#pragma mark TXLiveBaseDelegate

- (void)onLog:(NSString *)log LogLevel:(int)level WhichModule:(NSString *)module {
//    [_eventSink success:[SuperPlayerPlugin getParamsWithEvent:EVENT_ON_LOG withParams:@{
//        @(EVENT_LOG_LEVEL) : @(level),
//        @(EVENT_LOG_MODULE) : module,
//        @(EVENT_LOG_MSG) : log
//    }]];
    // this may be too busy, so currently do not throw on the Flutter side
}

- (void)onUpdateNetworkTime:(int)errCode message:(NSString *)errMsg {
//    [_eventSink success:[SuperPlayerPlugin getParamsWithEvent:EVENT_ON_UPDATE_NETWORK_TIME withParams:@{
//        @(EVENT_ERR_CODE) : @(errCode),
//        @(EVENT_ERR_MSG) : errMsg,
//    }]];
    // This will be opened in a subsequent version
}

- (void)onLicenceLoaded:(int)result Reason:(NSString *)reason {
    FTXLOGV(@"onLicenceLoaded,result:%d, reason:%@", result, reason);
    __block int blockResult = result;
    __block NSString* blockReason = reason;
    __block NSDictionary *param = @{
        @(EVENT_RESULT) : @(blockResult),
        @(EVENT_REASON) : blockReason,
    };
    [self.pluginFlutterApi onSDKListenerEvent:[TXCommonUtil getParamsWithEvent:EVENT_ON_LICENCE_LOADED withParams:param] completion:^(FlutterError * _Nullable error) {
        if (nil != error) {
            FTXLOGE(@"callback message error:%@", error);
        }
    }];
}

- (void)onCustomHttpDNS:(NSString *)hostName ipList:(NSMutableArray<NSString *> *)list {
//    [_eventSink success:[SuperPlayerPlugin getParamsWithEvent:EVENT_ON_LICENCE_LOADED withParams:@{
//        @(EVENT_HOST_NAME) : hostName,
//        @(EVENT_IPS) : list,
//    }]];
    // This will be opened in a subsequent version
}

@end
