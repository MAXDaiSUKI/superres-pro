# 超境画质 PRO（gpp_extend）使用说明

> 版本 **v1.4** ｜ 适用：nubia / RedMagic 机型（带 Qualcomm GPP 超分/插帧能力的 ROM，如 NX741J / NebulaAIOS 2.0） ｜ 需要 **KernelSU**（或支持 WebUI 的 KSU 分支）

---

## 1. 这个模块做什么

系统里有一套由厂商 **GPP** 组件（`gppservice`，缩写全称未公开）提供的「超境画质」能力：超分辨率（upscale）+ 插帧（interp）。它是否对某个游戏生效，由三层控制：

| 层 | 位置 | 作用 |
|---|---|---|
| ① 设备能力 | `ro.vendor.feature.zte_feature_gfrc=true` | ROM 级开关，改不了 |
| ② 游戏名单 | `/system/etc/gpp_app_list`（格式 `包名,超分档,插帧`） | 决定「这个游戏能不能用」 |
| ③ 逐游戏档位 | `Settings.Global game_gfrc_mode`（格式 `包名+超分,插帧,gfrc`） | 记录具体档位 |

默认只有几十款游戏在名单里。本模块做的事：

1. **不改 /system 分区**，用 bind mount 把「你勾选的名单」覆盖到 `/system/etc/gpp_app_list`；
2. 打开 **「全局支持」**（`vendor.gpp.allgame.enable=1`）后，Cube 对**任意游戏**都返回非 0 的 cap，游戏内就会出现原生「超境画质」面板；
3. 面板里选「超分/插帧」后，系统会自己把档位写进 `game_gfrc_mode` —— 模块**不需要**再干预档位（默认「面板优先」模式）。

一句话：**勾上游戏 → 进游戏 → 打开悬浮面板里的「超境画质」→ 自己选档位。**

---

## 2. 安装

1. 把 `gpp_extend_v1.4.zip` 传到手机；
2. 打开 **KernelSU 管理器 → 模块 → 从本地安装**，选择该 zip；
3. 安装完成后**重启**（或软重启）一次；
4. 回到模块列表，`超境画质 PRO` 卡片上会出现 **「打开」** 按钮，点它进入 WebUI。

> 不重启也能用：首次进入 WebUI 点一次「保存并应用」即可立即生效（内部会 bind mount 并重启 gppservice 读取新名单）。重启只是让模块的 overlay 在开机时自动接管。

---

## 3. WebUI 界面

顶部一排状态：

| 显示 | 含义 |
|---|---|
| `服务 运行中 (pid)` | gppservice 存活，绿色为正常 |
| `注入 已生效` | `/system/etc/gpp_app_list` 已被模块覆盖 |
| `基础 N` | 原厂名单条数（通常是 240） |
| `已选 N` | 你勾选的条数 |
| `插帧 工作中/未激活` | 读取 `vendor.gpp.gfrc.interp.rate`，1 = 插帧正在跑 |

三个按钮：

- **搜索包名**：过滤列表；
- **+ 当前前台**：把此刻前台的应用加入列表（方便加游戏）；
- **重载**：重新读取设备状态。

列表每一项：

- 左侧包名（`默认 x/y` 表示原厂名单里的档位，`已装` 表示是已安装应用）；
- **超分档** 下拉：`超分关 / 超分中 / 超分高`（即 0 / 1 / 2）；
- **插帧** 下拉：`插帧开 / 插帧关`；
- 右侧开关：是否启用（关掉不会删除原厂条目，只是不再强制）。

底部两个全局开关：

- **全局支持：开/关** —— 对应 `vendor.gpp.allgame.enable`。**想让系统原本不支持的游戏出现面板，就打开它**；
- **档位：面板优先 / 强制写入** ——
  - `面板优先`（默认）：模块只加名单，档位完全交给游戏内面板，**推荐**；
  - `强制写入`：模块每 15 秒把你在列表里选的档位写进 `game_gfrc_mode`，用于面板里没有该档位、但底层能跑的情况。

