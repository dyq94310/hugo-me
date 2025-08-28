# Hugo 极简博客 (Docker + Nginx)

这是一个基于 **Hugo + Nginx** 的极简个人博客项目：

* **无主题**：自定义最小模板（纯文本/Markdown 渲染）。
* **静态化**：Hugo 构建站点，输出纯静态文件。
* **高效部署**：Nginx 托管，Docker/Compose 一键启动。

---

## 📂 项目结构

```
├─ site/                 # Hugo 源站目录
│  ├─ hugo.toml          # Hugo 配置
│  ├─ archetypes/        # 新建文章时的默认 front matter
│  ├─ content/           # Markdown 文章
│  │  └─ posts/          # 文章目录
│  └─ layouts/_default/  # 最小模板 (baseof/list/single)
│
├─ public/               # Hugo 构建输出 (HTML/CSS/JS)
│                        # Nginx 直接托管此目录
│
├─ docker-compose.yml    # Docker Compose 定义
└─ nginx.conf            # Nginx 配置
```

---

## ⚡ Quick Start (本地快速启动)

1. 拉取项目：

```bash
git clone https://github.com/dyq94310/hugo-me.git
cd hugo-me
```

2. 构建静态文件：

```bash
docker compose --profile build run --rm hugo hugo --minify
```
或者
```bash
minify.sh
```

3. 启动服务：

```bash
docker compose up -d web
```

4. 打开浏览器访问：

* [http://localhost](http://localhost)
* 或者 [http://127.0.0.1](http://127.0.0.1)

> 默认端口在 `docker-compose.yml` 中定义，可自行修改。

---

## 🚀 常用命令

### 构建站点

```bash
docker compose --profile build run --rm hugo hugo --minify
```

### 启动 Nginx

```bash
docker compose up -d web
```

### 新建文章

```bash
hugo new posts/my-first-post.md
```

---

## 📦 VPS 部署流程

1. 拉取项目：

```bash
git clone https://github.com/dyq94310/hugo-me.git
```

2. 构建并拷贝至 Nginx：

```bash
sh vminify.sh
```

3. Nginx 配置示例：

```nginx
server {
    server_name blog.groovydeng.eu.org;
    access_log  /var/log/nginx/blog.eu.org.access.log  main;

    listen 10443 ssl proxy_protocol;
    listen [::]:10443 ssl proxy_protocol;
    http2  on;
    port_in_redirect  off;

    ssl_certificate     /etc/data/certificate/groovydeng.eu.org.pem;
    ssl_certificate_key /etc/data/certificate/groovydeng.eu.org.key;

    underscores_in_headers on;
    set_real_ip_from 0.0.0.0/0;
    real_ip_header CF-Connecting-IP; 

    root /usr/share/nginx/html;
    index index.html;

    location / { 
        try_files $uri $uri/ /index.html; 
    }

    # 基础压缩
    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;
}
```

---

## 🌐 在线访问

👉 [我的博客](https://blog.groovydeng.eu.org)
