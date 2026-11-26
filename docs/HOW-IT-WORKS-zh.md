# 原理与逆向笔记

> 本文记录「超境画质」到底是怎么被系统开关的，以及本模块每一条命令的依据。
> 所有结论都来自真机（nubia NX741J / NebulaAIOS 2.0 / Android 16）实测，不是猜测。

---

## 1. 执行链在哪里

跑超分/插帧的**不是任何一个 APK**：

- 14 个游戏套件 APK 里没有任何超分 native 库；
- 没有 `DexClassLoader` 动态加载插件（只有 `PathClassLoader`），插件是内置类；
- 客户端（`cn.nubia.gameassist` / `cn.nubia.gamelauncher`）只负责 UI、开关、以及写一条档位记录。

真正执行的是：

```
应用 → SurfaceFlinger → vendor.gppservice（Binder: vendor.gppservice）
      → GPP/VPP 会话（HexlpComponent） → NPU（nsp-session: gfrc_plus）
      → 输出到显示
```

`/system/bin/gppservice` 是 **ELF64 AArch64** 原生守护进程，开机由 init 拉起；相关库都在 `/system/lib64`：

```
libgppextension.so  libgpppreprocessing.so  libgpptxr.so
libgpphexlpsession.so  libgppvppgfrcplussession.so
```

它自己不保存名单，**每次启动时读 `/system/etc/gpp_app_list`**（日志：`loadWhitelistApps: read app name: <pkg>`）。

---

## 2. 名单文件

`/system/etc/gpp_app_list`（原厂 7703 字节 / 254 行，其中约 240 条有效）：

```
#! file: gpp_app_list
# The original game resolution must be smaller than 1080 x 2400
#package,upscale(values:0, 1, 2),interp(values:0, 1)
com.tencent.tmgp.sgame,1,1
com.kurogame.mingchao,1,1
com.tencent.jkchess,0,1
com.miHoYo.Yuanshen,1,1
...
```

三列：包名、超分档（0 原始 / 1 高 / 2 超高）、插帧（0/1）。

改这个文件**不能**直接写 —— `/`、`/system_ext`、`/vendor` 都是 `erofs` 只读。所以模块用 `mount --bind` 覆盖单文件，SELinux 标签必须保持 `u:object_r:system_file:s0`，否则 daemon 读不到。

换掉之后要让 daemon 重新读：`kill $(pidof gppservice)`，init 会自动拉起。

---

## 3. 谁是真正的「支持名单」

只把包名塞进 `gpp_app_list` **不够** —— 游戏内面板还是不会出现。因为 system_server 里还有一层：

```
Cube_PerformanceController: getGfrcCapByPkg pkgName=<pkg> cap=<N>
```

- `cap = 0` → 不支持，面板不出现，强写档位也会在 300ms 后被回退；
- `cap = 11` / `22` → 支持，面板出现。

`cap` 由 `system_server` 里的 Cube 组件算出来，数据源是 `/system_ext/etc/cube/`（**加密的**：16 字节对齐、熵 7.98+、固定 IV 的块加密、各个二进制里都找不到 AES/decrypt 字符串，静态解不开）。所以「名单」其实有两层：`gpp_app_list`（daemon 的开关） + Cube 的 cap（面板的开关）。

### 绕过 cap 的开关

试过改包名清单、改分辨率、伪装 `reqFeatures`，都不行。真正有效的是一个现成的系统属性：

```sh
resetprop vendor.gpp.allgame.enable 1
```

开启后：

```
Cube_PerformanceController: getGfrcCapByPkg pkgName=com.fantablade.icey cap=22
GameAssist: parseSupportFunction superResolutionSupport = 2, interpolationSupport = 2
GPP-Service: createSession: package com.fantablade.icey is supported 1 / 2
```

**该属性在每次查询时读取**，不用重启 daemon。非游戏应用（比如设置）不会触发 GPP 会话，所以不会拖累日常应用。

---

## 4. `game_gfrc_mode` 的三位

`Settings.Global game_gfrc_mode`，格式：

```
包名+XYZ,包名+XYZ,...
```

每位实测含义（用 `settings put` 逐位改，看 `Cube_GfrcModeCtrl` 的 `GfrcModeSettings` 与 `reportGfrcInterpToRefreshRate`）：

