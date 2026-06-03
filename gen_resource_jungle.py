#!/usr/bin/env python3
"""
gen_resource_jungle.py  --  READ ONLY. Writes nothing, modifies nothing.

Reads the products in manifest.xml, looks up each device's screen resolution
from the Connect IQ SDK device database, and prints:
  1. a human-readable table (device -> WxH -> shape -> folder status), and
  2. the monkey.jungle resourcePath lines to append, for devices whose
     matching resources-WxH folder actually exists in the project.

Review the table before pasting anything into monkey.jungle.
"""

import os, re, sys, json, glob, argparse
import xml.etree.ElementTree as ET

DEFAULT_DEVICES = os.path.expanduser("~/.Garmin/ConnectIQ/Devices")

def find_resolution_and_shape(obj):
    """Recursively pull a (width,height) int pair and a shape string from a
    device JSON, tolerant of differing schemas."""
    res = {"wh": None, "shape": None}

    def walk(node):
        if isinstance(node, dict):
            # collect a shape string if present
            for k, v in node.items():
                if isinstance(v, str) and "shape" in k.lower() and res["shape"] is None:
                    res["shape"] = v.lower()
            # look for a width/height pair inside THIS dict
            w = h = None
            for k, v in node.items():
                kl = k.lower()
                if isinstance(v, (int, float)):
                    if kl in ("width", "screenwidth", "w") or kl.endswith("width"):
                        w = int(v)
                    if kl in ("height", "screenheight", "h") or kl.endswith("height"):
                        h = int(v)
            if w and h and 50 < w < 2000 and 50 < h < 2000:
                # prefer the first sensible pair we find
                if res["wh"] is None:
                    res["wh"] = (w, h)
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(obj)
    return res["wh"], res["shape"]

def load_device(devices_dir, dev_id):
    for fname in ("compiler.json", "simulator.json"):
        p = os.path.join(devices_dir, dev_id, fname)
        if os.path.isfile(p):
            try:
                with open(p, encoding="utf-8") as f:
                    return json.load(f), p
            except Exception as e:
                print(f"  ! {dev_id}: failed to parse {fname}: {e}", file=sys.stderr)
    return None, None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default=".", help="project root (has manifest.xml + resources-* folders)")
    ap.add_argument("--devices", default=DEFAULT_DEVICES, help="SDK Devices dir")
    args = ap.parse_args()

    manifest = os.path.join(args.project, "manifest.xml")
    if not os.path.isfile(manifest):
        sys.exit(f"manifest.xml not found at {manifest}")
    if not os.path.isdir(args.devices):
        sys.exit(f"Devices dir not found at {args.devices} (override with --devices)")

    # product ids from manifest (namespace-agnostic)
    tree = ET.parse(manifest)
    ids = [el.get("id") for el in tree.iter() if el.tag.endswith("}product") or el.tag == "product"]
    ids = [i for i in ids if i]

    # which resources-WxH folders actually exist in the project
    existing = set()
    for d in glob.glob(os.path.join(args.project, "resources-*")):
        m = re.fullmatch(r"resources-(\d+x\d+)", os.path.basename(d))
        if m:
            existing.add(m.group(1))
    # device-id override folders that already exist (these auto-apply, leave alone)
    devid_folders = {os.path.basename(d).split("resources-", 1)[1]
                     for d in glob.glob(os.path.join(args.project, "resources-*"))
                     if not re.fullmatch(r"resources-\d+x\d+", os.path.basename(d))}

    rows, jungle_lines, gaps = [], [], []
    for dev in ids:
        data, src = load_device(args.devices, dev)
        if data is None:
            rows.append((dev, "?", "?", "DEVICE JSON NOT FOUND"))
            continue
        wh, shape = find_resolution_and_shape(data)
        if wh is None:
            rows.append((dev, "?", shape or "?", "resolution not detected (inspect manually)"))
            continue
        res = f"{wh[0]}x{wh[1]}"
        if dev in devid_folders:
            rows.append((dev, res, shape or "-", f"OK via device folder resources-{dev}"))
        elif res in existing:
            rows.append((dev, res, shape or "-", f"-> resources-{res}"))
            jungle_lines.append(f"{dev}.resourcePath = $({dev}.resourcePath);resources-{res}")
        else:
            rows.append((dev, res, shape or "-", "NO matching folder (falls back to base resources)"))
            gaps.append((dev, res))

    w0 = max((len(r[0]) for r in rows), default=6)
    print("\n=== Device resolution table ===")
    print(f"{'device'.ljust(w0)}  {'WxH':9}  {'shape':12}  status")
    for dev, res, shape, status in rows:
        print(f"{dev.ljust(w0)}  {res:9}  {shape:12}  {status}")

    print("\n=== Append these lines to monkey.jungle ===")
    if jungle_lines:
        print("\n".join(jungle_lines))
    else:
        print("(none generated)")

    if gaps:
        print("\n=== GAPS: resolutions with no resources-WxH folder ===", file=sys.stderr)
        for dev, res in gaps:
            print(f"  {dev}: needs resources-{res} (or a resources-{dev} device folder)", file=sys.stderr)

if __name__ == "__main__":
    main()
