# lalutir.com

Landing page and infrastructure config for **lalutir.com** — a static portfolio page that links out to a small set of side projects, each running as its own subdomain on the same server.

This repo contains only the landing page and the top-level Caddy config. The projects behind each subdomain live in their own repositories and are deployed independently (see [Subdomains](#subdomains) below).

## Contents

- [Domain & DNS](#domain--dns)
- [Hosting](#hosting)
- [Architecture](#architecture)
- [This repo](#this-repo)
- [Deploying the main site](#deploying-the-main-site)
- [Subdomains](#subdomains)
  - [world-cup-simulation.lalutir.com](#world-cup-simulationlalutircom)
  - [p2000.lalutir.com](#p2000lalutircom)
- [Adding a new subdomain](#adding-a-new-subdomain)
- [Troubleshooting](#troubleshooting)

## Domain & DNS

- Domain: **lalutir.com**
- Registrar / DNS: **Cloudflare**
- DNS records: a single `A` record for `lalutir.com` (and any subdomain records, e.g. `world-cup-simulation`, `p2000`) pointing at the Droplet's public IP.
- Cloudflare's proxy ("orange cloud") can be left on. If it's enabled, **SSL/TLS mode must be set to `Full (strict)`** in the Cloudflare dashboard under SSL/TLS → Overview — otherwise Cloudflare will fail to connect to Caddy's Let's Encrypt certificate over HTTPS.
- TLS certificates themselves are **not managed in Cloudflare** — Caddy obtains and renews them automatically from Let's Encrypt on the origin server. No manual certificate steps are needed as long as ports 80 and 443 are open and DNS resolves to the Droplet.

## Hosting

Everything — the main site and every subdomain — runs on a **single DigitalOcean Droplet**:

- OS: Ubuntu 22.04+
- Web server: [Caddy](https://caddyserver.com/) (reverse proxy + static file server, automatic HTTPS)
- Deploy user: `lalutir` (non-root, passwordless `sudo` scoped to the specific commands each project's deploy script needs — `cp`, `systemctl`)
- Each project lives in its own directory under `/home/lalutir/`

There is no container orchestration, load balancer, or CI/CD pipeline. Deploys are manually triggered, but not manual SSH sessions — each project's deploy script connects to the Droplet itself (over SSH) to pull the latest code and reload the relevant service.

## Architecture

```
Cloudflare (DNS + proxy, lalutir.com)
        │
        ▼
DigitalOcean Droplet
        │
        ▼
  Caddy (ports 80/443, automatic HTTPS)
        │
        ├── lalutir.com                        → /home/lalutir/lalutir.com            (this repo — static)
        ├── world-cup-simulation.lalutir.com    → /home/lalutir/world-cup-predictor    (static)
        └── p2000.lalutir.com                   → /home/lalutir/p2000-reader/frontend/web/dist  (static)
                                                 → reverse_proxy localhost:8000 for /api/*
                                                     └── p2000 systemd service (FastAPI, port 8000, internal only)
```

Caddy is configured with a **single top-level `Caddyfile`** (owned by this repo) that only defines the main `lalutir.com` site and then imports every file in `/etc/caddy/conf.d/*.caddy`:

```caddyfile
lalutir.com {
    root * /home/lalutir/lalutir.com
    try_files {path} /index.html
    file_server
}

import /etc/caddy/conf.d/*.caddy
```

Each subdomain project ships its **own** `*.caddy` snippet in its own repo (e.g. `world-cup.caddy`, `p2000.caddy`) and copies it into `/etc/caddy/conf.d/` as part of its own deploy script. This means:

- The main Caddyfile (this repo) rarely changes — only when the top-level domain's own config changes.
- Adding, changing, or removing a subdomain never requires touching this repo — it's entirely self-contained in the subdomain's own project and deploy script.

## This repo

```
.
├── index.html            # the landing page served at lalutir.com
├── caddy/
│   └── Caddyfile          # top-level Caddy config (main domain + import of conf.d/*)
└── scripts/
    └── deploy.sh          # SSHes into the Droplet, pulls the repo, re-applies caddy/Caddyfile, reloads Caddy
```

`scripts/deploy.sh` runs **locally** — it SSHes into the Droplet itself, so there's no manual login step. It pulls the latest code on the Droplet, then re-applies the **Caddy config** (it does not copy `index.html` — that comes from `git pull`):

```bash
#!/usr/bin/env bash
set -euo pipefail

DROPLET_USER="${DROPLET_USER:-lalutir}"
DROPLET_HOST="${DROPLET_HOST:?...}"
REMOTE_PATH="${REMOTE_PATH:-/home/lalutir/lalutir.com}"

ssh "${DROPLET_USER}@${DROPLET_HOST}" bash -s <<EOF
cd "${REMOTE_PATH}"
git pull
sudo cp caddy/Caddyfile /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
EOF
```

## Deploying the main site

The Droplet keeps its own clone of this repo at `/home/lalutir/lalutir.com`, which is exactly what Caddy's `root` points at. To update the live landing page:

```bash
# 1. Push your changes to GitHub
git push

# 2. Deploy
DROPLET_HOST=<droplet-ip> bash scripts/deploy.sh
```

No manual SSH login is needed — `deploy.sh` connects to the Droplet itself, runs `git pull` there, and (since Caddy serves `index.html` directly from that working copy via `file_server`) that alone is enough to update the page's content. The script always re-applies `caddy/Caddyfile` and reloads Caddy too, which is a no-op unless that file changed.

Override `DROPLET_USER` (default `lalutir`), `REMOTE_PATH` (default `/home/lalutir/lalutir.com`), or set `SSH_KEY` to point at a specific private key, the same way `world-cup-predictor`'s `deploy_site.sh` does.

## Subdomains

Both subdomains are self-contained projects: each owns its own Caddy snippet, its own deploy script, and (for p2000) its own systemd service. Updating them never requires changes in this repo.

### world-cup-simulation.lalutir.com

**Repo:** [github.com/lalutir/world-cup-predictor](https://github.com/lalutir/world-cup-predictor)

A Python pipeline that simulates the 2026 FIFA World Cup knockout phase 1,000,000 times (Elo ratings + a trained match-outcome model + Monte Carlo simulation) and renders the results as a static dashboard.

**How it's served:**

```
world-cup-simulation.lalutir.com {
    root * /home/lalutir/world-cup-predictor
    file_server
}
```

Purely static — Caddy just serves whatever is in `/home/lalutir/world-cup-predictor`. There is no backend process for this subdomain.

**How it's updated:** the site is generated locally (or wherever the pipeline is run), then pushed to the Droplet over `rsync`/`scp` via that repo's `scripts/deploy_site.sh`:

```bash
# In the world-cup-predictor repo, after running the simulation:
python -m src.simulator.montecarlo          # regenerates site/

DROPLET_HOST=<droplet-ip> DROPLET_USER=<droplet-user> bash scripts/deploy_site.sh
```

This copies the generated `site/` directory straight into `/home/lalutir/world-cup-predictor` over SSH — no `git pull` on the Droplet is involved for this project, and no service restart is needed since it's static content. The Caddy snippet (`caddy/world-cup.caddy`) only needs to be (re-)copied to `/etc/caddy/conf.d/` manually the first time it's set up.

### p2000.lalutir.com

**Repo:** [github.com/lalutir/p2000-reader](https://github.com/lalutir/p2000-reader)

A live feed of Dutch emergency-services (P2000) alerts — fire, ambulance, police — scraped from `p2000-online.net` and broadcast to connected browsers over WebSocket, with optional Web Push notifications. No database; the last 50 alerts are kept in memory on the server and in the browser's `localStorage`.

**How it's served:**

```
p2000.lalutir.com {
    handle /api/* {
        reverse_proxy localhost:8000 {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
        }
    }
    handle {
        root * /home/lalutir/p2000-reader/frontend/web/dist
        try_files {path} /index.html
        file_server
    }
}
```

- `/api/*` (including the WebSocket connection) is reverse-proxied to a **FastAPI backend** running locally on port 8000 (not exposed directly to the internet).
- Everything else is served as a static single-page app from the Vite production build (`frontend/web/dist`).

**Backend process:** managed by systemd (`p2000.service`), running under the `lalutir` user:

```ini
[Unit]
Description=P2000 Reader API
After=network.target

[Service]
User=lalutir
Group=lalutir
WorkingDirectory=/home/lalutir/p2000-reader/backend
ExecStart=/home/lalutir/p2000-reader/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
Environment=SCRAPE_INTERVAL_SECONDS=30

[Install]
WantedBy=multi-user.target
```

| Variable | Default | Description |
|---|---|---|
| `SCRAPE_INTERVAL_SECONDS` | `30` | How often the backend polls p2000-online.net for new alerts. Editing the service file and running `sudo systemctl daemon-reload && sudo systemctl restart p2000` changes it permanently; the interval dropdown in the app UI changes it live but reverts on restart. |

**How it's updated:** on the Droplet, after `git push` to GitHub:

```bash
cd ~/p2000-reader
bash scripts/deploy.sh
```

That script (from the p2000-reader repo) does everything in one pass:

```bash
#!/bin/bash
set -e

cd "$HOME/p2000-reader"
git pull

# Backend deps
python3 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt
deactivate

# Frontend build
cd "$HOME/p2000-reader/frontend/web"
npm install
npm run build
cd "$HOME/p2000-reader"

# Caddy snippet + systemd unit + restart
sudo cp caddy/p2000.caddy /etc/caddy/conf.d/p2000.caddy
caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo cp backend/p2000.service /etc/systemd/system/p2000.service
sudo systemctl daemon-reload
sudo systemctl enable p2000
sudo systemctl restart p2000
```

A fresh Droplet can be provisioned for this project from scratch with that repo's `scripts/setup.sh`, which installs Python/Node/git, clones the repo, grants the `lalutir` user passwordless `sudo` for exactly the commands `deploy.sh` needs, and then runs `deploy.sh` itself.

## Adding a new subdomain

The pattern established by the two existing subdomains is meant to be repeated for future projects, without ever touching this repo:

1. In the new project's own repo, add a `caddy/<name>.caddy` snippet scoped to its own subdomain (static `file_server`, or `reverse_proxy` to a local backend port, following the p2000 example if it needs an API).
2. Add an `A` record for the subdomain in Cloudflare, pointing at the same Droplet IP.
3. In the new project's deploy script, copy that snippet into `/etc/caddy/conf.d/<name>.caddy` and run `caddy validate` + `sudo systemctl reload caddy` — the same two-line pattern used by both existing projects.
4. If the project needs a background process, give it its own systemd unit (see `p2000.service` as a template) rather than running it manually or under Caddy.
5. Add a card for it to `index.html` in this repo, and deploy the main site as described above.

Because the main `Caddyfile` only ever does `import /etc/caddy/conf.d/*.caddy`, no step here requires editing or redeploying this repo's Caddy config.

## Troubleshooting

```bash
# Validate the full Caddy config (main Caddyfile + everything in conf.d/) before reloading
caddy validate --config /etc/caddy/Caddyfile

# Caddy logs
sudo journalctl -u caddy -f

# p2000 backend logs / status
sudo journalctl -u p2000 -f
sudo systemctl status p2000 --no-pager -l
```

If a subdomain isn't resolving or serving HTTPS, check in this order: Cloudflare DNS record exists and points at the Droplet → SSL/TLS mode is `Full (strict)` if the Cloudflare proxy is on → `caddy validate` passes → the relevant `*.caddy` snippet actually exists in `/etc/caddy/conf.d/`.