| 值 | mGfrc | mInterp | mUpscale | 是否真插帧 |
|---|---|---|---|---|
| `010` | 0 | 1 | 0 | ❌ |
| `011` | 1 | 1 | 0 | ✅ |
| `001` | 1 | 0 | 0 | ❌ |
| `100` | 0 | 0 | 1 | ❌ |
| `110` | 0 | 1 | 1 | ❌ |
| `101` | 1 | 0 | 1 | ❌ |
| `111` | 1 | 1 | 1 | ✅ |

所以：

- **第 1 位** = 超分档（0/1/2）
- **第 2 位** = 插帧意愿
- **第 3 位** = gfrc 通道（**必须为 1**，否则 interp 不生效）

GameAssist 自己的逐游戏配置（`cn.nubia.plugin.superresolution.SuperResolutionTypeDataManager` 的 `SuperResolutionTypeItemData{packageName, imageQualityItem, frameRateItem}`）就是往这里写：鸣潮 `high + frameRate_super` → `+111`；王者 `origin + origin` → `+000`；赛马娘 `origin + frameRate_super` → `+010`。

生效时的旁证：

```
vendor.gpp.gfrc.interp.rate = 1
vendor.gpp.frc.enable = 0x22        # 0x21 = 关
dumpsys display → renderFrameRate 120.00001
gppservice: Output Real FPS 119.34
```

---

## 5. 超分档位与尺寸限制

从 `/vendor/lib64/rfs/dsp/libvpp_gfrc_networks.so` 的模型名可以反推：

| 档 | 模型族 | 内建输入尺寸 |
|---|---|---|
| 1.5× | `LowerPower_1p5x_LumaNet_B2_n32` | 720×1600、864×1920、968×2148、1080×2400、1164×2560（及横屏翻转） |
| 2× | `AIS_2x_AA_plus_StrongerTextureV4` | 640×1424、720×1600、804×1788、864×1920（及横屏翻转） |

限制：

- 输入必须 **< 1080×2400**，否则不放大（只保留插帧）；
- 输出硬上限 **1728×3840**，超过会回退到 `FRC 1x + AIS 1x`；
- 因此游戏跑满屏幕原生分辨率时，超分「看不到效果」是正常的。

---

## 6. 日志速查

```sh
# daemon 读名单
logcat -s GPP-Service | grep loadWhitelistApps

# 会话建立/销毁
logcat -s GPP-Service | grep -E "createSession|destroySession|Get layer name|supported"

# 档位下发与真实状态
logcat -s Cube_GfrcModeCtrl | grep -E "GfrcModeSettings|Enanble|reportGfrcInterp"
logcat -s Cube_PerformanceController | grep getGfrcCapByPkg

# 处理耗时
logcat -s GPP-GPPPreProcessing-Vulkan | grep RGBToNV12
```

---

## 7. 为什么模块不改 /system

- 分区是 `erofs` 只读，没有 overlayfs 写入点；
- KernelSU 的模块机制本身就是「开机 magic mount」，把 `模块目录/system/**` 叠到 `/system/**`，天然满足「不改分区、可卸载」；
- 运行时再叠一层 `mount --bind` 只是为了「改完立刻生效」，重启后由模块 overlay 接管。

---

## 8. 踩过的坑

- **`ksu.exec` 只返回 stdout 最后一行** → WebUI 里所有输出都要压成单行（`base64 -w0`），文件分块 `dd` 读。
- **SELinux 标签**：`cp` 出来的文件可能变成 `shell_data_file`，daemon/守护读不到 → 统一 `chcon u:object_r:ksu_file:s0`。
- **不要整表覆盖 `game_gfrc_mode`**：系统自己也往里写，覆盖会把别人的条目删掉；只做「合并」。
- **`state.txt` 里的 `\r`**：Windows 侧编辑过就会带 CR，`awk -F, '$4=="1"'` 会全部匹配失败 → 先 `tr -d '\r'`。
- **`monkey` 会留下 `persist.sys.monkey=true`**（与本模块无关，但调试时会遇到）：之后所有应用冷启动都不显示 splash，`resetprop persist.sys.monkey false` 恢复。
