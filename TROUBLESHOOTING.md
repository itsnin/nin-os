# Troubleshooting

Fixes for the specific problems people actually hit running [`debloat.sh`](debloat.sh). If something here doesn't cover your case, open an issue — see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Table of Contents

- [`Failed to enable unit: Unit gdm3.service does not exist`](#failed-to-enable-unit-unit-gdm3service-does-not-exist)
- [Black screen after reboot](#black-screen-after-reboot)
- [No network after reboot](#no-network-after-reboot)
- [`apt upgrade` keeps back a bunch of packages](#apt-upgrade-keeps-back-a-bunch-of-packages)
- [The default-terminal keybinding wasn't set](#the-default-terminal-keybinding-wasnt-set)
- [I want to undo a hold](#i-want-to-undo-a-hold)
- [I want to undo everything](#i-want-to-undo-everything)

---

## `Failed to enable unit: Unit gdm3.service does not exist`

This means `gdm3` was removed somewhere along the way. The current version of the script should not produce this — but if it does, run:

```bash
sudo apt-mark unhold $(apt-mark showhold)  # clear any holds
sudo apt install gdm3 gnome-shell gnome-session
sudo systemctl enable gdm3
sudo systemctl set-default graphical.target
```

If `apt install gdm3` fails with "ubuntu-wallpapers-resolute is not installable", check `apt-mark showhold` — `ubuntu-wallpapers-resolute` must NOT be in that list. Run `sudo apt-mark unhold ubuntu-wallpapers-resolute` if present, then `sudo apt update && sudo apt install gdm3`.

## Black screen after reboot

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

## No network after reboot

NetworkManager should manage networking automatically. If not:

```bash
nmcli device status
sudo nmtui  # text UI to configure connections
```

## `apt upgrade` keeps back a bunch of packages

After running this script, `apt update && apt upgrade` may print messages like:

```
The following packages have been kept back:
  gnome-calculator gnome-calendar ...
```

This is **expected and harmless** — an apt hold blocks each of these from being installed. The packages listed are exactly the ones the script explicitly held (see the README's [Apt holds](README.md#apt-holds) section). No action needed.

## The default-terminal keybinding wasn't set

The script's `gsettings set org.gnome.desktop.default-applications.terminal ...` calls only run if `$SUDO_USER` is set — i.e., someone ran the script via `curl … | sudo bash` from a logged-in user session. If you ran the script from a root shell or via cloud-init instead, these calls skip silently and Ctrl+Alt+T won't launch a terminal. Fix it after your first GNOME login:

```bash
gsettings set org.gnome.desktop.default-applications.terminal exec 'alacritty'
gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
```

## I want to undo a hold

```bash
sudo apt-mark unhold <package-name>
sudo apt update
```

## I want to undo everything

```bash
sudo apt-mark unhold $(apt-mark showhold)
sudo apt update
sudo apt install ubuntu-desktop
```

This will reinstall the full Ubuntu Desktop with all the bloat. You may need to fix `apt-mark` flags first:

```bash
sudo apt-mark auto $(apt-mark showmanual | grep -E 'gnome-|tecla|ubuntu-wallpapers')
```
