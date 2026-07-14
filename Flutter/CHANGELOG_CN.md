# 播放器 SDK Flutter 端发布日志

## 版本历史

### 播放器 SDK Flutter 端V13.3.1 @ 2026.06.16
- 支持 Android 端的 HDR 播放
- 提升最低支持的 Flutter 版本至 3.27.4
- 修复已知问题

### 播放器 SDK Flutter 端V13.3.0 @ 2026.05.08
- 提升多引擎模式下的兼容性
- Android TXLiteAVSDK 升级至 13.3.0.20247
- iOS TXLiteAVSDK 升级至 13.3.20845
- 修复已知问题

### 播放器 SDK Flutter 端V13.2.1 @ 2026.04.21
- 修复已知问题

### 播放器 SDK Flutter 端V13.2.0 @ 2026.04.20
- Android TXLiteAVSDK 升级至 13.2.0.20058
- iOS TXLiteAVSDK 升级至 13.2.20652
- 修复已知问题

### 播放器 SDK Flutter 端V13.1.0 @ 2026.01.29
- Android TXLiteAVSDK 升级至 13.1.0.19861
- iOS TXLiteAVSDK 升级至 13.1.20454
- 新增直播截图和本地录制相关接口和回调
- 修复已知问题

### 播放器 SDK Flutter 端V13.0.1 @ 2026.01.22
- iOS TXLiteAVSDK 升级至 13.0.20275
- 新增 TRTC 流转发相关接口
- 兼容 Android 15 及以上版本的接口调用
- 修复已知问题

### 播放器 SDK Flutter 端V13.0.0 @ 2026.01.08
- Android TXLiteAVSDK 升级至 13.0.0.19676
- iOS TXLiteAVSDK 升级至 13.0.20258
- 集成方式修改为自定义 sub_spec 方式，通过 sub_spec 方法指定 SDK
- 兼容 Android 端更低的编译版本
- 插件释放时会释放当前持有的所有播放器
- 修复已知问题

### 播放器 SDK Flutter 端V12.9.1 @ 2025.12.04
- Android TXLiteAVSDK 升级至 12.9.0.19478
- iOS TXLiteAVSDK 升级至 12.9.20085
- 修复 getDownloadInfo 不返回 isResourceBroken 的问题
- 调整 UI 组件音量时，iOS 端不再抢占音频焦点
- 修复 UI 组件的一些逻辑问题
- 修复已知问题

### 播放器 SDK Flutter 端V12.9.0 @ 2025.11.13
- Android TXLiteAVSDK 升级至 12.9.0.19467
- iOS TXLiteAVSDK 升级至 12.9.20063
- 修复直播播放器在播放停止时不保留最后一帧的问题
- 播放器组件默认开启多码率
- 修复已知问题

### 播放器 SDK Flutter 端V12.8.1 @ 2025.10.23
- 增强渲染兼容性

### 播放器 SDK Flutter 端V12.8.0 @ 2025.09.19
- Android TXLiteAVSDK 升级至 12.8.0.19279
- iOS TXLiteAVSDK 升级至 12.8.19666
- 修复已知问题

### 播放器 SDK Flutter 端V12.7.4 @ 2025.09.09
- 修复部分 Android 设备 PIP 恢复失败的问题

### 播放器 SDK Flutter 端V12.7.3 @ 2025.09.03
- 修复 renderMode 无效的问题

### 播放器 SDK Flutter 端V12.7.2 @ 2025.08.29
- VOD 支持 autoRotate 配置
- Android TXLiteAVSDK 升级至 12.7.0.19083
- iOS TXLiteAVSDK 升级至 12.7.19324
- 修复已知问题

### 播放器 SDK Flutter 端V12.7.1 @ 2025.08.13
- 修复 Android 端在某些情况下画面锯齿严重的问题
- 修复 Android 停止播放时出现渲染失败错误的问题
- 修复 Android 画中画恢复时发送额外退出事件的问题
- 修复已知问题

