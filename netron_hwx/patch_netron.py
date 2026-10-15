#!/usr/bin/env python3
"""
Netron ANE HWX Extension Installer & Patcher

Enables Netron to open and visualize Apple Neural Engine (ANE) compiled .hwx models.
Usage:
    python3 patch_netron.py --install
    python3 patch_netron.py --status
    python3 patch_netron.py --uninstall
    python3 patch_netron.py --test <path/to/model.hwx>
"""

import argparse
import os
import re
import shutil
import subprocess
import sys


def get_netron_dir():
    try:
        import netron
        netron_path = os.path.dirname(os.path.abspath(netron.__file__))
        return netron_path
    except ImportError:
        print("[ERROR] netron package is not installed in the current Python environment.")
        sys.exit(1)


def check_status(netron_dir):
    hwx_js = os.path.join(netron_dir, "hwx.js")
    view_js = os.path.join(netron_dir, "view.js")

    has_hwx_js = os.path.exists(hwx_js)
    has_registration = False

    if os.path.exists(view_js):
        with open(view_js, "r", encoding="utf-8") as f:
            content = f.read()
            if "this.register('./hwx'" in content:
                has_registration = True

    return has_hwx_js, has_registration


def install_patch(netron_dir):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    src_hwx_js = os.path.join(script_dir, "hwx.js")
    dst_hwx_js = os.path.join(netron_dir, "hwx.js")
    view_js = os.path.join(netron_dir, "view.js")
    view_bak = os.path.join(netron_dir, "view.js.bak")

    if not os.path.exists(src_hwx_js):
        print(f"[ERROR] Source {src_hwx_js} not found.")
        sys.exit(1)

    print(f"Installing hwx.js to {dst_hwx_js}...")
    shutil.copy2(src_hwx_js, dst_hwx_js)

    print(f"Checking view.js in {netron_dir}...")
    with open(view_js, "r", encoding="utf-8") as f:
        content = f.read()

    reg_line = "        this.register('./hwx', ['.hwx'], [], [/^\\xce\\xfa\\xef\\xbe/, /^\\xcf\\xfa\\xed\\xfe/, /^\\xbe\\xef\\xfa\\xce/, /^\\xfe\\xed\\xfa\\xcf/]);\n"

    if "this.register('./hwx'" in content:
        print("[OK] Netron view.js is already patched with ./hwx registration.")
    else:
        # Backup original view.js if not yet backed up
        if not os.path.exists(view_bak):
            shutil.copy2(view_js, view_bak)
            print(f"Created backup at {view_bak}")

        # Insert registration after espresso
        anchor = "this.register('./espresso', ['.espresso.net', '.espresso.shape', '.espresso.weights'], ['.mlmodelc']);"
        if anchor in content:
            new_content = content.replace(anchor, anchor + "\n" + reg_line)
        else:
            # Fallback anchor: ModelFactoryService constructor
            fallback_anchor = "view.ModelFactoryService = class {"
            if fallback_anchor in content:
                new_content = re.sub(
                    r"(view\.ModelFactoryService = class \{[^\n]*\n\s*constructor\([^\)]*\)\s*\{)",
                    r"\1\n" + reg_line,
                    content
                )
            else:
                print("[ERROR] Could not find insertion anchor in view.js.")
                sys.exit(1)

        with open(view_js, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("[SUCCESS] Patched view.js successfully.")

    print("\nNetron is now enabled for .hwx files!")
    print("Run `netron <model.hwx>` to open and visualize ANE models.")


def uninstall_patch(netron_dir):
    hwx_js = os.path.join(netron_dir, "hwx.js")
    view_js = os.path.join(netron_dir, "view.js")
    view_bak = os.path.join(netron_dir, "view.js.bak")

    if os.path.exists(hwx_js):
        os.remove(hwx_js)
        print(f"Removed {hwx_js}")

    if os.path.exists(view_bak):
        shutil.copy2(view_bak, view_js)
        os.remove(view_bak)
        print("Restored original view.js from backup.")
    else:
        with open(view_js, "r", encoding="utf-8") as f:
            content = f.read()
        cleaned = re.sub(r"[ \t]*this\.register\('\./hwx'.*?\);\n?", "", content)
        with open(view_js, "w", encoding="utf-8") as f:
            f.write(cleaned)
        print("Removed hwx registration from view.js.")

    print("[SUCCESS] Netron hwx extension uninstalled.")


def main():
    parser = argparse.ArgumentParser(description="Netron ANE HWX Extension Installer & Patcher")
    parser.add_argument("--install", action="store_true", help="Install HWX extension into Netron")
    parser.add_argument("--uninstall", action="store_true", help="Uninstall HWX extension from Netron")
    parser.add_argument("--status", action="store_true", help="Check Netron extension status")
    parser.add_argument("--test", metavar="FILE", help="Test parsing a .hwx file with Node test runner")
    args = parser.parse_args()

    netron_dir = get_netron_dir()

    if args.status:
        has_hwx, has_reg = check_status(netron_dir)
        print(f"Netron directory: {netron_dir}")
        print(f"  hwx.js installed:    {has_hwx}")
        print(f"  view.js registered:  {has_reg}")
        if has_hwx and has_reg:
            print("Status: READY (.hwx support active)")
        else:
            print("Status: NOT INSTALLED or incomplete (run with --install)")
        return

    if args.uninstall:
        uninstall_patch(netron_dir)
        return

    if args.test:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        test_script = os.path.join(script_dir, "test_netron_hwx.mjs")
        cmd = ["node", test_script]
        print(f"Running test: {' '.join(cmd)}")
        subprocess.run(cmd, check=True)
        return

    # Default action: install
    install_patch(netron_dir)


if __name__ == "__main__":
    main()
