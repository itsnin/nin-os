#!/usr/bin/env bash
# ubuntu 26.04 server -> vanilla gnome 50 desktop without snap

set -euo pipefail

# re-exec as root if run directly eg bash debloat.sh without sudo
# skipped when already invoked as curl | sudo bash
if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

# 0 update + upgrade
echo "==> updating package lists"
apt-get update

echo "==> upgrading installed packages"
apt-get upgrade -y

# 1 install pure gnome core, --no-install-recommends skips ubuntu-session
# gnome-session is a hard dep of gnome-core and is what gdm boots
# ref https://packages.ubuntu.com/resolute/gnome-core
echo "==> installing gnome-core (vanilla gnome, no recommends)"
apt-get install -y --no-install-recommends gnome-core

# 2 networking, install networkmanager and switch the netplan renderer
# gnome's network panel needs networkmanager, server defaults to
# systemd-networkd via netplan
echo "==> installing networkmanager"
apt-get install -y network-manager

echo "==> setting netplan renderer to networkmanager"
apt-get install -y python3-yaml

# mask networkd before netplan apply, matches ubuntu's own
# switch-to-networkmanager order, avoids two renderers fighting the
# same interface mid-switch. not related to netplan bug #2042519
# (that one is about mtu-driven .link units masking networkd after
# netplan already expects it running, this masks it before the switch)
echo "==> stopping and masking systemd-networkd (switching to networkmanager)"
systemctl stop systemd-networkd 2>/dev/null || true
systemctl mask systemd-networkd 2>/dev/null || true

# wait-online is a separate unit, still pulled in by network-online.target
# even with the parent masked
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

