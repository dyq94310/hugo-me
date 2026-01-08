---
title: "K3s 数据备份实践：基于 RustFS 与 Cloudflare R2 的双重保险"
date: 2026-01-08
---

# K3s 数据备份实践：基于 RustFS 与 Cloudflare R2 的双重保险

## 背景

随着业务全面迁移至 K3s 集群，数据安全成为了核心课题。由于集群中部分应用（如 Bitwarden）的数据持久化在宿主机的 `/opt/k3s-data/` 目录下，我需要一套简单、直观且具备异地容灾能力的方案。

**目标：**

* **操作简单**：自动化完成。
* **可视化检查**：具备 Web UI，方便随时查看备份状态和文件。
* **异地容灾**：本地 S3 与云端 S3 双备份。

## 技术选型

在存储协议上，我对比了 POSIX 和 S3：

| 特性 | POSIX (如 NFS, SeaweedFS) | S3 (如 MinIO, RustFS, R2) |
| --- | --- | --- |
| **优势** | 像本地目录一样挂载，低延迟 | 协议通用，易于跨网络、跨云传输 |
| **劣势** | 跨节点管理复杂，Web 视图较弱 | 需要通过 API 或工具访问 |

**最终选择：S3 协议**
Cloudflare R2 等厂商提供了极具性价比的对象存储，配合轻量级的本地 S3 实现，既能保证速度又能实现异地备份。

### 存储组件对比

* **MinIO**：功能强大但商业协议调整后不再纯粹，且资源占用较高。
* **RustFS**：
* **优**：Rust 实现，内存占用极低；自带 Web 控制台。
* **缺**：处于 Alpha 阶段，曾曝出硬编码 Token 漏洞（**CVE-2025-68926**）。*注：已在 1.0.0-alpha.78 修复。*


* **SeaweedFS**：性能优秀，但其 Web 界面主要用于集群管理而非文件浏览。

---

## 备份实现方案

### 1. 部署 RustFS（本地 S3 后端）

RustFS 默认运行在 **10001** 用户下。我们将 API 端口（9000）和控制台端口（9001）分别暴露。

> [!IMPORTANT]
> **安全提示**：请确保升级到 `1.0.0-alpha.78` 或更高版本，以修复已知的硬编码校验漏洞。

```yaml
# 核心配置部分
spec:
  template:
    spec:
      securityContext:
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
      nodeSelector:
        kubernetes.io/hostname: ccs # 固定在有大容量硬盘的节点
      containers:
      - name: rustfs
        image: rustfs/rustfs:1.0.0-alpha.78
        env:
        - name: RUSTFS_CONSOLE_ENABLE
          value: "true"
        ports:
        - containerPort: 9000 # S3 API
        - containerPort: 9001 # Console UI
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        hostPath:
          path: /opt/k3s-data/rustfs
          type: DirectoryOrCreate

```

---

### 2. CronJob 双重备份逻辑

利用 `rclone rcat` 配合标准输入，可以直接将 `tar` 压缩流实时传向远端，**无需在容器内产生临时文件**，极大节省了磁盘 IO。

```yaml
# 核心备份逻辑 (CronJob Container Args)
args:
  - |
    set -e
    DATE=$(date +%Y%m%d)
    FILE_NAME="k3s-data-${MY_NODE_NAME}-${DATE}.tar.gz"
    
    # 使用 rclone rcat (Remote Cat) 直接接收 tar 流
    echo "正在备份至 RustFS..."
    tar -cz -C /host-data --exclude='rustfs*' . | rclone rcat "mys3:${S3_BUCKET}/backups/${MY_NODE_NAME}/${FILE_NAME}"

    echo "正在同步至 Cloudflare R2..."
    tar -cz -C /host-data --exclude='rustfs*' . | rclone rcat "cfr2:${R2_BUCKET}/backups/${MY_NODE_NAME}/${FILE_NAME}"

    # 保留最近 10 天备份
    rclone delete "mys3:${S3_BUCKET}/backups/${MY_NODE_NAME}/" --min-age 10d
    rclone delete "cfr2:${R2_BUCKET}/backups/${MY_NODE_NAME}/" --min-age 10d

```

---

### 3. 使用 Kustomize 管理多节点差异

由于每个节点都需要独立运行备份任务，使用 `Kustomize` 的 `patches` 功能可以避免编写大量重复的 YAML。

**目录结构：**

```text
.
└── cronjob
    ├── base/             # 基础模板
    └── overlays/         # 各节点差异化配置
        ├── aliyun-sz/
        └── cc/

```

**Overlays 示例 (`aliyun-sz/kustomization.yaml`)：**

```yaml
resources:
  - ../../base
patches:
  - target:
      kind: CronJob
      name: k3s-backup-placeholder
    patch: |-
      - op: replace
        path: /metadata/name
        value: k3s-node-backup-daily-aliyun-sz
      - op: replace
        path: /spec/jobTemplate/spec/template/spec/nodeSelector/kubernetes.io~1hostname
        value: "aliyun-sz"

```

---


## 总结

通过 RustFS 解决本地快速访问和可视化需求，通过 Cloudflare R2 解决异地容灾，再配合 Kustomize 的优雅管理，这套 K3s 备份方案在灵活性和安全性之间取得了很好的平衡。

## 完整代码
[Mixup](https://github.com/dyq94310/Mixup/tree/main/common)