Unicode true
Name "RIFTCORE Installer 0.2"
VIProductVersion "0.2.0.0"
VIAddVersionKey /LANG=1033 "ProductName" "RIFTCORE Installer"
VIAddVersionKey /LANG=1033 "FileVersion" "0.2.0"
VIAddVersionKey /LANG=1033 "FileDescription" "RIFTCORE Installer and Updater"
VIAddVersionKey /LANG=1033 "LegalCopyright" "RIFTCORE"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\RIFTCORE"
InstallDirRegKey HKCU "Software\RIFTCORE" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!define MUI_ICON "${BRAND_ICO}"
!define MUI_UNICON "${BRAND_ICO}"
!include "MUI2.nsh"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\RIFTCORE.exe"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\RIFTCORE.exe"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Open Steam's Add a Non-Steam Game dialog"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION OpenSteamShortcut
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function OpenSteamShortcut
  ClearErrors
  ExecShell "open" "steam://AddNonSteamGame"
  IfErrors 0 +2
  MessageBox MB_OK "Open Steam and choose Games > Add a Non-Steam Game to My Library. Select $INSTDIR\RIFTCORE.exe."
FunctionEnd

Section "RIFTCORE Playtest" Main
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD}/*"
  FileOpen $0 "$INSTDIR\riftcore.install" w
  FileWrite $0 "RIFTCORE playtest installation"
  FileClose $0
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\RIFTCORE"
  CreateShortcut "$SMPROGRAMS\RIFTCORE\RIFTCORE.lnk" "$INSTDIR\RIFTCORE.exe" "" "$INSTDIR\riftcore.ico"
  CreateShortcut "$SMPROGRAMS\RIFTCORE\Uninstall RIFTCORE.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\RIFTCORE" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RIFTCORE" "DisplayName" "RIFTCORE Playtest"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RIFTCORE" "UninstallString" '"$INSTDIR\Uninstall.exe"'
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  IfFileExists "$INSTDIR\riftcore.install" +2
  Abort "This folder is not a RIFTCORE install."
  Delete "$INSTDIR\riftcore.install"
  Delete "$SMPROGRAMS\RIFTCORE\RIFTCORE.lnk"
  Delete "$SMPROGRAMS\RIFTCORE\Uninstall RIFTCORE.lnk"
  RMDir "$SMPROGRAMS\RIFTCORE"
  Delete "$INSTDIR\RIFTCORE.exe"
  Delete "$INSTDIR\updates.cfg"
  Delete "$INSTDIR\PATCH_NOTES.md"
  Delete "$INSTDIR\riftcore.ico"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR\versions"
  RMDir /r "$INSTDIR\downloads"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "Software\RIFTCORE"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RIFTCORE"
SectionEnd
