# apt

Debian/Ubuntu package repository for `gildas` packages, hosted on GitHub.

## Repository layout

This repository follows the Debian archive structure:

- `pool/main/`: `.deb` package files
- `dists/stable/main/binary-amd64/Packages`: amd64 package index
- `dists/stable/main/binary-amd64/Packages.gz`: amd64 compressed package index
- `dists/stable/main/binary-arm64/Packages`: arm64 package index
- `dists/stable/main/binary-arm64/Packages.gz`: arm64 compressed package index
- `dists/stable/Release`: distribution metadata and checksums

## Configure APT

Download the signing key:

```bash
curl -fsSL https://gildas.github.io/apt/gildas-archive-keyring.gpg | \
  sudo tee /usr/share/keyrings/gildas-archive-keyring.gpg >/dev/null
```

Add this source:

```bash
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/gildas-archive-keyring.gpg] https://gildas.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/gildas.list
sudo apt update
```

Then install packages from this repository with `apt install <package-name>`.

## Publishing new packages

The repository is updated automatically by GitHub Actions from the latest releases of:

- `gildas/lv`
- `gildas/bitbucket-cli`

The workflow downloads any available `.deb` assets for the supported architectures (`amd64`, `arm64`), rebuilds the repository metadata with `reprepro`, signs the release, and publishes the updated contents for GitHub Pages.

For manual maintenance, install `reprepro` and `gnupg`, import the signing key, then rebuild the repository:

```bash
./scripts/update-apt-repo-from-releases.sh
```
