# apt

Debian/Ubuntu package repository for `gildas` packages, hosted on GitHub.

## Repository layout

This repository follows the Debian archive structure:

- `pool/main/`: `.deb` package files
- `dists/stable/main/binary-amd64/Packages`: package index
- `dists/stable/main/binary-amd64/Packages.gz`: compressed package index
- `dists/stable/Release`: distribution metadata and checksums

## Configure APT

Add this source:

```bash
echo "deb [trusted=yes] https://gildas.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/gildas.list
sudo apt update
```

Then install packages from this repository with `apt install <package-name>` (note: `trusted=yes` disables signature verification; prefer a signed repository with `signed-by=` for regular use).

## Publishing new packages

1. Copy new `.deb` files into `pool/main/`
2. Regenerate metadata:

```bash
dpkg-scanpackages --arch amd64 pool/main > dists/stable/main/binary-amd64/Packages
gzip -n -c dists/stable/main/binary-amd64/Packages > dists/stable/main/binary-amd64/Packages.gz
```

3. Update `dists/stable/Release` checksums (MD5/SHA256 for `Packages` and `Packages.gz`)
