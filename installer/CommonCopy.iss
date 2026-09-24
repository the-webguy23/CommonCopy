#define MyAppName "CommonCopy"
#define MyAppVersion "0.2.0-dev"
#define MyAppPublisher "CommonCopy contributors"
#define MyAppExeName "CommonCopy.exe"

[Setup]
AppId={{D40544E3-0E8D-4DF8-90E3-D7EAB1D77892}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=CommonCopy-Setup-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}

[Tasks]
Name: "startup"; Description: "Start CommonCopy when I sign in"; GroupDescription: "Additional options:"; Flags: unchecked

[Files]
Source: "..\artifacts\publish\win-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[InstallDelete]
Type: files; Name: "{userprograms}\PhraseMenu.lnk"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "PhraseMenu"; Flags: deletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "CommonCopy"; ValueData: """{app}\{#MyAppExeName}"" --startup --enable-startup"; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExeName}"; Parameters: "--enable-startup"; Description: "Launch CommonCopy"; Flags: nowait postinstall skipifsilent; Tasks: startup
Filename: "{app}\{#MyAppExeName}"; Description: "Launch CommonCopy"; Flags: nowait postinstall skipifsilent; Tasks: not startup
