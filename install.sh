#!/usr/bin/env sh
set -eu

INSTALL_DIR="${FLINT_HOME:-"$HOME/.flint"}"
CHANNEL="${DART_CHANNEL:-stable}"
SKIP_PATH_UPDATE="${SKIP_PATH_UPDATE:-0}"
SKIP_PACKAGE_INSTALL="${SKIP_PACKAGE_INSTALL:-0}"

info() {
  printf '[flint] %s\n' "$1"
}

fail() {
  printf '[flint] %s\n' "$1" >&2
  exit 1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

install_packages() {
  if [ "$SKIP_PACKAGE_INSTALL" = "1" ]; then
    return 1
  fi

  case "${platform:-unknown}" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        info "Installing required packages with Homebrew: $*"
        brew install "$@"
        return $?
      fi
      return 1
      ;;
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        info "Installing required packages with apt: $*"
        run_as_root apt-get update
        run_as_root apt-get install -y "$@"
        return $?
      elif command -v dnf >/dev/null 2>&1; then
        info "Installing required packages with dnf: $*"
        run_as_root dnf install -y "$@"
        return $?
      elif command -v yum >/dev/null 2>&1; then
        info "Installing required packages with yum: $*"
        run_as_root yum install -y "$@"
        return $?
      elif command -v pacman >/dev/null 2>&1; then
        info "Installing required packages with pacman: $*"
        run_as_root pacman -S --needed --noconfirm "$@"
        return $?
      elif command -v apk >/dev/null 2>&1; then
        info "Installing required packages with apk: $*"
        run_as_root apk add "$@"
        return $?
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

bootstrap_packages() {
  missing=""
  for command_name in curl unzip git; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      missing="$missing $command_name"
    fi
  done

  if [ "$platform" = "linux" ]; then
    missing="$missing ca-certificates"
  fi

  if [ -n "$missing" ]; then
    # shellcheck disable=SC2086
    install_packages $missing || true
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    info "Missing required command: $1"
    if install_packages "$1" && command -v "$1" >/dev/null 2>&1; then
      return
    fi
    case "${platform:-unknown}" in
      macos)
        printf 'Install %s with Homebrew: brew install %s\n' "$1" "$1" >&2
        ;;
      linux)
        printf 'Could not auto-install %s. Install it with your package manager, then rerun this installer.\n' "$1" >&2
        ;;
      *)
        printf 'Install missing command: %s\n' "$1" >&2
        ;;
    esac
    exit 1
  fi
}

append_path_line() {
  file="$1"
  line="$2"
  touch "$file"
  if ! grep -F "$line" "$file" >/dev/null 2>&1; then
    printf '\n%s\n' "$line" >> "$file"
  fi
}

add_path() {
  dir="$1"
  if [ "$SKIP_PATH_UPDATE" = "1" ]; then
    return
  fi

  export PATH="$PATH:$dir"
  shell_name="$(basename "${SHELL:-sh}")"
  case "$shell_name" in
    zsh) profile="$HOME/.zshrc" ;;
    bash) profile="$HOME/.bashrc" ;;
    *) profile="$HOME/.profile" ;;
  esac

  append_path_line "$profile" "export PATH=\"\$PATH:$dir\""
}

detect_platform() {
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin) platform="macos" ;;
    Linux) platform="linux" ;;
    *) fail "Unsupported OS: $os. Use install.ps1 on Windows, or run this script on macOS/Linux." ;;
  esac

  case "$arch" in
    x86_64|amd64) architecture="x64" ;;
    arm64|aarch64) architecture="arm64" ;;
    *) fail "Unsupported architecture: $arch. Supported architectures are x64 and arm64." ;;
  esac
}

preflight() {
  info "Detected $platform-$architecture"
  bootstrap_packages
  require_command curl
  require_command unzip
  require_command git
}

install_dart() {
  dart_home="$INSTALL_DIR/dart-sdk"
  dart_bin="$dart_home/bin"
  if [ -x "$dart_bin/dart" ]; then
    info "Dart SDK already installed at $dart_home"
    return
  fi

  info "Installing Dart SDK ($CHANNEL)"
  version="$(curl -fsSL "https://storage.googleapis.com/dart-archive/channels/$CHANNEL/release/latest/VERSION" | sed -n 's/.*"version":[ ]*"\([^"]*\)".*/\1/p')"
  if [ -z "$version" ]; then
    fail "Could not resolve the latest Dart SDK version for channel '$CHANNEL'."
  fi
  archive_url="https://storage.googleapis.com/dart-archive/channels/$CHANNEL/release/$version/sdk/dartsdk-$platform-$architecture-release.zip"
  zip_path="$INSTALL_DIR/dart-sdk.zip"
  extract_path="$INSTALL_DIR/_dart_extract"

  rm -rf "$extract_path"
  curl -fL "$archive_url" -o "$zip_path"
  unzip -q "$zip_path" -d "$extract_path"
  rm -rf "$dart_home"
  mv "$extract_path/dart-sdk" "$dart_home"
  rm -f "$zip_path"
  rm -rf "$extract_path"
}

sync_repo() {
  name="$1"
  url="$2"
  target="$INSTALL_DIR/$name"
  if [ -d "$target/.git" ]; then
    info "Updating $name"
    git -C "$target" pull --ff-only
  else
    rm -rf "$target"
    info "Cloning $name"
    git clone "$url" "$target"
  fi
}

detect_platform
preflight
mkdir -p "$INSTALL_DIR"

install_dart

DART_BIN="$INSTALL_DIR/dart-sdk/bin"
PUB_CACHE_BIN="${PUB_CACHE:-"$HOME/.pub-cache"}/bin"
add_path "$DART_BIN"
add_path "$PUB_CACHE_BIN"

DART="$DART_BIN/dart"

sync_repo "flint_ui" "https://github.com/flint-dart/flint-ui.git"
sync_repo "flint_dart" "https://github.com/flint-dart/flint_dart.git"

info "Resolving Flint UI dependencies"
"$DART" pub get --directory "$INSTALL_DIR/flint_ui"

info "Resolving FlintDart dependencies"
"$DART" pub get --directory "$INSTALL_DIR/flint_dart"

info "Activating Flint CLI"
"$DART" pub global activate --source path "$INSTALL_DIR/flint_dart"

info "Verifying installation"
"$DART" --version
if command -v flint >/dev/null 2>&1; then
  flint version || true
else
  "$PUB_CACHE_BIN/flint" version || true
fi

printf '\nFlint is installed.\n'
printf 'Open a new terminal so PATH changes are loaded, then run:\n'
printf '  flint create my_app\n'
printf '  cd my_app\n'
printf '  flint run\n'
