#!/bin/bash
# Compila o Usage A.I e monta o "Usage A.I.app" nesta mesma pasta.
# Requer as ferramentas de linha de comando do Xcode:  xcode-select --install
set -e
cd "$(dirname "$0")"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc nao encontrado. Instale as ferramentas do Xcode com:"
  echo "  xcode-select --install"
  exit 1
fi

APP="Usage A.I.app"
echo "Compilando..."
swiftc -O UsageAI.swift -o UsageAI

echo "Montando $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv UsageAI "$APP/Contents/MacOS/UsageAI"
cp LogoClaude.png LogoChatGPT.png MenuBarIcon.png "$APP/Contents/Resources/"

# Icone do aplicativo (Finder, Dock, Spotlight), gerado a partir de AppIcon.png
if [ -f AppIcon.png ] && command -v iconutil >/dev/null 2>&1; then
  echo "Gerando o icone do aplicativo..."
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for TAM in 16 32 128 256 512; do
    sips -z $TAM $TAM AppIcon.png --out "$ICONSET/icon_${TAM}x${TAM}.png" >/dev/null
    sips -z $((TAM*2)) $((TAM*2)) AppIcon.png --out "$ICONSET/icon_${TAM}x${TAM}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Usage A.I</string>
    <key>CFBundleDisplayName</key><string>Usage A.I</string>
    <key>CFBundleIdentifier</key><string>com.jmschmitz.usageai</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>UsageAI</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo
echo "Pronto. Para abrir:  open \"$APP\""
echo "O icone aparece na barra de menus, ao lado do relogio."
