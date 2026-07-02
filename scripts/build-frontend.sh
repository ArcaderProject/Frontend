#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

ARCH="${ARCH:-x86_64}"
case "$ARCH" in
  x86_64)
    GODOT_PRESET="Linux/X11"
    EXT_RUST_TARGET="x86_64-unknown-linux-gnu.2.34"
    GD_LIB_ARCH="x86_64"
    ;;
  x86_32)
    GODOT_PRESET="Linux/X11 (32-bit)"
    EXT_RUST_TARGET="i686-unknown-linux-gnu.2.34"
    GD_LIB_ARCH="x86_32"
    ;;
  *)
    echo "Error: unsupported ARCH '$ARCH' (expected 'x86_64' or 'x86_32')" >&2
    exit 1
    ;;
esac

command -v cargo >/dev/null 2>&1 || { echo "Error: cargo (Rust) not installed"; exit 1; }
command -v cargo-zigbuild >/dev/null 2>&1 || { echo "Error: cargo-zigbuild not installed"; exit 1; }
command -v godot >/dev/null 2>&1 || { echo "Error: Godot not installed"; exit 1; }

echo "Building Arcader frontend for $ARCH (godot: $GODOT_PRESET, ext: $EXT_RUST_TARGET)"

GODOT_VERSION=4.6
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
if [ ! -f "$TEMPLATE_DIR/linux_release.x86_64" ]; then
    echo "Godot export templates not found, downloading..."
    mkdir -p "$TEMPLATE_DIR"
    TEMP_DIR=$(mktemp -d)
    ( cd "$TEMP_DIR"
      wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
      unzip -q "Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
      cp templates/* "$TEMPLATE_DIR/" )
    rm -rf "$TEMP_DIR"
fi

echo "Building unix-socket GDExtension for $GD_LIB_ARCH ..."
EXT_TRIPLE="${EXT_RUST_TARGET%%.*}"
( cd extensions/unixsocket
  rustup target add "$EXT_TRIPLE" 2>/dev/null || true
  cargo zigbuild --release --target "$EXT_RUST_TARGET"
  cp "target/$EXT_TRIPLE/release/libunixsocket.so" \
     "../../arcaderui/addons/unix-socket/libunixsocket.linux.release.${GD_LIB_ARCH}.so" )

rm -rf build
mkdir -p build/pkg/addons/unix-socket
( cd arcaderui
  godot --headless --export-release "$GODOT_PRESET" ../build/pkg/arcaderui )

cp arcaderui/addons/unix-socket/lib.gdextension build/pkg/addons/unix-socket/
cp "arcaderui/addons/unix-socket/libunixsocket.linux.release.${GD_LIB_ARCH}.so" \
   build/pkg/addons/unix-socket/
cp arcader-frontend.json build/pkg/arcader-frontend.json

TARBALL="arcaderui-linux-${ARCH}.tar.gz"
( cd build/pkg && tar czf "../$TARBALL" arcaderui arcaderui.pck arcader-frontend.json addons )
echo "Built build/$TARBALL"
