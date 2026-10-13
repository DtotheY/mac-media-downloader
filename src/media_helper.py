#!/usr/bin/env python3
"""Download original images from Xiaohongshu and Douyin image posts."""

import mimetypes
import re
import sys
from pathlib import Path
from urllib.request import Request as UrlRequest, urlopen

from yt_dlp import YoutubeDL
from yt_dlp.extractor.tiktok import DouyinIE
from yt_dlp.extractor.xiaohongshu import XiaoHongShuIE
from yt_dlp.utils import js_to_json
from yt_dlp.utils.traversal import traverse_obj


def safe_name(value, fallback="作品"):
    value = re.sub(r'[\\/:*?"<>|\x00-\x1f]', "_", value or fallback).strip(" .")
    return value[:80] or fallback


def extension(content_type, url):
    guessed = mimetypes.guess_extension((content_type or "").split(";", 1)[0].strip())
    if guessed == ".jpe":
        guessed = ".jpg"
    if guessed:
        return guessed
    suffix = Path(url.split("?", 1)[0]).suffix.lower()
    return suffix if suffix in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"} else ".jpg"


def save_images(urls, destination, post_id, title, referer):
    folder = Path(destination) / f"{post_id}_{safe_name(title)}"
    folder.mkdir(parents=True, exist_ok=True)
    saved = 0
    for index, image_url in enumerate(dict.fromkeys(urls), 1):
        image_url = image_url.replace("http://", "https://", 1)
        request = UrlRequest(image_url, headers={
            "Referer": referer,
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/130 Safari/537.36",
        })
        try:
            with urlopen(request, timeout=40) as response:
                data = response.read()
                ext = extension(response.headers.get("Content-Type"), image_url)
            target = folder / f"{index:02d}{ext}"
            temporary = target.with_suffix(target.suffix + ".part")
            temporary.write_bytes(data)
            temporary.replace(target)
            print(f"已保存原图 {index}/{len(urls)}：{target.name}")
            saved += 1
        except Exception as error:
            print(f"第 {index} 张图片下载失败：{error}", file=sys.stderr)
    return saved == len(urls) and saved > 0


def ydl_options(browser):
    options = {"quiet": True, "no_warnings": True}
    if browser:
        options["cookiesfrombrowser"] = (browser, None, None, None)
    return options


def xiaohongshu(url, destination, browser):
    with YoutubeDL(ydl_options(browser)) as ydl:
        extractor = XiaoHongShuIE(ydl)
        post_id = extractor._match_id(url)
        webpage = extractor._download_webpage(url, post_id)
        state = extractor._search_json(
            r"window\.__INITIAL_STATE__\s*=", webpage, "initial state", post_id,
            transform_source=js_to_json)
        note = traverse_obj(state, ("note", "noteDetailMap", post_id, "note")) or {}
        video_streams = traverse_obj(note, ("video", "media", "stream", ..., ...))
        if video_streams or traverse_obj(note, ("video", "consumer", "originVideoKey")):
            return 3
        urls = []
        for item in note.get("imageList") or []:
            best = item.get("urlDefault") or item.get("urlPre")
            if best:
                urls.append(best)
        if not urls:
            raise RuntimeError("没有在这个小红书作品中找到可下载的图片或视频")
        title = note.get("title") or note.get("desc") or "小红书作品"
        return 0 if save_images(urls, destination, post_id, title, url) else 1


def douyin(url, destination, browser):
    post_id_match = re.search(r"/video/(\d+)", url)
    if not post_id_match:
        raise RuntimeError("没有识别到抖音作品编号")
    post_id = post_id_match.group(1)
    with YoutubeDL(ydl_options(browser)) as ydl:
        extractor = DouyinIE(ydl)
        response = extractor._download_json(
            "https://www.douyin.com/aweme/v1/web/aweme/detail/", post_id,
            query={"aweme_id": post_id})
        detail = response.get("aweme_detail") or {}
    images = detail.get("images") or detail.get("image_post_info", {}).get("images") or []
    urls = []
    for image in images:
        candidates = (
            traverse_obj(image, ("download_url_list", ...))
            or traverse_obj(image, ("display_image", "url_list", ...))
            or traverse_obj(image, ("url_list", ...))
        )
        if candidates:
            urls.append(candidates[-1])
    if not urls:
        return 3
    title = detail.get("desc") or "抖音图文"
    return 0 if save_images(urls, destination, post_id, title, url) else 1


def main():
    if len(sys.argv) != 5:
        print("参数不完整", file=sys.stderr)
        return 2
    platform, url, destination, browser = sys.argv[1:]
    try:
        if platform == "xiaohongshu":
            return xiaohongshu(url, destination, browser)
        if platform == "douyin":
            return douyin(url, destination, browser)
        raise RuntimeError("不支持的平台")
    except Exception as error:
        print(f"识别失败：{error}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
