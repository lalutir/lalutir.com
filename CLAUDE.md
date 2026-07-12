# lalutir.com

Personal site: resume + portfolio, self-hosted on a single DigitalOcean droplet behind Caddy. Design system is **Seaglass** — soft, tinted glass. Read this whole file before touching any page; it's short on purpose.

## Site map

| Path | Purpose | Status |
|---|---|---|
| `/` | Home — hero, featured work (2 projects), infra note | Real |
| `/portfolio/` | Full write-ups: World Cup Simulator, P2000 Reader, "more on the way" | Real |
| `/about/` | Background + "Currently" | **Placeholder — see below** |
| `/resume/` | Experience, skills, education, PDF download | **Placeholder — see below** |
| `/contact/` | Email, GitHub, LinkedIn | **LinkedIn is a placeholder** |
| `/404.html` | Custom not-found page | Real, wired via Caddyfile |

## What's placeholder — fill these in before calling it done

- `/about/` — "Background" is a plausible draft grounded in the two real projects, not verified biography. "Currently" needs to reflect whatever's actually true right now.
- `/resume/` — Experience and Education entries are format examples (`[Company]`, `[Month Year]`) — not real history. Skills section *is* real (pulled from what the two projects demonstrably use), just expand it if there's more elsewhere.
- `/contact/` — LinkedIn URL and its detail line.
- `/resume.pdf` — the download button on `/resume/` points here; the file doesn't exist yet.
- `/assets/og-image.png`, `/assets/favicon.svg` — referenced in every page's `<head>`. Pages work fine without them (graceful fallback, no visual break), but add them when convenient.

**Get these from the site owner directly — don't invent biographical details to fill the gaps.**

## Design system — Seaglass

Tumbled sea glass, not "frosted UI glass." Frosted, tinted, never perfectly clear, edges softened rather than sharp — glass with a history, not a filter effect. Deliberately **not**: cream-plus-serif-plus-terracotta, near-black-plus-one-acid-accent, or plain white/grey iOS-style glass — the three defaults AI-generated design tends to land on.

Non-negotiable rules:
- Reference tokens only (`assets/css/tokens.css`). Never hardcode a hex, `rgba()`, or px spacing in a page or in `site.css`.
- Glass is always tinted (`--glass-tint-*`) — never plain white/grey translucent.
- `--cobalt-rare` appears **once per screen, max**. Its scarcity is the point.
- Respect `prefers-reduced-motion` *and* `prefers-reduced-transparency` — both are already handled in `tokens.css`; don't add new transitions/blur without checking both still apply.
- Display type (Fraunces) is forced to its low-`opsz` cut (`font-variation-settings: 'opsz' 12`) even at large sizes — left on auto it snaps to a tighter, higher-contrast cut, which fights the soft concept. This is already set on `h1, h2, h3` in `site.css`; keep it that way on any new heading style.
- Signature motion (hero glow follows the pointer; showcase cards sharpen into focus on scroll) lives in `assets/js/site.js` and is deliberately **not** applied to `/resume/` entries — that page is for scanning, not delight. Don't add it there.

Anti-patterns: numbered 01/02/03 markers unless content is a genuine sequence; more than one hero-style gradient per page; cards covering every inch of the `--sand` background.

## Infrastructure — don't relearn this by trial and error

- **Static only, no build step.** Caddy's `file_server` serves this repo's working directory directly on the droplet — `git pull` there is the entire deploy for content changes. Don't introduce a framework or build step without also updating `scripts/deploy.sh` to run it (see how `p2000-reader`'s deploy script does `npm install && npm run build` as the pattern to follow, if it ever comes to that).
- **Deploy:** `scripts/deploy.sh`, unchanged by this pass — SSHes to the droplet, `git pull`s, re-applies `caddy/Caddyfile`, reloads Caddy.
- **Caddyfile changed this pass:** removed the old `try_files {path} /index.html` fallback (SPA-style — it silently served the homepage for *any* typo'd URL, which is wrong for a real multi-page site) in favor of plain `file_server` (which serves each folder's `index.html` automatically) plus a `handle_errors` block pointing at `/404.html`. Run `caddy validate --config caddy/Caddyfile` before deploying if you touch it again.
- **The two subdomains are separate repos** (`world-cup-predictor`, `p2000-reader`), each with its own Caddy snippet and deploy script. Nothing in this repo should reference or affect them beyond linking out.
- **All internal links are absolute** (`/portfolio/`, never `portfolio/` or `../portfolio/`) — required for pages at different folder depths to link correctly.

## Adding a page or a portfolio project

**New page:** new folder + `index.html`, copy the `<head>`/nav/footer block from an existing page, add the nav link to `nav-links` **on every page** (no templating here, see tradeoff below), and add the URL to `sitemap.xml`.

**New portfolio project:** copy an existing `.project` block in `/portfolio/index.html`, and consider adding a matching `.work-card` to the home page's featured-work section if it's a flagship piece.

## A known tradeoff

Nav and footer are duplicated by hand across every page rather than templated — kept that way to match this repo's existing zero-build-step philosophy (its own README: "This repo contains only the landing page and top-level Caddy config"). If hand-editing six copies of the nav ever gets painful, the natural next step is a light static site generator (Eleventy, for instance) or a small script that stitches shared partials at commit time — not needed yet, just worth knowing it's the escape hatch.

## When to commit

- Create commits after completing each logical unit of work.
- Do not push to the remote repository unless asked.
- Use conventional commit messages (e.g. "feat:", "fix:", "refactor:").