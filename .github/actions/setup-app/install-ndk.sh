#!/usr/bin/env bash
# Installs the Android NDK version that Flutter's Gradle plugin pins, before
# Gradle runs. sdkmanager (and Gradle's own auto-install) failed on GitHub's
# runners with cut-off downloads ("Error on ZipFile unknown archive"), so the
# zip is fetched directly from Google's SDK repository: resumable, retried,
# and checked against the size and SHA-1 in the repository manifest.
#
# Usage: install-ndk.sh   (needs FLUTTER_ROOT and ANDROID_HOME)
set -euo pipefail

ext="$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
ndk=$(grep -oE 'val ndkVersion: String = "[0-9.]+"' "$ext" | grep -oE '[0-9]+(\.[0-9]+)+' || true)
if [ -z "$ndk" ]; then
  echo "::error::Could not read Flutter's NDK version from $ext."
  exit 1
fi
dir="$ANDROID_HOME/ndk/$ndk"
if [ -f "$dir/source.properties" ]; then
  echo "NDK $ndk is already installed."
  exit 0
fi

case "$(uname -s)" in
  Linux*) host=linux ;;
  Darwin*) host=macosx ;;
  *) host=windows ;;
esac
work="${RUNNER_TEMP:-$(mktemp -d)}/ndk-install"
rm -rf "$work"
mkdir -p "$work"

repo=https://dl.google.com/android/repository
curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 -o "$work/repository.xml" "$repo/repository2-3.xml"
# tr: Python on Windows ends lines with CRLF.
read -r url size sha1 < <(python3 - "$work/repository.xml" "ndk;$ndk" "$host" <<'PY' | tr -d '\r'
import sys
import xml.etree.ElementTree as ET

manifest, path, host = sys.argv[1:]
for package in ET.parse(manifest).getroot().iter('remotePackage'):
    if package.get('path') != path:
        continue
    for archive in package.iter('archive'):
        if archive.findtext('host-os') in (host, None):
            complete = archive.find('complete')
            print(complete.findtext('url'), complete.findtext('size'), complete.findtext('checksum'))
            sys.exit(0)
sys.exit(f'{path} for {host} is not in the repository manifest')
PY
)
if [ -z "${url:-}" ] || [ -z "${size:-}" ] || [ -z "${sha1:-}" ]; then
  echo "::error::NDK $ndk for $host was not found in Google's SDK repository manifest."
  exit 1
fi
echo "NDK $ndk: $url ($size bytes)"

zip="$work/$url"
file_size() { if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi; }
downloaded() { [ "$(file_size "$zip")" = "$size" ] && [ "$(sha1sum "$zip" | cut -d' ' -f1)" = "$sha1" ]; }

for attempt in 1 2 3 4 5; do
  # A file at full size with the wrong checksum is broken: start over.
  if [ "$(file_size "$zip")" -ge "$size" ]; then rm -f "$zip"; fi
  # -C - resumes a partial download instead of starting from zero.
  curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 -C - -o "$zip" "$repo/$url" || true
  if downloaded; then break; fi
  echo "::warning::NDK download attempt $attempt stopped at $(file_size "$zip") of $size bytes, resuming."
  sleep $((attempt * 5))
done
if ! downloaded; then
  echo "::error::Could not download NDK $ndk ($url): got $(file_size "$zip") of $size bytes or a wrong checksum."
  exit 1
fi

unzip -q "$zip" -d "$work/unpacked"
mkdir -p "$ANDROID_HOME/ndk"
rm -rf "$dir"
mv "$work"/unpacked/android-ndk-* "$dir"
rm -rf "$work"
if [ ! -f "$dir/source.properties" ]; then
  echo "::error::NDK $ndk was unpacked but $dir/source.properties is missing."
  exit 1
fi
echo "Installed NDK $ndk in $dir."
