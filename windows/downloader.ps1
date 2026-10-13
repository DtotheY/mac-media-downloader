[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = "Stop"

$AppDir = Join-Path $env:LOCALAPPDATA "多平台媒体下载器"
$VenvDir = Join-Path $AppDir "tools"
$Python = Join-Path $VenvDir "Scripts\python.exe"
$UpdateStamp = Join-Path $AppDir ".last_update_v1"
$DownloadRoot = Join-Path (Join-Path $HOME "Downloads") "媒体下载"
$ResourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MediaHelper = Join-Path $ResourceDir "media_helper.py"
$script:BrowserName = "chrome"
$script:Ffmpeg = $null

New-Item -ItemType Directory -Force -Path $AppDir, $DownloadRoot | Out-Null

function Show-Title {
    Clear-Host
    Write-Host "========================================"
    Write-Host "      多平台媒体下载器（Windows）"
    Write-Host "========================================"
    Write-Host "Instagram · 小红书 · 抖音 · YouTube"
    Write-Host "保存位置：$DownloadRoot"
    Write-Host ""
}

function Wait-BeforeExit {
    Write-Host ""
    [void](Read-Host "按回车键关闭窗口")
}

function Find-SystemPython {
    $launchers = @(
        @{ Command = "py"; Prefix = @("-3") },
        @{ Command = "python"; Prefix = @() },
        @{ Command = "python3"; Prefix = @() }
    )
    foreach ($launcher in $launchers) {
        if (Get-Command $launcher.Command -ErrorAction SilentlyContinue) {
            try {
                & $launcher.Command @($launcher.Prefix) -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)" 2>$null
                if ($LASTEXITCODE -eq 0) { return $launcher }
            } catch {}
        }
    }
    return $null
}

function Install-Python {
    Write-Host "电脑里还没有找到 Python，正在尝试自动安装……"
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        & winget.exe install --id Python.Python.3.13 --exact --source winget --accept-package-agreements --accept-source-agreements | Out-Host
        if ($LASTEXITCODE -eq 0) {
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
            return Find-SystemPython
        }
    }
    Write-Host ""
    Write-Host "自动安装没有完成，已为你打开 Python 官方下载页面。"
    Write-Host "安装 Python 后，请重新双击“Start Downloader.cmd”。"
    Start-Process "https://www.python.org/downloads/windows/"
    return $null
}

function Install-Tools {
    Show-Title
    Write-Host "首次使用，正在准备下载组件……"
    Write-Host "这一步通常需要一两分钟，以后会直接打开。"
    Write-Host ""

    $launcher = Find-SystemPython
    if (-not $launcher) { $launcher = Install-Python }
    if (-not $launcher) { Wait-BeforeExit; exit 1 }

    if (-not (Test-Path $Python)) {
        & $launcher.Command @($launcher.Prefix) -m venv $VenvDir
        if ($LASTEXITCODE -ne 0) { throw "无法建立下载组件的独立运行环境。" }
    }

    & $Python -m pip install --disable-pip-version-check --upgrade pip gallery-dl "yt-dlp[default]" imageio-ffmpeg
    if ($LASTEXITCODE -ne 0) { throw "下载组件安装失败，请检查网络后重试。" }
    Set-Content -Path $UpdateStamp -Value ([DateTimeOffset]::Now.ToUnixTimeSeconds()) -Encoding ASCII
}

function Update-ToolsIfNeeded {
    $needsUpdate = $true
    if (Test-Path $UpdateStamp) {
        try {
            $last = [int64](Get-Content $UpdateStamp -ErrorAction Stop)
            $age = [DateTimeOffset]::Now.ToUnixTimeSeconds() - $last
            $needsUpdate = $age -ge 604800
        } catch {}
    }
    if ($needsUpdate) {
        Write-Host "正在检查下载组件更新……"
        & $Python -m pip install --disable-pip-version-check --quiet --upgrade gallery-dl "yt-dlp[default]" imageio-ffmpeg 2>$null
        Set-Content -Path $UpdateStamp -Value ([DateTimeOffset]::Now.ToUnixTimeSeconds()) -Encoding ASCII
    }
}

function Get-Ffmpeg {
    if ($script:Ffmpeg -and (Test-Path $script:Ffmpeg)) { return $script:Ffmpeg }
    $script:Ffmpeg = (& $Python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())").Trim()
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $script:Ffmpeg)) {
        throw "没有找到视频合并组件，请重新启动程序后再试。"
    }
    return $script:Ffmpeg
}

function Choose-Browser {
    Write-Host ""
    Write-Host "请选择你平时已经登录这些网站的浏览器："
    Write-Host "  1) Chrome（推荐）"
    Write-Host "  2) Edge"
    Write-Host "  3) Firefox"
    Write-Host "  0) 不使用登录状态（只尝试公开内容）"
    $choice = Read-Host "请输入数字 [1]"
    switch ($choice) {
        "2" { $script:BrowserName = "edge" }
        "3" { $script:BrowserName = "firefox" }
        "0" { $script:BrowserName = "" }
        default { $script:BrowserName = "chrome" }
    }
}

