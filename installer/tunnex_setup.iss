[Setup]
AppName=Tunnex VPN
AppVersion=1.4.0
AppPublisher=Tunnex
AppPublisherURL=https://github.com/ChernOvOne/tunnex
DefaultDirName={autopf}\Tunnex
DefaultGroupName=Tunnex
OutputDir=..\build\installer
OutputBaseFilename=Tunnex-Setup-v1.4.0
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\assets\icons\logo.ico
UninstallDisplayIcon={app}\tunnex.exe
PrivilegesRequired=admin
WizardStyle=modern
DisableProgramGroupPage=yes
DisableWelcomePage=no
LicenseFile=
WizardImageFile=
WizardSmallImageFile=

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startup"; Description: "Запускать при входе в Windows"; GroupDescription: "Дополнительно:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "..\build\windows\x64\runner\Release\xray\xray.exe"; DestDir: "{app}\xray"; DestName: "tunnex-core.exe"; Flags: ignoreversion

[Icons]
Name: "{group}\Tunnex VPN"; Filename: "{app}\tunnex.exe"
Name: "{autodesktop}\Tunnex VPN"; Filename: "{app}\tunnex.exe"; Tasks: desktopicon
Name: "{userstartup}\Tunnex VPN"; Filename: "{app}\tunnex.exe"; Tasks: startup

[Run]
Filename: "{app}\tunnex.exe"; Description: "Запустить Tunnex VPN"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallRun]
Filename: "taskkill"; Parameters: "/F /IM tunnex.exe"; Flags: runhidden
Filename: "taskkill"; Parameters: "/F /IM tunnex-core.exe"; Flags: runhidden
Filename: "taskkill"; Parameters: "/F /IM tun2socks-windows-amd64.exe"; Flags: runhidden