# skip *.orig and curtin leftovers from the installer
for f in /etc/netplan/*.yaml; do
  case "$f" in
    *.orig|*curtin*) continue ;;
  esac
  python3 - "$f" <<'PY'
import sys, yaml
f = sys.argv[1]
try:
    with open(f) as fh:
        data = yaml.safe_load(fh)
except Exception as e:
    print("skip", f, e); sys.exit(0)
if isinstance(data, dict) and isinstance(data.get('network'), dict):
    data['network']['renderer'] = 'NetworkManager'
    with open(f, 'w') as fh:
        yaml.safe_dump(data, fh, default_flow_style=False, sort_keys=False)
    print("updated", f)
PY
done

# regenerates backend config for the networkmanager renderer, see
# netplan-generate(8). networkd already stopped/masked above so this
# hands interfaces over cleanly
netplan apply

echo "==> enabling networkmanager service"
systemctl unmask NetworkManager 2>/dev/null || true
systemctl enable --now NetworkManager

# 3 terminal, alacritty registered now, stray-terminal purge deferred
# to section 10 so we keep a working terminal if anything breaks early
echo "==> installing alacritty and registering as default terminal"
apt-get install -y alacritty

update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50
update-alternatives --set x-terminal-emulator /usr/bin/alacritty

# ctrl+alt+t key, deprecated gsettings key in gnome 50 but still read
# run as $SUDO_USER not root so it lands in the user's dconf
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  sudo -u "$SUDO_USER" gsettings set org.gnome.desktop.default-applications.terminal exec 'alacritty' 2>/dev/null || true
  sudo -u "$SUDO_USER" gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e' 2>/dev/null || true
fi

# 4 protect everything that must survive autoremove (section 13)
#
# (a) gnome core we explicitly want
#   gnome-shell gdm3 gnome-control-center gnome-session nautilus
#   gnome-settings-daemon gnome-keyring gnome-menus gnome-backgrounds
#   gsettings-desktop-schemas adwaita-icon-theme gnome-snapshot
#   gnome-bluetooth-sendto alacritty network-manager pipewire-audio
#   xdg-desktop-portal-gnome libpam-gnome-keyring gnome-online-accounts
#
# (b) hard deps of gdm3/gnome-shell/gnome-control-center, verified
# against packages.gz
#   gnome-session-common gdm3 hard-dep >= 50~alpha
#   gnome-session-bin gdm3 hard-dep >= 50~alpha
#   gnome-shell-common gnome-shell hard-dep = 50.1-0ubuntu1.1
#   mutter-common gnome-control-center hard-dep
#   libgdm1 gdm3 hard-dep = 50.0-0ubuntu1
#   gir1.2-gdm-1.0 gnome-shell + gdm3 hard-dep = 50.0-0ubuntu1
# ref http://archive.ubuntu.com/ubuntu/dists/resolute/main/binary-amd64/Packages.gz
#
# (c) hard deps of gnome-shell that look like bloat but arent, the
# ubuntu-wallpapers-resolute trap, ubuntu bug 1894347
#   tecla gnome-shell hard-dep
#   ubuntu-wallpapers gnome-shell hard-dep
#   ubuntu-wallpapers-resolute ubuntu-wallpapers hard-dep
#   gdm3 depends gnome-shell >= 50~alpha
#   gnome-shell depends ubuntu-wallpapers (ubuntu patch)
#   ubuntu-wallpapers depends ubuntu-wallpapers-resolute (hard dep)
#   gnome-shell depends tecla (hard dep)
# holding or removing any of these cascades through gnome-shell to
# gdm3 to gnome-session and breaks the desktop
# ref https://lists.ubuntu.com/archives/foundations-bugs/2020-September/431929.html
#
# (d) xdg-user-dirs-gtk creates desktop/documents/downloads/music/
# pictures/videos on first gnome login
# ref https://wiki.archlinux.org/title/XDG_user_directories
#
# (e) ubuntu-server + kernel metapackages protect the running kernel
# from autoremove, must stay manual so future kernel upgrades install
# ref https://askubuntu.com/questions/563483/why-doesnt-apt-get-autoremove-remove-my-old-kernels
echo "==> marking critical packages as manually installed (protects autoremove)"
apt-mark manual \
  gnome-shell gdm3 gnome-control-center gnome-session nautilus \
  gnome-settings-daemon gnome-keyring gnome-menus gnome-backgrounds \
  gsettings-desktop-schemas adwaita-icon-theme gnome-snapshot gnome-bluetooth-sendto alacritty \
  network-manager pipewire-audio xdg-desktop-portal-gnome \
  libpam-gnome-keyring gnome-online-accounts xdg-user-dirs-gtk \
  gnome-session-common gnome-session-bin gnome-shell-common mutter-common \
  libgdm1 gir1.2-gdm-1.0 \
  tecla ubuntu-wallpapers ubuntu-wallpapers-resolute \
  ubuntu-server linux-image-generic linux-generic

# 5 make gdm the display manager, done early before holding/autoremove
# so if that later breaks gdm3, gdm3.service is already registered and
# the system can still boot graphical. reversed order gives
# "failed to enable unit: unit gdm3.service does not exist"
echo "==> enabling gdm and graphical target"
systemctl enable gdm3
systemctl set-default graphical.target
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager

# 6 extras, no cursor theme is set
echo "==> installing extras (htop wget fonts-noto gnome-boxes micro gnome-shell-extension-manager)"
apt-get install -y htop wget fonts-noto gnome-boxes micro gnome-shell-extension-manager

echo "==> installing google chrome (direct .deb)"
# apt-get install not dpkg -i so apt resolves chrome's deps, the .deb's
# postinst also adds google's repo so future apt upgrade pulls chrome
wget -q -O /tmp/google-chrome-stable.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt-get install -y /tmp/google-chrome-stable.deb || echo "chrome install failed (continuing)"
rm -f /tmp/google-chrome-stable.deb

# 7 free the ~512mb kdump reserves, safe on desktop, kernel
# metapackages already protected in section 4
echo "==> removing kdump-tools (frees ~512mb reserved memory)"
apt-get remove -y --purge kdump-tools 2>/dev/null || true
rm -f /etc/default/grub.d/kdump-tools.cfg
update-grub

# 8 drop the gnome-core metapackage, core pkgs are already manual
# (section 4) so this just frees the optional apps for autoremove,
# done before removing them so their removal doesnt cascade back
# through gnome-core's deps
echo "==> removing gnome-core metapackage (core pkgs protected by apt-mark manual)"
apt-get remove -y gnome-core 2>/dev/null || true

# 9 remove optional gnome apps, all 23 verified safe against 26.04
# resolute packages.gz, none is a hard dep of gnome-shell gdm3
# gnome-control-center gnome-session nautilus or ubuntu-server
#
# not in this list, would break gnome, see 4c:
# ubuntu-wallpapers-resolute ubuntu-wallpapers tecla
echo "==> removing optional gnome apps (bloat)"
apt-get remove -y --purge \
  gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-contacts \
  gnome-disk-utility gnome-font-viewer gnome-logs gnome-maps gnome-weather \
  gnome-sushi gnome-system-monitor gnome-text-editor baobab loupe papers \
  showtime simple-scan gnome-connections gnome-user-docs \
  yelp orca gnome-software

# 10 remove stray terminals
echo "==> removing stray terminals (alacritty is the only terminal)"
apt-get remove -y --purge ptyxis 2>/dev/null || true
apt-get remove -y --purge xterm gnome-terminal 2>/dev/null || true

# hold not just remove, so apt upgrade cant pull snapd back via
# ubuntu-server's recommends
echo "==> removing snapd"
if command -v snap >/dev/null 2>&1 || dpkg -s snapd >/dev/null 2>&1; then
  apt-get remove -y --purge snapd
  apt-mark hold snapd
  echo "successfully removed snaps"
else
  echo "snapd is not installed"
fi

# 11 hold everything unwanted so apt upgrade can never bring it back,
# apt-mark hold instead of a priority -1 pin, same effect
#
# do not hold, would break gnome, see 4c:
#   ubuntu-wallpapers-resolute hard dep of ubuntu-wallpapers
#   ubuntu-wallpapers hard dep of gnome-shell
#   tecla hard dep of gnome-shell
#   vim vim-common vim-runtime hard dep of ubuntu-server
#
# safe to hold, not hard deps of anything we keep:
#   vim-tiny not a hard dep of anything
#   ubuntu-session alt in gdm3's deps (ubuntu-session | gnome-session | ...)
#   gnome-shell-ubuntu-extensions alt in gdm3's deps
#   yaru-theme-gnome-shell recommends of gnome-shell-common, not hard
#   yaru-theme-gtk/icon/sound recommends, not hard
#   gsettings-ubuntu-schemas not a hard dep of anything we keep
#   ptyxis hard dep of gnome-core which we removed, held as
#     defense-in-depth against a future apt install gnome-core
#   ghostty xterm gnome-terminal not installed, not deps
#   all 23 gnome apps from section 9, verified safe above
echo "==> holding unwanted packages (apt-mark hold)"
apt-mark hold \
  gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-contacts \
  gnome-disk-utility gnome-font-viewer gnome-logs gnome-maps gnome-weather \
  gnome-sushi gnome-system-monitor gnome-text-editor baobab loupe papers \
  showtime simple-scan gnome-connections gnome-user-docs \
  yelp orca gnome-software \
  ubuntu-session gnome-shell-ubuntu-extensions \
  yaru-theme-gnome-shell yaru-theme-gtk yaru-theme-icon yaru-theme-sound \
  gsettings-ubuntu-schemas \
  ghostty xterm gnome-terminal ptyxis vim-tiny \
  2>/dev/null || true

# 12 remove cloud-init
echo "==> removing cloud-init"
apt remove cloud-init -y

# 13 clean up orphans, safe since everything wanted is manual (section 4)
echo "==> autoremoving orphans (core is protected by apt-mark manual)"
apt-get autoremove -y --purge

# 14 final sanity check, catches a broken hold/autoremove before reboot
if ! systemctl list-unit-files gdm3.service --all 2>/dev/null | grep -q gdm3; then
  echo "!! warning: gdm3.service is missing, something went wrong"
  echo "!! inspect /var/log/apt/history.log and rerun sections 4-5"
  exit 1
fi

echo
echo "done, pure vanilla gnome 50 is installed"
echo "at the gdm login only the vanilla gnome session is available"
echo "(no ubuntu session exists). reboot now: sudo reboot"
echo
echo "optional gnome apps were removed and held, snap is gone"
echo "alacritty is the only terminal, networkmanager manages networking"
echo "no cursor theme was set, standard home folders"
echo "(desktop documents downloads music pictures videos) will be created"
echo "on first gnome login by xdg-user-dirs-gtk"

# 15 dev toolchain: python c/c++ rust java node.js db clients web
# tooling, placed last after the gdm check and the done banner on
# purpose. this is a large independent package list under
# set -euo pipefail, a single bad/unavailable name here would halt the
# script. running it after the desktop conversion is already
# installed and sanity-checked means a failure here cant take down
# gnome/gdm, worst case only this block needs a rerun
echo "==> installing development toolchain"
apt-get install -y \
  python3 python3-pip python3-venv python3-dev python3-full \
  libssl-dev libffi-dev zlib1g-dev libbz2-dev liblzma-dev libreadline-dev libsqlite3-dev libncurses-dev \
  build-essential gcc g++ clang clangd clang-format clang-tidy make cmake ninja-build gdb pkg-config valgrind llvm \
  default-jdk maven \
  nodejs \
  sqlite3 postgresql-client mariadb-client pgcli mycli \
  tidy html-xml-utils sassc \
  ca-certificates gnupg

# rustup not apt (apt lags upstream), run as $SUDO_USER not root or it installs into /root/.cargo
echo "==> installing rust via rustup"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  sudo -u "$SUDO_USER" sh -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# rustup adds ~/.cargo/bin via shell profile, takes effect next login
# or after manually sourcing $HOME/.cargo/env, not in this script

echo "==> development toolchain installed"
