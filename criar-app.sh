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
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo
echo "Pronto. Para abrir:  open \"$APP\""
echo "O icone aparece na barra de menus, ao lado do relogio."
