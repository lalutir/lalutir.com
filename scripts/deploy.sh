#!/usr/bin/env bash
# deploy.sh — Deploy lalutir.com to the DigitalOcean droplet over SSH.
#
# ── Quick start ────────────────────────────────────────────────────────────────
#   1. Push your changes to GitHub:
#        git push
#
#   2. Set DROPLET_HOST (once, or export it from your shell profile):
#        export DROPLET_HOST=<your-droplet-ip>
#
#   3. Deploy:
#        bash scripts/deploy.sh
#
# ── Configuration ──────────────────────────────────────────────────────────────
#   Override any variable by setting it as an environment variable before running.
#
#   DROPLET_USER   SSH username on the droplet              (default: lalutir)
#   DROPLET_HOST   Droplet IP address or hostname            (REQUIRED)
#   REMOTE_PATH    Path to this repo's clone on the droplet  (default: /home/lalutir/lalutir.com)
#   SSH_KEY        Path to your private SSH key              (optional — omit if ssh-agent handles it)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

DROPLET_USER="${DROPLET_USER:-lalutir}"
DROPLET_HOST="${DROPLET_HOST:-142.93.232.87}"
REMOTE_PATH="${REMOTE_PATH:-/home/lalutir/lalutir.com}"
SSH_KEY="${SSH_KEY:-}"

SSH_OPTS="-o StrictHostKeyChecking=accept-new"
if [[ -n "${SSH_KEY}" ]]; then
  SSH_OPTS+=" -i ${SSH_KEY}"
fi

TARGET="${DROPLET_USER}@${DROPLET_HOST}"

echo "──────────────────────────────────────────────────────"
echo "Deploying to ${TARGET}:${REMOTE_PATH}"
echo "──────────────────────────────────────────────────────"

# shellcheck disable=SC2086
ssh $SSH_OPTS "${TARGET}" bash -s <<EOF
set -euo pipefail
cd "${REMOTE_PATH}"
git pull
sudo cp caddy/Caddyfile /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
EOF

echo ""
echo "Deploy complete."
echo "Visit: https://lalutir.com"
