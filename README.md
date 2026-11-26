# 超境画质 PRO · SuperRes PRO

> 让任意游戏在 nubia / 红魔设备上出现系统原生的「超境画质」面板，并解锁最高档位（超分 + 插帧 + 最高档位）。
> A KernelSU WebUI module that unlocks the stock **Super Resolution / Frame Interpolation** panel for any game on ZTE/nubia ROMs.

[![License: CC0-1.0](https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg)](LICENSE)
![Platform](https://img.shields.io/badge/Platform-Android%2014%2B-green)
![Root](https://img.shields.io/badge/Root-KernelSU-blue)

---
## 请注意！

此模块由 *AI* 逆向系统开发，并由 *AI* 完成100%的代码。
发布前已经过实机测试，但仍然可能会出现尚未发现的问题。

**！！！！请谨慎安装！！！！**

---

## 兼容性

- **已验证**：nubia NX741J（Z80 Ultra）/ NebulaAIOS 2.0 / Android 16
- **Root**：需要 KernelSU（或带 WebUI 的 KSU 分支，如 SukiSU / KernelSU Next）
- **未验证，但理论可行的机型**：红魔 11 系（不包括11s）
- **未知可用性的机型**：其它 努比亚/红魔系列 支持【超境画质】的机型

---

## 安装

1. 下载 Release 里的 `gpp_extend_vX.Y.zip`
2. KernelSU 管理器 → **模块** → **从本地安装**
3. 安装完成后**重启一次**
4. 回到模块列表，点模块卡片上的 **「打开」**，进入 WebUI

> 不想重启也行：首次进 WebUI 点一次「保存并应用」，bind mount 立即生效；模块的 overlay 只在开机时挂载，作用是「重启后保持」。

---

## 使用

**快速启动：**

1. 选择面板优先，开启全局支持
2. 保存并应用
3. 重启游戏
4. 性能控制面板启用【超境画质】

WebUI 顶部状态行：

| 显示 | 含义 |
|---|---|
| `服务 运行中 (pid)` | gppservice 在跑 |
| `注入 已生效` | `/system/etc/gpp_app_list` 已被模块覆盖 |
| `基础 N` | 原厂名单条目数（通常 240） |
| `已选 N` | 你勾选的数量 |
| `插帧 工作中/未激活` | `vendor.gpp.gfrc.interp.rate` 是否 ≥ 1（1 = 一档，2 = 二档） |

操作三步：**勾游戏 → 选档位 → 保存并应用**。

完整说明见 [docs/USAGE-zh.md](docs/USAGE-zh.md)。

---

## 参数速查

| 超分档 | 面板显示 | 实际行为 |
|---|---|---|
| `0` | 原始 | 不超分 |
| `1` | 高 | 1.5× 超分（`LowerPower_1p5x_LumaNet` 族） |
| `2` | 超高 | 2× 超分（`AIS_2x_AA_plus_StrongerTextureV4` 族） |

| 插帧档 | 面板显示 | 倍率 | 30 fps 源 | 60 fps 源 |
|---|---|---|---|---|
| `0` | 原始 | 不插帧 | 30 | 60 |
| `1` | 高帧率 | **2×** | 60–61（实测） | 120（实测） |
| `2` | 超高帧率 | **3×** | 86–87（实测，目标 90） | 144–145（实测，被 144 Hz 上限截断） |

> - **30 fps 源**（赛马娘）：一档 `target=60 / 实测 61`（屏幕 120 Hz）；二档 `target=90 / 实测 86–87`（屏幕 144 Hz）。
> - **60 fps 源**（战双帕弥什）：一档 `target=120 / 实测 120`（屏幕 120 Hz）；二档 3× 本该 180，但 `target` 被压回 **144**、实测 144–145（屏幕 144 Hz）——即到达面板上限后不再往上翻。
>
> 所以倍率是 2× / 3×，但最终输出会被「屏幕刷新率上限」和「实际渲染能力」两个因素削掉几帧。

**不是所有游戏都适合 *超高* 档位插帧。实测一些游戏虽然能插到144fps但1%low帧却大幅下降，观感上反而比原始更卡**

**30帧这种极低原始帧的游戏不建议插帧。你插的再高1%low帧都是上不去的，观感相似功耗和发热还会上升**

物理限制：

- 超分要求游戏**原始渲染分辨率 < 1080×2400**，否则不放大、只保留插帧
- 输出硬上限 **1728×3840**
- 游戏本身跑满屏幕原生分辨率（例如 1216×2688）时，超分看不到效果是正常的 —— 把游戏内画质调低反而更容易触发

---

## 目录结构

```
├── module.prop                 # 模块信息（id/name/version/description）
├── apply.sh                    # 合并名单 + bind mount + 重启 gppservice + 同步 allgame
├── mode.sh                     # 合并写 game_gfrc_mode（仅强制写入模式）
├── service.sh                  # 常驻守护：单实例锁 + allgame 维持 + 可选 mode.sh
├── ctl.sh                      # 命令行：list / put / reset / status
├── uninstall.sh                # 卸载时 umount 并清理
├── system/etc/gpp_app_list     # 原厂名单副本（模块 overlay 用）
├── webroot/index.html          # WebUI
├── docs/
│   ├── USAGE-zh.md             # 使用说明（会打进 zip）
│   └── HOW-IT-WORKS-zh.md      # 原理与逆向笔记
└── .github/workflows/build.yml # CI：打 zip 并上传 artifact
```

运行时状态都在 `/data/adb/gpp_extend/`：`base_list`（原厂快照）、`state.txt`（你的勾选）、`allgame`、`force`。

---

## 常见问题

见 [docs/USAGE-zh.md 第 6 节](docs/USAGE-zh.md)。高频的几条：

- **勾了但游戏里没有面板** → 打开「全局支持」再保存，杀掉游戏重进
- **面板出现但档位是灰的** → 游戏渲染分辨率过高，或该档位底层不支持；可试「强制写入」
- **插帧看不出变化** → 先看 `interp.rate`（1 或 2 才是在跑），再看游戏自身帧率是否明显低于屏幕刷新率的一半（2× 插帧才有发挥空间）
- **变卡/发热** → 超分和插帧是显示级管线，所有窗口都吃开销；不用时把「全局支持」关掉

---

## 原理与逆向笔记

见 [docs/HOW-IT-WORKS-zh.md](docs/HOW-IT-WORKS-zh.md)。

---

## 免责声明

- 本项目是**社区逆向**产物，与中兴 / 努比亚 / 红魔官方**无关**，未获其授权或背书。
- 修改系统行为存在风险：可能导致耗电增加、发热、显示异常；OTA 后可能需要重新同步。
- 使用本模块造成的任何后果（包括但不限于设备无法开机、数据丢失、显示异常、系统不稳定、OTA 后功能失效、游戏账号被处罚等）由使用者自行承担；请在了解上述风险后自行决定是否使用。

---

## License

本项目全部内容（脚本、WebUI、文档）以 **CC0 1.0 Universal** 释出，即**放弃著作权、进入公有领域**，可任意使用、修改、商用，无需署名。

详见 [LICENSE](LICENSE)。
