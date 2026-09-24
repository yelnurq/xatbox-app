#!/usr/bin/env bash
# Raises the XatBox build number in pubspec.yaml ("version: X.Y.Z+N").
#
# Usage: scripts/bump-version.sh [--name X.Y.Z] [--set-code N] [--pubspec FILE]
#   (no options)    N → N+1
#   --name X.Y.Z    also set the version name
#   --set-code N    set the build number to N instead of N+1
#   --pubspec FILE  default: <repo>/pubspec.yaml
#
# The build number must stay below 1000: split APKs add 1000*ABI to it.
# Only the version line is changed; the rest of the file is kept byte for byte.
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
PUBSPEC="$REPO_ROOT/pubspec.yaml"
NEW_NAME=""
SET_CODE=""

die() { echo "bump-version: ERROR: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || die "--name needs a value"; NEW_NAME=$2; shift 2 ;;
    --set-code) [ $# -ge 2 ] || die "--set-code needs a value"; SET_CODE=$2; shift 2 ;;
    --pubspec) [ $# -ge 2 ] || die "--pubspec needs a value"; PUBSPEC=$2; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

[ -f "$PUBSPEC" ] || die "pubspec not found: $PUBSPEC"
LINE=$(grep -nE '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+[[:space:]]*$' "$PUBSPEC" | head -n 1 || true)
[ -n "$LINE" ] || die "no 'version: X.Y.Z+N' line in $PUBSPEC"
OLD=$(printf '%s' "${LINE#*:}" | sed -E 's/^version:[[:space:]]*//; s/[[:space:]]+$//')
OLD_NAME=${OLD%%+*}
OLD_CODE=$((10#${OLD##*+}))

NAME=$OLD_NAME
if [ -n "$NEW_NAME" ]; then
  printf '%s' "$NEW_NAME" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || die "--name must look like X.Y.Z"
  NAME=$NEW_NAME
fi
if [ -n "$SET_CODE" ]; then
  case "$SET_CODE" in ''|*[!0-9]*) die "--set-code must be a number" ;; esac
  CODE=$((10#$SET_CODE))
else
  CODE=$((OLD_CODE + 1))
fi
[ "$CODE" -ge 1 ] || die "build number must be >= 1"
[ "$CODE" -lt 1000 ] || die "build number $CODE is too large: it must stay below 1000 (split APKs add 1000*ABI)"
if [ "$CODE" -le "$OLD_CODE" ]; then
  echo "bump-version: WARNING: build number does not increase ($OLD_CODE → $CODE); phones will not see it as an update" >&2
fi

NEW="$NAME+$CODE"
TMP="$PUBSPEC.bump.$$"
# Replace only the first version line; keep line endings (CRLF) as they are.
awk -v new="$NEW" '
  !done && /^version:[ \t]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+[ \t\r]*$/ {
    cr = ""; if ($0 ~ /\r$/) cr = "\r"
    print "version: " new cr; done = 1; next
  }
  { print }
' "$PUBSPEC" > "$TMP"
# awk adds a final newline; drop it again when the original file had none.
if [ -n "$(tail -c 1 "$PUBSPEC")" ]; then
  printf '%s' "$(cat "$TMP")" > "$TMP.2" && mv -f "$TMP.2" "$TMP"
fi
cat "$TMP" > "$PUBSPEC"
rm -f "$TMP"
echo "version: $OLD → $NEW"
