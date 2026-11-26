#!/system/bin/sh
# SPDX-License-Identifier: CC0-1.0
# GPP 游戏名单控制器 —— 只读写 /data 下的状态，不碰 /system
MODDIR=${MODDIR:-/data/adb/modules/gpp_extend}
DATA=/data/adb/gpp_extend
BASE=$DATA/base_list
STATE=$DATA/state.txt

mkdir -p "$DATA"
# 首次运行时把原始名单快照到 /data（此时还没有 bind mount）
if [ ! -f "$BASE" ]; then
  cp -f /system/etc/gpp_app_list "$BASE" 2>/dev/null
fi
[ -f "$STATE" ] || : > "$STATE"

case "$1" in
  list)
    echo "@@@BASE"
    cat "$BASE" 2>/dev/null
    echo "@@@STATE"
    cat "$STATE" 2>/dev/null
    echo "@@@END"
    ;;
  put)
    # put <base64 的 state 全文>
    printf '%s' "$2" | base64 -d > "$STATE.tmp" 2>/dev/null && mv -f "$STATE.tmp" "$STATE"
    echo OK
    ;;
  reset)
    : > "$STATE"
    echo OK
    ;;
  status)
    echo "@@@MOUNT"
    mount | grep gpp_app_list
    echo "@@@RATE"
    getprop vendor.gpp.gfrc.interp.rate
    getprop vendor.gpp.gfrc.upscale.ratio
    echo "@@@PID"
    pidof gppservice
    echo "@@@END"
    ;;
  *)
    echo "usage: ctl.sh list|put <b64>|reset|status"
    ;;
esac
