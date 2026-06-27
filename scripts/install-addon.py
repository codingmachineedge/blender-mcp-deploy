"""
Installs the blender-mcp addon into Blender automatically.
Run via: blender --background --python install-addon.py
"""

import bpy
import os
import sys
import subprocess
import importlib
import tempfile
import zipfile
import urllib.request


def find_addon_path():
    try:
        import blender_mcp
        pkg_dir = os.path.dirname(blender_mcp.__file__)
        addon_dir = os.path.join(pkg_dir, "addon")
        if os.path.isdir(addon_dir):
            return addon_dir
        init_file = os.path.join(pkg_dir, "addon.py")
        if os.path.isfile(init_file):
            return init_file
    except ImportError:
        pass

    result = subprocess.run(
        [sys.executable, "-m", "pip", "show", "blender-mcp"],
        capture_output=True, text=True
    )
    for line in result.stdout.splitlines():
        if line.startswith("Location:"):
            site_packages = line.split(":", 1)[1].strip()
            addon_dir = os.path.join(site_packages, "blender_mcp", "addon")
            if os.path.isdir(addon_dir):
                return addon_dir
            addon_file = os.path.join(site_packages, "blender_mcp", "addon.py")
            if os.path.isfile(addon_file):
                return addon_file
    return None


def install_addon(addon_path):
    if os.path.isdir(addon_path):
        zip_path = os.path.join(tempfile.gettempdir(), "blender_mcp_addon.zip")
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(addon_path):
                for f in files:
                    full = os.path.join(root, f)
                    arcname = os.path.relpath(full, os.path.dirname(addon_path))
                    zf.write(full, arcname)
        bpy.ops.preferences.addon_install(filepath=zip_path)
        os.remove(zip_path)
    else:
        bpy.ops.preferences.addon_install(filepath=addon_path)


def enable_addon():
    addon_names = ["blender_mcp", "mcp_server"]
    for name in addon_names:
        try:
            bpy.ops.preferences.addon_enable(module=name)
            print(f"   Enabled addon: {name}")
            return
        except RuntimeError:
            continue
    print("   WARNING: Could not enable addon (tried: {})".format(", ".join(addon_names)))


def main():
    print(">> Looking for blender-mcp addon files...")
    addon_path = find_addon_path()
    if not addon_path:
        print("   ERROR: Could not find blender-mcp addon. Is blender-mcp installed?")
        sys.exit(1)
    print(f"   Found addon at: {addon_path}")

    print(">> Installing addon into Blender...")
    install_addon(addon_path)
    print("   OK: Addon installed")

    print(">> Enabling addon...")
    enable_addon()
    print("   OK: Addon enabled")

    bpy.ops.wm.save_userpref()
    print("   OK: Preferences saved")
    print(">> Blender addon setup complete")


if __name__ == "__main__":
    main()
