; EST STAR Commande Installer
!define APPNAME "EST STAR Commande"
!define COMPANYNAME "EST STAR"
!define DESCRIPTION "Application de gestion des commandes"
!define VERSIONMAJOR 1
!define VERSIONMINOR 0
!define VERSIONBUILD 0

RequestExecutionLevel admin

InstallDir "$PROGRAMFILES\${COMPANYNAME}\${APPNAME}"

Name "${APPNAME}"
Icon "assets\icons\icon.ico"
OutFile "dist\EST_STAR_Commande_Setup.exe"

Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles

Section "install"
    SetOutPath $INSTDIR
    File /r "build\windows\x64\runner\Release\*"
    
    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    CreateDirectory "$SMPROGRAMS\${COMPANYNAME}"
    CreateShortcut "$SMPROGRAMS\${COMPANYNAME}\${APPNAME}.lnk" "$INSTDIR\estarcommande.exe"
    CreateShortcut "$SMPROGRAMS\${COMPANYNAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe"
    
    CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\estarcommande.exe"
    
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "DisplayName" "${APPNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "Publisher" "${COMPANYNAME}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "VersionMajor" ${VERSIONMAJOR}
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "VersionMinor" ${VERSIONMINOR}
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "NoRepair" 1
SectionEnd

Section "uninstall"
    Delete "$INSTDIR\*.*"
    RMDir /r "$INSTDIR"
    
    Delete "$SMPROGRAMS\${COMPANYNAME}\*.*"
    RMDir "$SMPROGRAMS\${COMPANYNAME}"
    
    Delete "$DESKTOP\${APPNAME}.lnk"
    
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}"
SectionEnd
