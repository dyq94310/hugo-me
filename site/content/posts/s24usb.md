---
title: "从 20MB/s 到 185MB/s：一次 Linux 下 USB 传输瓶颈排查实录"
date: 2025-11-11
---

# 🚀 从 20MB/s 到 185MB/s：一次 Linux 下 USB 传输瓶颈排查实录

## 🧩 背景
由于我最近需要传输大量照片到我的手机，确认手机是支持USB3.2的，xps也是

设备环境：

- 💻 **电脑**：Dell XPS 9370（Thunderbolt 3 / USB-C 接口）  
- 🐧 **系统**：Debian 12  
- 📱 **手机**：Samsung Galaxy S24  
- ❌ **问题**：通过 USB 传照片仅有约 20 MB/s 速度  

---

## 一、初步排查：确认 USB 接口与识别情况

首先查看系统识别的 USB 设备：

```bash
lsusb
````

输出（节选）：

```
Bus 001 Device 010: ID 04e8:6860 Samsung Electronics Co., Ltd Galaxy series, misc. (MTP mode)
```

查看内核日志：

```bash
sudo dmesg | tail -n 20
```

结果：

```
usb 1-1: new high-speed USB device number 10 using xhci_hcd
```

> “high-speed” 表示 **USB 2.0 模式（480 Mbps）**
> 对应理论速率上限 60 MB/s，因此 20 MB/s 的传输速率是正常的 USB2.0 表现。

---

## 二、分析：为什么手机只跑在 USB 2.0 模式？

### 1️⃣ 线缆问题

很多快充线（哪怕 PD 100W）**只支持 USB 2.0 数据**，因为：

| 通道类型             | 导线组成                | 作用          |
| ---------------- | ------------------- | ----------- |
| **PD 电力通道**      | VBUS、GND、CC1/CC2    | 供电（最高 240W） |
| **USB 3.x 数据通道** | TX1±、RX1±、TX2±、RX2± | 高速数据传输      |

PD 只要求能供电，不要求传数据，因此很多线省掉了高速差分线。

> ✅ 结果：快充没问题，但传输速率被锁在 USB 2.0。

---

### 2️⃣ 接口问题

XPS 9370 有多个 Type-C 接口，不同端口对应不同的 **root hub**。
部分接口挂在 USB 2.0 Hub 上，因此要测试每个端口。

---

### 3️⃣ 手机设置问题

三星默认 USB 模式通常为 “仅充电”，需要切换为：

* **Use USB for → Transferring files / Android Auto**
* **USB controlled by → Connected device**

---

## 三、更换线缆 + 调整模式后再次检测

执行：

```bash
lsusb -t
```

输出：

```
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/6p, 5000M
    |__ Port 1: Dev 2, If 0, Class=Imaging, Driver=usbfs, 5000M
```

> ✅ “5000M” 表示已进入 **USB 3.0 SuperSpeed 模式（5 Gbps）**

理论上最高 625 MB/s。

---

## 四、仍然只有 30 MB/s？原来是 MTP 协议瓶颈

MTP（Media Transfer Protocol）是 Android 默认文件传输协议：

* 每个文件需 metadata 协商；
* 数据在用户态/内核态频繁切换；
* 单线程顺序传输。

> ⚠️ 即便物理层是 USB3.0，MTP 实际速率仍仅 20–40 MB/s。

---

## 五、绕过 MTP：改用 ADB Bulk 传输

### 1️⃣ 启用 ADB 调试模式

手机端：

> 开发者选项 → 开启 **USB 调试**

PC 端：

```bash
adb devices
```

第一次执行可能出现：

```
unauthorized
```

手机上会弹出提示框：

> “是否允许此计算机调试？”

勾选“始终允许”，再执行：

```bash
adb kill-server
adb start-server
adb devices
```

成功后输出：

```
RFCXC0B4D9P    device
```

---

### 2️⃣ 实际文件传输命令

创建目标目录：

```bash
adb shell "mkdir -p /sdcard/DCIM/20251111"
```

传输文件：

```bash
adb push /home/dyq/Downloads/test.mkv /sdcard/DCIM/20251111/
```

输出：

```
1 file pushed, 0 skipped. 185.6 MB/s (2080135658 bytes in 10.689s)
```

> 🚀 实测速率 185 MB/s，完全释放 USB 3.0 链路带宽。

---

## 六、协议科普：USB、Thunderbolt、PD 的关系

| 协议                             | 管理机构          | 最大速率              | 特点                     |
| ------------------------------ | ------------- | ----------------- | ---------------------- |
| **USB (Universal Serial Bus)** | USB-IF        | USB4 可达 80 Gbps   | 主流通用标准                 |
| **Thunderbolt (雷电)**           | Intel / Apple | TB3/TB4 = 40 Gbps | 多协议复用（PCIe + DP + USB） |
| **PD (Power Delivery)**        | USB-IF        | 最高 240W           | 仅负责供电，与数据通道独立          |

### 📚 关键区别

* **USB = 数据协议**
* **PD = 供电协议**
* **Thunderbolt = 复合协议（兼容 USB + PCIe + DP）**

> 一根 PD 100W 线不一定支持高速数据，
> 而 Thunderbolt 3 线一定支持至少 40 Gbps 数据 + PD 供电。

---

## 七、Thunderbolt 与 USB 的融合

* **Thunderbolt 3 → 由 Intel 开发**
* **USB4 → 由 USB-IF 基于 Thunderbolt 3 开放规范制定**

换句话说：

> ✅ USB4 = 开放版 Thunderbolt 3
> ✅ Thunderbolt 4 = Intel 认证版 USB4

因此 M 系列 MacBook、XPS、ThinkPad 等现代设备的 Type-C 端口同时支持：

* USB3.2
* Thunderbolt 3/4
* USB4
* PD 快充
* DisplayPort Alt Mode

---

## 八、最终结果对比

| 层级   | 初始状态                 | 优化后状态            |
| ---- | -------------------- | ---------------- |
| 物理链路 | USB 2.0 (480 Mbps)   | USB 3.0 (5 Gbps) |
| 协议   | MTP                  | ADB Bulk         |
| 实际速度 | 20 MB/s              | 185 MB/s         |
| 核心改动 | 换线 + 调整手机模式 + ADB 调试 | 🚀 性能恢复正常        |

---

## 🧠 总结

* ⚡ PD 供电 ≠ 高速数据
* ⚡ USB 3.x / Thunderbolt / USB4 正在融合
* ⚡ MTP 是性能瓶颈，ADB 才能充分利用 USB3 带宽

常用命令：

```bash
lsusb -t
dmesg | tail -n 20
adb devices
adb push /path/file /sdcard/path/
```

---

📘 **最终感想**

USBC的确是一个开放的协议，能插，但不一定能用。哈哈哈哈。

