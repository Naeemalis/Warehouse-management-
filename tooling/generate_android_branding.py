#!/usr/bin/env python3
"""Generate NaeemSoft WMS Android branding and launcher icons from the supplied logo."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path("android/app/src/main")
SOURCE = Path("assets/branding/naeemsoft_launcher_source.png")
ANDROID_URI = "http://schemas.android.com/apk/res/android"
ANDROID = "{" + ANDROID_URI + "}"
ET.register_namespace("android", ANDROID_URI)

def main():
    if not SOURCE.is_file():
        raise SystemExit(f"Launcher logo is missing: {SOURCE}")
    manifest = ROOT / "AndroidManifest.xml"
    tree = ET.parse(manifest)
    app = tree.getroot().find("application")
    if app is None:
        raise SystemExit("AndroidManifest.xml has no application element")
    app.set(ANDROID + "label", "NaeemSoft WMS")
    app.set(ANDROID + "icon", "@mipmap/ic_launcher")
    app.set(ANDROID + "roundIcon", "@mipmap/ic_launcher")
    for child in list(app):
        if child.tag == "meta-data" and child.get(ANDROID + "name") == "flutterEmbedding":
            app.remove(child)
    ET.SubElement(app, "meta-data", {
        ANDROID + "name": "flutterEmbedding",
        ANDROID + "value": "2",
    })
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

    gradle = Path("android/app/build.gradle")
    gradle_kts = Path("android/app/build.gradle.kts")
    gradle_text = gradle.read_text() if gradle.exists() else gradle_kts.read_text()
    match = re.search(r'namespace\s*=\s*["\']([^"\']+)["\']', gradle_text)
    if not match:
        raise SystemExit("Could not determine Android namespace for MainActivity")
    package = match.group(1)
    activity = Path("android/app/src/main/kotlin") / Path(*package.split(".")) / "MainActivity.kt"
    activity.parent.mkdir(parents=True, exist_ok=True)
    activity.write_text(
        f"package {package}\n\n"
        "import io.flutter.embedding.android.FlutterActivity\n\n"
        "class MainActivity : FlutterActivity()\n",
        encoding="utf-8",
    )

    sizes = {
        "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
    }
    with Image.open(SOURCE) as original:
        logo = original.convert("RGBA")
        for folder, size in sizes.items():
            target = ROOT / "res" / folder
            target.mkdir(parents=True, exist_ok=True)
            resized = logo.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(target / "ic_launcher.png", format="PNG", optimize=True)
    print("Applied supplied NaeemSoft logo to all Android launcher densities.")

if __name__ == "__main__":
    main()
