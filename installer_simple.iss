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
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\EST STAR Commande"; Filename: "{app}\estarcommande.exe"
Name: "{group}\{cm:UninstallProgram,EST STAR Commande}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\EST STAR Commande"; Filename: "{app}\estarcommande.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\estarcommande.exe"; Description: "{cm:LaunchProgram,EST STAR Commande}"; Flags: nowait postinstall skipifsilent
