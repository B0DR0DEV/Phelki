#!/usr/bin/env bash
# Собирает build/android/phelki.apk.
# Подписывает тестовым ключом ci/debug.keystore — он одинаковый в каждой сборке,
# поэтому новая версия ставится поверх старой. Для магазинов нужен свой секретный ключ.
set -euo pipefail

V="${GODOT_VERSION:-4.7.2}"
MM="${V%.*}"  # 4.7.2 → 4.7
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
JAVA="${JAVA_HOME:?Нужна Java 17: JAVA_HOME не задан}"
KS="$PWD/ci/debug.keystore"
RUN="${GITHUB_RUN_NUMBER:-1}"

mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-${MM}.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$JAVA"
export/android/android_sdk_path = "$SDK"
export/android/debug_keystore = "$KS"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF

# Номер версии = номер сборки, чтобы телефон видел обновление
sed -i "s/^version\/code=.*/version\/code=${RUN}/; s/^version\/name=.*/version\/name=\"0.1.${RUN}\"/" export_presets.cfg

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KS"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="android"

mkdir -p build/android
godot --headless --path . --import
godot --headless --path . --export-release "Android" build/android/phelki.apk
test -s build/android/phelki.apk
ls -la build/android
