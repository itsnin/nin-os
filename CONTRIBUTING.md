## Contributing

Found a bug? Want to verify for a new Ubuntu release?

1. **Reproduce the verification yourself.** The script's evidence section links to the `Packages.gz` files used. Download them and trace the dependency chains.
2. **Open an issue** with:
   - The exact Ubuntu release and architecture
   - The full output of the script (or the failing step)
   - The output of `apt-cache depends --recurse gdm3 gnome-shell` on your system
3. **Pull requests welcome** — but only with verified changes. Don't add or remove packages without checking the reverse-dependencies first.

## How to verify a package is safe to pin

```bash
# What hard-depends on the package?
apt-cache rdepends --installed <package>

# Is it a hard dep of any critical package?
apt-cache rdepends --installed <package> | grep -E 'gnome-shell|gdm3|gnome-session|gnome-control-center|ubuntu-server'

# If the second command returns anything, DO NOT pin or remove the package.
```
