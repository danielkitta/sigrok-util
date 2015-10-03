;
; This file is part of the sigrok-util project.
;
; Copyright (C) 2013-2014 Uwe Hermann <uwe@hermann-uwe.de>
; Copyright (C) 2015 Daniel Elstner <daniel.kitta@gmail.com>
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, see <http://www.gnu.org/licenses/>.
;

; NSIS documentation:
; http://nsis.sourceforge.net/Docs/
; http://nsis.sourceforge.net/Docs/Modern%20UI%202/Readme.html

; Include the "Modern UI" header, which gives us the usual Windows look-n-feel.
!include "MUI2.nsh"

; --- Global stuff ------------------------------------------------------------

; Path where the cross-compiled sigrok tools and libraries are located.
!ifndef PREFIX
!error "Local sigrok install prefix not defined, use -DPREFIX=<prefix>"
!endif

; Where to place the installer executable.
!ifndef OUTDIR
!define OUTDIR "."
!endif

; The version being packaged.
!ifndef VERSION
!define /utcdate VERSION "%Y-%m-%d"
!endif

; License file to include.
!define LICENSE_FILE "../../COPYING.v3"

; Installer/product name.
Name "sigrok"

; Filename of the installer executable.
OutFile "${OUTDIR}/sigrok-${VERSION}-installer.exe"

; Where to install the application.
InstallDir "$PROGRAMFILES\sigrok"

; Request admin privileges for Windows Vista and Windows 7.
; http://nsis.sourceforge.net/Docs/Chapter4.html
RequestExecutionLevel admin

; Local helper definitions.
!define REGSTR "Software\Microsoft\Windows\CurrentVersion\Uninstall\sigrok"


; --- MUI interface configuration ---------------------------------------------

; Use the following icon for the installer EXE file.
!define MUI_ICON "sigrok-logo-notext.ico"

; Show a nice image at the top of each installer page.
!define MUI_HEADERIMAGE

; Don't automatically go to the Finish page so the user can check the log.
!define MUI_FINISHPAGE_NOAUTOCLOSE

; Upon "cancel", ask the user if he really wants to abort the installer.
!define MUI_ABORTWARNING

; Don't force the user to accept the license, just show it.
; Details: http://trac.videolan.org/vlc/ticket/3124
!define MUI_LICENSEPAGE_BUTTON $(^NextBtn)
!define MUI_LICENSEPAGE_TEXT_BOTTOM "Click Next to continue."


; --- MUI pages ---------------------------------------------------------------

; Show a nice "Welcome to the ... Setup Wizard" page.
!insertmacro MUI_PAGE_WELCOME

; Show the license of the project.
!insertmacro MUI_PAGE_LICENSE "${LICENSE_FILE}"

; Show a screen which allows the user to select which components to install.
!insertmacro MUI_PAGE_COMPONENTS

; Allow the user to select a different install directory.
!insertmacro MUI_PAGE_DIRECTORY

; Perform the actual installation, i.e. install the files.
!insertmacro MUI_PAGE_INSTFILES

; Show a final "We're done, click Finish to close this wizard" message.
!insertmacro MUI_PAGE_FINISH

; Pages used for the uninstaller.
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH


; --- MUI language files ------------------------------------------------------

; Select an installer language (required!).
!insertmacro MUI_LANGUAGE "English"


; --- Install sections --------------------------------------------------------

