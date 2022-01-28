mkdir -p .build/symbol-graphs
rm -rf docs
mkdir -p docs

xcrun swift build --target Automerge \
-Xswiftc -emit-symbol-graph \
-Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs

rm -f .build/symbol-graphs/ZippyJSON.symbols.json

echo "HINTS+"

xcrun docc convert Source/Automerge.docc \
--fallback-display-name Automerge \
--fallback-bundle-identifier org.automerge.Automerge-swift \
--fallback-bundle-version 0.1.6 \
--additional-symbol-graph-dir .build/symbol-graphs  \
--diagnostic-level hint

echo "SUMMARY"

xcrun docc convert Source/Automerge.docc \
--fallback-display-name Automerge \
--fallback-bundle-identifier org.automerge.Automerge-swift \
--fallback-bundle-version 0.1.6 \
--additional-symbol-graph-dir .build/symbol-graphs \
--experimental-documentation-coverage \
--level brief

echo "GENERATING FOR STATIC HOSTING"

xcrun docc convert Source/Automerge.docc \
--transform-for-static-hosting \
--hosting-base-path 'automerge-swift' \
--enable-inherited-docs \
--output-path docs \
--fallback-display-name Automerge \
--fallback-bundle-identifier org.automerge.Automerge-swift \
--fallback-bundle-version 0.1.6 \
--additional-symbol-graph-dir .build/symbol-graphs \
--emit-digest

echo "Github pages docs at https://automerge.github.io/automerge-swift/documentation/automerge-swift/"

echo "Extracting Symbols"

cat docs/linkable-entities.json| jq '.[].referenceURL' -r | sort > all_symbols.txt
# Xcode generated output
#xcodebuild docbuild -scheme Automerge \
#  -derivedDataPath ~/Desktop/AutomergeBuild \
#  -destination platform=macOS \
#  OTHER_DOCC_FLAGS="--experimental-documentation-coverage --level brief"
#
# generated coverage file (in .JSON format at
# Desktop/AutomergeBuild/Build/Products/Debug/Automerge.doccarchive/documentation-coverage.json
