#!/bin/zsh

# 多平台媒体下载器（Mac）
# 支持 Instagram、小红书、抖音和 YouTube。
# 请只下载自己拥有或获授权保存的内容。

setopt NO_NOMATCH

APP_DIR="$HOME/Library/Application Support/Instagram全媒体下载器"
TOOLS_VENV="$APP_DIR/gallery-venv"
PYTHON_BIN="$TOOLS_VENV/bin/python"
YTDLP_BIN="$TOOLS_VENV/bin/yt-dlp"
GALLERY_BIN="$TOOLS_VENV/bin/gallery-dl"
UPDATE_STAMP="$APP_DIR/.last_update_v3"
DOWNLOAD_ROOT="$HOME/Downloads/媒体下载"
RESOURCE_DIR="${0:A:h}"
MEDIA_HELPER="$RESOURCE_DIR/media_helper.py"

mkdir -p "$APP_DIR" "$DOWNLOAD_ROOT"

title() {
  clear
  print "========================================"
  print "       多平台媒体下载器（Mac）"
  print "========================================"
  print "Instagram · 小红书 · 抖音 · YouTube"
  print "保存位置：$DOWNLOAD_ROOT"
  print
}

pause_before_exit() {
  print
  read "?按回车键关闭窗口……"
}

find_or_install_python() {
  if command -v python3 >/dev/null 2>&1; then
    SYSTEM_PYTHON=$(command -v python3)
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    print "正在准备运行组件……"
    if brew install python; then
      SYSTEM_PYTHON=$(command -v python3)
      return 0
    fi
  fi

  print "还缺少运行组件，接下来会打开 Python 官方下载页面。"
  print "安装完成后，请重新打开本 App。"
  open "https://www.python.org/downloads/macos/" >/dev/null 2>&1
  pause_before_exit
  exit 1
}

install_tools() {
  title
  print "首次升级，正在准备多平台下载组件……"
  print "这一步通常需要一两分钟，以后会直接打开。"
  print

  find_or_install_python
  if [[ ! -x "$PYTHON_BIN" ]]; then
    if ! "$SYSTEM_PYTHON" -m venv "$TOOLS_VENV"; then
      print "无法建立下载组件的独立运行环境。"
      pause_before_exit
      exit 1
    fi
  fi

  if ! "$PYTHON_BIN" -m pip install --disable-pip-version-check \
      --upgrade pip gallery-dl 'yt-dlp[default]'; then
    print "下载组件安装失败，请检查网络后重试。"
    pause_before_exit
    exit 1
  fi
  touch "$UPDATE_STAMP"
}

update_if_needed() {
  local now last age
  now=$(date +%s)
  last=0
  [[ -f "$UPDATE_STAMP" ]] && last=$(stat -f %m "$UPDATE_STAMP" 2>/dev/null || print 0)
  age=$((now - last))
  if (( age >= 604800 )); then
    print "正在检查下载组件更新……"
    "$PYTHON_BIN" -m pip install --disable-pip-version-check --quiet \
      --upgrade gallery-dl 'yt-dlp[default]' >/dev/null 2>&1 || true
    touch "$UPDATE_STAMP"
  fi
}

choose_browser() {
  print
  print "请选择你平时已经登录这些网站的浏览器："
  print "  1) Chrome（推荐）"
  print "  2) Safari"
  print "  3) Firefox"
  print "  4) Edge"
  print "  0) 不使用登录状态（只尝试公开内容）"
  read "?请输入数字 [1]：" browser_choice
  case "$browser_choice" in
    2) BROWSER_NAME="safari" ;;
    3) BROWSER_NAME="firefox" ;;
    4) BROWSER_NAME="edge" ;;
    0) BROWSER_NAME="" ;;
    *) BROWSER_NAME="chrome" ;;
  esac
}

cookie_args() {
  COOKIE_ARGS=()
  [[ -n "$BROWSER_NAME" ]] && COOKIE_ARGS=(--cookies-from-browser "$BROWSER_NAME")
}

ensure_ffmpeg() {
  command -v ffmpeg >/dev/null 2>&1 && return 0
  print
  print "首次处理视频，正在准备 MP4 高清合并组件……"
  print "这一步可能需要几分钟，请不要关闭窗口。"
  if command -v brew >/dev/null 2>&1 && brew install ffmpeg; then
    return 0
  fi
  print
  print "高清合并组件安装失败，暂时无法保证 YouTube 最高画质。"
  print "请先安装 Homebrew 后再试：https://brew.sh/"
  return 1
}

