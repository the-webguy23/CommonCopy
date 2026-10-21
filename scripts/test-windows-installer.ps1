# Run only on a disposable CI Windows profile, never against a user's library.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Installer lifecycle checks require a disposable GitHub Actions runner.' }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class InstallerClick {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
}
'@
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
    $windowCondition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,'CommonCopy Setup')
    $window = [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,$windowCondition)
    if (!$window) { return $null }
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$name)
    return $window.FindFirst([Windows.Automation.TreeScope]::Descendants,$condition)
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
function Click($button) {
    # Queue a normal native button click so the test can observe live extraction.
    if (![InstallerClick]::PostMessage([IntPtr]$button.Current.NativeWindowHandle,0x00F5,[IntPtr]::Zero,[IntPtr]::Zero)) { throw 'Could not click installer button.' }
}
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
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        if (Find-Button 'Installing CommonCopy') { break }
        Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $deadline)
    if (!(Find-Button 'Installing CommonCopy')) { throw 'Live installation progress was not observed.' }
    Screenshot '02-installing'
    $openButton = Wait-Button 'Open CommonCopy'
    Screenshot '03-finished'
    if (!(Test-Path "$installed\CommonCopy.exe") -or !(Test-Path "$installed\Help\help.html") -or !(Test-Path "$installed\LICENSE.txt")) { throw 'Installed files missing.' }
    if (@(Get-ChildItem "$installed\Notices" -Recurse -File).Count -lt 4) { throw 'Runtime notices missing from installation.' }
    if (!(Test-Path $shortcut) -or !(Test-Path $uninstallKey)) { throw 'Shortcut or uninstall registration missing.' }
    Click $openButton
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $app = Get-Process CommonCopy -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($app -and (Test-Path "$data\phrases.json")) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    if (!$app -or !(Test-Path "$data\phrases.json")) { throw 'Installed application did not open and create its library.' }
    $beforeBlockedUpgrade = (Get-FileHash "$data\phrases.json").Hash
    $blocked = Start-Process $setup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="{0}\running-app.log"' -f $evidence)) -PassThru
    if (!$blocked.WaitForExit(30000) -or $blocked.ExitCode -eq 0) { throw 'Setup did not safely refuse to replace the running application.' }
    if ((Get-FileHash "$data\phrases.json").Hash -ne $beforeBlockedUpgrade) { throw 'Blocked upgrade modified the library.' }
    # Dispose this CI-only process before upgrade; never force-close a user's app.
    Stop-Process -Id $app.Id -Force
    $document = Get-Content "$data\phrases.json" -Raw | ConvertFrom-Json
    $fixture = [pscustomobject]@{ Id=[Guid]::NewGuid().ToString(); Title='Installer preservation check'; Text='Fictional installer test phrase'; CategoryId=$document.Categories[0].Id; IsEnabled=$true; IsFavorite=$false; UseCount=7 }
    $document.Phrases = @($document.Phrases) + @($fixture)
    $document | ConvertTo-Json -Depth 30 | Set-Content "$data\phrases.json" -Encoding UTF8
    $hash = (Get-FileHash "$data\phrases.json").Hash
    Copy-Item "$data\phrases.json" "$data\phrases.backup.json"
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
    if ((Get-FileHash "$data\phrases.backup.json").Hash -ne $hash) { throw 'Uninstall removed or modified the backup.' }
    Run-Silent $setup @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="{0}\reinstall.log"' -f $evidence))
    $reopened = Start-Process "$installed\CommonCopy.exe" -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $reopened.Refresh()
        if ($reopened.HasExited) { throw 'Reinstalled application failed to reopen.' }
        if ($reopened.MainWindowHandle -ne 0) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($reopened.MainWindowHandle -eq 0) { throw 'Reinstalled manager did not appear.' }
    if ((Get-FileHash "$data\phrases.json").Hash -ne $hash) { throw 'Reinstalled application replaced the existing library.' }
    Stop-Process -Id $reopened.Id -Force
    Run-Silent "$installed\unins000.exe" @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    Set-Content "$evidence\result.txt" 'PASS: interactive install, application launch, offline help, shortcut, running-app guard, upgrade preservation, uninstall, startup cleanup, library and backup preservation, and reopening after reinstall. Physical Windows 10/11 and DPI review remain required.'
} catch {
    $_ | Out-String | Set-Content "$evidence\failure.txt"
    throw
}
