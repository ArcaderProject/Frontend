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
# Godot's official x86_64 build enables SSE4.2 engine-wide AND hard-checks for it at startup,
# so it aborts on older CPUs
if [ "$GD_LIB_ARCH" = "x86_64" ]; then
    echo "Building custom Godot ${GD_LIB_ARCH} export template (SSE2 baseline)..."
    command -v scons >/dev/null 2>&1 || { echo "Error: scons not installed"; exit 1; }
    mkdir -p "$TEMPLATE_DIR"
    SRC_DIR=$(mktemp -d)
    git clone --depth 1 --branch "${GODOT_VERSION}-stable" https://github.com/godotengine/godot.git "$SRC_DIR"
    sed -i 's/CCFLAGS=\["-msse4.2", "-mpopcnt"\]/CCFLAGS=[]/' "$SRC_DIR/SConstruct"
    sed -i 's/if (!(cpuinfo\[2\] & (1 << 20)))/if (false)/' "$SRC_DIR/platform/linuxbsd/godot_linuxbsd.cpp"
    ( cd "$SRC_DIR"
      scons platform=linuxbsd target=template_release arch="${GD_LIB_ARCH}" \
        module_raycast_enabled=no accesskit=no speechd=no wayland=no production=yes -j"$(nproc)" )
    cp "$SRC_DIR/bin/godot.linuxbsd.template_release.${GD_LIB_ARCH}" "$TEMPLATE_DIR/linux_release.${GD_LIB_ARCH}"
    echo "${GODOT_VERSION}.stable" > "$TEMPLATE_DIR/version.txt"
    rm -rf "$SRC_DIR"
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
