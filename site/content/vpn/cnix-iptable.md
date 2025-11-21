---
title: "初探 CNIX 专线： IX 的一次体验"
date: 2025-11-21
---

# CNIX 服务器安全开放 Socket 端口指南（iptables + 持久化）

## 1. 背景说明
为了在阿里云前置机中部署 Docker，并提供访问 CNIX 服务器的 socket 服务，需要在 CNIX 上开放一组端口。但为了避免端口被扫描、滥用或遭受攻击，必须严格限制访问 IP。

本次方案采用 iptables 实现精确白名单，只允许阿里云前置的出口 IP（**47.99.99.99**）访问指定端口，确保绝对安全。

---

## 2. 安全策略设计：为什么要限制 IP
公网暴露端口会带来安全风险，包括：

- 被扫描器（Shodan/ZoomEye）发现
- 被爆破或代理滥用
- 被恶意流量攻击
- 暴露服务器结构信息

因此最安全的做法是：

> **使用白名单：只允许可信 IP 访问，其他来源全部拒绝**

---

## 3. iptables 规则配置（允许阿里云前置访问）

### 3.1 基础规则
```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
````

### 3.2 开放 SSH 端口（22）

```bash
iptables -A INPUT -p tcp -s 47.99.99.99 --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j DROP
```

### 3.3 放行自定义端口段 11780–11799

```bash
# TCP
iptables -A INPUT -p tcp -s 47.99.99.99 --dport 11780:11799 -j ACCEPT
iptables -A INPUT -p tcp --dport 11780:11799 -j DROP

# UDP
iptables -A INPUT -p udp -s 47.99.99.99 --dport 11780:11799 -j ACCEPT
iptables -A INPUT -p udp --dport 11780:11799 -j DROP
```

### 3.4 拒绝所有其他来源的访问

上述 DROP 已覆盖所有非白名单来源。

### 3.5 可选：默认拒绝所有未匹配流量

仅专家使用，否则可能锁死 SSH：

```bash
# iptables -P INPUT DROP
```

---

## 4. 持久化 iptables 规则（iptables-persistent）

```bash
apt install iptables-persistent -y
netfilter-persistent save
```

### 4.1 规则持久化存放位置

* `/etc/iptables/rules.v4`
* `/etc/iptables/rules.v6`

系统启动时会自动加载它们。

### 4.2 netfilter-persistent 为什么不需要常驻

因为它是 `Type=oneshot`，只在开机时运行一次：

```ini
ExecStart=/usr/sbin/netfilter-persistent start
```

它的作用是：

> **在网络初始化前恢复 iptables 规则，然后退出**

所以不需要常驻服务。

---

## 5. netfilter-persistent 的启动机制解析

该服务具有以下特点：

* `Before=network-pre.target` → 在网络启动前恢复防火墙
* `WantedBy=multi-user.target` → 正常启动时自动触发
* `Type=oneshot` → 启动后立即退出
* `ExecStart`/`ExecStop` 负责加载与卸载规则

这是 Debian 的标准防火墙持久化机制。

---

## 6. 总结

本文实现了：

* 为阿里云前置开放 socket 端口
* 使用 iptables 精确白名单控制
* 防止端口扫描、攻击、滥用
* 持久化规则，确保重启后仍生效
* 解释了 netfilter-persistent 的工作原理

这是最安全、最稳定的 CNIX 端口开放方案。

---

## 7. 附录：完整 iptables 脚本

```bash
# 允许本机
iptables -A INPUT -i lo -j ACCEPT

# 允许已建立连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 可选：允许 ping
iptables -A INPUT -p icmp -j ACCEPT

# SSH
iptables -A INPUT -p tcp -s 47.99.99.99 --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j DROP

# TCP 11780–11799
iptables -A INPUT -p tcp -s 47.99.99.99 --dport 11780:11799 -j ACCEPT
iptables -A INPUT -p tcp --dport 11780:11799 -j DROP

# UDP 11780–11799
iptables -A INPUT -p udp -s 47.99.99.99 --dport 11780:11799 -j ACCEPT
iptables -A INPUT -p udp --dport 11780:11799 -j DROP
```

