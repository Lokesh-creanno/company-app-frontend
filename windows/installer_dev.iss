; ══════════════════════════════════════════════════════════════════════════════
;  CREANNO — DEV / TEST INSTALLER
;  ─────────────────────────────────────────────────────────────────────────────
;  PURPOSE : Test new features BEFORE they go into the production installer.
;
;  ✅ SAFE TO USE ALONGSIDE PRODUCTION:
;     - Installs to a DIFFERENT folder  →  C:\Program Files\CREANNO-Dev\
;     - Separate Start Menu group       →  "CREANNO Dev"
;     - Desktop icon labeled            →  "CREANNO [DEV]"
;     - Separate registry key           →  Software\Smart Innovations\CREANNO-Dev
;     - WILL NOT overwrite or affect the production CREANNO installation
;
;  WORKFLOW:
;     1. Build Windows exe  (scripts\build_dev.ps1 does this automatically)
;     2. Run THIS installer → installs "CREANNO Dev" alongside production
;     3. Test all new features thoroughly
;     4. If ✅ everything works → run scripts\build_production.ps1
;     5. Production installer (installer.iss) is ONLY updated after testing passes
;
;  OUTPUT  →  C:\Users\lokes\Desktop\CREANNO_Distribution\Dev\CREANNO_Dev_Setup.exe
; ══════════════════════════════════════════════════════════════════════════════

[Setup]
AppName=CREANNO Dev
AppVersion=DEV
AppVerName=CREANNO [DEV BUILD]
AppPublisher=Smart Innovations
AppPublisherURL=https://backend-production-8b728.up.railway.app
AppSupportURL=https://backend-production-8b728.up.railway.app
AppCopyright=Copyright (C) 2025 Smart Innovations

; ── Different install location — does NOT conflict with production ─────────────
DefaultDirName={autopf}\CREANNO-Dev
DefaultGroupName=CREANNO Dev

; ── Output ────────────────────────────────────────────────────────────────────
OutputDir=C:\Users\lokes\Desktop\CREANNO_Distribution\Dev
OutputBaseFilename=CREANNO_Dev_Setup

SetupIconFile=C:\Users\lokes\Desktop\Lokesh Claude\Company app\mobile\windows\runner\resources\app_icon.ico
Compression=zip
SolidCompression=no
WizardStyle=modern
UninstallDisplayIcon={app}\company_app.exe

PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

ArchitecturesInstallIn64BitMode=x64compatible

VersionInfoVersion=0.0.0.1
VersionInfoCompany=Smart Innovations
VersionInfoDescription=CREANNO Dev Build — NOT FOR DISTRIBUTION
VersionInfoCopyright=Copyright 2025 Smart Innovations
VersionInfoProductName=CREANNO Dev
VersionInfoProductVersion=0.0.0.1

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create desktop icon (CREANNO [DEV])"; GroupDescription: "Additional Icons"

[Files]
Source: "C:\Users\lokes\Desktop\Lokesh Claude\Company app\mobile\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Desktop & Start Menu icons use different names → no conflict with production
Name: "{group}\CREANNO Dev"; Filename: "{app}\company_app.exe"
Name: "{group}\Uninstall CREANNO Dev"; Filename: "{uninstallexe}"
Name: "{commondesktop}\CREANNO [DEV]"; Filename: "{app}\company_app.exe"; Tasks: desktopicon

[Registry]
; Separate registry key — does NOT touch production CREANNO registry
Root: HKLM; Subkey: "Software\Smart Innovations\CREANNO-Dev"; ValueType: string; ValueName: "Version"; ValueData: "DEV"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Smart Innovations\CREANNO-Dev"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKLM; Subkey: "Software\Smart Innovations\CREANNO-Dev"; ValueType: string; ValueName: "IsDev"; ValueData: "true"

[Run]
Filename: "{app}\company_app.exe"; Description: "Launch CREANNO Dev"; Flags: nowait postinstall skipifsilent
