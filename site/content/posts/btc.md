---
title: "CryptCoin - BTC 篇"
date: 2025-10-22
---

## 一、背景

比特币（BTC）是第一个去中心化的加密货币。虽然“挖矿”这个概念经常被提及，但许多人并没有亲自尝试过。本篇文章记录我在学习和实验 BTC 挖矿过程中掌握的知识与配置方法。

---

## 二、前置知识

### 1. 挖矿原理

比特币网络由无数节点共同维护一份**去中心化账本**（区块链）。
每个区块通过其前一个区块的哈希值（`hashPrevBlock`）相互连接，形成链式结构。

矿工的任务是：

* 在已有区块链的末端尝试“添加”一个新区块；
* 区块中包含若干交易以及一个**挖矿奖励**（区块补贴 + 手续费），该奖励会自动转入矿工的钱包；
* 新区块必须满足“工作量证明”（Proof of Work，PoW）要求：

  > 区块头经过 SHA-256 两次哈希后，结果必须小于当前网络目标值（Target）。
  > 通俗说，就是哈希结果的前导零必须达到指定数量（例如当前约需前 70 多个二进制零，约等于 24 个十六进制零）。

矿工通过不断调整区块头中的随机数 `nonce` 与时间戳，反复计算哈希，直到找到一个满足难度要求的结果。第一个找到的矿工可以将新区块广播到全网，从而获得当前的区块奖励。

---

### 2. 算法与计算

* **算法**：`SHA-256d`（即双 SHA-256 哈希）。
* **硬件**：早期可用 CPU/GPU，如今主流为 ASIC 专用矿机。
* **难度**：网络每约 2016 个区块调整一次（约两周），保持平均出块时间为 10 分钟。

---

### 3. 矿池（Pool）

由于单个矿工算力有限，挖出整块的概率极低。
矿池通过分配子任务（工作量份额 share）让矿工协同挖矿，并按贡献比例分配奖励。
加入矿池可以显著提高“稳定收益”，但牺牲了“独挖中大奖”的机会。

---

### 4. 挖矿工具

* **cpuminer / cpuminer-multi**：经典的 CPU 挖矿程序，支持 SHA-256、scrypt 等算法；
* 启动时指定算法、矿池地址、钱包地址即可运行。

示例命令：

```bash
cpuminer -a sha256d -o stratum+tcp://pool.solomining.de:3333 -u bc1qxxxxxxx.worker
```

---

### 5. 合规与风险

比特币挖矿在部分地区（如中国大陆）受到限制或禁止。
务必了解所在地法律与云服务条款，避免在公共云上直接暴露挖矿流量。
学习实验目的下，应**控制算力占用、隐藏特征流量、避免对他人造成影响**。

---

## 三、隐藏挖矿流量

`cpuminer` 是纯 TCP 客户端，会直接连接矿池。如果所在网络环境对挖矿流量敏感，可通过 VPN 容器（如 `gluetun`）进行转发和隔离。

流量路径可设计为：

```
cpuminer → gluetun(vpn client) → WireGuard → VPS → 矿池
```

这样，本地主机看到的只是加密的 WireGuard 流量，不会暴露挖矿特征。

---

## 四、Docker Compose 实践

在容器中运行挖矿程序最为安全与可控。
以下示例展示了如何使用 `gluetun` 提供 VPN 出口，并将 `cpuminer` 流量绑定到该 VPN：

```yaml
services:
  vpn:
    image: qmcgaw/gluetun:latest
    cap_add: [ NET_ADMIN ]
    devices: [ /dev/net/tun:/dev/net/tun ]
    environment:
      - VPN_SERVICE_PROVIDER=custom
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=111
      - WIREGUARD_PUBLIC_KEY=aaa
      - WIREGUARD_ENDPOINT_IP=1.112.115.1
      - WIREGUARD_ENDPOINT_PORT=17821
      - WIREGUARD_ADDRESSES=10.0.0.3/32
      - DOT=on
      - DOT_PROVIDERS=cloudflare
      - TZ=Asia/Taipei
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- https://ifconfig.me || exit 1"]
      interval: 20s
      timeout: 5s
      retries: 6

  cpuminer:
    image: wernight/cpuminer-multi
    restart: unless-stopped
    network_mode: "service:vpn"
    depends_on:
      vpn:
        condition: service_healthy
    entrypoint: ["cpuminer"]
    command:
      - "-a"
      - "sha256d"
      - "-o"
      - "stratum+tcp://pool.solomining.de:3333"
      - "-u"
      - "bc1qhxyja6s22222c3w5721ghmxlghl4ww3vccysp.xps"
    cpus: 0.2  # 限制 CPU 使用率
```

> 注意：容器内的 `cpuminer` 会通过 `gluetun` 的 WireGuard 隧道出网，因此宿主需具备 `/dev/net/tun` 设备与 `NET_ADMIN` 权限。

---

## 五、挖矿收益与现实概率

在当前网络难度下，使用家用 CPU 或 VPS 挖比特币几乎不可能获得区块奖励。
概率可近似理解为：

> 使用 50 H/s（普通 CPU）的算力，成功独挖一个块的概率 ≈ 每天 1 / 数十亿。

换句话说，相当于买彩票。
但作为学习、理解区块链共识机制的实践，这样的实验仍具有教育意义。

---

## 六、总结

| 项目     | 说明                                |
| ------ | --------------------------------- |
| 算法     | SHA-256d                          |
| 共识机制   | PoW（工作量证明）                        |
| 当前区块奖励 | 3.125 BTC + 手续费                   |
| 出块时间   | 平均 10 分钟                          |
| 调整周期   | 每 2016 块（约两周）                     |
| 推荐学习工具 | cpuminer、Docker、gluetun、WireGuard |
| 实验建议   | 使用低算力设备，保持合规，仅作技术学习               |

---

### 💡 结语

错过了比特币草根时代。。。。。。
