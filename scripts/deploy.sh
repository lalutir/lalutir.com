#!/bin/bash
set -euo pipefail

sudo cp caddy/Caddyfile /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
