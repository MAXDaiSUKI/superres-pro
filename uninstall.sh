#!/system/bin/sh
# SPDX-License-Identifier: CC0-1.0
# 卸载时自动还原：卸掉 bind mount、重启 gppservice、清掉状态
if mount | grep -q " /system/etc/gpp_app_list "; then
  umount /system/etc/gpp_app_list 2>/dev/null
fi
pid=$(pidof gppservice)
if [ -n "$pid" ]; then kill $pid 2>/dev/null; fi
rm -rf /data/adb/gpp_extend