function Invoke-YtDownload {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination,
        [bool]$UseCookies = $true
    )
    $ffmpeg = Get-Ffmpeg
    $arguments = @(
        "-m", "yt_dlp",
        "--no-overwrites", "--no-mtime", "--trim-filenames", "180", "--progress",
        "--format", "bestvideo*+bestaudio/best",
        "--merge-output-format", "mp4", "--remux-video", "mp4",
        "--ffmpeg-location", $ffmpeg,
        "-P", $Destination,
        "-o", "%(uploader|未知作者)s/%(upload_date|未知日期)s_%(id)s_%(title).100B.%(ext)s"
    )
    if ($UseCookies -and $script:BrowserName) {
        $arguments += @("--cookies-from-browser", $script:BrowserName)
    }
    $arguments += @("--", $Url)
    & $Python @arguments | Out-Host
    return $LASTEXITCODE -eq 0
}

function Invoke-InstagramDownload {
    param([string]$Url)
    $destination = Join-Path $DownloadRoot "Instagram"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $arguments = @(
        "-m", "gallery_dl", "--config-ignore", "--destination", $destination,
        "--option", "extractor.instagram.videos=true",
        "--option", "extractor.instagram.static-videos=true",
        "--option", "extractor.instagram.previews=false"
    )
    if ($script:BrowserName) { $arguments += @("--cookies-from-browser", $script:BrowserName) }
    $arguments += @("--", $Url)
    Write-Host "正在获取 Instagram 的原图和最高可用画质视频……"
    & $Python @arguments | Out-Host
    if ($LASTEXITCODE -eq 0) { return $true }
    Write-Host "正在换一种方式重试视频……"
    return (Invoke-YtDownload -Url $Url -Destination $destination)
}

function Invoke-XiaohongshuDownload {
    param([string]$Url)
    $destination = Join-Path $DownloadRoot "小红书"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Write-Host "正在识别小红书原图或视频……"
    & $Python $MediaHelper "xiaohongshu" $Url $destination $script:BrowserName | Out-Host
    $result = $LASTEXITCODE
    if ($result -eq 3) {
        Write-Host "已识别为视频，正在下载最高可用画质……"
        return (Invoke-YtDownload -Url $Url -Destination $destination)
    }
    return $result -eq 0
}

function Get-NormalizedDouyinUrl {
    param([string]$Url)
    if ($Url -match "[?&]modal_id=([0-9]+)") {
        return "https://www.douyin.com/video/$($Matches[1])"
    }
    return $Url
}

function Invoke-DouyinDownload {
    param([string]$Url)
    $Url = Get-NormalizedDouyinUrl $Url
    $destination = Join-Path $DownloadRoot "抖音"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Write-Host "正在识别抖音图片或视频……"
    & $Python $MediaHelper "douyin" $Url $destination $script:BrowserName | Out-Host
    $result = $LASTEXITCODE
    if ($result -eq 3) {
        Write-Host "已识别为视频，正在下载最高可用画质……"
        return (Invoke-YtDownload -Url $Url -Destination $destination)
    }
    return $result -eq 0
}

function Invoke-YouTubeDownload {
    param([string]$Url)
    $destination = Join-Path $DownloadRoot "YouTube"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Write-Host "正在下载 YouTube 最高可用画质……"
    if (Invoke-YtDownload -Url $Url -Destination $destination -UseCookies $false) { return $true }
    if ($script:BrowserName) {
        Write-Host "公开方式未成功，正在使用浏览器登录状态重试……"
        return (Invoke-YtDownload -Url $Url -Destination $destination -UseCookies $true)
    }
    return $false
}

function Invoke-Download {
    param([string]$Url)
    if ($Url -match "instagram\.com/") { return (Invoke-InstagramDownload $Url) }
    if ($Url -match "xiaohongshu\.com/") { return (Invoke-XiaohongshuDownload $Url) }
    if ($Url -match "douyin\.com/") { return (Invoke-DouyinDownload $Url) }
    if ($Url -match "(youtube\.com/|youtu\.be/)") { return (Invoke-YouTubeDownload $Url) }
    Write-Host "目前支持 Instagram、小红书、抖音和 YouTube。"
    return $false
}

try {
    if (-not (Test-Path $Python)) { Install-Tools }
    Show-Title
    Update-ToolsIfNeeded
    Choose-Browser

    while ($true) {
        Show-Title
        if ($script:BrowserName) {
            Write-Host "登录状态：使用 $script:BrowserName"
        } else {
            Write-Host "登录状态：不使用浏览器，只尝试公开内容"
        }
        Write-Host ""
        Write-Host "请粘贴 Instagram、小红书、抖音或 YouTube 链接。"
        Write-Host "直接按回车可退出；输入 B 可更换浏览器。"
        Write-Host ""
        $mediaUrl = (Read-Host "链接").Trim()
        if (-not $mediaUrl) { break }
        if ($mediaUrl -ieq "B") { Choose-Browser; continue }

        Write-Host ""
        $success = Invoke-Download $mediaUrl
        if ($success) {
            Write-Host ""
            Write-Host "处理完成，已保存网站当前提供的最高可用画质。"
            Write-Host "位置：$DownloadRoot"
            Start-Process explorer.exe -ArgumentList ('"{0}"' -f $DownloadRoot)
        } else {
            Write-Host ""
            Write-Host "这次没有下载成功。请确认浏览器已登录、链接有效，"
            Write-Host "并且你的账户有权查看该内容，然后再试一次。"
        }
        Write-Host ""
        [void](Read-Host "按回车键继续下载其他链接")
    }
    Write-Host ""
    Write-Host "已退出。下载文件保存在：$DownloadRoot"
    Start-Sleep -Seconds 1
} catch {
    Write-Host ""
    Write-Host "运行失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "请检查网络后重新打开；如果仍失败，请截图此窗口。"
    Wait-BeforeExit
    exit 1
}
