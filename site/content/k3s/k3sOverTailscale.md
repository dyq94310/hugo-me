---
title: "基于 Tailscale 构建跨云 K3s 集群实践"
date: 2025-12-16
---
# 基于 Tailscale 构建跨云 K3s 集群实践

## 1\. 背景与方案选型

在混合云或边缘计算场景下，节点往往分布在不同的网络环境（公网、内网、NAT 后）。使用 Tailscale 构建 Mesh 网络（Overlay Network）可以有效解决跨云通信问题。

**方案优势：**

  * **K3s 原生支持**：K3s 提供了实验性的 VPN 集成接口，通过 `vpn-auth` 参数可实现自动加入 Tailscale 网络并配置节点通信。参考：[K3s Distributed Hybrid Setup](https://docs.k3s.io/networking/distributed-multicloud)。
  * **网络透明化**：屏蔽了复杂的防火墙、端口映射和 NAT 穿透细节。
  * **成本低**：Tailscale 个人版目前支持无限设备接入（此前限制为 100 台），对于中小规模集群完全免费。

## 2\. 前置准备：Tailscale 配置

### 2.1 获取 ACL 权限与 Token

为了让 K3s 的 Pod 网络（Flannel/CNI）能够通过 Tailscale 路由，需要配置 ACL 允许节点宣告子网路由，并设置自动批准。

1.  登录 [Tailscale 控制台](https://login.tailscale.com/admin/acls/file)。
2.  在 **Access Controls** 中添加以下配置（假设 K3s 默认 Cluster CIDR 为 `10.42.0.0/16`）：

<!-- end list -->

```json
{
  "autoApprovers": {
    "routes": {
      // 允许自动批准 10.42.0.0/16 网段的路由宣告
      // 请将 user@example.com 替换为你的 Tailscale 账户邮箱
      "10.42.0.0/16": ["user@example.com"]
    }
  },
  "acls": [
    {
      "action": "accept",
      "src": ["10.42.0.0/16"],
      "dst": ["10.42.0.0/16:*"]
    }
    // ... 保留其他默认 ACL
  ]
}
```

3.  在 **Settings \> Keys** 中创建一个 **Reusable**（可复用）的 Auth Key，并添加标签（可选，便于管理）。记下 Key 为 `${TAILSCALE_AUTH_KEY}`。

## 3\. 集群部署

### 3.1 安装 Tailscale (所有节点)

在 Server 和 Agent 节点上安装 Tailscale，但**不需要**手动执行 `tailscale up`，K3s 会自动接管这一步。

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### 3.2 部署 Server (Control Plane)

为了保持系统整洁，建议将配置全部写入 `config.yaml`，而非修改 systemd 单元文件。

1.  **创建配置文件** `/etc/rancher/k3s/config.yaml`：

<!-- end list -->

```yaml
# 自动加入 Tailscale 网络
vpn-auth: "name=tailscale,joinKey=${TAILSCALE_AUTH_KEY}"

# 指定节点 IP 为 Tailscale IP (需确保 Tailscale 启动后获取该 IP，或留空由 K3s 自动识别)
# K3s 集成模式下，通常会自动处理接口绑定，如需强制指定可使用 node-external-ip
# node-external-ip: "<Server-Tailscale-IP>"

# TLS 证书包含公网 IP 和 Tailscale IP，便于 kubectl 远程访问
tls-san:
  - "<Server-Public-IP>"
  - "<Server-Tailscale-IP>"

# 权限设置
write-kubeconfig-mode: "644"
```

2.  **安装并启动 K3s Server**：

<!-- end list -->

```bash
curl -sfL https://get.k3s.io | sh -
```

### 3.3 部署 Agent (Worker Node)

#### 常规节点
1.  **创建配置文件** `/etc/rancher/k3s/config.yaml`：

<!-- end list -->

```yaml
vpn-auth: "name=tailscale,joinKey=${TAILSCALE_AUTH_KEY}"
```

2.  **安装并加入集群**：
      * `K3S_URL` 建议使用 Server 的 Tailscale IP（如果 Server 已经就绪），或者公网 IP。
      * `K3S_TOKEN` 为 Server 节点的 `/var/lib/rancher/k3s/server/node-token`。

<!-- end list -->

```bash
export K3S_URL=https://<Server-Tailscale-IP>:6443
export K3S_TOKEN=<k3s-node-token>

curl -sfL https://get.k3s.io | K3S_URL=${K3S_URL} K3S_TOKEN=${K3S_TOKEN} sh -
```

#### 国内节点
下载脚本使用镜像
```bash
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn K3S_URL=${K3S_URL} K3S_TOKEN=${K3S_TOKEN} sh -
```
其他步骤一致


#### NAT节点
 **创建配置文件** `/etc/rancher/k3s/config.yaml`：

由于nat节点没有公网ip,需要指定node节点的ip。这里ts组网，直接写nat节点的tsip
```bash
vpn-auth: "name=tailscale,joinKey=${TAILSCALE_AUTH_KEY}"

node-ip: "<Node-Tailscale-IP>"
flannel-iface: "tailscale0"
```
其他步骤一致

## 4\. 验证与排查

执行以下命令检查节点状态：

```bash
kubectl get node -o wide
```

**预期输出：**

  * `INTERNAL-IP` 应为 `100.x.y.z` (Tailscale 网段)。
  * `STATUS` 为 `Ready`。

<!-- end list -->

```text
NAME       STATUS   ROLES                  AGE   VERSION        INTERNAL-IP      OS-IMAGE
ccs        Ready    control-plane,master   11d   v1.30.2+k3s1   100.112.54.59    Debian GNU/Linux 12 (bookworm)
hosteons   Ready    <none>                 11d   v1.30.2+k3s1   100.125.206.46   Debian GNU/Linux 12 (bookworm)
...
```

**验证 Pod 网络连通性：**

启动一个测试 Pod 并尝试 ping 其他节点的 Pod IP：

```bash
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600
# 等待 Pod 运行后，进入容器 ping 其他 Pod IP
```