Section "sigrok CLI" SectionCli

	; This section is gray (can't be disabled) in the component list.
	SectionIn RO

	; Install the file(s) specified below into the specified directory.
	SetOutPath "$INSTDIR"

	; License file.
	File "${LICENSE_FILE}"

	; sigrok-cli executable.
	File "${PREFIX}/bin/sigrok-cli.exe"

	; Icon.
	File "sigrok-logo-notext.ico"

	; Python.
	File "${PREFIX}/python32.dll"
	File "${PREFIX}/python32.zip"

	SetOutPath "$INSTDIR\share"

	; Protocol decoders.
	File /r /x "__pycache__" /x "*.pyc" "${PREFIX}/share/libsigrokdecode"

	; Firmware files.
	File /r "${PREFIX}/share/sigrok-firmware"

	SetOutPath "$INSTDIR"

	; Generate the uninstaller executable.
	WriteUninstaller "$INSTDIR\Uninstall.exe"

	; Create a sub-directory in the start menu.
	CreateDirectory "$SMPROGRAMS\sigrok"

	; Create a shortcut for sigrok-cli (this merely opens a "DOS box").
	; Set the working directory (where the user will be placed into when
	; the DOS box starts) to the installation directory.
	CreateShortCut "$SMPROGRAMS\sigrok\sigrok CLI.lnk" \
		"$SYSDIR\cmd.exe" \
		"/K echo For instructions run sigrok-cli --help." \
		"$SYSDIR\cmd.exe" 0 \
		SW_SHOWNORMAL "" "Run sigrok-cli"

	; Create a shortcut for the uninstaller.
	CreateShortCut "$SMPROGRAMS\sigrok\Uninstall.lnk" \
		"$INSTDIR\Uninstall.exe" "" "$INSTDIR\Uninstall.exe" 0 \
		SW_SHOWNORMAL "" "Uninstall sigrok"

	; Create registry keys for "Add/remove programs" in the control panel.
	WriteRegStr HKLM "${REGSTR}" "DisplayName" "sigrok"
	WriteRegStr HKLM "${REGSTR}" "UninstallString" \
		"$\"$INSTDIR\Uninstall.exe$\""
	WriteRegStr HKLM "${REGSTR}" "InstallLocation" "$\"$INSTDIR$\""
	WriteRegStr HKLM "${REGSTR}" "DisplayIcon" \
		"$\"$INSTDIR\sigrok-logo-notext.ico$\""
	WriteRegStr HKLM "${REGSTR}" "Publisher" "sigrok"
	WriteRegStr HKLM "${REGSTR}" "HelpLink" \
		"http://sigrok.org/wiki/Main_Page"
	WriteRegStr HKLM "${REGSTR}" "URLUpdateInfo" \
		"http://sigrok.org/wiki/Downloads"
	WriteRegStr HKLM "${REGSTR}" "URLInfoAbout" "http://sigrok.org"
	WriteRegStr HKLM "${REGSTR}" "DisplayVersion" "${VERSION}"
	WriteRegStr HKLM "${REGSTR}" "Contact" \
		"sigrok-devel@lists.sourceforge.org"
	WriteRegStr HKLM "${REGSTR}" "Comments" \
		"Signal analysis software suite."

	; Display "Remove" instead of "Modify/Remove" in the control panel.
	WriteRegDWORD HKLM "${REGSTR}" "NoModify" 1
	WriteRegDWORD HKLM "${REGSTR}" "NoRepair" 1

SectionEnd ; SectionCli


Section "PulseView" SectionGui

	; Install the file(s) specified below into the specified directory.
	SetOutPath "$INSTDIR"

	; PulseView (statically linked, includes all libs).
	File "${PREFIX}/bin/pulseview.exe"

	; Create a shortcut for the PulseView application.
	CreateShortCut "$SMPROGRAMS\sigrok\PulseView.lnk" \
		"$INSTDIR\pulseview.exe" "" "$INSTDIR\pulseview.exe" \
		0 SW_SHOWNORMAL \
		"" "Open-source, portable sigrok GUI"

SectionEnd ; SectionGui


Section "Example files" SectionExamples

	; Install the file(s) specified below into the specified directory.
	SetOutPath "$INSTDIR"

	; Example *.sr files.
	SetOutPath "$INSTDIR\examples"
	File /r "${PREFIX}/share/sigrok-dumps/*"

SectionEnd ; SectionExamples


Section "Zadig (USB driver setup)" SectionZadig

	; Install the file(s) specified below into the specified directory.
	SetOutPath "$INSTDIR"

	; Zadig (used for installing WinUSB drivers).
	File "${PREFIX}/zadig.exe"
	File "${PREFIX}/zadig_xp.exe"

	; Create a shortcut for the Zadig executable.
	CreateShortCut "$SMPROGRAMS\sigrok\Zadig.lnk" \
		"$INSTDIR\zadig.exe" "" "$INSTDIR\zadig.exe" 0 \
		SW_SHOWNORMAL "" "Zadig USB driver setup"

	; Create a shortcut for the Zadig executable (for Win XP).
	CreateShortCut "$SMPROGRAMS\sigrok\Zadig (Windows XP).lnk" \
		"$INSTDIR\zadig_xp.exe" "" "$INSTDIR\zadig_xp.exe" 0 \
		SW_SHOWNORMAL "" "Zadig USB driver setup (Windows XP)"

SectionEnd ; SectionZadig


; --- Uninstaller section -----------------------------------------------------

Section "Uninstall"

	; Always delete the uninstaller first (yes, this really works).
	Delete "$INSTDIR\Uninstall.exe"

	; Delete the application, the application data, and related libs.
	Delete "$INSTDIR\COPYING"
	Delete "$INSTDIR\sigrok-cli.exe"
	Delete "$INSTDIR\pulseview.exe"
	Delete "$INSTDIR\zadig.exe"
	Delete "$INSTDIR\zadig_xp.exe"
	Delete "$INSTDIR\python32.dll"
	Delete "$INSTDIR\python32.zip"

	; Delete all decoders and everything else in decoders/.
	; There could be *.pyc files or __pycache__ subdirs and so on.
	RMDir /r "$INSTDIR\share\libsigrokdecode"

	; Delete the firmware files.
	RMDir /r "$INSTDIR\share\sigrok-firmware"

	; Delete the example *.sr files.
	RMDir /r "$INSTDIR\examples\*"

	; Delete the install directory and its sub-directories.
	RMDir "$INSTDIR\share"
	RMDir "$INSTDIR\examples"
	RMDir "$INSTDIR"

	; Delete the links from the start menu.
	Delete "$SMPROGRAMS\sigrok\sigrok CLI.lnk"
	Delete "$SMPROGRAMS\sigrok\PulseView.lnk"
	Delete "$SMPROGRAMS\sigrok\Uninstall.lnk"
	Delete "$SMPROGRAMS\sigrok\Zadig.lnk"
	Delete "$SMPROGRAMS\sigrok\Zadig (Windows XP).lnk"

	; Delete the sub-directory in the start menu.
	RMDir "$SMPROGRAMS\sigrok"

	; Delete the registry key(s).
	DeleteRegKey HKLM "${REGSTR}"

SectionEnd ; Uninstall


; --- Component selection section descriptions --------------------------------

LangString DESC_SectionCli ${LANG_ENGLISH} \
	"This installs the sigrok-cli command-line tool, some firmware files, the protocol decoders, and all required libraries."

LangString DESC_SectionGui ${LANG_ENGLISH} \
	"This installs the PulseView graphical user interface for sigrok."

LangString DESC_SectionExamples ${LANG_ENGLISH} \
	"This installs some example sigrok session files."

LangString DESC_SectionZadig ${LANG_ENGLISH} \
	"This installs the Zadig USB driver selection tool."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN

!insertmacro MUI_DESCRIPTION_TEXT ${SectionCli} $(DESC_SectionCli)
!insertmacro MUI_DESCRIPTION_TEXT ${SectionGui} $(DESC_SectionGui)
!insertmacro MUI_DESCRIPTION_TEXT ${SectionExamples} $(DESC_SectionExamples)
!insertmacro MUI_DESCRIPTION_TEXT ${SectionZadig} $(DESC_SectionZadig)

!insertmacro MUI_FUNCTION_DESCRIPTION_END
