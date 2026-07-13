; Script Inno Setup per VEXON.
; Inno Setup è gratuito: https://jrsoftware.org/isinfo.php
;
; COME USARLO:
; 1. Compila l'app in modalità release:  flutter build windows
; 2. Installa Inno Setup (link sopra)
; 3. Apri questo file con Inno Setup Compiler e premi "Compile"
;    (oppure da riga di comando: iscc vexon_installer.iss)
; 4. Il risultato è un unico file "VEXON_Setup.exe" in installer/output/
;
; Prima di compilare, verifica che SourceDir sotto punti davvero alla
; cartella generata da "flutter build windows" (di solito
; build\windows\x64\runner\Release, ma può variare in base alla versione
; di Flutter — controlla il percorso reale sul tuo PC).

#define MyAppName "VEXON"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Tesys Group"
#define MyAppExeName "vexon.exe"
#define SourceDir "..\build\windows\x64\runner\Release"
#define CompanionExe "..\companion_service\bin\Release\net8.0\win-x64\publish\vexon_hardware_service.exe"

[Setup]
AppId={{B6E8C9A1-VEXON-4F3D-9C1B-000000000001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=VEXON_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Icona mostrata nell'installer stesso (non l'icona dell'app installata,
; quella viene già dall'.exe generato da flutter_launcher_icons)
SetupIconFile=..\assets\icons\vexon_taskbar.ico
; Nessuna firma digitale del codice qui: senza un certificato di code
; signing, Windows SmartScreen mostrerà un avviso "editore sconosciuto"
; al primo avvio dell'installer. Per un prodotto venduto a clienti B2B
; vale la pena valutare un certificato in futuro (vedi nota in SETUP.md).

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "Crea un'icona sul Desktop"; GroupDescription: "Icone aggiuntive:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Il companion deve stare nella STESSA cartella dell'eseguibile principale,
; perché HardwareCompanionLauncher lo cerca accanto a
; Platform.resolvedExecutable — vedi lib/services/hardware_companion_launcher.dart.
; Se non hai ancora pubblicato il companion service, commenta la riga sotto:
; l'app funziona comunque con dati hardware simulati.
Source: "{#CompanionExe}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Avvia {#MyAppName}"; Flags: nowait postinstall skipifsilent
