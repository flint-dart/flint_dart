# Flint One-Command Installer

The installer bootstraps a complete local Flint developer setup:

- Dart SDK
- FlintDart CLI
- Flint UI source dependency
- `dart` and `flint` on PATH

It installs into:

- Windows: `%USERPROFILE%\.flint`
- macOS/Linux: `$HOME/.flint`

## Windows

Run PowerShell:

```powershell
iwr https://raw.githubusercontent.com/flint-dart/flint_dart/main/install.ps1 -UseB | iex
```

Or from a local checkout:

```powershell
.\install.ps1
```

## macOS And Linux

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/flint-dart/flint_dart/main/install.sh | sh
```

Or from a local checkout:

```bash
sh ./install.sh
```

## Compiled Rust Installer

The Rust installer is the stronger release path because it can be shipped as a single binary per OS.

From the monorepo:

```bash
cd flint/installer-app
cargo run --bin flint-install
```

Build a release binary:

```bash
cargo build --release --bin flint-install
```

The binary installs the same toolchain as the scripts: Dart SDK, Flint UI, FlintDart, the activated `flint` CLI, and PATH entries.

## Options

Windows:

```powershell
.\install.ps1 -InstallDir "$HOME\.flint" -Channel stable
.\install.ps1 -SkipPathUpdate
.\install.ps1 -SkipPackageInstall
```

macOS/Linux:

```bash
FLINT_HOME="$HOME/.flint" DART_CHANNEL=stable sh ./install.sh
SKIP_PATH_UPDATE=1 sh ./install.sh
SKIP_PACKAGE_INSTALL=1 sh ./install.sh
```

## What The Installer Does

1. Downloads the latest stable Dart SDK from the official Dart SDK archive.
2. Installs missing required system packages where supported:
   - macOS: `curl`, `unzip`, and `git` with Homebrew when Homebrew is available
   - Linux: `curl`, `unzip`, `git`, and `ca-certificates` with `apt`, `dnf`, `yum`, `pacman`, or `apk`
   - Windows: Git through `winget` or Chocolatey
3. Clones or updates:
   - `https://github.com/flint-dart/flint-ui.git`
   - `https://github.com/flint-dart/flint_dart.git`
4. Runs `dart pub get` for both packages.
5. Activates the Flint CLI from the local FlintDart checkout.
6. Adds Dart SDK and pub cache executables to your user PATH.

Open a new terminal after installation, then run:

```bash
flint create my_app
cd my_app
flint run
```
