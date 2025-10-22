---
title: "CryptCoin - XMR 篇"
date: 2025-10-22
---

## 一、背景

在上一篇介绍的比特币（BTC）中，我们了解到由于其挖矿算法（SHA-256d）对 ASIC 极为友好，普通人使用 CPU 或 GPU 已几乎无法参与竞争。
门罗币（Monero, XMR）则采用了完全不同的设计理念：

* 它的 **RandomX** 工作量证明算法刻意优化为 CPU 友好型；
* 拥有**匿名性与隐私保护**特性；
* 即使家用设备也能参与挖矿，从而保持去中心化与公平性。

因此，本篇记录我学习和实践门罗币挖矿的过程。

---

## 二、前置知识

### 1. 门罗币简介

门罗币（Monero, XMR）是一种强调 **隐私性、可替代性（fungibility）和去中心化** 的加密货币。
它的目标是：

> “让每一笔交易都是私密、安全、不可追踪的。”

---

### 2. 核心技术概念

* **环签名（Ring Signature）**
  一种加密签名方法，允许一组密钥中的任意成员代表整个组签名。
  这样外界只能确认“签名来自该组中的某人”，却无法判断具体是哪一位。

* **隐匿地址（Stealth Address）与子地址（Subaddress）**
  门罗币每笔交易都会生成一次性地址（子地址）。
  收款方通过私钥扫描区块链识别属于自己的交易，但外界无法将多笔交易关联到同一钱包。

* **环机密交易（RingCT）**
  通过加密方式隐藏交易金额，只验证输入输出的总量守恒。

* **RandomX 算法**
  门罗币的 PoW 算法。
  它不是固定的哈希函数，而是一个动态虚拟机执行环境，会随机生成伪代码指令并在 CPU 上执行。
  算法频繁调用内存、整数与浮点运算，使得 **CPU 更高效，而 ASIC 难以优化**，从而维持挖矿公平性。

* **P2Pool（去中心化矿池）**
  与传统矿池不同，P2Pool 采用分布式架构，矿工在本地验证 share 并直接与他人节点通信，无集中控制，也无需手续费。

* **xmrig**
  高性能门罗币挖矿工具，支持 RandomX / CryptoNight / Argon2 等算法，常用于 CPU 挖矿。

---

## 三、挖矿架构设计

为了在安全、合规的前提下学习挖矿，我采用以下架构：

```
xmrig → p2pool → gluetun(VPN Client) → WireGuard → VPS → 外部 P2Pool 网络
```

* `xmrig`：执行 RandomX 算法的挖矿核心。
* `p2pool`：本地轻量矿池节点，与外部 Monero 网络同步工作。
* `gluetun`：容器化的 VPN 客户端，将挖矿流量加密转发，避免直接暴露矿池流量特征。

---

## 四、Docker Compose 实践

下面是完整配置。通过 `network_mode: "service:gluetun"`，所有容器流量统一走 VPN。

```yaml
version: "3.8"

services:
  # 1️⃣ gluetun — WireGuard/OpenVPN 客户端
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add: [ NET_ADMIN ]
    devices: [ /dev/net/tun:/dev/net/tun ]
    restart: unless-stopped
    volumes:
      - ./gluetun:/gluetun
    environment:
      - VPN_SERVICE_PROVIDER=custom
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=111
      - WIREGUARD_PUBLIC_KEY=222
      - WIREGUARD_ENDPOINT_IP=1.1.253.60
      - WIREGUARD_ENDPOINT_PORT=7779
      - WIREGUARD_ADDRESSES=10.0.0.5/32
      - DOT=on
      - DOT_PROVIDERS=cloudflare
      - TZ=Asia/Taipei
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- https://ifconfig.me || exit 1"]
      interval: 20s
      timeout: 5s
      retries: 6

  # 2️⃣ p2pool — 去中心化矿池节点
  p2pool:
    image: gbenson/p2pool:latest
    container_name: p2pool
    network_mode: "service:gluetun"
    depends_on:
      - gluetun
    restart: unless-stopped
    volumes:
      - ./p2pool/data:/data
    command:
      - --wallet
      - 48L1111111111111111111111111111111111111111
      - --host
      - node.monerodevs.org
      - --rpc-port
      - "18089"
      - --zmq-port
      - "18084"
      - --stratum
      - 0.0.0.0:3333
      - --p2p
      - 0.0.0.0:37889
      - --mini
      - --light-mode
      - --no-igd
      - --loglevel
      - "4"
    logging:
      options:
        max-size: "10m"
        max-file: "3"

  # 3️⃣ xmrig — 实际执行挖矿的 CPU 程序
  xmrig:
    image: minerboy/xmrig
    container_name: xmrig
    network_mode: "service:gluetun"
    depends_on:
      - gluetun
      - p2pool
    restart: unless-stopped
    volumes:
      - ./xmrig/config:/config
    environment:
      - CPU_THREADS=2
    command: [ "-c", "/config/xmrig.json" ]
    cpus: "3.4"
    logging:
      options:
        max-size: "10m"
        max-file: "3"
```

> ⚙️ 说明：
>
> * `p2pool` 使用本地钱包地址运行小型节点；
> * `xmrig` 连接本地的 `p2pool:3333` 端口；
> * 所有流量经 `gluetun` 的 WireGuard 隧道加密转发。


再创建xmring配置文件：xmrig/config/xmrig.json ，保持默认即可

```json
{
    "randomx": {
        "init": -1,
        "mode": "fast",
        "1gb-pages": false
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "priority": 3,
        "memory-pool": false,
    },
    "log-file": null,
    "donate-level": 1,
    "donate-over-proxy": 1,
    "pools": [
        {
            "url": "127.0.0.1:3333",
            "user": "48000000000000000000000000000000000000000000000000000000000000000000000000000",
            "pass": "x",
        }
    ]
}
```

> ⚙️ 说明：
>
> * `pools.user` 钱包地址
> * `cpu.priority` 启动多少线程

---

## 五、门罗币与比特币对比

| 项目    | 比特币（BTC）      | 门罗币（XMR）                  |
| ----- | ------------- | ------------------------- |
| 共识算法  | SHA-256d      | RandomX                   |
| 硬件友好度 | ASIC 优化（矿机主导） | CPU 优化（抗 ASIC）            |
| 匿名性   | 公开可追踪         | 完全匿名（环签名 + RingCT + 隐匿地址） |
| 区块时间  | ~10 分钟        | ~2 分钟                     |
| 奖励调整  | 每约 4 年减半      | 渐进尾部补贴（Tail Emission）     |
| 矿池机制  | 中心化为主         | 支持去中心化 P2Pool             |
| 隐私合规性 | 交易透明，可审计      | 默认隐私，部分交易所限制交易            |

---

## 六、学习结论

* **XMR 更适合个人学习挖矿原理**：
  RandomX 让普通 CPU 也能挖矿；理解其虚拟机随机执行机制，有助于深入理解 PoW 的“抗专用硬件”设计。

* **P2Pool 去中心化设计更贴近区块链精神**：
  无需信任第三方矿池、无手续费、奖励自动结算。

* **使用 VPN / 隧道是良好安全习惯**：
  能隔离挖矿流量、保护隐私、并符合云平台安全策略。

---
### 经济收益
目前只挖了一天，收益预计是0.4元

我使用4C8G的机器，GB5 benchmark单核1200,多核5000

### 💡 结语

门罗币不仅是一种“更公平”的挖矿币种，我持续看好
