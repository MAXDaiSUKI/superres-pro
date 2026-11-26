#!/system/bin/sh
# SPDX-License-Identifier: CC0-1.0
# 把 WebUI 里勾选的游戏同步进 Settings.Global game_gfrc_mode
# 格式 "<pkg>+<超分档><插帧><gfrc>"，实测只有 第二位(插帧)=1 且 第三位(gfrc)=1
# 时 system_server 才上报 interp=1（logcat 标签 Cube_GfrcModeCtrl）。
#
# 重要：这一项是系统自己的游戏清单（GameAssist 的 SuperResolutionTypeDataManager
# 会按每个游戏的 imageQuality/frameRate 写 "",  "111" 等），所以本脚本只做“合并”，
# 绝不整表覆盖——否则会把系统给其它游戏写的条目一起删掉。

DATA=/data/adb/gpp_extend
STATE=$DATA/state.txt
SEL=$DATA/sel_pkgs.txt
CUR=$DATA/cur_mode.txt
TMP=$DATA/mode.new
[ -f "$STATE" ] || exit 0
mkdir -p "$DATA"

# 档位来源：默认「面板优先」——只加名单，不碰 game_gfrc_mode（把 force 写 1 才强制写入）
[ "$(tr -d '\r\n ' < $DATA/force 2>/dev/null)" = "1" ] || { echo "skip: panel-first"; exit 0; }

# 只取用户在 UI 里“打开”的项：pkg=超分档+插帧
tr -d '\r' < "$STATE" | awk -F, '!/^[ \t]*#/ && NF>=4 && $4=="1" { print $1 "=" $2 $3 }' | sort -u > "$SEL"
[ -s "$SEL" ] || exit 0

settings get global game_gfrc_mode 2>/dev/null | tr -d '\r' > "$CUR"

# 逐条处理现有表：命中的包替换为我们算出的值，其余原样保留；最后补上新增的包
awk -F'=' '
  NR==FNR { sel[$1] = $2 "1"; next }
  {
    n = split($0, ent, ",")
    out = ""
    for (i = 1; i <= n; i++) {
      e = ent[i]
      if (e == "" || e == "null") continue
      split(e, p, "+")
      if (p[1] in sel) {
        out = out (out == "" ? "" : ",") p[1] "+" sel[p[1]]
        delete sel[p[1]]
      } else {
        out = out (out == "" ? "" : ",") e
      }
    }
    for (k in sel) out = out (out == "" ? "" : ",") k "+" sel[k]
    print out
  }
' "$SEL" "$CUR" > "$TMP"

NEW=$(cat "$TMP")
OLD=$(sed 's/[ \t\r\n]//g' "$CUR")
[ -n "$NEW" ] || exit 0

# 只是顺序变化时也写回一次，保持稳定
if [ "$NEW" != "$OLD" ]; then
  settings put global game_gfrc_mode "$NEW"
  echo "mode updated: $NEW"
else
  echo "mode unchanged"
fi
