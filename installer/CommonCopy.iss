#define MyAppName "CommonCopy"
#define MyAppVersion "0.4.2"
#define MyAppExeName "CommonCopy.exe"

[Setup]
AppId={{D40544E3-0E8D-4DF8-90E3-D7EAB1D77892}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=CommonCopy contributors
DefaultDirName={localappdata}\Programs\CommonCopy
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableWelcomePage=yes
DisableReadyMemo=yes
DisableFinishedPage=no
OutputDir=output
OutputBaseFilename=CommonCopy-Setup-x64
SetupIconFile=..\artifacts\branding\CommonCopy.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
CloseApplications=yes
CloseApplicationsFilter=CommonCopy.exe
RestartApplications=no
SetupLogging=yes

[Files]
Source: "..\artifacts\publish\win-x64\CommonCopy.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\artifacts\publish\win-x64\Help\help.html"; DestDir: "{app}\Help"; Flags: ignoreversion
Source: "..\artifacts\publish\win-x64\Notices\*"; DestDir: "{app}\Notices"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion
Source: "..\artifacts\branding\CommonCopy.bmp"; Flags: dontcopy
Source: "..\LICENSE"; DestName: "CommonCopy-LICENSE.txt"; Flags: dontcopy

[Icons]
Name: "{userprograms}\CommonCopy"; Filename: "{app}\{#MyAppExeName}"

[Registry]
; Uninstall removes startup registration, never the user's phrase library.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "CommonCopy"; Flags: uninsdeletevalue

[Code]
type TProcessIds = array[0..4095] of LongWord;
function GetCurrentProcessId: LongWord;
  external 'GetCurrentProcessId@kernel32.dll stdcall';
function ProcessIdToSessionId(ProcessId: LongWord; var SessionId: LongWord): Boolean;
  external 'ProcessIdToSessionId@kernel32.dll stdcall';
function EnumProcesses(var Ids: TProcessIds; BufferSize: LongWord; var BytesNeeded: LongWord): Boolean;
  external 'EnumProcesses@psapi.dll stdcall';
function OpenProcess(Access: LongWord; InheritHandle: Boolean; ProcessId: LongWord): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function QueryFullProcessImageName(ProcessHandle: THandle; Flags: LongWord; FileName: String; var Size: LongWord): Boolean;
  external 'QueryFullProcessImageNameW@kernel32.dll stdcall';
function CloseHandle(Handle: THandle): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';
function CreateRoundRectRgn(Left, Top, Right, Bottom, EllipseWidth, EllipseHeight: Integer): THandle;
  external 'CreateRoundRectRgn@gdi32.dll stdcall';
function SetWindowRgn(Window: HWND; Region: THandle; Redraw: Boolean): Integer;
  external 'SetWindowRgn@user32.dll stdcall';
function DeleteObject(Handle: THandle): Boolean;
  external 'DeleteObject@gdi32.dll stdcall';

var
  BrandImage: TBitmapImage;
  BrandName, Tagline, Heading, Detail, ProgressText: TNewStaticText;
  LicenseLink: TNewButton;
  Progress: TNewProgressBar;
  InstallerCard: TPanel;
  CardBackground: TBitmapImage;
  OriginalResize: TNotifyEvent;
  Rounding: Boolean;

procedure RoundInstallerCard(Sender: TObject);
var Region: THandle;
begin
  if Rounding or (InstallerCard.Width < 2) or (InstallerCard.Height < 2) then Exit;
  Rounding := True;
  try
    Region := CreateRoundRectRgn(0, 0, InstallerCard.Width, InstallerCard.Height, ScaleX(28), ScaleY(28));
    if Region <> 0 then begin
      { Round only the content card; preserve the native DWM title bar and shadow. }
      if SetWindowRgn(InstallerCard.Handle, Region, True) = 0 then DeleteObject(Region);
    end;
  finally
    Rounding := False;
  end;
end;

procedure WizardResized(Sender: TObject);
begin
  if Rounding then Exit;
  if OriginalResize <> nil then OriginalResize(Sender);
  InstallerCard.SetBounds(ScaleX(12), ScaleY(12), WizardForm.ClientWidth - ScaleX(24), WizardForm.ClientHeight - ScaleY(24));
  CardBackground.SetBounds(0, 0, InstallerCard.Width, InstallerCard.Height);
  RoundInstallerCard(Sender);
end;

function AppIsRunning: Boolean;
var Ids: TProcessIds; BytesNeeded, SessionId, OtherSession, Size: LongWord;
    I: Integer; Handle: THandle; FileName, BaseName: String;
begin
  Result := False;
  if not ProcessIdToSessionId(GetCurrentProcessId, SessionId) then Exit;
  if not EnumProcesses(Ids, SizeOf(Ids), BytesNeeded) then Exit;
  for I := 0 to (BytesNeeded div 4) - 1 do begin
    if ProcessIdToSessionId(Ids[I], OtherSession) and (OtherSession = SessionId) then begin
      Handle := OpenProcess($1000, False, Ids[I]);
      if Handle <> 0 then begin
        Size := 32768;
        SetLength(FileName, Size);
        if QueryFullProcessImageName(Handle, 0, FileName, Size) then begin
          SetLength(FileName, Size);
          BaseName := ExtractFileName(FileName);
          Result := (CompareText(BaseName, 'CommonCopy.exe') = 0) or (CompareText(BaseName, 'PhraseMenu.exe') = 0);
        end;
        CloseHandle(Handle);
        if Result then Exit;
      end;
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if AppIsRunning then
    Result := 'CommonCopy is still running. Right-click its icon beside the clock (check the hidden-icons arrow), choose Exit, then click Retry. Closing the manager only hides it.';
end;

function InitializeUninstall: Boolean;
begin
  Result := not AppIsRunning;
  if not Result and not UninstallSilent then
    MsgBox('Exit CommonCopy from its icon beside the clock, then start uninstall again. Your saved phrases will be kept.', mbInformation, MB_OK);
end;

function LabelAt(Text: String; X, Y, W, H, Size: Integer): TNewStaticText;
begin
  Result := TNewStaticText.Create(WizardForm);
  Result.Parent := InstallerCard;
  Result.AutoSize := False;
  Result.SetBounds(ScaleX(X - 12), ScaleY(Y - 12), ScaleX(W), ScaleY(H));
  Result.Caption := Text;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := Size;
  Result.Font.Color := clBlack;
  Result.WordWrap := True;
end;

procedure ShowLicense(Sender: TObject);
var ResultCode: Integer;
begin
  ExtractTemporaryFile('CommonCopy-LICENSE.txt');
  ShellExec('open', ExpandConstant('{tmp}\CommonCopy-LICENSE.txt'), '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
end;

procedure InitializeWizard;
begin
  WizardForm.Caption := 'CommonCopy Setup';
  WizardForm.ClientWidth := ScaleX(500);
  WizardForm.ClientHeight := ScaleY(400);
  WizardForm.Color := $00F0F0F0;
  InstallerCard := TPanel.Create(WizardForm);
  InstallerCard.Parent := WizardForm;
  InstallerCard.BevelOuter := bvNone;
  InstallerCard.Color := clWhite;
  InstallerCard.SetBounds(ScaleX(12), ScaleY(12), ScaleX(476), ScaleY(376));
  { TPanel inherits the themed parent background; paint an opaque white surface. }
  CardBackground := TBitmapImage.Create(WizardForm);
  CardBackground.Parent := InstallerCard;
  CardBackground.SetBounds(0, 0, InstallerCard.Width, InstallerCard.Height);
  CardBackground.Bitmap.Width := 1;
  CardBackground.Bitmap.Height := 1;
  CardBackground.Bitmap.Canvas.Pixels[0, 0] := clWhite;
  CardBackground.Stretch := True;
  WizardForm.NextButton.SetBounds(ScaleX(316), ScaleY(346), ScaleX(156), ScaleY(34));
  WizardForm.CancelButton.SetBounds(ScaleX(204), ScaleY(346), ScaleX(100), ScaleY(34));
  BrandImage := TBitmapImage.Create(WizardForm);
  BrandImage.Parent := InstallerCard;
  BrandImage.SetBounds(ScaleX(24), ScaleY(28), ScaleX(62), ScaleY(76));
  BrandImage.Stretch := True;
  ExtractTemporaryFile('CommonCopy.bmp');
  BrandImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\CommonCopy.bmp'));
  BrandName := LabelAt('CommonCopy', 112, 48, 340, 44, 28);
  BrandName.Font.Style := [fsBold];
  Tagline := LabelAt('Save it once. Paste it forever.', 114, 94, 340, 28, 11);
  Heading := LabelAt('', 36, 164, 428, 34, 20);
  Heading.Font.Style := [fsBold];
  Detail := LabelAt('', 36, 210, 428, 64, 11);
  ProgressText := LabelAt('', 36, 284, 428, 22, 10);
  Progress := TNewProgressBar.Create(WizardForm);
  Progress.Parent := InstallerCard;
  Progress.SetBounds(ScaleX(24), ScaleY(298), ScaleX(428), ScaleY(6));
  Progress.Max := 1000;
  LicenseLink := TNewButton.Create(WizardForm);
  LicenseLink.Parent := InstallerCard;
  LicenseLink.SetBounds(ScaleX(16), ScaleY(334), ScaleX(132), ScaleY(34));
  LicenseLink.Caption := 'MIT License';
  LicenseLink.OnClick := @ShowLicense;
  OriginalResize := WizardForm.OnResize;
  WizardForm.OnResize := @WizardResized;
  RoundInstallerCard(nil);
end;

procedure CurPageChanged(CurPageID: Integer);
var Card: Boolean;
begin
  Card := (CurPageID = wpReady) or (CurPageID = wpInstalling) or (CurPageID = wpFinished);
  InstallerCard.Visible := Card;
  RoundInstallerCard(nil);
  WizardForm.NextButton.BringToFront;
  WizardForm.CancelButton.BringToFront;
  WizardForm.OuterNotebook.Visible := not Card;
  WizardForm.Bevel.Visible := not Card;
  BrandImage.Visible := Card;
  BrandName.Visible := Card;
  Tagline.Visible := Card;
  Heading.Visible := Card;
  Detail.Visible := Card;
  LicenseLink.Visible := Card;
  Progress.Visible := CurPageID = wpInstalling;
  ProgressText.Visible := CurPageID = wpInstalling;
  if Card then WizardForm.BackButton.Visible := False;
  if CurPageID = wpReady then begin
    Heading.Caption := 'Ready when you are.';
    Detail.Caption := 'Install CommonCopy for your Windows account.' + #13#10 + 'Your saved phrases stay with you when you update.';
    WizardForm.NextButton.Caption := 'Install CommonCopy';
  end;
  if CurPageID = wpInstalling then begin
    Heading.Caption := 'Installing CommonCopy';
    Detail.Caption := 'Making your words a right-click away.';
    ProgressText.Caption := 'Installing files...';
  end;
  if CurPageID = wpFinished then begin
    Heading.Caption := 'You''re all set.';
    Detail.Caption := 'Open CommonCopy to manage your phrases.' + #13#10 + 'Use Ctrl + right-click when you need them.';
    WizardForm.NextButton.Caption := 'Open CommonCopy';
  end;
end;

procedure CurInstallProgressChanged(CurProgress, MaxProgress: Integer);
begin
  if MaxProgress > 0 then begin
    Progress.Position := Round((CurProgress / MaxProgress) * 1000);
    ProgressText.Caption := 'Installing files... ' + IntToStr(Round((CurProgress / MaxProgress) * 100)) + '%';
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var ResultCode: Integer;
begin
  Result := True;
  if (CurPageID = wpFinished) and not WizardSilent then begin
    if not ShellExec('open', ExpandConstant('{app}\{#MyAppExeName}'), '', ExpandConstant('{app}'), SW_SHOWNORMAL, ewNoWait, ResultCode) then begin
      MsgBox('CommonCopy is installed, but Windows could not open it. Try the CommonCopy shortcut in Start.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;
