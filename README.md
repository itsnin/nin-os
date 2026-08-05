# Ubuntu 26.04 LTS → Pure Vanilla GNOME Desktop

A single, well-tested shell script that transforms a fresh **Ubuntu 26.04 LTS "Resolute Raccoon" Server** install into a clean, vanilla **GNOME 50** desktop — no Ubuntu skin, no Snap, no Yaru theme, no pre-installed bloat apps.

For people who want a "better Ubuntu": install the Server ISO, run this script, reboot into a pristine GNOME desktop.

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
- [Issues worth noting](#issues-worth-noting)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Contributing](#contributing)
- [References](#references)
- [License](#license)
- [Disclaimer](#disclaimer)

---

## Why this exists

Ubuntu Desktop ships with a lot of stuff many people don't want:

- The Ubuntu session, Yaru theme, and Ubuntu extensions (a skin layered over vanilla GNOME)
- Snap and snapd
- 23 GNOME utility apps (Calculator, Calendar, Maps, Weather, Contacts, Clocks, …)
- The Ptyxis terminal (Ubuntu's custom terminal)
- Crash-dump kernel memory reservation (~512 MB)

This script removes all of that and gives you **pure upstream GNOME 50** — the same session you'd get on Fedora or a from-source GNOME install — while keeping the things you actually need: NetworkManager, PipeWire, xdg user folders, GDM, alacritty.

---

## Target

| | |
|---|---|
| **OS** | Ubuntu 26.04 LTS "Resolute Raccoon" — Server edition |
| **Architecture** | x86_64 (amd64) |
| **Starting point** | Fresh Server install, no desktop environment |
| **Ending point** | Vanilla GNOME 50 desktop with alacritty + NetworkManager |

> **Not supported:** Ubuntu Desktop, Ubuntu flavours (Kubuntu/Xubuntu/etc.), 24.04 LTS or older, ARM, WSL. The script may work on close variants but is **only tested against 26.04 Server amd64**.

---

## Quick start

```bash
# 1. Boot your fresh Ubuntu 26.04 Server install

# 2. Run the script directly
curl -fsSL https://raw.githubusercontent.com/itsnin/ubuntu-debloat/main/debloat.sh | sudo bash

# 3. Reboot
sudo reboot
```

After reboot you'll see the GDM login screen. Log in — only the vanilla **"GNOME"** session is available (the "Ubuntu" session no longer exists).


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

> **Note:** `alacritty` lives in Ubuntu's `universe` component, not `main`. Server installs don't reliably ship `universe` enabled (it varies by ISO/installer/image type), so the script enables it via `add-apt-repository universe` (installing `software-properties-common` first) before its one `apt-get update` — otherwise the alacritty install below can fail outright under `set -e`.

### Extras (Section 6)

| Component | Package | Why |
|---|---|---|
| Fonts | `fonts-noto` | Comprehensive Unicode font coverage (many languages, emoji) |
| Virtualization | `gnome-boxes` | GNOME's VM manager (for running other OSes in VMs) |
| Editor | `micro` | Modern terminal text editor (intuitive nano-style, Ctrl-based shortcuts) |
| Extensions | `gnome-shell-extension-manager` | GUI for installing/managing GNOME Shell extensions |
| Utilities | `htop`, `wget` | Process viewer + HTTP fetch tool |
| Browser | Google Chrome | Installed via direct `.deb` from `dl.google.com` (postinst auto-adds the Chrome apt repo for updates) |
| Editor (GUI) | VS Code | Installed via direct `.deb` from `code.visualstudio.com` (postinst auto-adds Microsoft's apt repo for updates); `debconf-set-selections` pre-answers the repo prompt so the install doesn't hang unattended |

### Development toolchain (Section 14, installed last)

Independent of the desktop conversion — installed in its own step after the GDM sanity check, so a problem here can't affect the GNOME/GDM install.

| Category | Packages | Why |
|---|---|---|
| Python | `python3`, `python3-pip`, `python3-venv`, `python3-dev`, `python3-full` | Full Python 3 dev environment |
| Python build deps | `libssl-dev`, `libffi-dev`, `zlib1g-dev`, `libbz2-dev`, `liblzma-dev`, `libreadline-dev`, `libsqlite3-dev`, `libncurses-dev` | Headers needed to build Python (e.g. via pyenv) and native extensions from source |
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

These 23 apps are removed and held (`apt-mark hold`) so `apt upgrade` can never reinstall them. Each was verified against Ubuntu 26.04 resolute `Packages.gz` to confirm none is a hard dependency of `gnome-shell`, `gdm3`, `gnome-control-center`, `gnome-session`, `nautilus`, or `ubuntu-server`:

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
- `gnome-core` — the metapackage wrapper (after marking what we want as manual)
- `kdump-tools` + `kexec-tools` — frees ~512 MB of reserved kernel memory
- `cloud-init` — server provisioning tool, unwanted on a desktop

### Apt holds

All of the above (plus the 23 GNOME apps and Ubuntu-skin packages) are marked with `apt-mark hold`, ensuring `apt upgrade` can never reinstall them and they won't come back as a transitive dependency.

---

## What is kept (and why)

These three packages are **hard dependencies** of `gnome-shell` and CANNOT be removed or held without breaking GNOME. This was the bug that broke the previous version of this script.

| Package | Required by | Why it must stay |
|---|---|---|
| `tecla` | `gnome-shell`, `gnome-control-center` | Keyboard layout viewer; hard dep since GNOME 46 |
| `ubuntu-wallpapers` | `gnome-shell` | Ubuntu's patched `gnome-shell` depends on it |
| `ubuntu-wallpapers-resolute` | `ubuntu-wallpapers` | The 26.04 wallpaper pack (~63 MB) |

Removing or holding any of these cascades through `gnome-shell → gdm3 → gnome-session` and breaks the desktop. This is **Ubuntu Bug 1894347**, open since 2020 and still present in 26.04:
<https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html>

The script marks these three as manually installed so `autoremove` will never touch them.

---

## How the script is ordered (and why)

`apt-get update` + `apt-get upgrade` run first, then:

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

### Why GDM is enabled BEFORE the apt holds

If anything goes wrong during holding or autoremove, `gdm3.service` is already registered and the system can still boot to a graphical target. The previous version of this script enabled GDM at the very end — by which point `autoremove` had already purged `gdm3` (because a hold broke its dependency chain), producing:

```
Failed to enable unit: Unit gdm3.service does not exist
```

### Why app removal and holding are LAST

So that if you Ctrl-C the script mid-way, you still have a working system with GNOME installed. The destructive operations happen at the end, after everything important is already protected by `apt-mark manual`.

### Why the development toolchain install is separate and LAST

It's a large, independent package list (~50 packages) with no relationship to the GNOME/GDM conversion. The script runs under `set -euo pipefail`, so one unavailable package name would halt the script wherever it sits. Running it after the desktop conversion is already installed and sanity-checked means a failure here can never take down GNOME/GDM — at worst, only this block needs a rerun.

---

## Prerequisites

1. **A fresh Ubuntu 26.04 LTS Server install.** Don't run this on Ubuntu Desktop — it's designed for Server → Desktop conversion.
2. **Internet access** (the script installs packages and downloads Chrome from `dl.google.com` and VS Code from `code.visualstudio.com`).
3. **`sudo` privileges.**
4. **At least 5 GB free disk space** (GNOME + Chrome + dev toolchain + deps).

---

## Verification

This script was verified by:

1. **Fetching the actual Ubuntu 26.04 resolute `Packages.gz` metadata** (main, universe, restricted, multiverse, updates, security — 8 sources) from `archive.ubuntu.com`.
2. **Building a pure-Python apt dependency resolver** that traces every install/remove/autoremove decision using that real metadata.
3. **Reverse-dependency analysis** of every package in the remove/hold list to confirm none is a hard dep of `gnome-shell`, `gdm3`, `gnome-control-center`, `gnome-session`, `nautilus`, or `ubuntu-server`.
4. **End-to-end simulation** of the script confirming:
   - `gdm3.service` exists at the end
   - All GNOME core packages survive `autoremove`
   - Kernel metapackages are not purged
   - All 23 optional GNOME apps are removed
   - Recovery `apt install gdm3` would succeed even after the holds are in place
5. **Real-world testing in VMware** on Ubuntu 26.04 LTS Server amd64.
6. **Tested on real hardware** — the author runs this script on their main laptop daily, after first validating each change in a VMware VM.
7. **Package-level inspection** of `adwaita-icon-theme` and `gsettings-desktop-schemas` `.deb` files (extracting postinst scripts, filelists, and gschema XML) to verify every claim about gsettings keys.

---

## Issues worth noting

### `org.gnome.desktop.default-applications.terminal` is "deprecated" but still works

The schema description in `gsettings-desktop-schemas 50.0` marks this key as "DEPRECATED: This key is deprecated and ignored. The default terminal is handled in GIO." **However**, GNOME 50 on Ubuntu 26.04 still reads it for the Ctrl+Alt+T keybinding (verified empirically). The script sets it anyway because without it, Ctrl+Alt+T does nothing. If a future GNOME release actually stops reading it, the script's `2>/dev/null || true` guard ensures no failure — the user can set up Ctrl+Alt+T manually via Settings → Keyboard → Shortcuts.

### `apt upgrade` may print "kept back" warnings

After running this script, `apt update && apt upgrade` may print messages like:

```
The following packages have been kept back:
  gnome-calculator gnome-calendar ...
```

This is **expected and harmless** — the apt hold blocks these packages from being installed. The packages listed are the ones we explicitly held. No action needed.

### `ubuntu-server` metapackage is still installed

The script does NOT remove the `ubuntu-server` metapackage (it's marked manual in section 4). This means `apt` still considers this an Ubuntu Server system for the purposes of metapackage tracking. If you want to fully convert to a desktop system, run manually after the script:

```bash
sudo apt remove ubuntu-server
sudo apt autoremove --purge
```

This will also free `vim` (which `ubuntu-server` hard-depends on) — the script does NOT remove `vim` itself because of this hard dependency.

### Running the script from a root shell (not via `curl | sudo bash`)

The `gsettings set` calls for the default terminal only run if `$SUDO_USER` is set — i.e., someone ran the script via `curl … | sudo bash` from a logged-in user session. If you run the script from a root shell or via cloud-init, these gsettings calls skip silently. After your first GNOME login, run manually:

```bash
gsettings set org.gnome.desktop.default-applications.terminal exec 'alacritty'
gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
```

---

## Troubleshooting

### `Failed to enable unit: Unit gdm3.service does not exist`

This means `gdm3` was removed somewhere along the way. The current version of the script should not produce this — but if it does, run:

```bash
sudo apt-mark unhold $(apt-mark showhold)  # clear any holds
sudo apt install gdm3 gnome-shell gnome-session
sudo systemctl enable gdm3
sudo systemctl set-default graphical.target
```

If `apt install gdm3` fails with "ubuntu-wallpapers-resolute is not installable", check `apt-mark showhold` — `ubuntu-wallpapers-resolute` must NOT be in that list. Run `sudo apt-mark unhold ubuntu-wallpapers-resolute` if present, then `sudo apt update && sudo apt install gdm3`.

### Black screen after reboot

Wait 30 seconds, then Ctrl+Alt+F2 to switch to a TTY. Log in and run:

```bash
sudo systemctl status gdm3
sudo journalctl -u gdm3 -b
```

If GDM is failing because of a graphics driver issue, install the appropriate driver:

```bash
# For VMware:
sudo apt install open-vm-tools open-vm-tools-desktop
# For VirtualBox:
sudo apt install virtualbox-guest-utils virtualbox-guest-x11
# For real hardware with NVIDIA:
sudo ubuntu-drivers autoinstall
```

### No network after reboot

NetworkManager should manage networking automatically. If not:

```bash
nmcli device status
sudo nmtui  # text UI to configure connections
```

### `apt update` warnings about held packages

This is normal and harmless — `apt` is just informing you that some packages are blocked by a hold. That's the intended behavior.

### I want to undo a hold

```bash
sudo apt-mark unhold <package-name>
sudo apt update
```

### I want to undo everything

```bash
sudo apt-mark unhold $(apt-mark showhold)
sudo apt update
sudo apt install ubuntu-desktop
```

This will reinstall the full Ubuntu Desktop with all the bloat. You may need to fix `apt-mark` flags first:

```bash
sudo apt-mark auto $(apt-mark showmanual | grep -E 'gnome-|tecla|ubuntu-wallpapers')
```

---

## FAQ

**Q: Why Ubuntu Server as the base, not Ubuntu Desktop?**
A: Ubuntu Desktop ships with Snap, the Ubuntu session, Yaru, and ~1 GB of extra packages. Starting from Server gives you a clean slate. This script then installs only the GNOME packages you actually want.

**Q: Will this work on Ubuntu 26.10, 27.04, etc.?**
A: Not as-is. Package names and dependency chains change between releases. You'll need to re-verify the dependency chains (the script's evidence section explains how) and update the `apt-mark manual` and hold lists accordingly.

**Q: Why alacritty and not ptyxis / gnome-terminal / ghostty?**
A: alacritty is GPU-accelerated and is the author's preference. It lives in Ubuntu's `universe` component, which the script enables in section 0 before installing it. The script removes ptyxis (Ubuntu's default) and holds it so it can't come back. To use a different terminal, edit section 3 of the script (and check whether it needs `universe` too).

**Q: Why is `gnome-snapshot` kept? Isn't it just a camera app?**
A: It's part of GNOME Core and is the modern replacement for Cheese (Ubuntu 24.04+ switched to it: [OMG Ubuntu article](https://www.omgubuntu.co.uk/2024/03/ubuntu-24-04-swaps-cheese-snapshot-webcam-app)). It's tiny and doesn't hurt to keep.

**Q: Can I remove `vim`? The script doesn't.**
A: `ubuntu-server` (which is still installed) hard-depends on `vim`. If you want to remove `vim`, first remove the `ubuntu-server` metapackage:
```bash
sudo apt remove ubuntu-server
sudo apt autoremove --purge
```
This is a separate decision and not part of this script.

**Q: The script installed Google Chrome. I don't want it.**
A: Comment out section 6 of the script (the Chrome `wget` + `apt-get install` block).

**Q: The script installed VS Code. I don't want it.**
A: Comment out section 6 of the script (the VS Code `debconf-set-selections` + `wget` + `apt-get install` block, right after Chrome).

**Q: How much disk space does this save vs. Ubuntu Desktop?**
A: Roughly 1.5–2 GB removed (Snap runtime + Ubuntu session + 23 GNOME apps + wallpapers-except-resolute + Ptyxis). The script also frees ~512 MB of kernel-reserved crash-dump memory.

**Q: Is this safe to run on a production server?**
A: **No.** This converts a server into a desktop. If you have a production server, don't run this. If you want a desktop, install Ubuntu Desktop or use this script on a fresh Server install.

**Q: Why does the script run `apt-get upgrade` at the start?**
A: To bring the system to current before doing the desktop conversion. If Ubuntu ships a broken package, that's Ubuntu's problem — the script just ensures it's working from a known-good baseline. The `apt-get install` calls later in the script always pull the latest available version anyway.

---


## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report bugs, verify packages, and submit pull requests.

---

## References

### Bug reports and dependency verification

- **Ubuntu Bug 1894347** — "Can't uninstall ubuntu-wallpapers and ubuntu-wallpapers-bionic without gnome-shell": <https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html>
- **Ubuntu 26.04 Packages.gz** (the metadata used for verification): <http://archive.ubuntu.com/ubuntu/dists/resolute/main/binary-amd64/Packages.gz>

### Package references

- **Ubuntu Repositories: main vs universe vs multiverse** — why alacritty needs `universe` enabled: <https://help.ubuntu.com/community/Repositories/Ubuntu>
- **gnome-snapshot replaces Cheese** — <https://www.omgubuntu.co.uk/2024/03/ubuntu-24-04-swaps-cheese-snapshot-webcam-app>
- **xdg-user-dirs** (creates Desktop/Documents/Downloads/etc.) — <https://wiki.archlinux.org/title/XDG_user_directories>
- **gsettings-desktop-schemas 50.0** — source of the `default-applications.terminal` schema definition: <https://packages.ubuntu.com/resolute/gsettings-desktop-schemas>
- **VS Code on Linux (`.deb`)** — the `add-microsoft-repo` debconf prompt this script pre-answers: <https://code.visualstudio.com/docs/setup/linux>

### GNOME 50 / Wayland

- **GNOME 50 removes X11 session support** (gHacks) — <https://www.ghacks.net/2025/09/13/gnome-50-releases-with-x11-session-support-removed-and-wayland/>
- **Fedora Wiki: Wayland-Only GNOME** — background on the X11 removal: <https://fedoraproject.org/wiki/Changes/WaylandOnlyGNOME>

### Apt / dpkg internals

- **Debian alternatives system** — how `update-alternatives --install` works (a filesystem tool, not display-protocol-aware): <https://wiki.debian.org/DebianAlternatives>
- **apt autoremove protects the running kernel** via `/etc/apt/apt.conf.d/01autoremove` (kernel metapackages still need to be manual to ensure future kernel upgrades install): <https://askubuntu.com/questions/563483/why-doesnt-apt-get-autoremove-remove-my-old-kernels>

---

## License

GNU Affero General Public License v3.0 (AGPL-3.0). See the [LICENSE](LICENSE) file for the full text.

In short: you can use, modify, and distribute this script, including as part of a network service — but any modified version that you make available to users over a network must also be licensed under AGPL-3.0 and have its source code available.

---

## Disclaimer

This script modifies your system's package state, removes packages, sets apt holds, and changes boot targets. **Test it in a VM first.** Take a snapshot before running on real hardware. The author is not responsible for broken systems, lost data, or bricked installs.