改完后点 **「保存并应用」**：生成新名单 → bind mount → 重启 gppservice → 同步全局支持属性 → （强制写入模式下）同步档位。

---

## 4. 参数说明

### 超分档（`gpp_app_list` 第 2 列 / `game_gfrc_mode` 第 1 位）

| 值 | 面板显示 | 实际行为 |
|---|---|---|
| `0` | 原始 | 不做超分，只走插帧 |
| `1` | 高 | 1.5× 超分（模型族 `LowerPower_1p5x_LumaNet`） |
| `2` | 超高 | 2× 超分（模型族 `AIS_2x_AA_plus_StrongerTextureV4`） |

### 插帧（第 3 列 / 第 2 位）

`1` = 开，`0` = 关。系统只在 **第 2 位与第 3 位（gfrc 位）都为 1** 时才真正上报插帧，所以脚本自动把 gfrc 位补成 `1`（例如你选「高 + 插帧开」→ 写入 `包名+111`）。

### 物理限制

- 超分要求**游戏原始渲染分辨率小于 1080×2400**，否则不放大，只会保留插帧；
- 输出分辨率硬上限 **1728×3840**，超过会回退到 `FRC 1x + AIS 1x`；
- 2× 模型的内建输入尺寸最小约 640×1424、最大约 864×1920（横屏对应翻转），所以**游戏本身跑满 1216×2688 时，超分看不到效果是正常的**，把游戏内画质调低反而更容易触发超分。

---

## 5. 生效验证（可选）

```sh
# 1) 名单里是否有这个游戏（4 列里的第 2、3 列就是超分/插帧）
cat /system/etc/gpp_app_list | grep com.tencent.tmgp.sgame

# 2) 系统有没有建立 GPP 会话（启动游戏后）
logcat -s GPP-Service | grep -E "createSession|Get layer name"

# 3) 插帧是否在跑：1 = 在跑
getprop vendor.gpp.gfrc.interp.rate
getprop vendor.gpp.frc.enable      # 0x22 = 插帧通道已开

# 4) 档位是否下发
logcat -s Cube_GfrcModeCtrl | grep -E "GfrcModeSettings|Enanble"
```

---

## 6. 常见问题

**Q1：勾了游戏，但游戏里没有「超境画质」面板？**
打开顶部 **「全局支持」** 开关再保存；然后杀掉游戏重进。该项让系统对任意包名都返回可用 cap。

**Q2：面板出现了，但档位是灰的 / 选了没反应？**
说明该游戏按全分辨率渲染，或 Cube 的第二道校验没过。可以：把游戏内画质调低（分辨率 < 1080×2400）后再试；或改用「强制写入」模式。

**Q3：插帧开了但帧数没变化？**
- 确认 `getprop vendor.gpp.gfrc.interp.rate` = 1；
- 面板只有 60/90/120/144Hz 档，插帧是在低帧基础上翻倍（例如 60 → 120），本来就跑满 144 的游戏看不出收益；
- 王者这类默认锁 60FPS 的游戏需要先开「高帧率」。

**Q4：开了以后感觉变卡、发热？**
超分/插帧是**显示级**管线（SurfaceFlinger → gppservice → GPP/VPP），一旦激活，所有窗口都吃这份开销。不用时把「全局支持」关掉，或在面板里选「原始/关」。软重启可以立刻复位所有显示状态。

**Q5：系统 OTA 升级后名单不对了？**
`/data/adb/gpp_extend/base_list` 是第一次运行时的快照。OTA 后删除它，再在 WebUI 点一次「保存并应用」即可重新抓取新原厂名单：

```sh
rm -f /data/adb/gpp_extend/base_list
```

**Q6：软重启和重启有什么区别？**
软重启只重启 system_server，bind mount 保留（模块继续生效）；完整重启时由 KSU 的 overlay 在开机阶段挂载模块自带的名单文件，同样生效。

