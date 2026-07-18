[CmdletBinding()]
param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$appRoot = Join-Path $repositoryRoot 'apps\wallpaper_app'
$releaseDirectory = Join-Path $appRoot 'build\windows\x64\runner\Release'
$pubspecPath = Join-Path $appRoot 'pubspec.yaml'
$innoSourcePath = Join-Path $PSScriptRoot 'Setup.iss'
$iconPath = Join-Path $appRoot 'windows\runner\resources\app_icon.ico'
$distributionDirectory = Join-Path $repositoryRoot 'dist'

$versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+\d+)?\s*$' | Select-Object -First 1
if (-not $versionLine) {
    throw "Could not read a three-part version from $pubspecPath."
}
$appVersion = $versionLine.Matches[0].Groups[1].Value

$compilerCandidates = @(
    (Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
) | Where-Object { $_ -and (Test-Path $_ -PathType Leaf) }
$compilerPath = $compilerCandidates | Select-Object -First 1

if (-not $compilerPath) {
    throw @'
Inno Setup 6 is required to build the Setup executable.
Install it once with:
  winget install --id JRSoftware.InnoSetup --exact
Then run this script again.
'@
}

$visualStudioRoots = @(
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022')
) | Where-Object { Test-Path $_ -PathType Container }
$runtimeDirectory = Get-ChildItem $visualStudioRoots -Recurse -Filter 'msvcp140.dll' -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch '\\onecore\\' -and
        $_.DirectoryName -match '\\VC\\Redist\\MSVC\\.*\\x64\\Microsoft\.VC\d+\.CRT$' -and
        (Test-Path (Join-Path $_.DirectoryName 'vcruntime140.dll') -PathType Leaf) -and
        (Test-Path (Join-Path $_.DirectoryName 'vcruntime140_1.dll') -PathType Leaf)
    } |
    Sort-Object { [version]$_.VersionInfo.FileVersion } -Descending |
    Select-Object -First 1 -ExpandProperty DirectoryName

if (-not $runtimeDirectory) {
    throw 'The x64 Visual C++ runtime was not found. Install the Visual Studio Desktop development with C++ workload.'
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

& $compilerPath `
    "/DAppVersion=$appVersion" `
    "/DSourceDir=$releaseDirectory" `
    "/DOutputDir=$distributionDirectory" `
    "/DAppIcon=$iconPath" `
    "/DVCRuntimeDir=$runtimeDirectory" `
    $innoSourcePath

if ($LASTEXITCODE -ne 0) {
    throw 'Inno Setup failed to build the Setup executable.'
}

$outputPath = Join-Path $distributionDirectory "Wallpaper-Manager-$appVersion-x64-Setup.exe"
$setup = Get-Item $outputPath
Write-Host "Setup created: $($setup.FullName)"
Write-Host "Size: $([Math]::Round($setup.Length / 1MB, 2)) MB"
