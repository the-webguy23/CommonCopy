[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (Get-Process -Name CommonCopy,PhraseMenu -ErrorAction SilentlyContinue) {
    throw 'Exit CommonCopy from its tray icon before building a release.'
}
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & "$PSScriptRoot\build-windows-branding.ps1"
    dotnet restore CommonCopy.sln
    if ($LASTEXITCODE -ne 0) { throw 'Restore failed.' }
    dotnet build CommonCopy.sln --configuration Release --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
    dotnet test CommonCopy.sln --configuration Release --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    & "$PSScriptRoot\package-windows.ps1"
    Write-Host 'CommonCopy setup, optional portable ZIP, and checksums are ready in artifacts\release.'
} finally { Pop-Location }
