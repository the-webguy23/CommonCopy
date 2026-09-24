$ErrorActionPreference = "Stop"

$websiteRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent $websiteRoot
$releaseDirectory = Join-Path $repositoryRoot "artifacts\release"
$downloadDirectory = Join-Path $websiteRoot "dist\downloads"
$releaseFiles = @(
    "CommonCopy-Setup-x64.exe",
    "CommonCopy-Portable-x64.zip",
    "SHA256SUMS.txt"
)

foreach ($fileName in $releaseFiles) {
    $sourcePath = Join-Path $releaseDirectory $fileName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing release file: $sourcePath"
    }
}

New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null

foreach ($fileName in $releaseFiles) {
    Copy-Item -LiteralPath (Join-Path $releaseDirectory $fileName) -Destination (Join-Path $downloadDirectory $fileName) -Force
}

Write-Host "CommonCopy downloads copied to $downloadDirectory"