### 播放器 SDK Flutter 端V12.7.0 @ 2025.08.04
- Android TXLiteAVSDK 升级至 12.7.0.19072
- iOS TXLiteAVSDK 升级至 12.7.19272
- 修复画中画恢复时显示异常的问题
- 修复已知问题

### 播放器 SDK Flutter 端V12.6.2 @ 2025.07.31
- Android TXLiteAVSDK 升级至 12.6.0.18891
- iOS TXLiteAVSDK 升级至 12.6.18894
- 修复预播放时首帧不显示的问题
- 修复清除最后一帧无效的问题
- 修复已知问题

### 播放器 SDK Flutter 端V12.6.1 @ 2025.06.20
- 修复已知问题

### 播放器 SDK Flutter 端V12.6.0 @ 2025.06.20
- Android TXLiteAVSDK_Player 升级至 12.5.0.17576，tag：release_player_v12.5.1
- iOS TXLiteAVSDK_Player 升级至 12.5.18393，tag：release_player_v12.5.1
- SuperPlayerPlugin 新增 setDrmProvisionEnv 方法，用于切换 DRM 播放环境
- 修复 Android 端使用 SurfaceView 时，从后台返回前台视频画面无法恢复的问题
- 修复 UI 组件在部分老旧 Android 设备上全屏操作表现异常的问题

### 播放器 SDK Flutter 端V12.5.1 @ 2025.06.18
- Android TXLiteAVSDK_Player 升级至 12.5.0.17576，tag：release_player_v12.5.1
- iOS TXLiteAVSDK_Player 升级至 12.5.18393，tag：release_player_v12.5.1
- SuperPlayerPlugin 新增 setDrmProvisionEnv 方法，用于切换 DRM 播放环境
- 修复 Android 端使用 SurfaceView 时，从后台返回前台视频画面无法恢复的问题
- 修复 UI 组件在部分老旧 Android 设备上全屏操作表现异常的问题

### 播放器 SDK Flutter 端V12.5.0 @ 2025.05.08
- Android TXLiteAVSDK_Player 升级至 12.5.0.17567，tag：release_player_v12.5.0
- iOS TXLiteAVSDK_Player 升级至 12.5.18359，tag：release_player_v12.5.0
- 播放器新增 setRenderMode 方法，可配置视频渲染的平铺模式
- 修复 Android 端播放器暂停后进入后台再返回前台画面变黑的问题
- 优化 Flutter 播放器首帧渲染相比事件触发的延迟
- 改进 super_player_widget 组件的屏幕方向切换逻辑，统一竖屏和横屏模式的纹理共享，提升方向切换时的用户体验
- iOS 端直播画中画在 iOS 15.0 及以上版本会自动切换到基于图层的播放模式
- demo 端增加简单的 license 轮询机制，防止首次启动时因长时间断网导致播放失败
- 修复 Android 画中画服务在某些条件下的内存泄漏问题
- 解决 Android 画中画缩放动画显示半透明黑色阴影效果的问题
- iOS 端调用 stopPlay 后不再清除 startTime，与 Android 实现保持一致

### 播放器 SDK Flutter 端V12.4.2 @ 2025.04.30
- 修复释放播放器会关闭全局画中画模式的问题

### 播放器 SDK Flutter 端V12.4.1 @ 2025.04.02
- 移除通过 TXPlayerVideo 控制器绑定纹理的方法

### 播放器 SDK Flutter 端V12.4.0 @ 2025.03.31
- Android TXLiteAVSDK_Player 升级至 12.4.0.17372，tag：release_player_v12.4.0
- iOS TXLiteAVSDK_Player 升级至 12.4.17856，tag：release_player_v12.4.0
- Android 画中画按钮图标可通过传入空字符串隐藏
- TXPlayerVideo 控制器参数绑定播放器纹理的方法不再推荐使用，建议改用 onRenderViewCreated 方法
- 修复 Android 直播进入画中画模式时窗口尺寸与画面宽高比不匹配的问题
- 修复播放器组件进入全屏后，播放器监听器仍在竖屏页面的问题
- 修复 Android 进入画中画模式时，部分机型过渡动画顶部出现半透明黑色状态栏的问题

