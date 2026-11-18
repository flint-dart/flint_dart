param(
  [string]$InstallDir = "$env:USERPROFILE\.flint",
  [string]$Channel = "stable",
  [switch]$SkipPathUpdate,
  [switch]$SkipPackageInstall
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
  Write-Host "[flint] $Message" -ForegroundColor Cyan
}

function Stop-Flint($Message) {
  throw "[flint] $Message"
}

function Assert-WindowsSupport {
  if (-not $IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
    Stop-Flint "install.ps1 is for Windows. Use install.sh on macOS/Linux."
  }

  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  if ($arch -ne "X64") {
    Stop-Flint "Unsupported Windows architecture: $arch. This installer currently supports Windows x64."
  }
}

function Ensure-Directory($Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Add-UserPath($Path) {
  if ($SkipPathUpdate) { return }
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @()
  if ($current) {
    $parts = $current -split ";"
  }
  if ($parts -notcontains $Path) {
    $next = (@($parts) + $Path | Where-Object { $_ -and $_.Trim() }) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $next, "User")
  }
  if (($env:Path -split ";") -notcontains $Path) {
    $env:Path = "$env:Path;$Path"
  }
}

function Test-Command($Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Require-Command($Name, $Hint) {
  if (-not (Test-Command $Name)) {
    Write-Step "Missing required command: $Name"
    if (-not $SkipPackageInstall) {
      Install-PackageCommand $Name
    }
    if (-not (Test-Command $Name)) {
      if ($Hint) {
        Write-Host $Hint -ForegroundColor Yellow
      }
      Stop-Flint "$Name is required. Install it, then run this installer again."
    }
  }
}

function Install-PackageCommand($Name) {
  if ($Name -eq "git") {
    if (Test-Command "winget") {
      Write-Step "Installing Git with winget"
      winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
      $gitCmd = Join-Path $env:ProgramFiles "Git\cmd"
      if (Test-Path -LiteralPath $gitCmd -and (($env:Path -split ";") -notcontains $gitCmd)) {
        $env:Path = "$env:Path;$gitCmd"
      }
      return
    }

    if (Test-Command "choco") {
      Write-Step "Installing Git with Chocolatey"
      choco install git -y
      return
    }
  }
}

function Install-DartSdk {
  $dartHome = Join-Path $InstallDir "dart-sdk"
  $dartExe = Join-Path $dartHome "bin\dart.exe"
  if (Test-Path -LiteralPath $dartExe) {
    Write-Step "Dart SDK already installed at $dartHome"
    return $dartHome
  }

  Write-Step "Installing Dart SDK ($Channel)"
  Ensure-Directory $InstallDir

  $versionInfo = Invoke-RestMethod "https://storage.googleapis.com/dart-archive/channels/$Channel/release/latest/VERSION"
  $version = $versionInfo.version
  $archiveUrl = "https://storage.googleapis.com/dart-archive/channels/$Channel/release/$version/sdk/dartsdk-windows-x64-release.zip"
  $zipPath = Join-Path $InstallDir "dart-sdk.zip"
  $extractPath = Join-Path $InstallDir "_dart_extract"

  if (Test-Path -LiteralPath $extractPath) {
    Remove-Item -LiteralPath $extractPath -Recurse -Force
  }

  Invoke-WebRequest -Uri $archiveUrl -OutFile $zipPath
  Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

  if (Test-Path -LiteralPath $dartHome) {
    Remove-Item -LiteralPath $dartHome -Recurse -Force
  }

  Move-Item -LiteralPath (Join-Path $extractPath "dart-sdk") -Destination $dartHome
  Remove-Item -LiteralPath $zipPath -Force
  Remove-Item -LiteralPath $extractPath -Recurse -Force

  return $dartHome
}

function Sync-Repo($Name, $Url) {
  $target = Join-Path $InstallDir $Name
  if (Test-Path -LiteralPath (Join-Path $target ".git")) {
    Write-Step "Updating $Name"
    git -C $target pull --ff-only
  } else {
    if (Test-Path -LiteralPath $target) {
      Remove-Item -LiteralPath $target -Recurse -Force
    }
    Write-Step "Cloning $Name"
    git clone $Url $target
  }
  return $target
}

Ensure-Directory $InstallDir
Assert-WindowsSupport

Require-Command "git" "Install Git from https://git-scm.com/download/win or run: winget install --id Git.Git -e"

$dartHome = Install-DartSdk
$dartBin = Join-Path $dartHome "bin"
$pubCacheBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"

Add-UserPath $dartBin
Add-UserPath $pubCacheBin

$dart = Join-Path $dartBin "dart.exe"
$flintUiPath = Sync-Repo "flint_ui" "https://github.com/flint-dart/flint-ui.git"
$flintDartPath = Sync-Repo "flint_dart" "https://github.com/flint-dart/flint_dart.git"

Write-Step "Resolving Flint UI dependencies"
& $dart pub get --directory $flintUiPath

Write-Step "Resolving FlintDart dependencies"
& $dart pub get --directory $flintDartPath

Write-Step "Activating Flint CLI"
& $dart pub global activate --source path $flintDartPath

Write-Step "Verifying installation"
& $dart --version
try {
  flint version
} catch {
  $flintBat = Join-Path $pubCacheBin "flint.bat"
  if (Test-Path -LiteralPath $flintBat) {
    & $flintBat version
  } else {
    Write-Host "Flint was activated, but it is not on PATH in this terminal yet." -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "Flint is installed." -ForegroundColor Green
Write-Host "Open a new terminal so PATH changes are loaded, then run:"
Write-Host "  flint create my_app"
Write-Host "  cd my_app"
Write-Host "  flint run"
