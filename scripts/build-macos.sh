#!/usr/bin/env bash
# Сборка XatBox для macOS одной командой — пара к scripts/build-windows.ps1.
#
# Результат кладётся в dist/ в корне проекта:
#   XatBox-macos-<версия>-b<сборка>.zip   — XatBox.app в архиве (распаковать и перетащить в «Программы»);
#   XatBox-macos-<версия>-b<сборка>.dmg   — образ диска с XatBox.app и ярлыком «Программы».
# Адреса серверов берутся из env/<имя>.json (см. env/README.md) — те же файлы, что для APK и Windows.
#
#   scripts/build-macos.sh                 # спросит, какой env/*.json взять
#   scripts/build-macos.sh server          # env/server.json
#   scripts/build-macos.sh server --run    # собрать и сразу запустить
#   scripts/build-macos.sh ci --build 105  # номер сборки вместо pubspec (GitHub Actions)
#
# Нужно на этом Маке: Xcode (из App Store, один раз открыть и принять лицензию),
# CocoaPods (brew install cocoapods) и Flutter. Подробности: docs/BUILD-DESKTOP.md.
#
# Сборка подписана ad-hoc («Sign to Run Locally»): на этом Маке запускается сразу,
# на другом Gatekeeper скажет «не удаётся проверить разработчика» — правый клик по
# XatBox.app → «Открыть» или `xattr -dr com.apple.quarantine /Applications/XatBox.app`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

say() { printf '%s\n' "$*"; }
step() { printf '\n\033[36m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mОШИБКА: %s\033[0m\n' "$*" >&2; exit 1; }

ENV_NAME=""
RUN=0
BUILD_ARG=""
while (( $# )); do
  case "$1" in
    --run) RUN=1 ;;
    --build) BUILD_ARG="${2:-}"; shift ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ENV_NAME="$1" ;;
  esac
  shift
done

[[ "$(uname)" == "Darwin" ]] || fail "Сборка для macOS возможна только на Маке."

step "Проверка инструментов"
command -v flutter >/dev/null || fail "Не найден flutter. Установите: https://docs.flutter.dev/get-started/install/macos"
xcodebuild -version >/dev/null 2>&1 || fail "Не найден Xcode. Установите его из App Store, затем:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch"
command -v pod >/dev/null || fail "Не найден CocoaPods. Установите: brew install cocoapods"
say "  $(flutter --version 2>/dev/null | head -1)"
say "  $(xcodebuild -version | head -1), CocoaPods $(pod --version)"

step "Настройки сервера"
shopt -s nullglob
envs=(env/*.json)
if [[ -n "$ENV_NAME" ]]; then
  ENV_FILE=""
  for c in "$ENV_NAME" "env/$ENV_NAME" "env/$ENV_NAME.json"; do
    [[ -f "$c" ]] && { ENV_FILE="$c"; break; }
  done
  [[ -n "$ENV_FILE" ]] || fail "Не найден файл настроек '$ENV_NAME'. В env/ есть: ${envs[*]:-ничего}"
elif (( ${#envs[@]} == 0 )); then
  fail "В env/ нет ни одного *.json. Скопируйте пример и впишите адреса серверов:
  cp env/prod.json.example env/my.json"
elif (( ${#envs[@]} == 1 )); then
  ENV_FILE="${envs[0]}"
else
  say "Какие настройки сервера использовать?"
  select ENV_FILE in "${envs[@]}"; do [[ -n "$ENV_FILE" ]] && break; done
fi
python3 - "$ENV_FILE" <<'EOF' || fail "$ENV_FILE — это не корректный JSON."
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
for k in ("XATBOX_FLAVOR", "XATBOX_API_BASE_URL", "XATBOX_CHAT_BASE_URL", "XATBOX_CALLS_BASE_URL"):
    print(f"  {k:<23} {cfg.get(k) or '(не задано)'}")
EOF

VERSION="$(sed -n 's/^version: *//p' pubspec.yaml)"
NAME="${VERSION%%+*}"
BUILD="${BUILD_ARG:-${VERSION##*+}}"
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "Номер сборки должен быть числом: '$BUILD'"

step "Зависимости"
flutter pub get

step "Сборка XatBox $NAME (сборка $BUILD)"
flutter build macos --release --build-number="$BUILD" --dart-define-from-file="$ENV_FILE"

APP="build/macos/Build/Products/Release/XatBox.app"
[[ -d "$APP" ]] || fail "Сборка закончилась, но $APP не найден."

step "Упаковка в dist/"
mkdir -p dist
BASE="dist/XatBox-macos-$NAME-b$BUILD"
rm -f "$BASE.zip" "$BASE.dmg"
ditto -c -k --keepParent "$APP" "$BASE.zip"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -R "$APP" "$stage/"
ln -s /Applications "$stage/Программы"
hdiutil create -quiet -volname "XatBox" -srcfolder "$stage" -ov -format UDZO "$BASE.dmg"
say "  $BASE.zip"
say "  $BASE.dmg"

if (( RUN )); then
  step "Запуск"
  open "$APP"
fi
say ""
say "Готово."