**Q7：会触发反作弊吗？**
模块只改系统名单文件和属性，不注入游戏进程；但超分/插帧本身属于渲染层改动，理论上存在被检测的可能，请自行评估。

---

## 7. 卸载

在 KernelSU 管理器里直接卸载模块即可，`uninstall.sh` 会自动：

1. `umount /system/etc/gpp_app_list`；
2. 重启 `gppservice`；
3. 删除 `/data/adb/gpp_extend`（状态与快照）。

卸载后系统名单会回到原厂文件，无需手动修系统分区。

---

## 8. 命令行（可选）

```sh
sh /data/adb/modules/gpp_extend/ctl.sh list     # 输出原厂名单 + 当前状态
sh /data/adb/modules/gpp_extend/ctl.sh reset    # 清空勾选
sh /data/adb/modules/gpp_extend/ctl.sh status   # 挂载 / 插帧属性 / gppservice pid
sh /data/adb/modules/gpp_extend/apply.sh        # 手动重新应用
```

---

## 9. 文件结构

```
gpp_extend/
├── module.prop                     # 模块信息（v1.4）
├── apply.sh                        # 生成名单 + bind mount + 重启 gppservice + 同步属性
├── mode.sh                         # 合并写 game_gfrc_mode（面板优先模式下直接跳过）
├── service.sh                      # 开机守护：单实例锁，空闲 60 秒一轮，仅强制写入模式才跑 mode.sh
├── ctl.sh                          # 命令行辅助
├── uninstall.sh                    # 卸载还原
├── system/etc/gpp_app_list         # 模块自带的名单（开机 overlay 用）
└── webroot/index.html              # WebUI 界面
```

运行时数据在 `/data/adb/gpp_extend/`：`base_list`（原厂快照）、`state.txt`（你的勾选）、`allgame`、`force`（两个开关）。

---

## 10. 资源占用（v1.3）

模块只有一个常驻 shell 循环（`service.sh`），没有 native 进程：

| 项目 | v1.2 | v1.3 |
|---|---|---|
| 常驻实例 | 可能因重复激活累积多份 | **单实例锁**，永远 1 份 |
| 空闲 CPU | 每 8 秒跑一次 mode.sh，约 **1.6% 单核** | 面板优先模式下 60 秒一轮、**实测 0.0%** |
| 内存（PSS） | 约 0.41 MB/份 | 0.4 MB |
| 磁盘 | 模块 66 KB + 状态 16 KB | 同左 |

> 强制写入模式下会每 15 秒跑一次 `mode.sh`（约 1.5% 单核），这是为了对抗 GameAssist 覆写档位，属于预期开销；不用强制模式就不会产生。

---

## 11. 版本记录

| 版本 | 变化 |
|---|---|
| v1.0 | 初版：名单勾选 + bind mount + WebUI |
| v1.1 | 修复 `ksu.exec` 只返回最后一行导致的列表加载失败（改为单行 base64 分块读取）；`mode.sh` 改为逐条合并，不再整表覆盖 |
| v1.2 | 新增「全局支持」（`vendor.gpp.allgame.enable`）让任意游戏出现原厂面板；新增「面板优先 / 强制写入」开关，默认不再覆盖面板档位；修复未勾选会删掉原厂条目的问题 |
| v1.3 | `service.sh` 加单实例锁（消除重复激活导致的实例泄漏）；空闲轮询从 8 秒改为 60 秒，面板优先模式下完全不 fork；改用 shell 内建读取状态文件 |
| v1.4 | 模块更名「超境画质 PRO」，简介改为面向「游戏空间」的表述（模块 id `gpp_extend` 不变，升级不丢勾选） |

---

## 12. 免责声明

本模块通过修改系统级名单文件与属性实现功能，属于非官方修改。使用前请确认你能接受以下风险：OTA 后可能需要重新配置、部分游戏可能检测渲染层改动、超分/插帧会显著增加功耗与发热。作者不对任何封号、数据丢失或硬件问题负责。
