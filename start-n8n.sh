#!/bin/sh
set -eu

echo "Waiting for ngrok tunnel..."
while true; do
  URL="$(node -e '
    const http = require("http");
    http.get("http://ngrok:4040/api/tunnels", (res) => {
      let data = "";
      res.on("data", (c) => data += c);
      res.on("end", () => {
        try {
          const j = JSON.parse(data);
          const t = (j.tunnels || []).find(x => String(x.public_url||"").startsWith("https://"));
          process.stdout.write(t ? t.public_url : "");
        } catch (e) {
          process.stdout.write("");
        }
      });
    }).on("error", () => process.stdout.write(""));
  ')"

  if [ -n "$URL" ]; then
    break
  fi
  sleep 1
done

export WEBHOOK_URL="${URL%/}/"
echo "Detected WEBHOOK_URL=$WEBHOOK_URL"

IMPORT_DIR="/import"
MARKER="/home/node/.n8n/.imported"

if [ -d "$IMPORT_DIR" ] && ls "$IMPORT_DIR"/*.json >/dev/null 2>&1; then
  if [ ! -f "$MARKER" ]; then
    EXISTING_NAMES="$(n8n list:workflow 2>/dev/null | awk -F'|' 'NF>1{print $2}')"
    if [ -n "$EXISTING_NAMES" ]; then
      IMPORT_NAMES="$(IMPORT_DIR="$IMPORT_DIR" node -e 'const fs=require("fs");const path=require("path");const dir=process.env.IMPORT_DIR;for (const f of fs.readdirSync(dir)) { if (!f.endsWith(".json")) continue; try { const j=JSON.parse(fs.readFileSync(path.join(dir,f),"utf8")); if (j && j.name) console.log(j.name); } catch(e) {} }')"
      all_present=1
      while IFS= read -r name; do
        [ -z "$name" ] && continue
        printf '%s\n' "$EXISTING_NAMES" | grep -Fqx "$name" || all_present=0
      done <<EOF
$IMPORT_NAMES
EOF
      if [ "$all_present" -eq 1 ]; then
        echo "Workflows already present; skipping import"
        touch "$MARKER"
      fi
    fi
  fi

  if [ ! -f "$MARKER" ]; then
    echo "Importing workflows from $IMPORT_DIR"
    if n8n import:workflow --separate --input="$IMPORT_DIR"; then
      touch "$MARKER"
    else
      echo "Workflow import failed; leaving marker unset"
    fi
  fi
fi

exec n8n