### 播放器 SDK Flutter 端V12.3.1 @ 2025.03.18
- Android TXLiteAVSDK_Player 升级至 12.3.0.17122，tag：release_player_v12.3.1
- TXPlayerVideo 新增 onRenderViewCreatedListener 回调，获取 TXPlayerVideo 的 viewId 后可在需要时将 viewId 设置给播放器
- 修复 iOS 画中画在某些情况下窗口中显示不正确的问题
- 修复 Android 画中画窗口宽高比不正确的问题
- 修复播放器组件从全屏返回后无画面的问题
- 修复 iOS 长期视频播放导致内存溢出的问题
- 修复 iOS 高安全级别 DRM 视频无法播放的问题

### 播放器 SDK Flutter 端V12.3.0 @ 2025.01.21
- Android TXLiteAVSDK_Player 升级至 12.3.0.17115，tag：release_player_v12.3.0
- iOS TXLiteAVSDK_Player 升级至 12.3.16995，tag：release_player_v12.3.0

### 播放器 SDK Flutter 端V12.2.2 @ 2024.12.30
- 修复 Android 从 PIP 恢复时崩溃的问题

### 播放器 SDK Flutter 端V12.2.1 @ 2024.12.27
- Android TXLiteAVSDK_Player 升级至 12.2.0.15065，tag：release_player_v12.2.0
- iOS TXLiteAVSDK_Player 升级至 12.2.16945，tag：release_player_v12.2.0
- 修复部分 Android 系统无法启动画中画的问题
- 修复部分 Android 系统冷启动后使用异常的问题
- 修复 iOS 未设置 config 时无字幕回调的问题
- 修复下载和预下载在某些情况下无回调的问题
- 新增 DRM 播放 API
- 修复其他已知问题

### 播放器 SDK Flutter 端V12.2.0 @ 2024.12.04
- Android TXLiteAVSDK_Player 升级至 12.2.0.15065，tag：release_player_v12.2.0
- iOS TXLiteAVSDK_Player 升级至 12.2.16945，tag：release_player_v12.2.0
- 预下载支持 httpHeader
- 支持 MP4 加密播放
- 新增 HEVC 播放降级支持
- 修复其他已知问题

### 播放器 SDK Flutter 端V12.1.0 @ 2024.11.20
- Android TXLiteAVSDK_Player 升级至 12.0.0.14689，tag：release_player_v12.0.1
- iOS TXLiteAVSDK_Player 升级至 12.0.16301，tag：release_player_v12.0.1
- 修复直播静音方法逻辑颠倒的问题
- iOS 新增直播画中画支持，需高级权限才能使用
- 修复其他已知问题

### 播放器 SDK Flutter 端V12.0.1 @ 2024.09.14
- Android TXLiteAVSDK_Player 升级至 12.0.0.14689，tag：release_player_v12.0.1
- iOS TXLiteAVSDK_Player 升级至 12.0.16301，tag：release_player_v12.0.1
- 修复某些情况下纹理不刷新的问题
- 修复画中画结束时在某些情况下更新画中画产生错误的问题
- 修改插件回调 Flutter 端消息架构
- SDK 初始化时所有模块改为懒加载
- demo 和播放器组件不再需要强制设置语言，如不设置则默认英文

### 播放器 SDK Flutter 端V12.0.0 @ 2024.08.21
- Android TXLiteAVSDK_Player 升级至 12.0.0.14681，tag：release_player_v12.0.0
- iOS TXLiteAVSDK_Player 升级至 12.0.16292，tag：release_player_v12.0.0
- 直播更换新内核
- 由于已更换新内核，直播 live config 目前仅保留 maxAutoAdjustCacheTime、minAutoAdjustCacheTime、connectRetryCount、connectRetryInterval 属性，其余参数标记为废弃
- 直播新增接口：enableReceiveSeiMessage、showDebugView、setProperty、getSupportedBitrate、setCacheParams
- 播放直播时不再需要传递 playType 参数，该参数已废弃
- 直播和点播 demo 页面增加等待 license 加载成功后再播放的逻辑
- 修复其他已知问题

