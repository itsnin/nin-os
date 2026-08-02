#!/usr/bin/env bash

# debloat.sh - minimal Ubuntu 26.04 LTS (server install), no desktop
# GNOME install/debloat/pins removed entirely. terminal is alacritty
# instead of ghostty. no cursor theme (nothing installs a display
# manager or desktop session here, so there's nothing to theme).
# run as: curl -fsSL <raw-url> | sudo bash
#
# target: Ubuntu 26.04 LTS "resolute raccoon" server (amd64) install.
# result: NetworkManager, alacritty terminal, kdump removed, snapd
# removed, cloud-init removed, dev toolchain installed. no
# GNOME, no display manager, no desktop session.

set -euo pipefail

# re-exec as root if not already root. this guard is for users who run
# the script as a downloaded file (e.g. `bash debloat.sh` without sudo).
# when run via `curl | sudo bash` (the recommended method), sudo is
# already on the outer command, so this branch is skipped.
if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

# 0. update + upgrade
echo "==> Updating package lists"
apt-get update

echo "==> Upgrading installed packages"
apt-get upgrade -y

# 1. networking: install NetworkManager and switch the netplan renderer
echo "==> Installing NetworkManager"
apt-get install -y network-manager

echo "==> Setting netplan renderer to NetworkManager"
apt-get install -y python3-yaml

# stop and mask systemd-networkd before netplan apply. this is the
# order actual Ubuntu switch-to-NetworkManager guides use: networkd is
# still the active renderer at this point (the netplan YAML rewrite
# below hasn't been applied yet), so if we don't get it out of the way
# first, `netplan apply` can end up fighting a live networkd for the
# same interface (double-configured interfaces, overwritten DNS, or an
# interface that doesn't come up at all).
#
# this is not the same situation as netplan bug #2042519, which is
# about masking networkd out from under netplan after netplan already
# expects it to be running (that bug is specifically triggered by
# device-level settings like `mtu:` that force a networkd-only .link
# unit even under the NetworkManager renderer). here networkd is being
# masked before the renderer switch and before `netplan apply` runs,
# so `netplan apply` regenerates its backend config already knowing
# NetworkManager owns the interfaces - nothing is pulled out from
# under it mid-flight.
echo "==> Stopping and masking systemd-networkd (switching to NetworkManager)"
systemctl stop systemd-networkd 2>/dev/null || true
systemctl mask systemd-networkd 2>/dev/null || true

# systemd-networkd-wait-online is a separate unit from systemd-networkd
# itself - it can still be pulled in by network-online.target even with
# the parent service masked, and would otherwise block boot waiting for
# an interface that networkd is no longer managing.
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

# loop over all netplan configs, skipping backups (*.orig) and curtinstage
# files (left over from the installer - not meant to be edited).
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

# apply the new netplan config. this regenerates the backend config for
# the NetworkManager renderer (netplan apply calls netplan generate
# internally - see netplan-generate(8)) and applies it. networkd is
# already stopped/masked above, so this hands the interfaces to
# NetworkManager cleanly instead of restarting a networkd that's still
# trying to hold them.
netplan apply

# unmask (defensive, in case a prior run or the base image left it
# masked) and enable+start the NetworkManager systemd service. on a
# GNOME install this happens as a side effect of the gdm3/graphical-
# session boot path; with no desktop environment nothing else triggers
# it, so nmcli/nmtui would otherwise see no managed interfaces from a
# TTY login even though the package and netplan renderer are correct.
echo "==> Enabling NetworkManager service"
systemctl unmask NetworkManager 2>/dev/null || true
systemctl enable --now NetworkManager

# 2. terminal: alacritty
echo "==> Installing alacritty and registering as default terminal"
apt-get install -y alacritty

update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50
update-alternatives --set x-terminal-emulator /usr/bin/alacritty

