// Copyright (c) 2022 Tencent. All rights reserved.

package com.tencent.vod.flutter;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.ContentObserver;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.provider.Settings.SettingNotFoundException;
import android.text.TextUtils;
import android.util.SparseArray;
import android.view.OrientationEventListener;
import android.view.Window;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.tencent.liteav.base.util.LiteavLog;
import com.tencent.rtmp.TXLiveBase;
import com.tencent.rtmp.TXLiveBaseListener;
import com.tencent.rtmp.TXPlayerGlobalSetting;
import com.tencent.vod.flutter.common.FTXPlayerConstants;
import com.tencent.vod.flutter.messages.FtxMessages;
import com.tencent.vod.flutter.messages.FtxMessages.BoolMsg;
import com.tencent.vod.flutter.messages.FtxMessages.DoubleMsg;
import com.tencent.vod.flutter.messages.FtxMessages.IntMsg;
import com.tencent.vod.flutter.messages.FtxMessages.LicenseMsg;
import com.tencent.vod.flutter.messages.FtxMessages.PlayerMsg;
import com.tencent.vod.flutter.messages.FtxMessages.StringMsg;
import com.tencent.vod.flutter.messages.FtxMessages.TXFlutterNativeAPI;
import com.tencent.vod.flutter.messages.FtxMessages.TXFlutterSuperPlayerPluginAPI;
import com.tencent.vod.flutter.player.FTXBasePlayer;
import com.tencent.vod.flutter.player.FTXLivePlayer;
import com.tencent.vod.flutter.player.FTXVodPlayer;
import com.tencent.vod.flutter.tools.TXCommonUtil;
import com.tencent.vod.flutter.tools.TXFlutterEngineHolder;
import com.tencent.vod.flutter.ui.TXAndroid12BridgeService;
import com.tencent.vod.flutter.ui.render.FTXRenderViewFactory;

import java.io.File;
import java.math.BigDecimal;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

/**
 * SuperPlayerPlugin
 * <p>
 * The MethodChannel that will the communication between Flutter and native Android
 * This local reference serves to register the plugin with the Flutter Engine and unregister it
 * when the Flutter Engine is detached from the Activity
 * </p>
 */
