[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$publish = Join-Path $root 'artifacts\publish\win-x64'
$release = Join-Path $root 'artifacts\release'
& (Join-Path $PSScriptRoot 'build-windows-branding.ps1')
# A clean staging folder prevents stale development files leaking into downloads.
if (Test-Path $publish) { Remove-Item $publish -Recurse -Force }
dotnet publish (Join-Path $root 'src\CommonCopy.Windows\CommonCopy.Windows.csproj') --configuration Release --runtime win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false --output $publish
if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
$unexpected = Get-ChildItem $publish -Recurse -File | Where-Object { $_.Name -notin @('CommonCopy.exe','help.html') }
if ($unexpected) { throw "Unexpected publish payload: $($unexpected.Name -join ', ')" }
if (!(Test-Path "$publish\Help\help.html")) { throw 'Offline help is missing.' }
if ((Get-FileHash "$root\docs\help\help.html").Hash -ne (Get-FileHash "$publish\Help\help.html").Hash) { throw 'Offline help differs from source.' }
# Preserve the notices from the exact runtime packs restored for this publish.
$assets = Get-Content "$root\src\CommonCopy.Windows\obj\project.assets.json" -Raw | ConvertFrom-Json
$downloads = @($assets.project.frameworks.PSObject.Properties.Value | ForEach-Object { $_.downloadDependencies })
foreach ($name in @('Microsoft.NETCore.App.Runtime.win-x64','Microsoft.WindowsDesktop.App.Runtime.win-x64')) {
    $dependency = $downloads | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (!$dependency) { throw "Runtime pack version not found in restored assets: $name" }
    $version = $dependency.version.Trim('[',']',' ')
    $pack = $assets.packageFolders.PSObject.Properties.Name | ForEach-Object { Join-Path $_ ($name.ToLowerInvariant() + '\' + $version) } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$pack) { throw "Restored runtime pack missing: $name $version" }
    $notices = @(Get-ChildItem $pack -File | Where-Object { $_.Name -match '^(LICENSE|THIRD.?PARTY.?NOTICES)(\..*)?$' })
    if ($notices.Count -lt 2) { throw "Runtime license or third-party notices missing: $name" }
    $destination = Join-Path $publish "Notices\$name"
    New-Item -ItemType Directory -Force $destination | Out-Null
    $notices | Copy-Item -Destination $destination
}
$compiler = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$compiler) { throw 'Install Inno Setup 6 before packaging CommonCopy.' }
& $compiler "$root\installer\CommonCopy.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
New-Item -ItemType Directory -Force $release | Out-Null
Copy-Item "$root\installer\output\CommonCopy-Setup-x64.exe" $release -Force
Copy-Item "$root\LICENSE" "$publish\LICENSE.txt" -Force
Compress-Archive "$publish\*" "$release\CommonCopy-Portable-x64.zip" -Force
$lines = foreach ($name in @('CommonCopy-Setup-x64.exe','CommonCopy-Portable-x64.zip')) {
    '{0}  {1}' -f (Get-FileHash "$release\$name").Hash.ToLowerInvariant(), $name
}
Set-Content "$release\SHA256SUMS.txt" $lines -Encoding utf8