# 3. protect kernel metapackages from apt autoremove (section 8)
# ref: https://askubuntu.com/questions/563483/why-doesnt-apt-get-autoremove-remove-my-old-kernels
echo "==> Marking kernel metapackages as manually installed (protects autoremove)"
apt-mark manual \
  ubuntu-server linux-image-generic linux-generic

# 4. extras: htop, wget, fonts-noto, micro, Google Chrome
echo "==> Installing extras (htop, wget, fonts-noto, micro)"
apt-get install -y htop wget fonts-noto micro

echo "==> Installing Google Chrome (direct .deb)"
# apt-get install (not dpkg -i) lets apt resolve Chrome's deps automatically.
# the .deb's postinst adds Google's signing key + apt repo, so future
# `apt upgrade` pulls Chrome updates natively.
wget -q -O /tmp/google-chrome-stable.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt-get install -y /tmp/google-chrome-stable.deb || echo "Chrome install failed (continuing)"
rm -f /tmp/google-chrome-stable.deb

# 5. free the ~512 mb the kernel reserves for crash dumps (kdump)
echo "==> Removing kdump-tools (frees ~512 MB reserved memory)"
apt-get remove -y --purge kdump-tools 2>/dev/null || true
rm -f /etc/default/grub.d/kdump-tools.cfg
update-grub

# 6. remove snapd. apt-mark hold (not just remove) so a future
# `apt upgrade` can't pull snapd back in via ubuntu-server's recommends.
echo "==> Removing snapd"
if command -v snap >/dev/null 2>&1 || dpkg -s snapd >/dev/null 2>&1; then
  apt-get remove -y --purge snapd
  apt-mark hold snapd
  echo "Successfully removed snaps."
else
  echo "Snapd is not installed."
fi

# 7. remove cloud-init. only meaningful on a real-hardware / non-cloud
# install where nothing re-runs it on every boot for provisioning.
echo "==> Removing cloud-init"
apt remove cloud-init -y

# 8. clean up orphans
echo "==> Autoremoving orphans"
apt-get autoremove -y --purge

echo
echo "DONE."
echo "NetworkManager manages networking. Alacritty is the terminal."
echo "No desktop environment or display manager was installed."

# 9. development toolchain (python, c/c++, rust, java, node.js, db
# clients, web tooling). placed last, after the done banner -
# deliberately kept separate. this is a large, independent package
# list, and `set -euo pipefail` means a single bad/unavailable package
# name here would halt the script. running it after everything else
# is already installed means a failure here only requires rerunning
# this block.
echo "==> Installing development toolchain"
apt-get install -y \
  python3 python3-pip python3-venv python3-dev python3-full \
  libssl-dev libffi-dev zlib1g-dev libbz2-dev liblzma-dev libreadline-dev libsqlite3-dev libncurses-dev \
  build-essential gcc g++ clang clangd clang-format clang-tidy make cmake ninja-build gdb pkg-config valgrind llvm \
  default-jdk maven \
  nodejs \
  sqlite3 postgresql-client mariadb-client pgcli mycli \
  tidy html-xml-utils sassc \
  ca-certificates gnupg

# rust: official rustup installer instead of the apt rustc/cargo/rustfmt/
# rust-clippy packages (apt's Rust lags upstream; rustup tracks stable
# releases directly and is the toolchain-management tool most Rust
# tooling/docs assume).
#
# -y makes rustup non-interactive (no install-profile prompt), needed
# because this whole script runs under `set -euo pipefail` unattended.
#
# run as $SUDO_USER, not root: this script re-execs itself as root at
# the very top, so without this rustup would install into /root/.cargo
# and add its path line to root's shell profile - invisible to the
# actual login user. falls back to root only if there's no SUDO_USER
# (e.g. already running as a root shell with no invoking sudo user).
echo "==> Installing Rust via rustup"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  sudo -u "$SUDO_USER" sh -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# rustup adds ~/.cargo/bin to path via the user's shell profile, which
# only takes effect on their next login shell (or after they manually
# `source $HOME/.cargo/env`) - not in this already-running script.

echo "==> Development toolchain installed"