public class SuperPlayerPlugin implements FlutterPlugin, ActivityAware,
        TXFlutterSuperPlayerPluginAPI, TXFlutterNativeAPI, FtxMessages.VoidResult {

    static final String TAG = "SuperPlayerPlugin";
    private static final String VOLUME_CHANGED_ACTION = "android.media.VOLUME_CHANGED_ACTION";
    private static final String EXTRA_VOLUME_STREAM_TYPE = "android.media.EXTRA_VOLUME_STREAM_TYPE";

    private VolumeBroadcastReceiver mVolumeBroadcastReceiver;

    private FlutterPluginBinding mFlutterPluginBinding;
    private final SparseArray<FTXBasePlayer> mPlayers = new SparseArray<>();

    private FTXDownloadManager mFTXDownloadManager;
    private FTXAudioManager mTxAudioManager;
    private FTXPIPManager mTxPipManager;

    private OrientationEventListener mOrientationManager;
    private int mCurrentOrientation = FTXEvent.ORIENTATION_PORTRAIT_UP;
    private boolean mIsBrightnessObserverRegistered = false;
    private final Handler mMainHandler = new Handler(Looper.getMainLooper());
    private FtxMessages.TXPluginFlutterAPI mPluginApi;
    private FTXRenderViewFactory mRenderViewFactory;

    // Texture 后端通道与缓存
    private MethodChannel mTextureChannel;
    private final Map<Integer, TextureEntryHolder> mTextureEntries = new HashMap<>();
    // 单例引用，便于播放器回调分辨率时更新 Texture 的默认缓冲尺寸
    private static SuperPlayerPlugin sInstance;

    /**
     * 保存每个 playerId 对应的 Flutter Texture 资源，便于释放和复用。
     */
    private static final class TextureEntryHolder {
        final TextureRegistry.SurfaceTextureEntry entry;
        final android.view.Surface surface;
        final long id;

        TextureEntryHolder(TextureRegistry.SurfaceTextureEntry entry) {
            this.entry = entry;
            this.surface = new android.view.Surface(entry.surfaceTexture());
            this.id = entry.id();
        }

        void release() {
            try {
                surface.release();
            } catch (Throwable t) {
                // ignore
            }
            try {
                entry.release();
            } catch (Throwable t) {
                // ignore
            }
        }
    }

    private final FTXAudioManager.AudioFocusChangeListener audioFocusChangeListener =
            new FTXAudioManager.AudioFocusChangeListener() {
                @Override
                public void onAudioFocusPause() {
                    onHandleAudioFocusPause();
                }

                @Override
                public void onAudioFocusPlay() {
                    onHandleAudioFocusPlay();
                }
            };

    private final ContentObserver brightnessObserver = new ContentObserver(new Handler(Looper.getMainLooper())) {
        @Override
        public void onChange(boolean selfChange, @NonNull Collection<Uri> uris, int flags) {
            super.onChange(selfChange, uris, flags);
            setWindowBrightness(-1D);
        }
    };

    private final TXLiveBaseListener mSDKEvent = new TXLiveBaseListener() {
        @Override
        public void onLog(int level, String module, String liteavLog) {
            super.onLog(level, module, liteavLog);
//            mMainHandler.post(new Runnable() {
//                @Override
//                public void run() {
//                    Bundle params = new Bundle();
//                    params.putInt(FTXEvent.EVENT_LOG_LEVEL, level);
//                    params.putString(FTXEvent.EVENT_LOG_MODULE, module);
//                    params.putString(FTXEvent.EVENT_LOG_MSG, LiteavLog);
//                    mEventSink.success(getParams(FTXEvent.EVENT_ON_LOG, params));
//                }
//            });

            // this may be too busy, so currently do not throw on the Flutter side
        }

        @Override
        public void onUpdateNetworkTime(int errCode, String errMsg) {
            super.onUpdateNetworkTime(errCode, errMsg);
//            mMainHandler.post(new Runnable() {
//                @Override
//                public void run() {
//                    Bundle params = new Bundle();
//                    params.putInt(FTXEvent.EVENT_ERR_CODE, errCode);
//                    params.putString(FTXEvent.EVENT_ERR_MSG, errMsg);
//                    mEventSink.success(getParams(FTXEvent.EVENT_ON_UPDATE_NETWORK_TIME, params));
//                }
//            });
            // This will be opened in a subsequent version
        }

        @Override
        public void onLicenceLoaded(int result, String reason) {
            super.onLicenceLoaded(result, reason);
            LiteavLog.v(TAG, "onLicenceLoaded,result:" + result + ",reason:" + reason);
            mMainHandler.post(new Runnable() {
                @Override
                public void run() {
                    Bundle params = new Bundle();
                    params.putInt(FTXEvent.EVENT_RESULT, result);
                    params.putString(FTXEvent.EVENT_REASON, reason);
                    mPluginApi.onSDKListener(getParams(FTXEvent.EVENT_ON_LICENCE_LOADED, params),
                            SuperPlayerPlugin.this);
                }
            });
        }

        @Override
        public void onCustomHttpDNS(String hostName, List<String> ipList) {
            super.onCustomHttpDNS(hostName, ipList);
//            mMainHandler.post(new Runnable() {
//                @Override
//                public void run() {
//                    Bundle params = new Bundle();
//                    params.putString(FTXEvent.EVENT_HOST_NAME, hostName);
//                    ArrayList<String> ipArrayList = new ArrayList<>(ipList);
//                    params.putStringArrayList(FTXEvent.EVENT_IPS, ipArrayList);
//                    mEventSink.success(getParams(FTXEvent.EVENT_ON_CUSTOM_HTTP_DNS, params));
//                }
//            });
            // This will be opened in a subsequent version
        }
    };

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        LiteavLog.i(TAG, "onAttachedToEngine");
        sInstance = this;
        mRenderViewFactory = new FTXRenderViewFactory(flutterPluginBinding.getBinaryMessenger());
        flutterPluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory(FTXEvent.FTX_RENDER_VIEW, mRenderViewFactory);
        LiteavLog.i(TAG, "plugin version is:" + BuildConfig.FLUTTER_PLAYER_VERSION);
        TXFlutterSuperPlayerPluginAPI.setUp(flutterPluginBinding.getBinaryMessenger(), this);
        TXFlutterNativeAPI.setUp(flutterPluginBinding.getBinaryMessenger(), this);
        mPluginApi = new FtxMessages.TXPluginFlutterAPI(flutterPluginBinding.getBinaryMessenger());
        mFlutterPluginBinding = flutterPluginBinding;
        TXFlutterEngineHolder.getInstance().attachBindLife(flutterPluginBinding);
        // register download message channel
        mFTXDownloadManager = new FTXDownloadManager(mFlutterPluginBinding);
        registerReceiver();
        TXLiveBase.setListener(mSDKEvent);

        // 注册 Texture 渲染后端通道（增量能力，不影响既有 Pigeon 通道）
        mTextureChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(),
                "com.tencent.vod.flutter/texture");
        mTextureChannel.setMethodCallHandler(new MethodChannel.MethodCallHandler() {
            @Override
            public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
                switch (call.method) {
                    case "createTexture":
                        handleCreateTexture(call, result);
                        break;
                    case "disposeTexture":
                        handleDisposeTexture(call, result);
                        break;
                    default:
                        result.notImplemented();
                }
            }
        });
    }

    public static SuperPlayerPlugin getInstance() {
        return sInstance;
    }

    private void handleCreateTexture(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        final Object pidObj = call.argument("playerId");
        if (!(pidObj instanceof Integer)) {
            LiteavLog.e(TAG, "createTexture bad_args: playerId required");
            result.error("bad_args", "playerId required", null);
            return;
        }
        final int playerId = (Integer) pidObj;
        final FTXBasePlayer base = mPlayers.get(playerId);
        if (base == null) {
            LiteavLog.e(TAG, "createTexture no_player: " + playerId);
            result.error("no_player", "player not found: " + playerId, null);
            return;
        }

        // 如果已存在旧的 Texture，先释放
        TextureEntryHolder old = mTextureEntries.remove(playerId);
        if (old != null) {
            try { old.release(); } catch (Throwable ignore) {}
        }

        // 创建 Flutter 提供的 SurfaceTexture，并将 Surface 绑定到播放器
        final TextureRegistry.SurfaceTextureEntry entry = mFlutterPluginBinding.getTextureRegistry().createSurfaceTexture();
        final TextureEntryHolder holder = new TextureEntryHolder(entry);
        mTextureEntries.put(playerId, holder);

        try {
            // 解除 PlatformView 绑定，切换为直接 Surface 输出
            if (base instanceof com.tencent.vod.flutter.player.render.FTXPlayerRenderHost) {
                ((com.tencent.vod.flutter.player.render.FTXPlayerRenderHost) base).setRenderView(null);
            }
            if (base instanceof com.tencent.vod.flutter.player.render.FTXPlayerRenderSurfaceHost) {
                ((com.tencent.vod.flutter.player.render.FTXPlayerRenderSurfaceHost) base).setSurface(holder.surface);
            }
            // 为新创建的 Texture 设置一个合理的默认缓冲尺寸，避免早期 1x1 造成的整屏单像素
            try {
                int fallbackW = 720; // 兜底宽
                int fallbackH = 1280; // 兜底高
                holder.entry.surfaceTexture().setDefaultBufferSize(fallbackW, fallbackH);
                LiteavLog.i(TAG, "createTexture setDefaultBufferSize fallback " + fallbackW + "x" + fallbackH
                        + ", playerId=" + playerId + ", textureId=" + holder.id);
            } catch (Throwable ignore) {}
            LiteavLog.i(TAG, "createTexture success, playerId=" + playerId + ", textureId=" + holder.id);
            result.success((int) holder.id);
        } catch (Throwable t) {
            // 创建或绑定失败，回滚并返回错误，Flutter 端将回退 PlatformView
            mTextureEntries.remove(playerId);
            try { holder.release(); } catch (Throwable ignore) {}
            LiteavLog.e(TAG, "createTexture failed: " + t);
            result.error("create_failed", t.getMessage(), null);
        }
    }

    private void handleDisposeTexture(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        final Object pidObj = call.argument("playerId");
        if (!(pidObj instanceof Integer)) {
            LiteavLog.e(TAG, "disposeTexture bad_args: playerId required");
            result.error("bad_args", "playerId required", null);
            return;
        }
        final int playerId = (Integer) pidObj;
        TextureEntryHolder holder = mTextureEntries.remove(playerId);
        if (holder != null) {
            try { holder.release(); } catch (Throwable ignore) {}
        }
        // 释放时不强制恢复 PlatformView，由上层自行决定
        LiteavLog.i(TAG, "disposeTexture, playerId=" + playerId);
        result.success(null);
    }

    /**
     * 在拿到视频真实分辨率后，更新对应 playerId 的 Texture 默认缓冲尺寸，规避 1x1 问题。
     */
    public void updateTextureBufferSizeByPlayer(int playerId, int videoW, int videoH) {
        if (playerId <= 0 || videoW <= 0 || videoH <= 0) return;
        TextureEntryHolder holder = mTextureEntries.get(playerId);
        if (holder == null) return;
        try {
            holder.entry.surfaceTexture().setDefaultBufferSize(videoW, videoH);
            LiteavLog.i(TAG, "updateTextureBufferSizeByPlayer setDefaultBufferSize " + videoW + "x" + videoH
                    + ", playerId=" + playerId + ", textureId=" + holder.id);
        } catch (Throwable t) {
            LiteavLog.e(TAG, "updateTextureBufferSizeByPlayer error: " + t);
        }
    }

    /******* native method call start *******/

    @NonNull
    @Override
    public StringMsg getPlatformVersion() {
        StringMsg stringMsg = new StringMsg();
        stringMsg.setValue("Android " + android.os.Build.VERSION.RELEASE);
        return stringMsg;
    }

    @NonNull
    @Override
    public PlayerMsg createVodPlayer(@NonNull Boolean onlyAudio) {
        FTXVodPlayer player = new FTXVodPlayer(mFlutterPluginBinding, getPipManager(), mRenderViewFactory, onlyAudio);
        int playerId = player.getPlayerId();
        mPlayers.append(playerId, player);
        PlayerMsg playerMsg = new PlayerMsg();
        playerMsg.setPlayerId((long) playerId);
        LiteavLog.i(TAG, "createVodPlayer :" + playerId);
        return playerMsg;
    }

    @NonNull
    @Override
    public PlayerMsg createLivePlayer(@NonNull Boolean onlyAudio) {
        FTXLivePlayer player = new FTXLivePlayer(mFlutterPluginBinding, getPipManager(), mRenderViewFactory, onlyAudio);
        int playerId = player.getPlayerId();
        mPlayers.append(playerId, player);
        PlayerMsg playerMsg = new PlayerMsg();
        playerMsg.setPlayerId((long) playerId);
        LiteavLog.i(TAG, "createLivePlayer :" + playerId);
        return playerMsg;
    }

    @Override
    public void setConsoleEnabled(@NonNull BoolMsg enabled) {
        if (enabled.getValue() != null) {
            TXLiveBase.setConsoleEnabled(enabled.getValue());
        }
    }

    @Override
    public void releasePlayer(@NonNull PlayerMsg playerId) {
        if (null != playerId.getPlayerId()) {
            int intPlayerId = playerId.getPlayerId().intValue();
            LiteavLog.i(TAG, "releasePlayer :" + intPlayerId);
            FTXBasePlayer player = mPlayers.get(intPlayerId);
            if (player != null) {
                LiteavLog.i(TAG, "releasePlayer start destroy player :" + intPlayerId);
                player.destroy();
                mPlayers.remove(intPlayerId);
            }
        }
    }

    @Override
    public void setGlobalMaxCacheSize(@NonNull IntMsg size) {
        if (null != size.getValue() && size.getValue() > 0) {
            TXPlayerGlobalSetting.setMaxCacheSize(size.getValue().intValue());
        }
    }

    @NonNull
    @Override
    public BoolMsg setGlobalCacheFolderPath(@NonNull StringMsg postfixPath) {
        boolean configResult = false;
        if (!TextUtils.isEmpty(postfixPath.getValue())) {
            File sdcardDir = mFlutterPluginBinding.getApplicationContext().getExternalFilesDir(null);
            if (null != sdcardDir) {
                LiteavLog.v(TAG, "setGlobalCacheFolderPath:" + postfixPath.getValue());
                TXPlayerGlobalSetting.setCacheFolderPath(sdcardDir.getPath() + File.separator + postfixPath.getValue());
                configResult = true;
            }
        }
        BoolMsg boolMsg = new BoolMsg();
        boolMsg.setValue(configResult);
        return boolMsg;
    }

    @NonNull
    @Override
    public BoolMsg setGlobalCacheFolderCustomPath(@NonNull FtxMessages.CachePathMsg cacheMsg) {
        boolean configResult = false;
        final String cachePath = cacheMsg.getAndroidAbsolutePath();
        if (!TextUtils.isEmpty(cachePath)) {
            LiteavLog.v(TAG, "setGlobalCacheFolderCustomPath:" + cachePath);
            TXPlayerGlobalSetting.setCacheFolderPath(cachePath);
            configResult = true;
        }
        BoolMsg boolMsg = new BoolMsg();
        boolMsg.setValue(configResult);
        return boolMsg;
    }

    @Override
    public void setGlobalLicense(@NonNull LicenseMsg licenseMsg) {
        TXLiveBase.getInstance().setLicence(mFlutterPluginBinding.getApplicationContext(), licenseMsg.getLicenseUrl(),
                licenseMsg.getLicenseKey());
    }

    @Override
    public void setLogLevel(@NonNull IntMsg logLevel) {
        if (null != logLevel.getValue()) {
            TXLiveBase.setLogLevel(logLevel.getValue().intValue());
        }
    }

    @NonNull
    @Override
    public StringMsg getLiteAVSDKVersion() {
        StringMsg stringMsg = new StringMsg();
        stringMsg.setValue(TXLiveBase.getSDKVersionStr());
        return stringMsg;
    }

    @NonNull
    @Override
    public IntMsg setGlobalEnv(@NonNull StringMsg envConfig) {
        int setResult = TXLiveBase.setGlobalEnv(envConfig.getValue());
        IntMsg intMsg = new IntMsg();
        intMsg.setValue((long) setResult);
        return intMsg;
    }

    @NonNull
    @Override
    public BoolMsg startVideoOrientationService() {
        boolean setResult = innerStartVideoOrientationService();
        BoolMsg boolMsg = new BoolMsg();
        boolMsg.setValue(setResult);
        return boolMsg;
    }

    @Override
    public void setUserId(@NonNull StringMsg msg) {
        TXLiveBase.setUserId(msg.getValue());
    }

    @Override
    public void setLicenseFlexibleValid(@NonNull BoolMsg msg) {
        if (null != msg.getValue()) {
            TXPlayerGlobalSetting.setLicenseFlexibleValid(msg.getValue());
        }
    }

    @Override
    public void setDrmProvisionEnv(@NonNull Long env) {
        if (env == FTXPlayerConstants.FTXDrmProvisionEnvInt.DRM_PROVISION_ENV_CN) {
            TXPlayerGlobalSetting.setDrmProvisionEnv(TXPlayerGlobalSetting.DrmProvisionEnv.DRM_PROVISION_ENV_CN);
        } else {
            TXPlayerGlobalSetting.setDrmProvisionEnv(TXPlayerGlobalSetting.DrmProvisionEnv.DRM_PROVISION_ENV_COM);
        }
    }

    /******* native method call end *******/


    private boolean innerStartVideoOrientationService() {
        if (null == mFlutterPluginBinding) {
            return false;
        }
        if (null == mOrientationManager) {
            try {
                mOrientationManager = new OrientationEventListener(mFlutterPluginBinding.getApplicationContext()) {
                    @Override
                    public void onOrientationChanged(int orientation) {
                        if (isDeviceAutoRotateOn()) {
                            LiteavLog.v(TAG, "onOrientationChanged:" + orientation);
                            int orientationEvent = getOrientationEvent(orientation);
                            if (orientationEvent != mCurrentOrientation) {
                                LiteavLog.v(TAG, "orientationEvent changed:" + orientationEvent);
                                mCurrentOrientation = orientationEvent;
                                Bundle bundle = new Bundle();
                                bundle.putInt(FTXEvent.EXTRA_NAME_ORIENTATION, orientationEvent);
                                mPluginApi.onNativeEvent(getParams(FTXEvent.EVENT_ORIENTATION_CHANGED, bundle)
                                        , SuperPlayerPlugin.this);
                            }
                        }
                    }
                };
                mOrientationManager.enable();
            } catch (Exception e) {
                LiteavLog.e(TAG, "innerStartVideoOrientationService error", e);
                return false;
            }
        }
        return true;
    }

    private int getOrientationEvent(int orientation) {
        int orientationEvent = mCurrentOrientation;
        // Each direction judges the current direction with an interval
        // of 60 degrees, with a total of 6 intervals.
        if (((orientation >= 0) && (orientation < 30)) || (orientation > 330)) {
            orientationEvent = FTXEvent.ORIENTATION_PORTRAIT_UP;
        } else if (orientation > 240 && orientation < 300) {
            orientationEvent = FTXEvent.ORIENTATION_LANDSCAPE_RIGHT;
        } else if (orientation > 150 && orientation < 210) {
            orientationEvent = FTXEvent.ORIENTATION_PORTRAIT_DOWN;
        } else if (orientation > 60 && orientation < 110) {
            orientationEvent = FTXEvent.ORIENTATION_LANDSCAPE_LEFT;
        }
        return orientationEvent;
    }

    /**
     * Set the current window brightness.
     *
     * 设置当前window亮度
     */
    private void setWindowBrightness(Double brightness) {
        if (null != brightness) {
            LiteavLog.v(TAG, "setWindowBrightness:" + brightness);
            // 保留两位小数
            BigDecimal bigDecimal = new BigDecimal(brightness);
            brightness = bigDecimal.setScale(2, BigDecimal.ROUND_HALF_UP).doubleValue();
            final Activity act = TXFlutterEngineHolder.getInstance().getCurActivity();
            if (null != act && !act.isDestroyed()) {
                Window window = act.getWindow();
                if (null != window) {
                    WindowManager.LayoutParams params = window.getAttributes();
                    params.screenBrightness = Float.parseFloat(String.valueOf(brightness));
                    if (params.screenBrightness > 1.0f) {
                        params.screenBrightness = 1.0f;
                    }
                    if (params.screenBrightness != -1 && params.screenBrightness < 0) {
                        params.screenBrightness = 0.01f;
                    }
                    window.setAttributes(params);
                    // 发送亮度变化通知
                    mPluginApi.onNativeEvent(getParams(FTXEvent.EVENT_BRIGHTNESS_CHANGED, null), this);
                }
            }
        }
    }

    /**
     * Get the current window brightness. If the current window brightness is not assigned,
     * return the current system brightness.
     *
     * 获得当前window亮度，如果当前window亮度未赋值，则返回当前系统亮度
     */
    private float getWindowBrightness() {
        final Activity act = TXFlutterEngineHolder.getInstance().getCurActivity();
        Window window = act.getWindow();
        WindowManager.LayoutParams params = window.getAttributes();
        float screenBrightness = params.screenBrightness;
        if (screenBrightness < 0) {
            screenBrightness = getSystemScreenBrightness();
        }
        // 保留两位小数
        BigDecimal bigDecimal = new BigDecimal(screenBrightness);
        bigDecimal = bigDecimal.setScale(2, BigDecimal.ROUND_HALF_UP);
        return bigDecimal.floatValue();
    }

    private float getSystemScreenBrightness() {
        float screenBrightness = -1;
        try {
            ContentResolver resolver = mFlutterPluginBinding.getApplicationContext().getContentResolver();
            final int brightnessInt = Settings.System.getInt(resolver, Settings.System.SCREEN_BRIGHTNESS);
            final float maxBrightness = TXCommonUtil.getBrightnessMax();
            screenBrightness = brightnessInt / maxBrightness;
        } catch (SettingNotFoundException e) {
            e.printStackTrace();
        }
        return screenBrightness;
    }

    private FTXAudioManager getAudioManager() {
        if (null == mTxAudioManager) {
            mTxAudioManager = new FTXAudioManager(mFlutterPluginBinding.getApplicationContext());
            mTxAudioManager.addAudioFocusChangedListener(audioFocusChangeListener);
        }
        return mTxAudioManager;
    }

    private FTXPIPManager getPipManager() {
        if (null == mTxPipManager) {
            mTxPipManager = new FTXPIPManager(mFlutterPluginBinding);
        }
        return mTxPipManager;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        LiteavLog.i(TAG, "onDetachedFromEngine");
        sInstance = null;
        mFTXDownloadManager.destroy();
        if (null != mOrientationManager) {
            mOrientationManager.disable();
        }
        if (null != mTxPipManager) {
            mTxPipManager.releaseActivityListener();
            mTxPipManager.exitCurrentPip();
        }
        // Close the solution to the problem of the picture-in-picture click restore
        // failure on some versions of Android 12.
        // 关闭用于解决Android12部分版本上画中画点击还原失灵的问题
        Intent serviceIntent = new Intent(binding.getApplicationContext(), TXAndroid12BridgeService.class);
        binding.getApplicationContext().stopService(serviceIntent);
        unregisterReceiver();
        TXFlutterEngineHolder.getInstance().destroy(binding);
        TXLiveBase.setListener(null);
        mFlutterPluginBinding = null;
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        LiteavLog.v(TAG, "called onAttachedToActivity");
    }

    @Override
    public void onDetachedFromActivity() {
        LiteavLog.v(TAG, "called onDetachedFromActivity");
    }

    void onHandleAudioFocusPause() {
        mPluginApi.onNativeEvent(getParams(FTXEvent.EVENT_AUDIO_FOCUS_PAUSE, null), this);
    }

    void onHandleAudioFocusPlay() {
        mPluginApi.onNativeEvent(getParams(FTXEvent.EVENT_AUDIO_FOCUS_PLAY, null), this);
    }

    /**
     * Whether the system allows automatic screen rotation.
     *
     * 系统是否允许自动旋转屏幕
     */
    protected boolean isDeviceAutoRotateOn() {
        //获取系统是否允许自动旋转屏幕
        try {
            return (android.provider.Settings.System.getInt(
                    mFlutterPluginBinding.getApplicationContext().getContentResolver(),
                    Settings.System.ACCELEROMETER_ROTATION, 0) == 1);
        } catch (Exception e) {
            LiteavLog.e(TAG, "isDeviceAutoRotateOn error", e);
            return false;
        }
    }

    /**
     * Register volume broadcast receiver.
     *
     * 注册音量广播接收器
     */
    @SuppressLint("WrongConstant")
    public void registerReceiver() {
        // volume receiver
        mVolumeBroadcastReceiver = new VolumeBroadcastReceiver(mPluginApi);
        IntentFilter filter = new IntentFilter();
        filter.addAction(VOLUME_CHANGED_ACTION);
        ContextCompat.registerReceiver(mFlutterPluginBinding.getApplicationContext(), mVolumeBroadcastReceiver, filter,
                ContextCompat.RECEIVER_NOT_EXPORTED);
    }

    public void enableBrightnessObserver(boolean enable) {
        if (null != mFlutterPluginBinding) {
            if (enable) {
                if (!mIsBrightnessObserverRegistered) {
                    // brightness observer
                    ContentResolver resolver = mFlutterPluginBinding.getApplicationContext().getContentResolver();
                    resolver.registerContentObserver(Settings.System.getUriFor(Settings.System.SCREEN_BRIGHTNESS),
                            true, brightnessObserver);
                    mIsBrightnessObserverRegistered = true;
                }
            } else {
                mFlutterPluginBinding.getApplicationContext().getContentResolver()
                        .unregisterContentObserver(brightnessObserver);
                mIsBrightnessObserverRegistered = false;
            }
        }
    }

    /**
     * Unregister volume broadcast listener. It needs to be used in pairs with registerReceiver.
     *
     * 反注册音量广播监听器，需要与 registerReceiver 成对使用
     */
    public void unregisterReceiver() {
        try {
            getAudioManager().removeAudioFocusChangedListener(audioFocusChangeListener);
            mFlutterPluginBinding.getApplicationContext().unregisterReceiver(mVolumeBroadcastReceiver);
            enableBrightnessObserver(false);
        } catch (Exception e) {
            LiteavLog.e(TAG, "unregisterReceiver failed", e);
        }
    }

    private static Map<String, Object> getParams(int event, Bundle bundle) {
        Map<String, Object> param = new HashMap<>();
        if (event != 0) {
            param.put("event", event);
        }
        if (bundle != null && !bundle.isEmpty()) {
            Set<String> keySet = bundle.keySet();
            for (String key : keySet) {
                Object val = bundle.get(key);
                param.put(key, val);
            }
        }
        return param;
    }

    @Override
    public void setBrightness(@NonNull DoubleMsg brightness) {
        setWindowBrightness(brightness.getValue());
    }

    @Override
    public void restorePageBrightness() {
        setWindowBrightness(-1D);
    }

    @NonNull
    @Override
    public DoubleMsg getBrightness() {
        float brightness = getWindowBrightness();
        BigDecimal bigDecimal = BigDecimal.valueOf(brightness);
        DoubleMsg doubleMsg = new DoubleMsg();
        doubleMsg.setValue(bigDecimal.doubleValue());
        return doubleMsg;
    }

    @NonNull
    @Override
    public DoubleMsg getSysBrightness() {
        float brightness = getSystemScreenBrightness();
        BigDecimal bigDecimal = BigDecimal.valueOf(brightness);
        DoubleMsg doubleMsg = new DoubleMsg();
        doubleMsg.setValue(bigDecimal.doubleValue());
        return doubleMsg;
    }

    @Override
    public void setSystemVolume(@NonNull DoubleMsg volume) {
        getAudioManager().setSystemVolume(volume.getValue());
    }

    @NonNull
    @Override
    public DoubleMsg getSystemVolume() {
        BigDecimal bigDecimal = BigDecimal.valueOf(getAudioManager().getSystemCurrentVolume());
        DoubleMsg doubleMsg = new DoubleMsg();
        doubleMsg.setValue(bigDecimal.doubleValue());
        return doubleMsg;
    }

    @Override
    public void abandonAudioFocus() {
        getAudioManager().abandonAudioFocus();
    }

    @Override
    public void requestAudioFocus() {
        getAudioManager().requestAudioFocus();
    }

    @NonNull
    @Override
    public IntMsg isDeviceSupportPip() {
        IntMsg intMsg = new IntMsg();
        intMsg.setValue((long) getPipManager().isSupportDevice());
        return intMsg;
    }

    @Override
    public void registerSysBrightness(@NonNull BoolMsg isRegister) {
        if (null != isRegister.getValue()) {
            enableBrightnessObserver(isRegister.getValue());
        }
    }

    @Override
    public void success() {

    }

    @Override
    public void error(@NonNull Throwable error) {
        LiteavLog.e(TAG, "callback message error:" + error);
    }

    private static class VolumeBroadcastReceiver extends BroadcastReceiver implements FtxMessages.VoidResult {

        private final FtxMessages.TXPluginFlutterAPI mPluginApi;

        private VolumeBroadcastReceiver(FtxMessages.TXPluginFlutterAPI api) {
            mPluginApi = api;
        }

        public void onReceive(Context context, Intent intent) {
            // Notify only when the media volume changes
            if (VOLUME_CHANGED_ACTION.equals(intent.getAction())
                    && (intent.getIntExtra(EXTRA_VOLUME_STREAM_TYPE, -1) == AudioManager.STREAM_MUSIC)) {
                mPluginApi.onNativeEvent(getParams(FTXEvent.EVENT_VOLUME_CHANGED, null), this);
            }
        }

        @Override
        public void success() {

        }

        @Override
        public void error(@NonNull Throwable error) {
            LiteavLog.e(TAG, "callback message error:" + error);
        }
    }
}
