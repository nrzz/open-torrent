; packaging/windows/opentorrent.iss — Inno Setup installer
#define MyAppName "OpenTorrent"
#define MyAppVersion "0.2.0"
#define MyAppPublisher "OpenTorrent Contributors"
#define MyAppURL "https://github.com/nrzz/open-torrent"
#define MyAppExeName "open_torrent.exe"

[Setup]
AppId={{8F3C2A1B-9D4E-4F6A-B2C1-7E5D9A0F3B21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\..\dist
OutputBaseFilename=OpenTorrent-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "magnet"; Description: "Associate magnet: links"; GroupDescription: "Associations:"
Name: "torrent"; Description: "Associate .torrent files"; GroupDescription: "Associations:"

[Files]
Source: "..\..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\magnet"; ValueType: string; ValueData: "URL:BitTorrent Magnet"; Flags: uninsdeletekey; Tasks: magnet
Root: HKCU; Subkey: "Software\Classes\magnet"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: magnet
Root: HKCU; Subkey: "Software\Classes\magnet\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: magnet
Root: HKCU; Subkey: "Software\Classes\.torrent"; ValueType: string; ValueData: "OpenTorrent.Torrent"; Flags: uninsdeletevalue; Tasks: torrent
Root: HKCU; Subkey: "Software\Classes\OpenTorrent.Torrent"; ValueType: string; ValueData: "BitTorrent File"; Flags: uninsdeletekey; Tasks: torrent
Root: HKCU; Subkey: "Software\Classes\OpenTorrent.Torrent\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: torrent

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
