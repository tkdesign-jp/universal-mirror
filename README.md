# Universal Mirror

A terminal-based, interactive **TUI wrapper around [HTTrack](https://www.httrack.com/)** for mirroring websites — including the Internet Archive's Wayback Machine — on macOS and Linux.

> 🇯🇵 日本語版は [README.ja.md](README.ja.md) を参照してください。

---

## What this is (and isn't)

This is **not a new download engine**. It drives `httrack` — all crawling, downloading, and link-rewriting is done by HTTrack itself. What this script adds is a **comfortable, terminal-native operating layer** on top of it:

- A `raspi-config`-style interactive TUI (via `whiptail`), so you don't have to memorize HTTrack's long option strings.
- Automatic detection of Wayback Machine URLs, with date-pattern handling that is fiddly to do by hand.
- A curated default exclusion list (social media, trackers, analytics, search engines) that's easy to edit and extend.
- Sensible safety rails (delete confirmation, output-path guards, numeric validation, cancel handling on every screen).

It fills a gap that GUI apps (WinHTTrack, SiteSucker) and raw CLI usage (`wget`/`httrack`) leave open: **a guided experience that runs entirely inside a terminal** — ideal over SSH, on headless servers, or for anyone who finds raw `wget` flags tedious but doesn't want a GUI.

---

## Limitations (read before using)

Because this wraps HTTrack, it inherits HTTrack's limits:

- **JavaScript-heavy / dynamic sites (SPAs) are not fully captured.** HTTrack downloads static assets and HTML; content rendered client-side at runtime generally won't be retrieved. If you need JS rendering, a browser-engine tool (SingleFile, browser-based archivers) is the better fit.
- **Wayback Machine support is best-effort, not perfect.** HTTrack does not flawlessly rewrite the Internet Archive's `/web/<timestamp>/` link prefixes, and some resource variants (`_if_`, `_cs_`, `_js_`, etc.) get partially missed. The script's exclusion filters mitigate this, but expect some broken internal links when browsing a Wayback mirror locally. For high-fidelity Wayback archiving, consider dedicated tools (e.g. `waybackpack`).
- Normal (live) site mirroring is the fully-supported path. Wayback is a convenience layer.

---

## Responsible use

This tool sets `--robots=0` (ignores `robots.txt`) and spoofs a browser User-Agent **by default**. These are deliberate choices suited to personal archiving, but they mean you can place load on a site that didn't invite it.

Please:

- Use it for **personal archiving and offline reading**, not for scraping at scale or republishing others' content.
- **Respect the target site's Terms of Service and `robots.txt`** where applicable.
- Keep the connection rate low (the default is 2/sec) and avoid hammering small or non-commercial sites.
- Do not use it against sites that prohibit automated mirroring.

You are responsible for how you use it.

---

## Requirements

| Dependency | Purpose | Install |
|---|---|---|
| `httrack` | Download engine (required) | `brew install httrack` / `apt install httrack` / `dnf install httrack` / `pacman -S httrack` |
| `whiptail` | TUI rendering (required) | macOS/Fedora: `brew install newt` / `dnf install newt` &nbsp; Debian/Ubuntu: `apt install whiptail` &nbsp; Arch: `pacman -S newt` |

`bash` 4+ is assumed. On macOS the system `bash` is old (3.2); if you hit issues, install a newer bash via Homebrew (`brew install bash`).

The script checks for both dependencies on startup and offers to install them via your detected package manager.

---

## Installation

```bash
git clone https://github.com/tkdesign-jp/universal-mirror.git
cd universal-mirror
chmod +x mirror.sh
./mirror.sh
```

On first run, the script generates two editable filter files in its own directory:

- `exclusions.txt` — default exclusion patterns (social/tracking/analytics/search).
- `wayback_extras.txt` — extra exclusions used only in Wayback mode.

---

## Usage

Just run it and follow the prompts:

```bash
./mirror.sh
```

The interactive flow (7 steps):

1. **URL** — paste a normal URL *or* a full Wayback URL. Wayback URLs are auto-detected.
2. **Wayback mode** — for a normal URL, choose whether to treat it as a live mirror or route it through the Wayback Machine.
3. **Date pattern** (Wayback only) — `2011` (whole year, recommended), `201105` (month), or `20110510` (single day).
4. **Domain scope** — restrict crawling to a domain (auto-detected from the URL).
5. **Output directory** — where the mirror is saved. If it already exists, you can overwrite, resume (`--update`), or cancel.
6. **Exclusion file** — pick the default, any `exclusions_*.txt` in the script directory, or a custom path.
7. **Performance** — recursion depth and connections-per-second.
8. **Run mode** — foreground (live progress) or background (`nohup`, with monitoring commands shown).

Press **ESC** or **Cancel** on any screen to abort cleanly.

### Resuming an interrupted run

Point it at an existing output directory and choose **resume**. The script rebuilds the full command and appends `--update`, so HTTrack reuses its cache while honoring any changed depth / filters / exclusions you set this time around.

---

## Customizing exclusions

`exclusions.txt` uses HTTrack's filter syntax — one pattern per line, `#` for comments:

```
# Exclude a whole domain
-*example-tracker.com*

# Exclude a path
-*/ads/*
```

To keep multiple named exclusion sets, drop additional files named `exclusions_<something>.txt` into the script directory; they'll appear as choices in step 6.

---

## Why HTTrack (and not wget)?

For Wayback mirroring and recursive offline browsing with link remapping, HTTrack tends to be more turnkey than `wget --mirror` for non-experts. `wget` is leaner and scriptable but requires more flags and manual link handling. This wrapper deliberately chooses HTTrack for the guided, offline-browsing use case. If you live on the command line and want maximum control, raw `wget` may suit you better — and that's fine.

---

## License

[MIT](LICENSE) — do what you like, no warranty. HTTrack itself is GPLv3; this script only *invokes* it and is independently licensed.

---

## Acknowledgements

Built on [HTTrack](https://www.httrack.com/) by Xavier Roche and contributors. The TUI uses `whiptail` (newt).
