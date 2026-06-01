[Setup]
AppName=CREANNO
AppVersion=1.4.0
AppVerName=CREANNO 1.4.0
AppPublisher=Smart Innovations
AppPublisherURL=https://backend-production-8b728.up.railway.app
AppSupportURL=https://backend-production-8b728.up.railway.app
AppCopyright=Copyright (C) 2025 Smart Innovations
DefaultDirName={autopf}\CREANNO
DefaultGroupName=CREANNO
OutputDir=C:\Users\lokes\Desktop\CREANNO_Distribution\Windows
OutputBaseFilename=CREANNO_Setup_v1.4.0
SetupIconFile=C:\Users\lokes\Desktop\Lokesh Claude\Company app\mobile\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\company_app.exe

; FIX 1: Require admin so installer can write shortcuts/registry properly
; This triggers UAC prompt — user clicks Yes once, then no more access denied errors
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

ArchitecturesInstallIn64BitMode=x64compatible

; Version info embedded in setup.exe — helps SmartScreen trust it
VersionInfoVersion=1.4.0.0
VersionInfoCompany=Smart Innovations
VersionInfoDescription=CREANNO Company Management App
VersionInfoCopyright=Copyright 2025 Smart Innovations
VersionInfoProductName=CREANNO
VersionInfoProductVersion=1.4.0.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "C:\Users\lokes\Desktop\Lokesh Claude\Company app\mobile\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; FIX 1: Use {commondesktop} — now works because we require admin
Name: "{group}\CREANNO"; Filename: "{app}\company_app.exe"
Name: "{group}\{cm:UninstallProgram,CREANNO}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\CREANNO"; Filename: "{app}\company_app.exe"; Tasks: desktopicon

[Registry]
; Register app in Windows — helps Windows trust the app over time (SmartScreen reputation)
Root: HKLM; Subkey: "Software\Smart Innovations\CREANNO"; ValueType: string; ValueName: "Version"; ValueData: "1.1.0"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Smart Innovations\CREANNO"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"

[Run]
Filename: "{app}\company_app.exe"; Description: "{cm:LaunchProgram,CREANNO}"; Flags: nowait postinstall skipifsilent
