part of SuperPlayer;

enum TXPlayerRenderMode {
  platformView,
  // 用 texture 渲染
  // 注意：iOS 上 Flutter 3.29.0 以后不同 texture 切换过程会出现不同 texture 渲染同一个画面的问题，
  //      参考 https://github.com/flutter/flutter/issues/168882
  texture,
  // 用 PlatformView 渲染，同时也创建 texture
  platformViewWithTexture,
}

/// Android/iOS 的 Flutter Texture 后端渲染组件。
///
/// - 非侵入式：优先尝试通过 MethodChannel 创建原生 Texture，并将播放器输出绑定到该 Texture 的 Surface。
/// - 兜底策略：如果 Texture 创建失败或当前平台非 Android，则回退到原有 PlatformView（TXPlayerVideo）。
/// - 注意：DRM/HDR/PIP 等场景可能不支持 Texture，建议按业务场景控制是否启用。
class TXPlayerTexture extends StatefulWidget {
  /// 对应的播放器控制器（仅支持 TXVodPlayerController）。
  final TXVodPlayerController controller;

  /// 回退到 PlatformView 时，Android 渲染类型（默认 TextureView，与原有一致）。
  final FTXAndroidRenderViewType? androidRenderType;

  /// 渲染模式
  final TXPlayerRenderMode renderMode;

  /// 当 Texture 创建成功并且已绑定到播放器时回调（用于业务侧设置 _isViewAttached 等状态）。
  /// 回调参数为当前创建成功的 `textureId`，便于上层做差异化处理或调试日志。
  final void Function(int textureId)? onTextureReady;

  /// 是否冻结 Texture 帧更新。
  ///
  /// - 为 true 时，底层不会继续将视频帧推送到 Flutter 侧，可降低不可见时的资源消耗；
  /// - 业务侧可根据自身可见性/是否为当前项等状态计算传入，例如：`!(_isValidCurrentItem && _isVisiable)`。
  final bool freeze;

  /// 当回退 PlatformView 时，暴露原始 onRenderViewCreated 回调，便于业务层进行自定义绑定逻辑。
  final FTXOnRenderViewCreatedListener? onPlatformViewCreated;

  const TXPlayerTexture({
    super.key,
    required this.controller,
    this.androidRenderType,
    this.renderMode = TXPlayerRenderMode.texture,
    this.onTextureReady,
    this.freeze = false,
    this.onPlatformViewCreated,
  });

  @override
  State<TXPlayerTexture> createState() => _TXPlayerTextureState();
}

class _TXPlayerTextureState extends State<TXPlayerTexture> {
  static const MethodChannel _textureChannel =
      MethodChannel('com.tencent.vod.flutter/texture');

  int? _textureId;
  bool _createFailed = false;
  static const String _tag = 'TXPlayerTexture';

  bool get _shouldCreateTexture =>
      widget.renderMode == TXPlayerRenderMode.texture ||
      widget.renderMode == TXPlayerRenderMode.platformViewWithTexture;

  bool get _isRenderWithPlatformView =>
      widget.renderMode == TXPlayerRenderMode.platformView ||
      widget.renderMode == TXPlayerRenderMode.platformViewWithTexture;

  bool get _isRenderWithTexture =>
      widget.renderMode == TXPlayerRenderMode.texture;

  @override
  void initState() {
    super.initState();
    _tryCreateTextureIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TXPlayerTexture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.renderMode != oldWidget.renderMode) {
      _tryCreateTextureIfNeeded();
    }
  }

  Future<void> _tryCreateTextureIfNeeded() async {
    // iOS/Android 支持 Texture，其他平台直接回退到 PlatformView
    if (!_shouldCreateTexture ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      LogUtils.d(_tag,
          'skip texture: preferTexture=$_shouldCreateTexture, platform=$defaultTargetPlatform');
      setState(() => _createFailed = true);
      return;
    }

    try {
      // 等待控制器初始化完成，避免 playerId 为空导致回退
      if (widget.controller._playerId == null ||
          (widget.controller._playerId ?? -1) < 0) {
        LogUtils.d(_tag, 'waiting controller init...');
        try {
          await widget.controller._initPlayer.future;
        } catch (_) {}
      }
      // 注意：_playerId 为 library 私有字段，这里处于同一 library，可直接访问
      final int? playerId = widget.controller._playerId;
      LogUtils.d(_tag, 'try create texture for playerId=$playerId');
      if (playerId == null || playerId < 0) {
        LogUtils.d(_tag, 'invalid playerId, fallback to PlatformView');
        setState(() => _createFailed = true);
        return;
      }

      final int? texId = await _textureChannel.invokeMethod<int>(
        'createTexture',
        <String, dynamic>{
          'playerId': playerId,
          'renderWithTexture': _isRenderWithTexture
        },
      );

      if (!mounted) return;
      if (texId == null || texId < 0) {
        // 创建失败，标记回退
        LogUtils.d(_tag,
            'createTexture failed, texId=$texId, fallback to PlatformView');
        setState(() => _createFailed = true);
        return;
      }

      setState(() => _textureId = texId);
      LogUtils.d(_tag, 'createTexture success, textureId=$texId');
      // 通知业务层：Texture 已经就绪，可更新自身状态（如 _isViewAttached）。
      try {
        // 传递 textureId 给上层，便于做进一步处理
        widget.onTextureReady?.call(texId);
      } catch (_) {}
    } catch (e) {
      // 创建异常，回退到 PlatformView
      LogUtils.d(_tag, 'createTexture exception: $e');
      setState(() => _createFailed = true);
    }
  }

  @override
  void dispose() {
    _disposeTextureSafe();
    super.dispose();
  }

  Future<void> _disposeTextureSafe() async {
    if (_textureId == null) return;
    try {
      final int? playerId = widget.controller._playerId;
      LogUtils.d(_tag, 'dispose textureId=$_textureId for playerId=$playerId');
      if (playerId != null && playerId >= 0) {
        await _textureChannel.invokeMethod<void>(
          'disposeTexture',
          <String, dynamic>{
            'playerId': playerId,
            'renderWithTexture': _isRenderWithTexture
          },
        );
      }
    } catch (_) {
      // 忽略释放异常，避免影响业务
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRenderWithPlatformView) {
      return _buildPlatformVideoView();
    }

    // 首先尝试 Texture，未完成创建前展示空容器（由上层封面遮挡），失败才回退 PlatformView
    if (_textureId != null) {
      return IgnorePointer(
        ignoring: true,
        // 通过 freeze 参数控制 Texture 是否冻结帧更新
        child: Texture(
          textureId: _textureId!,
          freeze: widget.freeze,
        ),
      );
    }
    if (_createFailed) {
      return _buildPlatformVideoView();
    }
    // 等待创建结果时，先返回空容器（避免误触发回退 PlatformView）
    return const SizedBox.expand();
  }

  Widget _buildPlatformVideoView() {
    return TXPlayerVideo(
      androidRenderType: widget.androidRenderType,
      onRenderViewCreatedListener: (viewId) {
        LogUtils.d(_tag, 'fallback PlatformView created, viewId=$viewId');
        if (widget.onPlatformViewCreated != null) {
          widget.onPlatformViewCreated!(viewId);
        } else {
          widget.controller.setPlayerView(viewId);
        }
      },
    );
  }
}
