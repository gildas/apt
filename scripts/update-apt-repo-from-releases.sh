#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

required_commands=(curl jq gpg reprepro dpkg-deb)
for command in "${required_commands[@]}"; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing required command: $command" >&2
    exit 1
  fi
done

: "${GPG_KEY_ID:?GPG_KEY_ID is required}"
: "${GPG_PRIVATE_KEY:?GPG_PRIVATE_KEY is required}"

github_api_headers=(
  --header "Accept: application/vnd.github+json"
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  github_api_headers+=(
    --header "Authorization: ******"
  )
fi

declare -a source_repositories=(
  "gildas/lv"
  "gildas/bitbucket-cli"
)
declare -a supported_architectures=(
  "amd64"
  "arm64"
)

gnupg_home="$workspace/gnupg"
mkdir -p "$gnupg_home"
chmod 700 "$gnupg_home"
export GNUPGHOME="$gnupg_home"

cat >"$GNUPGHOME/gpg.conf" <<EOF
batch
no-tty
pinentry-mode loopback
EOF

cat >"$GNUPGHOME/gpg-agent.conf" <<EOF
allow-loopback-pinentry
allow-preset-passphrase
EOF

# Kill any existing gpg-agent and start a fresh one with our config
gpgconf --homedir "$GNUPGHOME" --kill gpg-agent 2>/dev/null || true
gpg-connect-agent --homedir "$GNUPGHOME" /bye 2>/dev/null || true

printf '%s' "$GPG_PRIVATE_KEY" | gpg --batch --yes --no-tty --pinentry-mode loopback --import
gpg --batch --yes --no-tty --pinentry-mode loopback --list-secret-keys "$GPG_KEY_ID" >/dev/null

# Pre-seed an empty passphrase so GPGME can sign non-interactively (CI keys have no passphrase)
keygrip="$(gpg --batch --with-keygrip --list-secret-keys "$GPG_KEY_ID" | awk '/Keygrip/ {print $3; exit}')"
if [[ -n "$keygrip" ]]; then
  gpg-preset-passphrase --preset "$keygrip" <<< "" 2>/dev/null || true
fi

work_repo="$workspace/repository"
downloads_dir="$workspace/downloads"
mkdir -p "$work_repo/conf" "$downloads_dir"

cat >"$work_repo/conf/distributions" <<EOF
Origin: gildas
Label: gildas
Suite: stable
Codename: stable
Architectures: ${supported_architectures[*]}
Components: main
Description: gildas APT repository
SignWith: $GPG_KEY_ID
EOF

touch "$work_repo/conf/options"

is_supported_architecture() {
  local architecture="$1"
  for supported in "${supported_architectures[@]}"; do
    if [[ "$supported" == "$architecture" ]]; then
      return 0
    fi
  done
  return 1
}

imported_packages=0

for repository in "${source_repositories[@]}"; do
  release_json="$(curl --fail --silent --show-error --location "${github_api_headers[@]}" "https://api.github.com/repos/$repository/releases/latest")"
  mapfile -t asset_urls < <(jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' <<<"$release_json")

  if [[ "${#asset_urls[@]}" -eq 0 ]]; then
    echo "No .deb assets found in the latest release of $repository"
    continue
  fi

  for asset_url in "${asset_urls[@]}"; do
    asset_name="${asset_url##*/}"
    asset_path="$downloads_dir/$asset_name"

    curl --fail --silent --show-error --location --output "$asset_path" "$asset_url"

    architecture="$(dpkg-deb -f "$asset_path" Architecture)"
    if ! is_supported_architecture "$architecture"; then
      echo "Ignoring unsupported architecture '$architecture' from $asset_name"
      continue
    fi

    reprepro --basedir "$work_repo" --gnupghome "$GNUPGHOME" includedeb stable "$asset_path"
    imported_packages=$((imported_packages + 1))
  done
done

if [[ "$imported_packages" -eq 0 ]]; then
  echo "No supported .deb packages were imported" >&2
  exit 1
fi

gpg --batch --yes --no-tty --pinentry-mode loopback --output "$work_repo/gildas-archive-keyring.gpg" --export "$GPG_KEY_ID"

rm -rf "$repo_root/dists" "$repo_root/pool"
cp -a "$work_repo/dists" "$repo_root/dists"
cp -a "$work_repo/pool" "$repo_root/pool"
cp "$work_repo/gildas-archive-keyring.gpg" "$repo_root/gildas-archive-keyring.gpg"
