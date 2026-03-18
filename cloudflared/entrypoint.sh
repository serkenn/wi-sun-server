#!/bin/sh
set -eu

if [ -z "${CF_TUNNEL_TOKEN:-}" ]; then
  echo "CF_TUNNEL_TOKEN is not set. cloudflared stays idle."
  exec sleep infinity
fi

exec cloudflared tunnel --no-autoupdate run --token "${CF_TUNNEL_TOKEN}"
