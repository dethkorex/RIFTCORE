Unicode true
Name "RIFTCORE"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\RIFTCORE"
InstallDirRegKey HKCU "Software\RIFTCORE" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\RIFTCORE.exe"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "RIFTCORE Playtest" Main
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD}/*"
  FileOpen $0 "$INSTDIR\riftcore.install" w
  FileWrite $0 "RIFTCORE playtest installation"
  FileClose $0
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\RIFTCORE"
  CreateShortcut "$SMPROGRAMS\RIFTCORE\RIFTCORE.lnk" "$INSTDIR\RIFTCORE.exe"
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
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR\versions"
  RMDir /r "$INSTDIR\downloads"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "Software\RIFTCORE"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RIFTCORE"
SectionEnd
