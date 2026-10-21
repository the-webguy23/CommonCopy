# Run only on a disposable CI Windows profile, never against a user's library.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Installer lifecycle checks require a disposable GitHub Actions runner.' }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $root 'artifacts\installer-check'
$setup = Join-Path $root 'artifacts\release\CommonCopy-Setup-x64.exe'
$installed = Join-Path $env:LOCALAPPDATA 'Programs\CommonCopy'
$data = Join-Path $env:LOCALAPPDATA 'CommonCopy'
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'CommonCopy.lnk'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{D40544E3-0E8D-4DF8-90E3-D7EAB1D77892}_is1'
if (Test-Path $data) { throw 'Refusing to run over an existing library.' }
New-Item -ItemType Directory -Force $evidence | Out-Null
function Find-Button([string]$name) {
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$name)
    return [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Descendants,$condition)
}
function Wait-Button([string]$name) {
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        $button = Find-Button $name
        if ($button) { return $button }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Installer button did not appear: $name"
}
function Click($button) { $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke() }
function Screenshot([string]$name) {
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,'CommonCopy Setup')
    $window = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,$condition)
    if (!$window) { throw 'Setup window not found for screenshot.' }
    $r = $window.Current.BoundingRectangle
    $image = [Drawing.Bitmap]::new([int]$r.Width,[int]$r.Height)
    $graphics = [Drawing.Graphics]::FromImage($image)
    try {
        $graphics.CopyFromScreen([int]$r.X,[int]$r.Y,0,0,$image.Size)
        $image.Save((Join-Path $evidence "$name.png"))
    } finally { $graphics.Dispose(); $image.Dispose() }
}
function Run-Silent([string]$exe,[string[]]$arguments) {
    $p = Start-Process $exe -ArgumentList $arguments -PassThru
    if (!$p.WaitForExit(120000)) { throw 'Installer process timed out.' }
    if ($p.ExitCode -ne 0) { throw "Installer exited with $($p.ExitCode)" }
}
try {
    Start-Process $setup -ArgumentList @('/NORESTART',('/LOG="{0}\interactive.log"' -f $evidence)) | Out-Null
    $installButton = Wait-Button 'Install CommonCopy'
    Screenshot '01-ready'
    Click $installButton
    # Capture real extraction, without slowing or inventing progress for the product.
    Start-Sleep -Milliseconds 250
    Screenshot '02-installing'
    $openButton = Wait-Button 'Open CommonCopy'
    Screenshot '03-finished'
    if (!(Test-Path "$installed\CommonCopy.exe") -or !(Test-Path "$installed\Help\help.html") -or !(Test-Path "$installed\LICENSE.txt")) { throw 'Installed files missing.' }
    if (!(Test-Path $shortcut) -or !(Test-Path $uninstallKey)) { throw 'Shortcut or uninstall registration missing.' }
    Click $openButton
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $app = Get-Process CommonCopy -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($app -and (Test-Path "$data\phrases.json")) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    if (!$app -or !(Test-Path "$data\phrases.json")) { throw 'Installed application did not open and create its library.' }
    # Dispose this CI-only process before upgrade; never force-close a user's app.
    Stop-Process -Id $app.Id -Force
    $document = Get-Content "$data\phrases.json" -Raw | ConvertFrom-Json
    $fixture = [pscustomobject]@{ Id=[Guid]::NewGuid().ToString(); Title='Installer preservation check'; Text='Fictional installer test phrase'; CategoryId=$document.Categories[0].Id; IsEnabled=$true; IsFavourite=$false; UseCount=7 }
    $document.Phrases = @($document.Phrases) + @($fixture)
    $document | ConvertTo-Json -Depth 30 | Set-Content "$data\phrases.json" -Encoding UTF8
    $hash = (Get-FileHash "$data\phrases.json").Hash
    Run-Silent $setup @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="{0}\upgrade.log"' -f $evidence))
    if ((Get-FileHash "$data\phrases.json").Hash -ne $hash) { throw 'Upgrade modified saved phrases.' }
    # Exercise startup cleanup without enabling startup on the user's behalf.
    New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force | Out-Null
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' CommonCopy ('"{0}\CommonCopy.exe" --startup' -f $installed)
    Run-Silent "$installed\unins000.exe" @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="{0}\uninstall.log"' -f $evidence))
    if (Test-Path "$installed\CommonCopy.exe") { throw 'Uninstall left the application executable.' }
    if (Test-Path $shortcut) { throw 'Uninstall left the Start menu shortcut.' }
    if (Test-Path $uninstallKey) { throw 'Uninstall registration was not removed.' }
    if (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name CommonCopy -ErrorAction SilentlyContinue) { throw 'Uninstall left startup registration.' }
    if ((Get-FileHash "$data\phrases.json").Hash -ne $hash) { throw 'Uninstall removed or modified saved phrases.' }
    Set-Content "$evidence\result.txt" 'PASS: interactive install, installed application launch, offline help, shortcut, upgrade preservation, uninstall, startup cleanup, and library preservation. Physical Windows 10/11 and DPI review remain required.'
} catch {
    $_ | Out-String | Set-Content "$evidence\failure.txt"
    throw
}
