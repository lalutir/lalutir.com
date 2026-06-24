#!/bin/bash
set -euo pipefail

DEPLOY_DIR=/home/lalutir/lalutir.com

mkdir -p "$DEPLOY_DIR"
cp index.html "$DEPLOY_DIR/index.html"

sudo cp caddy/Caddyfile /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
