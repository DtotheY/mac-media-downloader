# Mac 多平台媒体下载器

一个简单的 macOS 下载工具，可保存网站当前提供的最高可用画质图片和视频。

支持：

- Instagram：图片、视频、Reels、多图和混合帖子
- 小红书：原图笔记和视频笔记
- 抖音：视频、图文作品，以及包含 `modal_id` 的网页链接
- YouTube：普通视频、Shorts 和播放列表

## 下载与安装

1. 打开仓库右侧的 **Releases**。
2. 下载最新版 `多平台媒体下载器-Mac.zip`。
3. 解压后，把“多平台媒体下载器”拖入 Mac 的“应用程序”文件夹。
4. 第一次打开时，按住 Control 点击 App，选择“打开”。
5. 选择已经登录相关网站的浏览器，再粘贴链接。

文件会按网站分类保存在：

```text
~/Downloads/媒体下载
```

首次运行会自动准备 `gallery-dl` 和 `yt-dlp`。首次处理视频时会通过 Homebrew 准备 FFmpeg，用于合并最高画质的视频、音频并生成通用 MP4。

## 系统要求

- macOS 10.15 或更高版本
- 网络连接
- Python 3（缺少时程序会引导安装）
- 建议安装 [Homebrew](https://brew.sh/)
- 对需要登录的内容，建议使用已登录的 Chrome、Safari、Firefox 或 Edge

## 隐私

- 本工具不会保存网站账号或密码。
- 如果选择浏览器登录状态，下载组件会临时读取该浏览器现有的 Cookie；macOS 可能显示钥匙串授权提示。
- Cookie 不会上传到此仓库，也不会发送给下载目标网站以外的第三方。

## 画质说明

“最高画质”指网站当前向你的账号和地区提供的最高可用版本，不一定等同于作者设备中的未压缩原文件。

## 使用责任

请只下载自己拥有、获授权保存或法律允许下载的内容。请遵守网站服务条款、版权规定和所在地法律。付费、DRM、已删除、过期或地区受限内容可能无法下载。

## 源码

- `src/downloader.command`：交互式下载主程序
- `src/media_helper.py`：小红书和抖音图文处理
- `src/launcher`：macOS App 启动器
- `src/Info.plist`：App 配置
- `assets/AppIcon.icns`：App 图标
- `scripts/build-app.sh`：本地重新打包脚本

在仓库根目录运行以下命令，可以在 `dist` 文件夹重新生成 App 和 ZIP：

```zsh
./scripts/build-app.sh
```

核心下载能力来自 [yt-dlp](https://github.com/yt-dlp/yt-dlp)、[gallery-dl](https://github.com/mikf/gallery-dl) 和 [FFmpeg](https://ffmpeg.org/)。这些项目各自适用其自己的许可证。

## License

本仓库自行编写的代码以 [MIT License](LICENSE) 发布。
