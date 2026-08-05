# Ubuntu 26.04 LTS → Pure Vanilla GNOME Desktop

A single, well-tested shell script that turns a fresh **Ubuntu 26.04 LTS "Resolute Raccoon" Server** install into a clean, vanilla **GNOME 50** desktop — no Ubuntu skin, no Snap, no Yaru theme, no pre-installed bloat.

Install the Server ISO, run the script, reboot into a pristine GNOME desktop. That's it.

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [Target](#target)
- [Quick start](#quick-start)
- [What gets installed](#what-gets-installed)
- [What gets removed](#what-gets-removed)
- [What is kept (and why)](#what-is-kept-and-why)
- [How the script is ordered (and why)](#how-the-script-is-ordered-and-why)
- [Prerequisites](#prerequisites)
- [Verification](#verification)
- [Design notes](#design-notes)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [References](#references)
- [License](#license)
- [Disclaimer](#disclaimer)

---

## Why this exists

Ubuntu Desktop ships with a lot most people never asked for:

- The Ubuntu session, Yaru theme, and Ubuntu Shell extensions — a skin layered over vanilla GNOME
- Snap and snapd
- 23 GNOME utility apps (Calculator, Calendar, Maps, Weather, Contacts, Clocks, …)
- Ptyxis, Ubuntu's custom terminal
- A crash-dump kernel memory reservation (~512 MB, permanently unavailable to everything else)

This script strips all of that and leaves **pure upstream GNOME 50** — the same session you'd get on Fedora or a from-source GNOME build — while keeping what actually matters: NetworkManager, PipeWire, xdg user folders, GDM, alacritty.

---

## Target

| | |
|---|---|
| **OS** | Ubuntu 26.04 LTS "Resolute Raccoon" — Server edition |
| **Architecture** | x86_64 (amd64) |
| **Starting point** | Fresh Server install, no desktop environment |
| **Ending point** | Vanilla GNOME 50 desktop with alacritty + NetworkManager |

> **Not supported:** Ubuntu Desktop, Ubuntu flavours (Kubuntu/Xubuntu/etc.), 24.04 LTS or older, ARM, WSL. Close variants might work, but this is **only tested against 26.04 Server amd64**.

---

## Quick start

```bash
# 1. Boot your fresh Ubuntu 26.04 Server install

# 2. Run the script directly
curl -fsSL https://raw.githubusercontent.com/itsnin/ubuntu-debloat/main/debloat.sh | sudo bash

# 3. Reboot
sudo reboot
```

After reboot you'll land on the GDM login screen. Only the vanilla **"GNOME"** session is listed — the "Ubuntu" session doesn't exist anymore.

---

## What gets installed

### Core desktop

| Component | Package | Why |
|---|---|---|
| GNOME core | `gnome-core` (with `--no-install-recommends`) | Vanilla GNOME shell + session + control center |
| Display manager | `gdm3` | Boot into graphical target |
| File manager | `nautilus` | GNOME Files |
| Terminal | `alacritty` | GPU-accelerated terminal, author's choice |
| Networking | `network-manager` | What upstream GNOME expects; replaces netplan's networkd renderer |
| Audio | `pipewire-audio` | Modern audio stack |
| Camera | `gnome-snapshot` | GNOME's modern camera app (replaces Cheese) |
| Settings | `gnome-control-center`, `gnome-settings-daemon` | Standard GNOME settings UI |
| User folders | `xdg-user-dirs-gtk` | Creates `Desktop/`, `Documents/`, `Downloads/`, `Music/`, `Pictures/`, `Videos/` on first login |

> **Note:** `alacritty` lives in Ubuntu's `universe` component, not `main`. Server installs don't reliably ship `universe` enabled — it varies by ISO, installer, and image type — so the script enables it via `add-apt-repository universe` (installing `software-properties-common` first) before its one `apt-get update`. Skip this and the alacritty install a few steps later can fail outright under `set -e`.

### Extras (Section 6)

| Component | Package | Why |
|---|---|---|
| Fonts | `fonts-noto` | Comprehensive Unicode coverage — many languages, emoji |
| Virtualization | `gnome-boxes` | GNOME's VM manager, for running other OSes in VMs |
| Editor | `micro` | Terminal text editor with intuitive, Ctrl-based shortcuts |
| Extensions | `gnome-shell-extension-manager` | GUI for installing/managing GNOME Shell extensions |
| Utilities | `htop`, `wget` | Process viewer + HTTP fetch tool |
| Browser | Google Chrome | Direct `.deb` from `dl.google.com` — postinst adds Chrome's own apt repo so it keeps updating |
| Editor (GUI) | VS Code | Direct `.deb` from `code.visualstudio.com`; `debconf-set-selections` pre-answers the "add Microsoft's repo?" prompt so the install never hangs unattended |

### Development toolchain (Section 14, installed last)

Fully independent of the desktop conversion — its own step, after the GDM sanity check, so a failure here can't touch GNOME.

| Category | Packages | Why |
|---|---|---|
| Python | `python3`, `python3-pip`, `python3-venv`, `python3-dev`, `python3-full` | Full Python 3 dev environment |
| Python build deps | `libssl-dev`, `libffi-dev`, `zlib1g-dev`, `libbz2-dev`, `liblzma-dev`, `libreadline-dev`, `libsqlite3-dev`, `libncurses-dev` | Headers for building Python (e.g. via pyenv) and native extensions from source |
| C / C++ | `build-essential`, `gcc`, `g++`, `clang`, `clangd`, `clang-format`, `clang-tidy`, `make`, `cmake`, `ninja-build`, `gdb`, `pkg-config`, `valgrind`, `llvm` | Full compiler, debugger, and build-system toolchain |
| Rust | `rustc`, `cargo`, `rustfmt`, `rust-clippy` | Rust compiler and tooling |
| Java | `default-jdk`, `maven` | JDK + build tool |
| Node.js | `nodejs` | JS runtime |
| Databases | `sqlite3`, `postgresql-client`, `mariadb-client`, `pgcli`, `mycli` | CLI clients for local dev databases |
| Web tooling | `tidy`, `html-xml-utils`, `sassc` | HTML/CSS lint and build utilities |
| System | `ca-certificates`, `gnupg` | Certificate store + key management |

---

## What gets removed

### GNOME utility apps

These 23 apps are removed and held (`apt-mark hold`) so `apt upgrade` can never reinstall them. Each was checked against Ubuntu 26.04 resolute's `Packages.gz` to confirm none is a hard dependency of `gnome-shell`, `gdm3`, `gnome-control-center`, `gnome-session`, `nautilus`, or `ubuntu-server`:

```
gnome-calculator   gnome-calendar       gnome-characters     gnome-clocks
gnome-contacts     gnome-disk-utility   gnome-font-viewer    gnome-logs
gnome-maps         gnome-weather        gnome-sushi          gnome-system-monitor
gnome-text-editor  baobab               loupe                papers
showtime           simple-scan          gnome-connections    gnome-user-docs
yelp               orca                 gnome-software
```

### Other bloat

- `ptyxis` — Ubuntu's custom terminal, replaced by alacritty (also held)
- `snapd` — Snap runtime and daemon (also held)
- `gnome-core` — the metapackage wrapper, once everything it pulled in that we want is marked manual
- `kdump-tools` + `kexec-tools` — frees ~512 MB of reserved kernel memory
- `cloud-init` — server provisioning tooling, unwanted on a desktop

### Apt holds

Everything above — plus the 23 GNOME apps and the remaining Ubuntu-skin packages — gets `apt-mark hold`. `apt upgrade` can't reinstall any of it, and none of it can sneak back in as a transitive dependency either.

---

## What is kept (and why)

Three packages are **hard dependencies** of `gnome-shell` and cannot be removed or held without breaking GNOME outright. Getting this wrong is exactly what broke the previous version of this script.

| Package | Required by | Why it must stay |
|---|---|---|
| `tecla` | `gnome-shell`, `gnome-control-center` | Keyboard layout viewer; hard dep since GNOME 46 |
| `ubuntu-wallpapers` | `gnome-shell` | Ubuntu's patched `gnome-shell` depends on it |
| `ubuntu-wallpapers-resolute` | `ubuntu-wallpapers` | The 26.04 wallpaper pack (~63 MB) |

Remove or hold any of these and the breakage cascades `gnome-shell → gdm3 → gnome-session`, taking the desktop down with it. This is **Ubuntu Bug 1894347**, open since 2020 and still present in 26.04: <https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html>

The script marks all three as manually installed so `autoremove` never touches them.

---

## How the script is ordered (and why)

```
 0. Enable universe, apt-get update + apt-get upgrade  ← bring system to current
 1. Install gnome-core (--no-install-recommends)
 2. Install NetworkManager
 3. Install alacritty, register as default terminal (incl. gsettings for Ctrl+Alt+T)
 4. apt-mark manual EVERYTHING that must survive autoremove
 5. Enable gdm3 + set graphical.target      ← done EARLY, while gdm3 exists
 6. Install extras (htop, wget, fonts-noto, gnome-boxes, micro,
    gnome-shell-extension-manager, Chrome, VS Code)
 7. Remove kdump-tools (free 512 MB)
 8. Remove gnome-core metapackage
 9. Remove optional GNOME apps              ← app removal
10. Remove ptyxis + snapd + cloud-init
11. apt-mark hold everything unwanted       ← holding (ptyxis now held too)
12. apt autoremove --purge                  ← last step of the core conversion
13. Sanity check: gdm3.service exists?
14. Install development toolchain           ← independent of the desktop conversion
```

### Why GDM is enabled *before* the holds

If holding or autoremove goes sideways, `gdm3.service` is already registered and the box can still boot to a graphical target. The previous version of this script enabled GDM last — by which point `autoremove` had already purged `gdm3` (a hold had broken its dependency chain), producing:

```
Failed to enable unit: Unit gdm3.service does not exist
```

### Why app removal and holding are last

So a Ctrl-C mid-script still leaves you with a working GNOME install. Everything destructive happens at the end, once everything that matters is already protected by `apt-mark manual`.

### Why the dev toolchain install is separate and last

It's a large, unrelated package list (~50 packages) running under `set -euo pipefail` — one unavailable name would halt the script wherever it sits. Running it after the desktop conversion is already installed and sanity-checked means a failure here can never take GNOME/GDM down with it; at worst, just this block needs a rerun.

---

## Prerequisites

1. **A fresh Ubuntu 26.04 LTS Server install.** Not Ubuntu Desktop — this is a Server → Desktop conversion.
2. **Internet access** — the script installs packages and downloads Chrome from `dl.google.com` and VS Code from `code.visualstudio.com`.
3. **`sudo` privileges.**
4. **At least 5 GB free disk space** (GNOME + Chrome + VS Code + dev toolchain + dependencies).

---

## Verification

This script was checked by:

1. **Fetching the actual Ubuntu 26.04 resolute `Packages.gz` metadata** (main, universe, restricted, multiverse, updates, security — 8 sources) from `archive.ubuntu.com`.
2. **Building a pure-Python apt dependency resolver** that traces every install/remove/autoremove decision against that real metadata.
3. **Reverse-dependency analysis** of every package in the remove/hold list, confirming none is a hard dep of `gnome-shell`, `gdm3`, `gnome-control-center`, `gnome-session`, `nautilus`, or `ubuntu-server`.
4. **End-to-end simulation**, confirming:
   - `gdm3.service` exists at the end
   - All GNOME core packages survive `autoremove`
   - Kernel metapackages are never purged
   - All 23 optional GNOME apps are removed
   - `apt install gdm3` would still succeed even with the holds in place
5. **Real-world testing in VMware** on Ubuntu 26.04 LTS Server amd64.
6. **Real hardware** — the author runs this on their main laptop daily, always validated in a VMware VM first.
7. **Package-level inspection** of `adwaita-icon-theme` and `gsettings-desktop-schemas` `.deb` files — postinst scripts, filelists, gschema XML — to verify every gsettings-key claim in this document.

---

## Design notes

### `org.gnome.desktop.default-applications.terminal` is "deprecated" but still works

`gsettings-desktop-schemas 50.0` marks this key: "DEPRECATED: This key is deprecated and ignored. The default terminal is handled in GIO." **In practice**, GNOME 50 on Ubuntu 26.04 still reads it for the Ctrl+Alt+T keybinding — verified empirically. The script sets it anyway, since without it Ctrl+Alt+T does nothing. If a future GNOME release genuinely stops reading it, the script's `2>/dev/null || true` guard just makes it a no-op; set the keybinding manually via Settings → Keyboard → Shortcuts instead.

### `ubuntu-server` stays installed

The script deliberately doesn't remove the `ubuntu-server` metapackage — it's marked manual in section 4. `apt` keeps treating this as a Server system for metapackage-tracking purposes. To finish the conversion yourself:

```bash
sudo apt remove ubuntu-server
sudo apt autoremove --purge
```

That also frees `vim` (a hard dep of `ubuntu-server`) — the script leaves `vim` alone specifically because of that dependency.

---

## FAQ

**Q: Why Ubuntu Server as the base, not Ubuntu Desktop?**
A: Ubuntu Desktop ships with Snap, the Ubuntu session, Yaru, and roughly a gigabyte of extra packages. Starting from Server means starting clean — this script then installs only the GNOME packages you actually want.

**Q: Will this work on Ubuntu 26.10, 27.04, etc.?**
A: Not as-is. Package names and dependency chains shift between releases. Re-verify the dependency chains (the Verification section above explains how) and update the `apt-mark manual` and hold lists before trusting it on a new release.

**Q: Why alacritty and not ptyxis / gnome-terminal / ghostty?**
A: GPU-accelerated, and the author's preference. It lives in `universe`, which the script enables in section 0 before installing it. `ptyxis` (Ubuntu's default) gets removed and held so it can't come back. Want something else? Edit section 3 — and check whether your pick needs `universe` too.

**Q: Why keep `gnome-snapshot`? Isn't that just a camera app?**
A: It's part of GNOME Core and the modern replacement for Cheese (Ubuntu 24.04+ made the same switch: [OMG Ubuntu](https://www.omgubuntu.co.uk/2024/03/ubuntu-24-04-swaps-cheese-snapshot-webcam-app)). Tiny, harmless, stays.

**Q: Can I remove `vim`? The script doesn't.**
A: `ubuntu-server` (still installed) hard-depends on it. Remove `ubuntu-server` first:
```bash
sudo apt remove ubuntu-server
sudo apt autoremove --purge
```
That's a separate decision from what this script does on its own.

**Q: The script installed Google Chrome. I don't want it.**
A: Comment out section 6's Chrome block (`wget` + `apt-get install`).

**Q: The script installed VS Code. I don't want it.**
A: Same idea — comment out the VS Code block in section 6 (`debconf-set-selections` + `wget` + `apt-get install`, right after Chrome).

**Q: How much disk space does this actually save vs. Ubuntu Desktop?**
A: Roughly 1.5–2 GB (Snap runtime + Ubuntu session + 23 GNOME apps + non-resolute wallpapers + Ptyxis), plus ~512 MB of kernel-reserved crash-dump memory freed on top.

**Q: Is this safe on a production server?**
A: **No.** This turns a server into a desktop. If it's a production box, don't run this — use a fresh Server install if you want a desktop out of it.

**Q: Why does the script run `apt-get upgrade` at the start?**
A: To start from a known-good, current baseline — if Ubuntu ships a broken package, that's between you and Ubuntu, not this script. Every later `apt-get install` call pulls the latest available version regardless.

---

## Troubleshooting

Something went wrong? See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — covers `gdm3.service` missing, black screens after reboot, no network after reboot, "kept back" warnings, the terminal keybinding not sticking, and how to undo holds (partially or completely).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for reporting bugs, verifying packages, and submitting pull requests.

---

## References

### Bug reports and dependency verification

- **Ubuntu Bug 1894347** — "Can't uninstall ubuntu-wallpapers and ubuntu-wallpapers-bionic without gnome-shell": <https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html>
- **Ubuntu 26.04 Packages.gz** — the metadata used for verification: <http://archive.ubuntu.com/ubuntu/dists/resolute/main/binary-amd64/Packages.gz>

### Package references

- **Ubuntu Repositories: main vs universe vs multiverse** — why alacritty needs `universe` enabled: <https://help.ubuntu.com/community/Repositories/Ubuntu>
- **gnome-snapshot replaces Cheese** — <https://www.omgubuntu.co.uk/2024/03/ubuntu-24-04-swaps-cheese-snapshot-webcam-app>
- **xdg-user-dirs** — creates Desktop/Documents/Downloads/etc.: <https://wiki.archlinux.org/title/XDG_user_directories>
- **gsettings-desktop-schemas 50.0** — source of the `default-applications.terminal` schema definition: <https://packages.ubuntu.com/resolute/gsettings-desktop-schemas>
- **VS Code on Linux (`.deb`)** — the `add-microsoft-repo` debconf prompt this script pre-answers: <https://code.visualstudio.com/docs/setup/linux>

### GNOME 50 / Wayland

- **GNOME 50 removes X11 session support** (gHacks) — <https://www.ghacks.net/2025/09/13/gnome-50-releases-with-x11-session-support-removed-and-wayland/>
- **Fedora Wiki: Wayland-Only GNOME** — background on the X11 removal: <https://fedoraproject.org/wiki/Changes/WaylandOnlyGNOME>

### Apt / dpkg internals

- **Debian alternatives system** — how `update-alternatives --install` works (a filesystem tool, not display-protocol-aware): <https://wiki.debian.org/DebianAlternatives>
- **apt autoremove protects the running kernel** via `/etc/apt/apt.conf.d/01autoremove` — kernel metapackages still need to be manual so future kernel upgrades install: <https://askubuntu.com/questions/563483/why-doesnt-apt-get-autoremove-remove-my-old-kernels>

---

## License

GNU Affero General Public License v3.0 (AGPL-3.0). Full text in [LICENSE](LICENSE).

In short: use, modify, and distribute this script freely, including as part of a network service — but any modified version you make available to users over a network must also be AGPL-3.0-licensed with its source available.

---

## Disclaimer

This script modifies your system's package state, removes packages, sets apt holds, and changes boot targets. **Test it in a VM first.** Snapshot before running on real hardware. The author isn't responsible for broken systems, lost data, or bricked installs.
