#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""把仓库打包成 KernelSU 可安装的模块 zip。

用法:
    python3 build_zip.py [--out 目录]

产物: gpp_extend_v<version>.zip（版本号取自 module.prop）
"""

import os
import re
import sys
import zipfile
import hashlib

ROOT = os.path.dirname(os.path.abspath(__file__))

# 打进包里的文件 -> 包内路径（None 表示同名）
FILES = [
    ("module.prop", None),
    ("apply.sh", None),
    ("mode.sh", None),
    ("service.sh", None),
    ("ctl.sh", None),
    ("uninstall.sh", None),
    ("system/etc/gpp_app_list", None),
    ("webroot/index.html", None),
    ("docs/USAGE-zh.md", "使用说明.md"),
]


def read_prop(path):
    props = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            props[k.strip()] = v.strip()
    return props


def main():
    outdir = ROOT
    args = sys.argv[1:]
    if "--out" in args:
        outdir = os.path.abspath(args[args.index("--out") + 1])

    props = read_prop(os.path.join(ROOT, "module.prop"))
    module_id = props.get("id", "module")
    version = props.get("version", "v0")
    zip_name = "%s_%s.zip" % (module_id, version)
    zip_path = os.path.join(outdir, zip_name)

    os.makedirs(outdir, exist_ok=True)
    if os.path.exists(zip_path):
        os.remove(zip_path)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for src, arc in FILES:
            full = os.path.join(ROOT, src.replace("/", os.sep))
            if not os.path.isfile(full):
                raise SystemExit("missing: " + src)
            arcname = arc if arc else src
            info = zipfile.ZipInfo(arcname)
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(full, "rb") as f:
                data = f.read()
            if b"\r\n" in data and src != "system/etc/gpp_app_list":
                raise SystemExit("CRLF found in " + src + "（请转成 LF）")
            unix_mode = 0o100755 if src.endswith(".sh") else 0o100644
            info.external_attr = unix_mode << 16
            z.writestr(info, data)
            print("%-30s %6d bytes" % (arcname, len(data)))

    with open(zip_path, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    print("---")
    print("zip:", zip_path, os.path.getsize(zip_path), "bytes")
    print("sha256:", digest)


if __name__ == "__main__":
    main()
