; XatBox for Windows installer (Inno Setup 6). Built by scripts\build-windows.ps1:
;   ISCC /DAppVersion=0.1.0 /DAppBuild=2 /DSourceDir=<Release dir> /DOutputDir=dist xatbox.iss
; Per-user install (no administrator rights), like desktop messengers: the app
; lands in %LOCALAPPDATA%\Programs\XatBox and updates itself there.
;
; IT departments install it for all users of a computer instead (Program Files,
; Start menu for everyone; the app then leaves updates to them):
;   XatBox-Setup-<version>.exe /VERYSILENT /ALLUSERS /NOLAUNCH
; /NOLAUNCH: do not start XatBox after a silent install (update on quit).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppBuild
  #define AppBuild "0"
#endif
#ifndef SourceDir
  #error SourceDir (the flutter build windows output) is required
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

[Setup]
; Fixed for the lifetime of the app: Windows finds the installed copy by it.
AppId={{6B7E3C1A-5D2F-4E8B-9A41-2C7F0D3E8B15}
AppName=XatBox
AppVersion={#AppVersion}
AppVerName=XatBox {#AppVersion}
VersionInfoVersion={#AppVersion}.{#AppBuild}
AppPublisher=XatBox
; {autopf}: %LOCALAPPDATA%\Programs per user, Program Files with /ALLUSERS.
DefaultDirName={autopf}\XatBox
DefaultGroupName=XatBox
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=XatBox-Setup-{#AppVersion}-b{#AppBuild}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\XatBox.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; A running XatBox (often hidden in the tray) is closed for the update.
CloseApplications=force
RestartApplications=no
; build-windows.ps1 passes /DSignInstaller and the «xatbox» sign tool when
; code signing is set up: the installer and the uninstaller are signed too.
#ifdef SignInstaller
SignTool=xatbox
SignedUninstaller=yes
#endif

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
ru.AutoStart=Запускать XatBox при входе в Windows
en.AutoStart=Start XatBox when I sign in to Windows
ru.DesktopIcon=Значок на рабочем столе
en.DesktopIcon=Desktop shortcut
ru.MailDescription=Почта, чат и звонки университета
en.MailDescription=University mail, chat and calls
ru.SendToName=XatBox (новое письмо)
en.SendToName=XatBox (new message)
ru.EmlName=Письмо
en.EmlName=Email message
ru.IcsName=Приглашение в календарь
en.IcsName=Calendar invitation

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"
Name: "autostart"; Description: "{cm:AutoStart}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; The AppUserModelID must match LocalNotificationHub.windowsAppUserModelId:
; Windows attributes the app's toasts to this shortcut.
Name: "{autoprograms}\XatBox"; Filename: "{app}\XatBox.exe"; AppUserModelID: "Xatbox.XatBox.Desktop"
Name: "{autodesktop}\XatBox"; Filename: "{app}\XatBox.exe"; Tasks: desktopicon
; Explorer → Отправить → XatBox: a new message with the chosen files. Per
; user only (an all-users install has no shared Send To folder).
Name: "{usersendto}\{cm:SendToName}"; Filename: "{app}\XatBox.exe"; Parameters: "--attach"; Check: not IsAdminInstallMode

[Registry]
; HKA: the current user, or the whole computer with /ALLUSERS.
; --hidden: at sign-in the window waits in the tray.
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "XatBox"; ValueData: """{app}\XatBox.exe"" --hidden"; Flags: uninsdeletevalue; Tasks: autostart
; mailto: links. Windows lists XatBox under Settings → Apps → Default apps;
; the app's settings open that page (ms-settings:defaultapps?registeredApp…=XatBox).
Root: HKA; Subkey: "Software\Classes\XatBox.mailto"; ValueType: string; ValueData: "URL:MailTo Protocol"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\XatBox.mailto"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\XatBox.mailto\DefaultIcon"; ValueType: string; ValueData: """{app}\XatBox.exe"",0"
Root: HKA; Subkey: "Software\Classes\XatBox.mailto\shell\open\command"; ValueType: string; ValueData: """{app}\XatBox.exe"" ""%1"""
Root: HKA; Subkey: "Software\XatBox\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "XatBox"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\XatBox\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "{cm:MailDescription}"
Root: HKA; Subkey: "Software\XatBox\Capabilities"; ValueType: string; ValueName: "ApplicationIcon"; ValueData: """{app}\XatBox.exe"",0"
Root: HKA; Subkey: "Software\XatBox\Capabilities\URLAssociations"; ValueType: string; ValueName: "mailto"; ValueData: "XatBox.mailto"
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "XatBox"; ValueData: "Software\XatBox\Capabilities"; Flags: uninsdeletevalue
; Open with → XatBox for saved messages (.eml) and invitations (.ics); the
; defaults stay as they are, the user may choose XatBox.
Root: HKA; Subkey: "Software\Classes\XatBox.eml"; ValueType: string; ValueData: "{cm:EmlName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\XatBox.eml\DefaultIcon"; ValueType: string; ValueData: """{app}\XatBox.exe"",0"
Root: HKA; Subkey: "Software\Classes\XatBox.eml\shell\open\command"; ValueType: string; ValueData: """{app}\XatBox.exe"" ""%1"""
Root: HKA; Subkey: "Software\Classes\XatBox.ics"; ValueType: string; ValueData: "{cm:IcsName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\XatBox.ics\DefaultIcon"; ValueType: string; ValueData: """{app}\XatBox.exe"",0"
Root: HKA; Subkey: "Software\Classes\XatBox.ics\shell\open\command"; ValueType: string; ValueData: """{app}\XatBox.exe"" ""%1"""
Root: HKA; Subkey: "Software\Classes\.eml\OpenWithProgids"; ValueType: string; ValueName: "XatBox.eml"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.ics\OpenWithProgids"; ValueType: string; ValueName: "XatBox.ics"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\XatBox\Capabilities\FileAssociations"; ValueType: string; ValueName: ".eml"; ValueData: "XatBox.eml"
Root: HKA; Subkey: "Software\XatBox\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ics"; ValueData: "XatBox.ics"

[Run]
Filename: "{app}\XatBox.exe"; Description: "{cm:LaunchProgram,XatBox}"; Flags: nowait postinstall skipifsilent
; In-app update (/SILENT from the running app): start the new build again.
Filename: "{app}\XatBox.exe"; Flags: nowait; Check: RestartAfterSilentInstall

[Code]
// Not after «Обновить при выходе» (/NOLAUNCH), and never for an all-users
// install: IT tools run it as SYSTEM or an administrator, not as the user.
function RestartAfterSilentInstall: Boolean;
begin
  Result := WizardSilent and not IsAdminInstallMode and
    (Pos('/NOLAUNCH', UpperCase(GetCmdTail)) = 0);
end;
