# HealthBridge

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[English](README.md) · **中文**

把 Apple Watch 的数据从 iPhone 里拿出来，每天自动、加密地存到你自己的 Mac 上，中间不经过任何云。

> **让 AI 帮你装：**「按照 https://github.com/runesleo/healthbridge/blob/main/install.md 的官方说明，在这台电脑上安装 HealthBridge。」

## 你能得到什么

- **每天自动导出**：步数、活动消耗、锻炼分钟、心率（平均/最高）、静息心率，以及每一次训练的类型、时长、消耗、心率和距离
- **完整历史**：点一下就把「健康」里所有历史补传过来，一直回到你有记录的第一天
- **不用管它**：手表同步了新训练，iOS 会在后台叫醒 App 自动发；Mac 按天存成 JSON
- **一份能直接看的档案**：Markdown 文件，按年、按月汇总，外加每次训练的明细，中英文可选
- **隐私优先**：手机上先加密，只发到家里 Wi-Fi 下你自己的 Mac，不经过任何第三方服务器

## 它是怎么工作的

```text
Apple Watch ──同步──▶ iPhone「健康」──▶ HealthBridge App ──AES-256-GCM──▶ 家里 Wi-Fi ──▶ Mac 接收端
                                                                                        ├─ data/2026-10-22.json …
                                                                                        └─ archive.md
```

苹果不允许任何东西通过网络直接读手表数据。唯一的出口是 iPhone 上的「健康」，而且只有装在这台手机上、你授权过的 App 能读。HealthBridge 就是这个小 App，再加上 Mac 上的一个接收端。

**一天的输出**（`data/2026-10-22.json`，数字为示意）：

```json
{
  "date": "2026-10-22",
  "steps": 8000,
  "active_kcal": 600.0,
  "exercise_min": 60,
  "heart_rate_avg": 75,
  "heart_rate_max": 150,
  "resting_hr_avg": 55,
  "workouts": [{ "type": 48, "minutes": 60.0, "active_kcal": 400, "hr_avg": 120, "hr_max": 150, "km": 3.0 }]
}
```

## 需要什么

- 一台有「健康」数据的 iPhone（心率和训练需要 Apple Watch）
- 同一 Wi-Fi 下的一台 Mac：装好 **Xcode**、`xcodegen`（`brew install xcodegen`）、Python 3.9+ 和 `cryptography`
- 在 Xcode 里登录 Apple ID。免费账号能用，但每 7 天要重装一次；付费开发者账号（99 美元/年）一次签一年
- **隐私：** 数据不出家里的网络。接收端只收用你的密钥加密过的数据；密钥存在 `~/.config/healthbridge/config.json`（权限 600）和不进 git 的 `ios/HealthBridge/Config.swift`

## 快速开始

```bash
git clone https://github.com/runesleo/healthbridge.git
cd healthbridge
python3 -m pip install --user cryptography
python3 mac/healthbridge.py init --team 你的TeamID   # 生成密钥、配置和 iOS 的 Config.swift
python3 mac/healthbridge.py serve                    # 保持运行（开机自启见 docs/healthbridge.receiver.plist）
cd ios && xcodegen generate && open HealthBridge.xcodeproj
```

在 Xcode 里选你的 iPhone，点运行。手机上：设置 → 通用 → VPN 与设备管理 → 信任你的开发者账号；打开 HealthBridge → **授权健康数据** → **立即同步**（允许本地网络），再点一次 **补传全部历史**。

随时自检：

```bash
python3 mac/healthbridge.py doctor          # 或加 --json
```

## 安全设计

- 数据用 AES-256-GCM 加密，钥匙是一个 256 位随机密钥的 SHA-256，密钥本身从不在网上传
- 解不开的、或 10 分钟前封装的数据包，一律 401 拒收
- 重放的旧包覆盖不了新数据：每一天只保留 `sent_at` 最新的那份
- 写入前先校验所有日期（`YYYY-MM-DD`），单次请求上限 4 MB，卡住不发数据的连接 15 秒断开；数据文件权限为 600
- 手机只在完全连不上 `.local` 名字时才改用 Mac 的局域网 IP，收到任何 HTTP 回应后都不会改发别处
- 局域网上走明文 HTTP；保密和防篡改靠的是加密封装

## 已验证

| 场景 | 环境 | 结果 |
|------|------|------|
| 每日同步 + 完整补传 | iPhone 15 Pro Max（iOS 26）、MacBook（macOS 26.5）、Xcode 26.5、个人团队（免费 Apple ID） | 一次补传收到约 10 年历史，档案生成成功 |
| 接收端拒收篡改 | 本机测试 | 正确 200 · 明文 401 · 钥匙错 401 · 过期 401 · 日期非法 400 |

## 已知限制（v0.1）

- iPhone App 需要你自己用 Xcode 编译安装，没有 App Store 版本
- 免费 Apple ID 的签名 7 天过期
- 只有手机和 Mac 在同一 Wi-Fi 时才会同步；不在家的日子会补上（每次同步重发最近 3 天）
- 后台什么时候跑由 iOS 决定（最多每小时一次）；打开 App 一定会同步
- 手机开着 VPN / 代理 App 的话，要让局域网流量走直连
- 训练类型按苹果的 `HKWorkoutActivityType` 编号对照；不认识的显示为 `#编号`

## 路线图

- [ ] 睡眠、HRV、最大摄氧量、血氧
- [ ] 可选 HTTPS（自签证书 + 固定指纹）
- [ ] 档案里加 CSV 导出和简单图表

## 关于作者

*Leo（[@runes_leo](https://x.com/runes_leo)）— AI × Crypto 独立构建者。在 [Polymarket](https://polymarket.com/?via=runes-leo&r=runesleo&utm_source=github&utm_content=healthbridge) 做量化，用 Claude Code 和 Codex 搭数据与内容管线。*

*[leolabs.me](https://leolabs.me) — 写作 · 社群 · 开源工具 · 独立项目*

*[X 订阅](https://x.com/runes_leo/creator-subscriptions/subscribe) — 付费内容周刊*

*Learn in public, Build in public.*

## 许可证

MIT，见 [LICENSE](LICENSE)。
