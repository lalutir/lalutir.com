#!/usr/bin/env bash
set -euo pipefail

HOST="lalutir@142.93.232.87"
REMOTE_DIR="/var/www/lalutir.com"

echo "Deploying index.html to $HOST:$REMOTE_DIR ..."
scp index.html "$HOST:$REMOTE_DIR/index.html"

echo "Done."
