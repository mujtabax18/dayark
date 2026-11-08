; DayArk Windows release installer (Inno Setup 6)
; Build once: flutter build windows --release
; Package:   ISCC.exe /DMyAppVersion=0.0.38 packaging\windows\dayark.iss
; IMPORTANT: AppId MUST remain the same in every future release.
#ifndef MyAppVersion
  #define MyAppVersion "0.0.37"
#endif

[Setup]
AppId={{CE08BC5F-9761-4BDC-8B1C-91CC2C59B5A9}
AppName=DayArk
AppVersion={#MyAppVersion}
AppPublisher=DayArk
DefaultDirName={localappdata}\Programs\DayArk
DefaultGroupName=DayArk
PrivilegesRequired=lowest
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=DayArk-Setup-windows-x64
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\metersystem.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\DayArk"; Filename: "{app}\metersystem.exe"
Name: "{autodesktop}\DayArk"; Filename: "{app}\metersystem.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\metersystem.exe"; Description: "Launch DayArk"; Flags: nowait postinstall skipifsilent