### 播放器 SDK Flutter 端V11.9.1 @ 2024.06.05
- 修复锁屏恢复后 PIP 播放失败的问题
- TXVodPlayerController 新增 setStringOption 接口，用于配置扩展功能
- Flutter 端对播放器的操作现在可以影响画中画窗口中的播放和暂停 UI 更新
- 修复潜在的内存泄漏问题
- 优化 superPlayer Widget 逻辑
- 修复其他已知问题

### 播放器 SDK Flutter 端V11.9.0 @ 2024.06.05
- Android TXLiteAVSDK_Player 升级至 11.9.0.14445，tag：release_player_v11.9.0
- iOS TXLiteAVSDK_Player 升级至 11.9.15963，tag：release_player_v11.9.0
- Android 兼容高版本 Gradle
- superPlayerWidget 位置变更，集成 superPlayer 将不再包含 superPlayerWidget 的源码
- Android 画中画功能逻辑优化，兼容更多机型

### 播放器 SDK Flutter 端V11.8.1 @ 2024.05.22
- Android TXLiteAVSDK_Player 升级至 11.8.0.14188，tag：release_player_v11.8.1
- iOS TXLiteAVSDK_Player 升级至 11.8.15687，tag：release_player_v11.8.1

### 播放器 SDK Flutter 端V11.8.0 @ 2024.05.06
- Android TXLiteAVSDK_Player 升级至 11.8.0.14176，tag：release_player_v11.8.0
- iOS TXLiteAVSDK_Player 升级至 11.8.15669，tag：release_player_v11.8.0

### 播放器 SDK Flutter 端V11.7.0 @ 2024.04.02
- Android TXLiteAVSDK_Player 升级至 11.7.0.13946，tag：release_player_v11.7.0
- iOS TXLiteAVSDK_Player 升级至 11.7.15343，tag：release_player_v11.7.0
- SuperPlayerPlugin 新增 setSDKListener 方法
- 修复已知问题

### 播放器 SDK Flutter 端V11.6.1 @ 2024.01.29
- Android TXLiteAVSDK_Player 升级至 11.6.0.13641，tag：release_player_v11.6.1
- iOS TXLiteAVSDK_Player 升级至 11.6.15041，tag：release_player_v11.6.1
- superPlayerWidget 新增 renderMode 配置
- superPlayerWidget 新增 stopPlay 方法
- vod/live dispose 方法现在支持 await
- 修复已知问题

### 播放器 SDK Flutter 端V11.6.0 @ 2024.01.11
- Android TXLiteAVSDK_Player 升级至 11.6.0.13613，tag：release_player_v11.6.0
- iOS TXLiteAVSDK_Player 升级至 11.6.15007，tag：release_player_v11.6.0
- 适配 Flutter 播放器到新版本 Flutter SDK
- 修复播放器和播放器组件的已知问题

### 播放器 SDK Flutter 端V11.4.1 @ 2023.12.20
- Android TXLiteAVSDK_Player 升级至 11.4.0.13270，tag：release_player_v11.4.1
- iOS TXLiteAVSDK_Player 升级至 11.4.14552，tag：release_player_v11.4.1
- 新增 fileId 预下载能力
- 修复已知问题

### 播放器 SDK Flutter 端V11.4.0 @ 2023.08.30
- Android TXLiteAVSDK_Player 升级至 11.4.0.13189，tag：release_player_v11.4.0
- iOS TXLiteAVSDK_Player 升级至 11.4.14445，tag：release_player_v11.4.0

### 播放器 SDK Flutter 端V11.3.0 @ 2023.07.07
- Android TXLiteAVSDK_Player 升级至 11.3.0.13171，tag：release_player_v11.3.0
- iOS TXLiteAVSDK_Player 升级至 11.3.14327，tag：release_player_v11.3.0

