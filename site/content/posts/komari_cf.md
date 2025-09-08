---
title: "不改 Nezha，照样新建 Komari：Docker + CF Tunnel 超简洁部署"
date: 2025-09-08
---
# 使用 Cloudflare Tunnel 部署 Komari

## 背景

我之前已经使用 **Nezha 监控** 一段时间，但发现一些痛点：

* Nezha 默认只能查看 **1 分钟的机器信息** 和 **24 小时的延迟数据**。
* 如果想通过公网访问，需要额外配置 **Nginx 反代**，过程繁琐。

而 **Komari** 原生支持 **Cloudflare Tunnel (CF Tunnel)**，可以直接通过 Cloudflare 提供的隧道进行访问，免去手动配置反代的烦恼。

因此我的目标是：

* **保留 Nezha**（不修改、不影响现有部署）；
* **新增 Komari**，通过 **子域名 + Cloudflare Tunnel** 部署。

---

## 官方文档参考

* [使用 Docker Compose 部署 Komari](https://komari-document.pages.dev/install/docker.html#%E4%BD%BF%E7%94%A8-docker-compose)
* [集成 Cloudflare Tunnel 指南](https://komari-document.pages.dev/faq/cloudflared.html)

---

## 部署步骤

### 1. 准备 Docker Compose 文件

在服务器上新建 `docker-compose.yml`：

```yaml
version: '3.8'
services:
  komari:
    image: ghcr.io/komari-monitor/komari:latest
    container_name: komari
    ports:
      - "25774:25774"
    volumes:
      - ./data:/app/data
    environment:
      ADMIN_USERNAME: admin
      ADMIN_PASSWORD: 123456
      KOMARI_ENABLE_CLOUDFLARED: "true"
      # 在 Cloudflare Tunnel 中获取的 Token
      KOMARI_CLOUDFLARED_TOKEN: eyJXXXX
    restart: unless-stopped
```


---

### 2. 在 Cloudflare Zero Trust 创建 Tunnel

1. 登录 [Cloudflare Zero Trust](https://dash.teams.cloudflare.com/)。
2. 进入 **Access → Tunnels**。
   ![进入 Tunnels](/img/posts/komari_cf/image.png)
3. 点击 **Create a tunnel** → 选择 **Cloudflare** → 复制生成的 **Token**。
   ![创建 Tunnel](/img/posts/komari_cf/image-2.png)
4. 将复制的 Token 填写到 `docker-compose.yml` 中 `KOMARI_CLOUDFLARED_TOKEN` 字段。

---

### 3. 启动 Komari

在项目目录下执行：

```bash
docker compose up -d
```

启动后，Komari 会自动通过 Cloudflare Tunnel 建立连接，你可以在 Cloudflare 中为该 Tunnel 绑定一个 **子域名**（如 `monitor.example.com`），即可在公网访问。

---

## 总结

通过 **Docker Compose + Cloudflare Tunnel** 部署 Komari，可以做到：

* 免去额外的 **Nginx/反代配置**；
* **安全稳定**地通过子域名访问监控面板；
* 与现有 **Nezha 监控** 并行使用，互不影响。

---