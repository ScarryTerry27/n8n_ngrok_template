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

exec n8n