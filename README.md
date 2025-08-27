# Hugo 极简博客 (Docker + Nginx)

这是一个基于 **Hugo + Nginx** 的极简个人博客项目：  
- 无主题，自定义最小模板（纯文本/Markdown 渲染）。  
- 站点由 Hugo 构建为静态文件，Nginx 负责托管。  
- 使用 Docker/Compose 部署，简单、稳定、高效。

---

## 📂 项目结构
```
├─ site/ # Hugo 源站目录
│ ├─ hugo.toml # Hugo 配置
│ ├─ archetypes/ # 新建文章时的默认 front matter
│ ├─ content/ # Markdown 文章
│ │ └─ posts/ # 文章目录
│ └─ layouts/_default/ # 最小模板 (baseof/list/single)
│
├─ public/ # Hugo 构建输出 (静态 HTML/CSS/JS)
│ # Nginx 直接托管此目录
│
├─ docker-compose.yml # Docker Compose 定义
└─ nginx.conf # Nginx 配置
```
---


## 🚀 常用命令

### 1. 构建站点
将 `site/` 转换为 `public/` 静态文件：
```bash
docker compose --profile build run --rm hugo hugo --minify
```

### 2. 启动 Nginx 服务调试

托管 public/，对外提供访问：
```bash
docker compose up -d web
```
访问 http://<VPS IP> 或 http://<你的域名> 即可。

### 3. 新建文章
在 site/content/ 下生成新文章,重复构建站点即可