yt_download() {
  local url="$1" destination="$2" use_cookies="${3:-yes}"
  local node_args=()
  ensure_ffmpeg || return 1
  cookie_args
  [[ "$use_cookies" == "no" ]] && COOKIE_ARGS=()
  if command -v node >/dev/null 2>&1; then
    node_args=(--js-runtimes "node:$(command -v node)")
  fi

  "$YTDLP_BIN" \
    "${COOKIE_ARGS[@]}" \
    "${node_args[@]}" \
    --no-overwrites \
    --no-mtime \
    --trim-filenames 180 \
    --progress \
    --format 'bestvideo*+bestaudio/best' \
    --merge-output-format mp4 \
    --remux-video mp4 \
    -P "$destination" \
    -o '%(uploader|未知作者)s/%(upload_date|未知日期)s_%(id)s_%(title).100B.%(ext)s' \
    -- "$url"
}

instagram_download() {
  local url="$1" destination="$DOWNLOAD_ROOT/Instagram"
  local gallery_cookie_args=()
  mkdir -p "$destination"
  [[ -n "$BROWSER_NAME" ]] && gallery_cookie_args=(--cookies-from-browser "$BROWSER_NAME")

  print "正在获取 Instagram 的原图和最高可用画质视频……"
  if "$GALLERY_BIN" --config-ignore "${gallery_cookie_args[@]}" \
      --destination "$destination" \
      --option "extractor.instagram.videos=true" \
      --option "extractor.instagram.static-videos=true" \
      --option "extractor.instagram.previews=false" \
      -- "$url"; then
    return 0
  fi
  print "正在换一种方式重试视频……"
  yt_download "$url" "$destination"
}

xhs_download() {
  local url="$1" destination="$DOWNLOAD_ROOT/小红书" rc
  mkdir -p "$destination"
  print "正在识别小红书原图或视频……"
  "$PYTHON_BIN" "$MEDIA_HELPER" xiaohongshu "$url" "$destination" "$BROWSER_NAME"
  rc=$?
  if (( rc == 3 )); then
    print "已识别为视频，正在下载最高可用画质……"
    yt_download "$url" "$destination"
  else
    return $rc
  fi
}

normalize_douyin_url() {
  local url="$1" modal_id
  modal_id=$(print -r -- "$url" | sed -nE 's/.*[?&]modal_id=([0-9]+).*/\1/p')
  if [[ -n "$modal_id" ]]; then
    print -r -- "https://www.douyin.com/video/$modal_id"
  else
    print -r -- "$url"
  fi
}

douyin_download() {
  local url destination="$DOWNLOAD_ROOT/抖音" rc
  url=$(normalize_douyin_url "$1")
  mkdir -p "$destination"
  print "正在识别抖音图片或视频……"
  "$PYTHON_BIN" "$MEDIA_HELPER" douyin "$url" "$destination" "$BROWSER_NAME"
  rc=$?
  if (( rc == 3 )); then
    print "已识别为视频，正在下载最高可用画质……"
    yt_download "$url" "$destination"
  else
    return $rc
  fi
}

youtube_download() {
  local url="$1" destination="$DOWNLOAD_ROOT/YouTube"
  mkdir -p "$destination"
  print "正在下载 YouTube 最高可用画质……"
  if yt_download "$url" "$destination" no; then
    return 0
  fi
  if [[ -n "$BROWSER_NAME" ]]; then
    print "公开方式未成功，正在使用浏览器登录状态重试……"
    yt_download "$url" "$destination" yes
  else
    return 1
  fi
}

download_url() {
  local url="$1"
  case "$url" in
    *instagram.com/*) instagram_download "$url" ;;
    *xiaohongshu.com/*) xhs_download "$url" ;;
    *douyin.com/*) douyin_download "$url" ;;
    *youtube.com/*|*youtu.be/*) youtube_download "$url" ;;
    *)
      print "目前支持 Instagram、小红书、抖音和 YouTube。"
      return 2
      ;;
  esac
}

if [[ ! -x "$PYTHON_BIN" || ! -x "$GALLERY_BIN" || ! -x "$YTDLP_BIN" ]]; then
  install_tools
fi

title
update_if_needed
choose_browser

while true; do
  title
  if [[ -n "$BROWSER_NAME" ]]; then
    print "登录状态：使用 ${BROWSER_NAME}（可能出现钥匙串授权提示）"
  else
    print "登录状态：不使用浏览器，只尝试公开内容"
  fi
  print
  print "请粘贴 Instagram、小红书、抖音或 YouTube 链接。"
  print "直接按回车可退出；输入 B 可更换浏览器。"
  print
  read "?链接：" media_url

  [[ -z "$media_url" ]] && break
  if [[ "$media_url" == "B" || "$media_url" == "b" ]]; then
    choose_browser
    continue
  fi

  print
  if download_url "$media_url"; then
    print
    print "处理完成，已保存网站当前提供的最高可用画质。"
    print "位置：$DOWNLOAD_ROOT"
    open "$DOWNLOAD_ROOT" >/dev/null 2>&1
  else
    print
    print "这次没有下载成功。请确认浏览器已登录、链接有效，"
    print "并且你的账户有权查看该内容，然后再试一次。"
  fi

  print
  read "?按回车键继续下载其他链接……"
done

print
print "已退出。下载文件保存在：$DOWNLOAD_ROOT"
sleep 1