### 播放器 SDK Flutter 端V11.2.0 @ 2023.06.05
- Android TXLiteAVSDK_Player 升级至 11.2.0.13154，tag：release_player_v11.2.0
- iOS TXLiteAVSDK_Player 升级至 11.2.14217，tag：release_player_v11.2.0

### 播放器 SDK Flutter 端V11.1.1 @ 2023.05.08
- Android TXLiteAVSDK_Player 升级至 11.1.0.13141，tag：release_player_v11.1.1
- iOS TXLiteAVSDK_Player 升级至 11.1.14143，tag：release_player_v11.1.1

### 播放器 SDK Flutter 端V11.1.0 @ 2023.04.10
- Android TXLiteAVSDK_Player 升级至 11.1.0.13111，tag：release_player_v11.1.0
- iOS TXLiteAVSDK_Player 升级至 11.1.14125，tag：release_player_v11.1.0

### 播放器 SDK Flutter 端V11.0.0 @ 2023.03.20
- Android TXLiteAVSDK_Player 升级至 11.0.0.13129，tag：release_player_v11.0.0
- iOS TXLiteAVSDK_Player 升级至 11.0.14032，tag：release_player_v11.0.0

### 播放器 SDK Flutter 端V10.9.1 @ 2023.02.24
- Android TXLiteAVSDK_Player 升级至 10.9.0.13102，tag：release_player_v10.9.1
- iOS TXLiteAVSDK_Player 升级至 10.9.13161，tag：release_player_v10.9.1

### 播放器 SDK Flutter 端V10.9.0 @ 2023.01.03
- Android TXLiteAVSDK_Player 升级至 10.9.0.13092，tag：release_player_v10.9.0
- iOS TXLiteAVSDK_Player 升级至 10.9.13148，tag：release_player_v10.9.0

### 播放器 SDK Flutter 端V10.8.0_stable @ 2022.12.01
- Android TXLiteAVSDK_Player 升级至 10.8.0.13065，tag：release_player_v10.0.8_stable
- iOS TXLiteAVSDK_Player 升级至 10.8.12025，tag：release_player_v10.0.8_stable

### 播放器 SDK Flutter 端V10.8.0 @ 2022.12.01
- Android TXLiteAVSDK_Player 升级至 10.8.0.13052，tag：release_player_v10.0.8
- iOS TXLiteAVSDK_Player 升级至 10.8.12015，tag：release_player_v10.0.8

### 播放器 SDK Flutter 端V1.0.7 @ 2022.10.27
- Android TXLiteAVSDK_Player 升级至 10.7.0.13053，tag：release_player_v1.0.7
- iOS TXLiteAVSDK_Player 升级至 10.7.11936，tag：release_player_v1.0.7

### 播放器 SDK Flutter 端V1.0.6 @ 2022.09.19
- Android TXLiteAVSDK_Player 升级至 10.6.0.11182，tag：release_player_v1.0.6
- iOS TXLiteAVSDK_Player 升级至 10.6.11822，tag：release_player_v1.0.6

### 播放器 SDK Flutter 端V1.0.5 @ 2022.09.02
- Android TXLiteAVSDK_Player 升级至 10.5.0.11177，tag：release_player_v1.0.5
- iOS TXLiteAVSDK_Player 升级至 10.5.11726，tag：release_player_v1.0.5

### 播放器 SDK Flutter 端V1.0.4 @ 2022.08.16
- Android TXLiteAVSDK_Player 升级至 10.4.0.11164，tag：release_player_v1.0.4
- iOS TXLiteAVSDK_Player 升级至 10.4.11617，tag：release_player_v1.0.4

### 播放器 SDK Flutter 端V1.0.3 @ 2022.07.13
- iOS 端新增画中画（PIP）功能
- Android TXLiteAVSDK_Player 升级至 10.3.0.11144，tag：release_player_v1.0.3
- iOS TXLiteAVSDK_Player 升级至 10.3.11513，tag：release_pro_v1.0.3