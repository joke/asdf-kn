#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/knative/client"
GH_REPO_SANDBOX="https://github.com/knative-sandbox"
TOOL_NAME="kn"
TOOL_TEST="kn"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^knative-//; s/^v//'
}

list_all_versions() {
  list_github_tags
}

detect_system() {
  case $(uname -s) in
    Darwin) echo "darwin" ;;
    *) echo "linux" ;;
  esac
}

detect_architecture() {
  case $(uname -m) in
    x86_64 | amd64) echo "amd64" ;;
    arm64 | aarch64) echo "arm64" ;;
    *) fail "Architecture not supported" ;;

  esac
}

version_prefix() {
  local version
  version="$1"

  case "$version" in
    '0.'*) echo 'v' ;;
    *) echo 'knative-v' ;;
  esac
}

download_release() {
  local version version_prefix filename variant url
  version="$1"
  version_prefix="$(version_prefix "$version")"
  filename="$2/kn"
  variant="$(detect_system)-$(detect_architecture)"

  url="$GH_REPO/releases/download/${version_prefix}${version}/kn-${variant}"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

download_plugin() {
  local plugin version version_prefix variant filename url
  plugin="$1"
  version="$2"
  version_prefix="$(version_prefix "$version")"
  variant="$(detect_system)-$(detect_architecture)"
  filename="$3/kn-${plugin}"

  url="$GH_REPO_SANDBOX/kn-plugin-${plugin}/releases/download/${version_prefix}${version}/kn-${plugin}-${variant}"

  echo "* Trying to download $plugin release $version."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || echo "Could not download plugin '$plugin' from: $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
