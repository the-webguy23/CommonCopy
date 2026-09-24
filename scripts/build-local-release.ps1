[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$runningCommonCopy = Get-Process -Name "CommonCopy", "PhraseMenu" -ErrorAction SilentlyContinue
if ($null -ne $runningCommonCopy) {
    throw "CommonCopy or PhraseMenu is running. Exit it from the notification-area icon, then run this command again."
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$solutionPath = Join-Path $repositoryRoot "CommonCopy.sln"
$projectPath = Join-Path $repositoryRoot "src\CommonCopy.Windows\CommonCopy.Windows.csproj"
$publishDirectory = Join-Path $repositoryRoot "artifacts\publish\win-x64"
$releaseDirectory = Join-Path $repositoryRoot "artifacts\release"
$portablePath = Join-Path $releaseDirectory "CommonCopy-Portable-x64.zip"
$installerSourcePath = Join-Path $repositoryRoot "installer\output\CommonCopy-Setup-x64.exe"
$installerReleasePath = Join-Path $releaseDirectory "CommonCopy-Setup-x64.exe"
$checksumPath = Join-Path $releaseDirectory "SHA256SUMS.txt"

Push-Location $repositoryRoot
try {
    dotnet restore $solutionPath
    if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed." }

    dotnet build $solutionPath --configuration Release --no-restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed." }

    dotnet test $solutionPath --configuration Release --no-build
    if ($LASTEXITCODE -ne 0) { throw "dotnet test failed." }

    dotnet publish $projectPath `
        --configuration Release `
        --runtime win-x64 `
        --self-contained true `
        -p:PublishSingleFile=true `
        --output $publishDirectory
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed." }

    New-Item -ItemType Directory -Force -Path $releaseDirectory | Out-Null
    Compress-Archive -Path (Join-Path $publishDirectory "*") -DestinationPath $portablePath -Force

    $innoCandidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
    )
    $innoCompiler = $innoCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ($null -eq $innoCompiler) {
        throw "Inno Setup 6 was not found. Install it, or compile installer\CommonCopy.iss manually."
    }

    & $innoCompiler (Join-Path $repositoryRoot "installer\CommonCopy.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed." }
    Copy-Item -LiteralPath $installerSourcePath -Destination $installerReleasePath -Force

    $releaseFiles = @($installerReleasePath, $portablePath)
    $checksumLines = foreach ($filePath in $releaseFiles) {
        $hash = Get-FileHash -LiteralPath $filePath -Algorithm SHA256
        "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), (Split-Path -Leaf $filePath)
    }
    Set-Content -LiteralPath $checksumPath -Value $checksumLines -Encoding UTF8

    & (Join-Path $repositoryRoot "website\scripts\sync-release.ps1")

    Write-Host ""
    Write-Host "CommonCopy v0.2.0 local release is ready:" -ForegroundColor Green
    Write-Host "  $installerReleasePath"
    Write-Host "  $portablePath"
    Write-Host "  $checksumPath"
    Write-Host "  $(Join-Path $repositoryRoot 'website\dist\index.html')"
}
finally {
    Pop-Location
}
