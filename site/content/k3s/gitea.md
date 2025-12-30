---
title: "K3s 组网下的私有 GitOps 中心：Gitea 部署实践"
date: 2025-12-30
---

# K3s 组网下的私有 GitOps 中心：Gitea 部署实践

## 1. 背景与选型

随着集群服务增多（如 Singbox 等），配置文件（Config）的变更管理变得琐碎。将配置“代码化”并托管在私有 Git 仓库，结合 FluxCD 等工具实现 **GitOps** 是目前的最佳方案。

### 为什么选择 Gitea？

在私密性要求极高的场景下，我们选择了 Gitea：

* **GitHub**：虽有私有仓库，但敏感配置（含账号密码）托管在公有云始终存在主权焦虑。
* **Gogs**：老牌轻量，但社区活跃度较低，功能迭代缓慢。
* **Gitea**：从 Gogs 分叉而来，功能全面且生态活跃，是目前私有化部署的最佳平衡点。

---

## 2. 核心架构设计

* **节点策略**：强制钉在 **Master 节点 (ccs)**。因为 Gitea 涉及文件 IO 且作为核心基础设施，需要利用主节点较好的性能（4C4G）和稳定性。
* **协议选择**：**全量 HTTPS**。在 Tailscale 组网中，为了穿透简单且复用 443 端口，我们放弃了复杂的 SSH 端口映射，统一走 HTTPS 流量。
* **持久化**：采用 `hostPath` 挂载，便于宿主机直接进行文件级备份。

---

## 3. 部署要点与“避坑”指南

### 权限初始化（关键）

Gitea 镜像默认以 UID `1000` 运行。如果宿主机目录权限不正确，会导致容器启动后无法写入数据库。

> **操作命令**：
> ```bash
> chown -R 1000:1000 /opt/k3s-data/gitea
> 
> ```
> 
> 

### 针对 TS 组网的优化

由于 Ingress 默认只处理七层（HTTP/HTTPS）协议，且在 Tailscale 环境下暴露非标端口（如 SSH 的 22 或 30222）会增加防火墙维护成本，我们决定**彻底禁用 SSH 服务**。这不仅安全，还能让 Gitea UI 界面更简洁。

---

## 4. 完整的 Kubernetes 配置

> **注意**：已修复原配置中 Ingress 语法重复的错误，并增加了禁用 SSH 的环境变量。

```yaml
# gitea-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  labels:
    app: gitea
spec:
  replicas: 1
  strategy:
    type: Recreate # 必须为 Recreate，防止多个 Pod 同时写入 SQLite 导致锁死
  selector:
    matchLabels:
      app: gitea
  template:
    metadata:
      labels:
        app: gitea
    spec:
      nodeSelector:
        kubernetes.io/hostname: ccs 
      containers:
      - name: gitea
        image: gitea/gitea:1.25.3
        env:
        - name: USER_UID
          value: "1000"
        - name: USER_GID
          value: "1000"
        - name: GITEA__database__DB_TYPE
          value: "sqlite3"
        - name: GITEA__database__PATH
          value: "/data/gitea.db"
        # [优化] 禁用 SSH 以适配单 HTTPS 环境
        - name: GITEA__server__DISABLE_SSH
          value: "true"
        - name: GITEA__server__ROOT_URL
          value: "https://git.groovydeng.eu.org/"
        - name: GITEA__server__DOMAIN
          value: "git.groovydeng.eu.org"
        - name: GITEA__server__DISABLE_ROUTER_LOG
          value: "true"
        - name: GITEA__admin__DISABLE_REGULAR_ORG_CREATION
          value: "true"
        ports:
        - name: http
          containerPort: 3000
        resources:
          limits:
            memory: "1Gi"
            cpu: "1000m"
          requests:
            memory: "256Mi"
            cpu: "100m"
        volumeMounts:
        - name: gitea-data
          mountPath: /data
      volumes:
      - name: gitea-data
        hostPath:
          path: /opt/k3s-data/gitea
          type: DirectoryOrCreate
---
apiVersion: v1
kind: Service
metadata:
  name: gitea-svc
spec:
  type: ClusterIP
  selector:
    app: gitea
  ports:
  - name: http
    port: 3000
    targetPort: 3000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitea-ingress
spec:
  tls:
    - hosts:
        - git.groovydeng.eu.org
      secretName: cf-tls # 引用已有的泛域名证书
  rules:
  - host: git.groovydeng.eu.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gitea-svc
            port:
              number: 3000

```

---

