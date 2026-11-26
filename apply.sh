#!/system/bin/sh
# SPDX-License-Identifier: CC0-1.0
# 根据 /data/adb/gpp_extend/state.txt 生成合并名单，bind mount 覆盖 /system/etc/gpp_app_list，并重启 gppservice
MODDIR=${MODDIR:-/data/adb/modules/gpp_extend}
DATA=/data/adb/gpp_extend
BASE=$DATA/base_list
STATE=$DATA/state.txt
READ=$DATA/state.read
OUT=$MODDIR/system/etc/gpp_app_list
TMP=$DATA/generated.tmp

mkdir -p "$DATA"
chcon -R u:object_r:ksu_file:s0 "$DATA" 2>/dev/null
if [ ! -f "$BASE" ]; then
  cp -f /system/etc/gpp_app_list "$BASE" 2>/dev/null
fi
[ -f "$STATE" ] || : > "$STATE"

# 哨兵行：保证 awk 的第一个输入文件非空，否则 NR==FNR 判断会失效
{ cat "$STATE" 2>/dev/null; echo "#__sentinel__"; } > "$READ"

# state 行格式：包名,超分档(0/1/2),插帧(0/1),启用(1/0)
awk -F, '
NR==FNR {
  if ($0 ~ /^#/ || $0 ~ /^[ \t]*$/) next
  pkg=$1
  on[pkg]=$4; up[pkg]=$2; itp[pkg]=$3; st[pkg]=1
  next
}
{
  if ($0 ~ /^#/ || $0 ~ /^[ \t]*$/) { print; next }
  pkg=$1
  if (pkg in st) {
    # 勾选：用面板里选的档位；未勾选：保留出厂行，只是不再强制写 game_gfrc_mode
    if (on[pkg] == "1") print pkg "," up[pkg] "," itp[pkg]
    else print
    done[pkg]=1
  } else {
    print
  }
}
END {
  for (p in st) {
    if (!(p in done) && on[p] == "1") print p "," up[p] "," itp[p]
  }
}' "$READ" "$BASE" > "$TMP" || exit 1

# 已挂载则先卸载，避免叠加
if mount | grep -q " /system/etc/gpp_app_list "; then
  umount /system/etc/gpp_app_list 2>/dev/null
fi

cp -f "$TMP" "$OUT" || exit 1
chcon u:object_r:system_file:s0 "$OUT" 2>/dev/null

mount --bind "$OUT" /system/etc/gpp_app_list 2>/dev/null
if ! mount | grep -q " /system/etc/gpp_app_list "; then
  echo "ERR: bind mount failed"
  exit 2
fi
chcon u:object_r:system_file:s0 /system/etc/gpp_app_list 2>/dev/null

if [ "$1" != "--no-restart" ]; then
  pid=$(pidof gppservice)
  if [ -n "$pid" ]; then kill $pid 2>/dev/null; fi
fi

# 同步 Settings.Global game_gfrc_mode（插帧真正生效的必要条件）
sh "$MODDIR/mode.sh" 2>/dev/null

# 全局支持：allgame=1 时 Cube 会给任意游戏非 0 的 cap，游戏内「超境画质」面板才会出现
RP=/data/adb/ksu/bin/resetprop
[ -x "$RP" ] || RP=resetprop
want=$(tr -d '\r\n ' < "$DATA/allgame" 2>/dev/null)
[ -n "$want" ] || want=1
"$RP" vendor.gpp.allgame.enable "$want" 2>/dev/null

echo "OK entries=$(awk 'NF && $0 !~ /^#/' "$OUT" | wc -l) allgame=$want"
