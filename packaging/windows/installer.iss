#define AppVersion GetEnv("POE2_APP_VERSION")
#define ReleaseDirectory GetEnv("POE2_RELEASE_DIRECTORY")
#define InstallerOutput GetEnv("POE2_INSTALLER_OUTPUT")
#define InstallerBaseName GetEnv("POE2_INSTALLER_BASENAME")

[Setup]
AppId={{6E66BBE0-54A4-4F30-916A-48D5199C29E7}
AppName=POE2 LootTracker
AppVersion={#AppVersion}
AppPublisher=zifox666
DefaultDirName={autopf}\POE2LootTracker
DefaultGroupName=POE2 LootTracker
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\poe2_loot_tracker.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputDir={#InstallerOutput}
OutputBaseFilename={#InstallerBaseName}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=yes
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#ReleaseDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "installed.marker"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\POE2 LootTracker"; Filename: "{app}\poe2_loot_tracker.exe"
Name: "{autodesktop}\POE2 LootTracker"; Filename: "{app}\poe2_loot_tracker.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\poe2_loot_tracker.exe"; Description: "{cm:LaunchProgram,POE2 LootTracker}"; Flags: nowait postinstall skipifsilent runascurrentuser
