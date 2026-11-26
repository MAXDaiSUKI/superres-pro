#!/system/bin/sh
# SPDX-License-Identifier: CC0-1.0
# 开机后守护（v1.3）：
#  1) 单实例锁，避免每次“激活 root / 重载模块”都多出一个循环
#  2) 维持 vendor.gpp.allgame.enable（让 Cube 对任意游戏返回非 0 cap）
#  3) 仅当 force=1（强制写入模式）才周期性跑 mode.sh；面板优先模式下完全空转
# 说明：所有判断都用 shell 内建（read/case），只有 getprop 与 resetprop 会 fork。

MODDIR=${0%/*}
DATA=/data/adb/gpp_extend
LOCK=$DATA/svc.lock
RP=/data/adb/ksu/bin/resetprop
[ -x "$RP" ] || RP=resetprop

mkdir -p "$DATA"
# 统一状态目录标签，避免个别文件被 cp/WebUI 写成 shell_data_file 后读不到
chcon -R u:object_r:ksu_file:s0 "$DATA" 2>/dev/null

# ---------- 单实例锁 ----------
BOOTID=
read -r BOOTID 2>/dev/null < /proc/sys/kernel/random/boot_id
if [ -f "$LOCK" ]; then
  LPID=
  LBOOT=
  { read -r LPID LBOOT; } 2>/dev/null < "$LOCK"
  if [ -n "$LPID" ] && [ "$LBOOT" = "$BOOTID" ] && kill -0 "$LPID" 2>/dev/null; then
    exit 0
  fi
fi
echo "$$ $BOOTID" > "$LOCK"

sync_allgame() {
  WANT=
  read -r WANT 2>/dev/null < "$DATA/allgame"
  case "$WANT" in
    0) WANT=0 ;;
    *) WANT=1 ;;
  esac
  CUR=$(getprop vendor.gpp.allgame.enable)
  [ "$CUR" = "$WANT" ] || "$RP" vendor.gpp.allgame.enable "$WANT" >/dev/null 2>&1
}

# 等 WebUI 首次写入 state.txt（最多 5 分钟），随后先同步一次
i=0
while [ ! -f "$DATA/state.txt" ] && [ $i -lt 60 ]; do sleep 5; i=$((i+1)); done
sync_allgame

while true; do
  FORCE=
  read -r FORCE 2>/dev/null < "$DATA/force"
  if [ "$FORCE" = "1" ]; then
    sh "$MODDIR/mode.sh" >/dev/null 2>&1
    sleep 15
  else
    sleep 60
  fi
  sync_allgame
done
