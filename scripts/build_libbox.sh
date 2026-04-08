#!/bin/bash
# =============================================================
#  Build sing-box libbox.aar for Android
#
#  Prerequisites:
#    - Go 1.22+ (https://go.dev/dl/)
#    - Android SDK + NDK (via Android Studio)
#    - ANDROID_HOME set (e.g., ~/Android/Sdk)
#
#  Usage:
#    chmod +x scripts/build_libbox.sh
#    ./scripts/build_libbox.sh
#
#  Output: android/app/libs/libbox.aar
# =============================================================

set -e

SING_BOX_VERSION="v1.11.7"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBS_DIR="$PROJECT_DIR/android/app/libs"
BUILD_DIR="$PROJECT_DIR/build/sing-box"

echo "=== Building sing-box $SING_BOX_VERSION libbox.aar ==="

# Check Go
if ! command -v go &>/dev/null; then
    echo "ERROR: Go not found. Install from https://go.dev/dl/"
    exit 1
fi
echo "Go: $(go version)"

# Check ANDROID_HOME
if [ -z "$ANDROID_HOME" ]; then
    # Try common locations
    for dir in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "$LOCALAPPDATA/Android/Sdk"; do
        if [ -d "$dir" ]; then
            export ANDROID_HOME="$dir"
            break
        fi
    done
fi

if [ -z "$ANDROID_HOME" ]; then
    echo "ERROR: ANDROID_HOME not set. Set it to your Android SDK path."
    exit 1
fi
echo "ANDROID_HOME: $ANDROID_HOME"

# Install gomobile
echo "=== Installing gomobile ==="
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
export PATH="$HOME/go/bin:$PATH"
gomobile init

# Clone or update sing-box
if [ -d "$BUILD_DIR" ]; then
    echo "=== Updating sing-box ==="
    cd "$BUILD_DIR"
    git fetch --tags
    git checkout "$SING_BOX_VERSION"
else
    echo "=== Cloning sing-box $SING_BOX_VERSION ==="
    mkdir -p "$BUILD_DIR"
    git clone --branch "$SING_BOX_VERSION" --depth 1 \
        https://github.com/SagerNet/sing-box.git "$BUILD_DIR"
    cd "$BUILD_DIR"
fi

# Build AAR
echo "=== Building AAR (this takes 5-10 min) ==="
# The make target builds libbox.aar
if [ -f "Makefile" ] && grep -q "lib_android" Makefile; then
    make lib_android
else
    # Manual gomobile bind
    gomobile bind -v \
        -androidapi 26 \
        -javapkg=io.nekohasekai \
        -tags "with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_ech" \
        -trimpath \
        -o "$LIBS_DIR/libbox.aar" \
        ./experimental/libbox
fi

# Copy AAR if make built it elsewhere
if [ -f "libbox.aar" ] && [ ! -f "$LIBS_DIR/libbox.aar" ]; then
    mkdir -p "$LIBS_DIR"
    cp libbox.aar "$LIBS_DIR/libbox.aar"
fi

if [ -f "$LIBS_DIR/libbox.aar" ]; then
    echo ""
    echo "=== SUCCESS ==="
    echo "AAR: $LIBS_DIR/libbox.aar"
    echo "Size: $(du -h "$LIBS_DIR/libbox.aar" | cut -f1)"
    echo ""
    echo "Now run: cd $PROJECT_DIR && flutter build apk --debug"
else
    echo ""
    echo "=== AAR not found, checking build output ==="
    find "$BUILD_DIR" -name "*.aar" 2>/dev/null
    echo "Copy the .aar file to: $LIBS_DIR/libbox.aar"
fi
