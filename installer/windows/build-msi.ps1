[CmdletBinding()]
param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$appRoot = Join-Path $repositoryRoot 'apps\wallpaper_app'
$releaseDirectory = Join-Path $appRoot 'build\windows\x64\runner\Release'
$pubspecPath = Join-Path $appRoot 'pubspec.yaml'
$wixSourcePath = Join-Path $PSScriptRoot 'Product.wxs'
$iconPath = Join-Path $appRoot 'windows\runner\resources\app_icon.ico'
$distributionDirectory = Join-Path $repositoryRoot 'dist'

$versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+\d+)?\s*$' | Select-Object -First 1
if (-not $versionLine) {
    throw "Could not read a three-part version from $pubspecPath."
}
$productVersion = $versionLine.Matches[0].Groups[1].Value

if (-not (Get-Command wix -ErrorAction SilentlyContinue)) {
    throw @'
WiX Toolset 5.0.2 is required to build the MSI.
Install it once with:
  dotnet tool install --global wix --version 5.0.2
Then open a new terminal and run this script again.
'@
}

$wixVersionText = (& wix --version).Trim()
if ($LASTEXITCODE -ne 0 -or $wixVersionText -notmatch '^5\.0\.2(?:\+|$)') {
    throw @"
This project uses WiX Toolset 5.0.2, but found '$wixVersionText'.
Install the supported version with:
  dotnet tool uninstall --global wix
  dotnet tool install --global wix --version 5.0.2
"@
}

if (-not $SkipFlutterBuild) {
    Push-Location $appRoot
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw 'The Flutter Windows release build failed.' }
    }
    finally {
        Pop-Location
    }
}

$executablePath = Join-Path $releaseDirectory 'wallpaper_app.exe'
if (-not (Test-Path $executablePath -PathType Leaf)) {
    throw "The Windows release payload was not found at $releaseDirectory. Run without -SkipFlutterBuild."
}
if (-not (Test-Path $iconPath -PathType Leaf)) {
    throw "The installer icon was not found at $iconPath."
}

New-Item -ItemType Directory -Path $distributionDirectory -Force | Out-Null
$outputPath = Join-Path $distributionDirectory "Wallpaper-Manager-$productVersion-x64.msi"

& wix build `
    -arch x64 `
    -d "ProductVersion=$productVersion" `
    -d "SourceDir=$releaseDirectory" `
    -d "IconPath=$iconPath" `
    -intermediateFolder (Join-Path $appRoot 'build\windows\msi') `
    -out $outputPath `
    $wixSourcePath

if ($LASTEXITCODE -ne 0) {
    throw 'WiX failed to build the MSI.'
}

$msi = Get-Item $outputPath
Write-Host "MSI created: $($msi.FullName)"
Write-Host "Size: $([Math]::Round($msi.Length / 1MB, 2)) MB"
