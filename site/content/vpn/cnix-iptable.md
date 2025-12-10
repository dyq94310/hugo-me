---
title: "CNIX 服务器安全开放 Socket 端口指南）"
date: 2025-11-21
---
# CNIX 服务器安全开放 Socket 端口指南

## 1. 背景说明
为了在阿里云前置机中部署 Docker，并提供访问 CNIX 服务器的 socket 服务，需要在 CNIX 上开放一组端口。但为了避免端口被扫描、滥用或遭受攻击，必须严格限制访问 IP。

本次方案采用 firewalld 实现精确白名单，只允许阿里云前置的出口 IP（**47.99.99.99**）访问指定端口，确保绝对安全。

firewalld 比 iptable更加简单

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

## 3. firewalld 规则配置（允许阿里云前置访问）

### 3.1 基础规则
创建白名单集合：
```bash
firewall-cmd --permanent --new-ipset=whitelist --type=hash:ip
firewall-cmd --permanent --ipset=whitelist --add-entry=47.99.99.99
firewall-cmd --permanent --ipset=whitelist --add-entry=42.184.184.184
```

使用集合配置规则（代替上面的单 IP 规则）：
```bash
# 允许白名单里的所有人访问 SSH
firewall-cmd --permanent --add-rich-rule='rule source ipset="whitelist" port port="22" protocol="tcp" accept'

# 允许白名单里的所有人访问端口范围
firewall-cmd --permanent --add-rich-rule='rule source ipset="whitelist" port port="11780-11799" protocol="tcp" accept'
firewall-cmd --permanent --add-rich-rule='rule source ipset="whitelist" port port="11780-11799" protocol="udp" accept'

firewall-cmd --reload
```


这样以后加 IP，只需要运行 ``firewall-cmd --permanent --ipset=whitelist --add-entry=新IP ``然后 reload 即可。

---

## 4. 总结

本文实现了：

* 为阿里云前置开放 socket 端口
* 防止端口扫描、攻击、滥用
* 持久化规则，确保重启后仍生效

这是最安全、最稳定的 CNIX 端口开放方案。

---
