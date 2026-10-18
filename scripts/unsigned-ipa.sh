#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project Bloom.xcodeproj -scheme Bloom -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Bloom.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
mkdir -p build/ipa/Payload
# Replace only this script's generated packaging directory.
rm -rf build/ipa/Payload/Bloom.app
cp -R build/Bloom.xcarchive/Products/Applications/Bloom.app build/ipa/Payload/
rm -f build/Bloom-unsigned.ipa
(cd build/ipa && /usr/bin/zip -qry ../Bloom-unsigned.ipa Payload)
unzip -t build/Bloom-unsigned.ipa
