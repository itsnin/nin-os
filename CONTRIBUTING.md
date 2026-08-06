# Contributing

Found a bug? Want to verify this against a new Ubuntu release?

1. **Reproduce the verification yourself.** The README's [Verification](README.md#verification) section links to the `Packages.gz` files used. Download them and trace the dependency chains yourself before assuming the script is wrong (or right).
2. **Open an issue** with:
   - The exact Ubuntu release and architecture
   - The full output of the script, or just the failing step if you know which one
   - The output of `apt-cache depends --recurse gdm3 gnome-shell` on your system
3. **Pull requests welcome** — but only with verified changes. Don't add or remove a package, and don't add or remove a hold, without checking its reverse-dependencies first. See below.

## How to verify a package is safe to hold or remove

```bash
# What hard-depends on the package?
apt-cache rdepends --installed <package>

# Is it a hard dep of anything the desktop actually needs?
apt-cache rdepends --installed <package> | grep -E 'gnome-shell|gdm3|gnome-session|gnome-control-center|ubuntu-server'

# If the second command returns anything, DO NOT hold or remove the package —
# see the README's "What is kept (and why)" section for why this matters:
# README.md#what-is-kept-and-why
```

## How to check what's currently held

The script uses `apt-mark hold`, not an apt pin file — there's no `/etc/apt/preferences.d/` entry to inspect. Check holds directly:

```bash
# List every package currently held
apt-mark showhold

# Check one specific package
apt-mark showhold | grep <package>
```

If you're adding a new package to the script's hold list, add it the same way the script does — `sudo apt-mark hold <package>` — and confirm it shows up in `apt-mark showhold` afterward.
