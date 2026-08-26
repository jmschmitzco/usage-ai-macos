#!/bin/bash
# Liga ou desliga a abertura automatica do Usage A.I no login.
# Uso:  ./iniciar-com-o-sistema.sh on    |    ./iniciar-com-o-sistema.sh off
set -e
cd "$(dirname "$0")"

PLIST="$HOME/Library/LaunchAgents/com.jmschmitz.usageai.plist"
APP="$(pwd)/Usage A.I.app"

case "$1" in
  on)
    if [ ! -d "$APP" ]; then
      echo "O aplicativo ainda nao existe. Rode antes:  ./criar-app.sh"
      exit 1
    fi
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.jmschmitz.usageai</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP/Contents/MacOS/UsageAI</string>
    </array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>
PLISTEOF
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
    echo "Ativado: o Usage A.I abre junto com o sistema."
    ;;
  off)
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Desativado."
    ;;
  *)
    echo "Uso: $0 on|off"
    exit 1
    ;;
esac
