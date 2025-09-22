#define AppVersion GetEnv("APP_VERSION")
#if AppVersion == ""
  #define AppVersion "1.0.0"
#endif

[Setup]
AppName=EST STAR Commande
AppVersion={#AppVersion}
DefaultDirName={autopf}\EST STAR Commande
DefaultGroupName=EST STAR Commande
OutputDir=dist
OutputBaseFilename=EST_STAR_Commande_Setup_v{#AppVersion}
Compression=lzma
SolidCompression=yes
; SetupIconFile=assets\icons\icon.ico
UninstallDisplayIcon={app}\est_star_commande.exe
PrivilegesRequired=admin
; Update-related settings
VersionInfoVersion={#AppVersion}.0
VersionInfoProductVersion={#AppVersion}
UninstallDisplayName=EST STAR Commande
; Allow updating over existing installation
CreateUninstallRegKey=yes
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousSetupType=yes
UsePreviousTasks=yes
UsePreviousUserInfo=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\EST STAR Commande"; Filename: "{app}\est_star_commande.exe"
Name: "{group}\{cm:UninstallProgram,EST STAR Commande}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\EST STAR Commande"; Filename: "{app}\est_star_commande.exe"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\EST STAR Commande"; Filename: "{app}\est_star_commande.exe"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\est_star_commande.exe"; Description: "{cm:LaunchProgram,EST STAR Commande}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKCU; Subkey: "Software\EST STAR\EST STAR Commande"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKCU; Subkey: "Software\EST STAR\EST STAR Commande"; ValueType: string; ValueName: "Version"; ValueData: "{#AppVersion}"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\EST STAR Commande"; ValueType: string; ValueName: "DisplayName"; ValueData: "EST STAR Commande"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\EST STAR Commande"; ValueType: string; ValueName: "UninstallString"; ValueData: "{uninstallexe}"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\EST STAR Commande"; ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#AppVersion}"

[Code]
function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
  CurrentVersion: String;
  UninstallString: String;
  ErrorCode: Integer;
begin
  Result := True;
  CurrentVersion := '{#AppVersion}';
  
  // Check if app is already installed
  if RegQueryStringValue(HKEY_CURRENT_USER, 'Software\EST STAR\EST STAR Commande', 'Version', InstalledVersion) then
  begin
    // If same version, ask user
    if InstalledVersion = CurrentVersion then
    begin
      if MsgBox('EST STAR Commande ' + InstalledVersion + ' est déjà installé. Voulez-vous le réinstaller?', 
                mbConfirmation, MB_YESNO) = IDNO then
      begin
        Result := False;
        Exit;
      end;
    end
    else
    begin
      // Different version - show update dialog
      if MsgBox('EST STAR Commande ' + InstalledVersion + ' est installé. Voulez-vous mettre à jour vers la version ' + CurrentVersion + '?', 
                mbConfirmation, MB_YESNO) = IDNO then
      begin
        Result := False;
        Exit;
      end;
    end;
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  if MsgBox('Êtes-vous sûr de vouloir désinstaller EST STAR Commande et tous ses composants?', 
            mbConfirmation, MB_YESNO) = IDNO then
    Result := False;
end;
