;===============================================
/*
	iTunesCoverManager
	Written using AutoHotkey_L v1.1.09.03+ (http://l.autohotkey.net/)
	By Jean Lalonde (JnLlnd on AHKScript.org forum)

	2014-01-05 v0.1 ALPHA
	* First Alpha release. Not ready for alpha distribution yet. But you can take a lkook at sources
	* Initialize script and language file, read ini file, implement check for update
	* Base of iTunesLib as tracks source (a future version could also support MP3 source files in a directory - ie without the use of iTunes)
	* Base of CoversLib libraries, rudimentary Gui with covers read from iTunes
	
*/ 
;===============================================

; --- COMPILER DIRECTIVES ---

; Doc: http://fincs.ahk4.net/Ahk2ExeDirectives.htm
; Note: prefix comma with `

;@Ahk2Exe-SetName iTunesCoverManager
;@Ahk2Exe-SetDescription iTunes Cover Manager. Freeware.
;@Ahk2Exe-SetVersion 0.1
;@Ahk2Exe-SetOrigFilename iTunesCoverManager.exe


;============================================================
; INITIALIZATION
;============================================================

#NoEnv
#SingleInstance force
; #KeyHistory 0
; ListLines, Off
Thread, interrupt, 0 ; essai pour GDIP

strCurrentVersion := "0.1 alpha" ; always "." between sub-versions, eg "0.1.2"

#Include %A_ScriptDir%\iTunesCoverManager_LANG.ahk
#Include %A_ScriptDir%\CoversLib.ahk
#Include %A_ScriptDir%\iTunesLib.ahk ; Cover source

SetWorkingDir, %A_ScriptDir%

strIniFile := A_ScriptDir . "\" . lAppName . ".ini"
;@Ahk2Exe-IgnoreBegin
; Piece of code for developement phase only - won't be compiled
if (A_ComputerName = "JEAN-PC") ; for my home PC
	strIniFile := A_ScriptDir . "\" . lAppName . "-HOME.ini"
else if InStr(A_ComputerName, "STIC") ; for my work hotkeys
	strIniFile := A_ScriptDir . "\" . lAppName . "-WORK.ini"
; / Piece of code for developement phase only - won't be compiled
;@Ahk2Exe-IgnoreEnd


pToken := InitGDIP()

Gosub, LoadIniFile
Gosub, Check4Update
Gosub, BuildGui

InitCoversSource()
InitArtistsAlbumsIndex()

if InitCoverScan("Albin de la Simone", "")
	loop, 40
	{
		objCover%A_Index% := NextCover()
		if !(objCover%A_Index%)
			break
		strTrackTitle := objCover%A_Index%.Name
		if !StrLen(objCover%A_Index%.CoverFilePathName)
			strCoverFilePathName := A_ScriptDir  . "\no_cover-200x200.png" ; if absent, url download from repo ? ###
		else
			strCoverFilePathName := objCover%A_Index%.CoverFilePathName
		TrayTip, %strTrackTitle%, %strCoverFilePathName%
		pBitmapPreview := Gdip_CreateBitmap(Pos%A_Index%w, Pos%A_Index%h)
		; ###_D(pBitmapPreview)
		GPreview := Gdip_GraphicsFromImage(pBitmapPreview)
		; ###_D(GPreview)
		Gdip_SetInterpolationMode(GPreview, 7)
		LoadPreview(Preview%A_Index%, strCoverFilePathName)
		
		GuiControl, , Label%A_Index%, % objCover%A_Index%.Name
	}
else
	###_D("Oops ###")

OnExit, CleanUpBeforeQuit
return


;-----------------------------------------------------------
LoadIniFile:
;-----------------------------------------------------------
strAlbumArtistDelimiter := chr(182)
strCoversCacheFolder := A_ScriptDir . "\covers_cache\"

IfNotExist, %strIniFile%
	FileAppend,
		(LTrim Join`r`n
			[Global]
			AlbumArtistDelimiter=%strAlbumArtistDelimiter%
			CoversCacheFolder=%A_ScriptDir%\covers_cache\
)
		, %strIniFile%
Loop
{
	IniRead, strAlbumArtistDelimiter, %strIniFile%, Global, AlbumArtistDelimiter, %strAlbumArtistDelimiter%
	if (strAlbumArtistDelimiter = "ERROR")
		###_D(strAlbumArtistDelimiter) ; Sleep, 20
	else
		break
}
IniRead, strLatestSkipped, %strIniFile%, Global, LatestVersionSkipped, 0.0
IniRead, strCoversCacheFolder, %strIniFile%, Global, CoversCacheFolder, %strCoversCacheFolder%

return
;------------------------------------------------------------


;-----------------------------------------------------------
GuiClose:
CleanUpBeforeQuit:
;-----------------------------------------------------------
Gdip_Shutdown(pToken)
ptrObjITunesunesApp := Object(objITunesunesApp)
ObjRelease(ptrObjITunesunesApp)

; ### delete covers cache
ExitApp
return
;-----------------------------------------------------------



;-----------------------------------------------------------
BuildGui:
;-----------------------------------------------------------
Gui, New, +Resize, % L(lGuiTitle, lAppName, lAppVersion)
Gui, Font, s12 w700, Verdana
Gui, Add, Text, x10, % L(lAppName)
Gui, Font, s10 w500, Verdana

intX := 10
intY := 30
loop, 40
{
	if (intX > 1200)
	{
		intX := 10
		intY := intY + 160
	}
	Gui, Add, Picture, x%intX% y%intY% w150 h150 0xE vPreview%A_Index% gPreviewClicked ; 0xE ?
	GuiControlGet, Pos%A_Index%, Pos, Preview%A_Index%
	GuiControlGet, hwnd%A_Index%, hwnd, Preview%A_Index%
	Gui, Add, Text, x%intX% y%intY% w150 h150 vLabel%A_Index% gLabelClicked hidden border
	; ###_D(Pos%A_Index%x . " " . Pos%A_Index%y . " " . hwnd%A_Index%)
	intX := intX + 160
}
Gui, Font

Gui, Add, StatusBar
SB_SetParts(200)
SB_SetText(L(lSBEmpty), 1)
if (A_IsCompiled)
	SB_SetIcon(A_ScriptFullPath)
else
	SB_SetIcon("C:\Dropbox\AutoHotkey\CSVBuddy\build\Ico - Visual Pharm\angel.ico") ; ###

Gui, Show, Autosize

return
;-----------------------------------------------------------


;-----------------------------------------------------------
LoadPreview(ByRef Variable, File)
{
	global pBitmapPreview, GPreview

	GuiControlGet, Pos, Pos, Variable
	GuiControlGet, hwnd, hwnd, Variable
	
	If !pBitmap := Gdip_CreateBitmapFromFile(File)
		return
	Width := Gdip_GetImageWidth(pBitmap), Height := Gdip_GetImageHeight(pBitmap)
	
	if (Posw/Width >= Posh/Height)
		NewHeight := Posh, NewWidth := Round(Width*(NewHeight/Height))
	else
		NewWidth := Posw, NewHeight := Round(Height*(NewWidth/Width))
	
	Gdip_GraphicsClear(GPreview)
	Gdip_DrawImage(GPreview, pBitmap, (Posw-NewWidth)//2, (Posh-NewHeight)//2, NewWidth, NewHeight, 0, 0, Width, Height)
	
	hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmapPreview)
	SetImage(hwnd, hBitmap)

	DeleteObject(hBitmap)
	Gdip_DisposeImage(pBitmap)
}
;-----------------------------------------------------------



;-----------------------------------------------------------
PreviewClicked:
;-----------------------------------------------------------
StringReplace, strLabel, A_GuiControl, Preview, Label
GuiControl, Hide, %A_GuiControl%
GuiControl, Show, %strLabel%
return
;-----------------------------------------------------------


;-----------------------------------------------------------
LabelClicked:
;-----------------------------------------------------------
StringReplace, strPreview, A_GuiControl, Label, Preview
GuiControl, Hide, %A_GuiControl%
GuiControl, Show, %strPreview%
return
;-----------------------------------------------------------



;============================================================
; TOOLS
;============================================================


; ------------------------------------------------
ButtonCheck4Update: ; ### TESTER
; ------------------------------------------------
blnButtonCheck4Update := True
Gosub, Check4Update

return
; ------------------------------------------------


; ------------------------------------------------
ButtonDonate:
; ------------------------------------------------
Run, https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=8UWKXDR5ZQNJW ; ### updater

return
; ------------------------------------------------


; ------------------------------------------------
Check4Update: ; ### TESTER
; ------------------------------------------------
Gui, 1:+OwnDialogs 
IniRead, strLatestSkipped, %strIniFile%, global, strLatestSkipped, 0.0
strLatestVersion := Url2Var("https://raw.github.com/JnLlnd/CSVBuddy/master/latest-version.txt") ; ###

if RegExMatch(strCurrentVersion, "(alpha|beta)")
	or (FirstVsSecondIs(strLatestSkipped, strLatestVersion) >= 0 and (!blnButtonCheck4Update)) ; ### blnButtonCheck4Update ???
	return

if FirstVsSecondIs(strLatestVersion, lAppVersion) = 1
{
	Gui, 1:+OwnDialogs
	SetTimer, ChangeButtonNames4Update, 50

	MsgBox, 3, % l(lUpdateTitle, lAppName), % l(lUpdatePrompt, lAppName, lAppVersion, strLatestVersion), 30
	IfMsgBox, Yes
		Run, http://code.jeanlalonde.ca/csvbuddy/
	IfMsgBox, No
		IniWrite, %strLatestVersion%, %strIniFile%, global, strLatestSkipped
	IfMsgBox, Cancel ; Remind me
		IniWrite, 0.0, %strIniFile%, Global, LatestVersionSkipped
	IfMsgBox, TIMEOUT ; Remind me
		IniWrite, 0.0, %strIniFile%, Global, LatestVersionSkipped
}
else if (blnButtonCheck4Update)
{
	MsgBox, 4, % l(lUpdateTitle, lAppName), % l(lUpdateYouHaveLatest, lAppVersion, lAppName)
	IfMsgBox, Yes
		Run, http://code.jeanlalonde.ca/csvbuddy/ ; ###
}

return
; ------------------------------------------------


;------------------------------------------------------------
FirstVsSecondIs(strFirstVersion, strSecondVersion)
;------------------------------------------------------------
{
	StringSplit, arrFirstVersion, strFirstVersion, `.
	StringSplit, arrSecondVersion, strSecondVersion, `.
	if (arrFirstVersion0 > arrSecondVersion0)
		intLoop := arrFirstVersion0
	else
		intLoop := arrSecondVersion0

	Loop %intLoop%
		if (arrFirstVersion%A_index% > arrSecondVersion%A_index%)
			return 1 ; greater
		else if (arrFirstVersion%A_index% < arrSecondVersion%A_index%)
			return -1 ; smaller
		
	return 0 ; equal
}
;------------------------------------------------------------


; ------------------------------------------------
ChangeButtonNames4Update: ; ### TESTER
; ------------------------------------------------
IfWinNotExist, % l(lUpdateTitle, lAppName)
    return  ; Keep waiting.
SetTimer, ChangeButtonNames4Update, Off 
WinActivate
ControlSetText, Button3, %lUpdateButtonRemind%

return
; ------------------------------------------------


;------------------------------------------------------------
Url2Var(strUrl)
;------------------------------------------------------------
{
	ComObjError(False)
	objWebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	objWebRequest.Open("GET", strUrl)
	objWebRequest.Send()

	Return objWebRequest.ResponseText()
}
;------------------------------------------------------------


; ------------------------------------------------
Oops(strMessage, objVariables*)
; ------------------------------------------------
{
	Gui, 1:+OwnDialogs
	MsgBox, 48, % L(lFuncOopsTitle, lAppName, lAppVersion), % L(strMessage, objVariables*)
}
; ------------------------------------------------



; ------------------------------------------------
L(strMessage, objVariables*)
; ------------------------------------------------
{
	Loop
	{
		if InStr(strMessage, "~" . A_Index . "~")
			StringReplace, strMessage, strMessage, ~%A_Index%~, % objVariables[A_Index]
 		else
			break
	}
	
	return strMessage
}
; ------------------------------------------------



/*

BACKUP PIECES OF CODE


objAlbumsByID := Object()
objTracksAndAlbumID := Object()

; objTracksAndAlbumID.Insert(objITunesTrack.Index, objAlbumsIndex[strAlbum])


s :=
i := 0
for strKey, intID in objAlbumsIndex
{
	i := i + 1
	; s := s . "#" . intID . " " . strKey . "`n"
	objAlbumsByID.Insert(intID, strKey)
	###_D(i . " " objAlbumsByID[intID])
	if !Mod(i,100)
		TrayTip, , % i . " / " . objAlbumsByID.MaxIndex()
}
return


###_D(s)
s :=
for intID, strKey in objAlbumsByID
{
	s := s . "#" . intID . " " . strKey . "`n"
}
###_D(s)

return




if (objTrack.Artwork.Count)
{
	Loop, % objTrack.Artwork.Count
	{
		objArtwork := objTrack.Artwork.Item(A_Index)
		TrayTip
		###_D("Track: " . objTrack.index . "`n"
			. "Artist: " . objTrack.Artist . "`n"
			. "Album: " . objTrack.Album . "`n"
			. "Name: " . objTrack.Name . "`n"
			. "Artwork: " . A_Index . "/" . objTrack.Artwork.Count . "`n"
			. "Format: " . objArtwork.Format  . "`n"
			. "IsDownloadedArtwork: " . objArtwork.IsDownloadedArtwork  . "`n"
			. "Description: " . objArtwork.Description . "`n"
			. "")
		strFilename := objTrack.index . "-" .  A_Index . ".jpg"
		###_D(strFilename)
		objArtwork.SaveArtworkToFile(strFilename)
	}
}
else
	if (!Mod(A_Index, 100))
		TrayTip, , % A_Index . " / " . objTracks.Count

objArtwork.Format


ITunesLibArtworkFormatNone = 0,
ITunesLibArtworkFormatBitmap = 1,
ITunesLibArtworkFormatJPEG = 2,
ITunesLibArtworkFormatJPEG2000 = 3,
ITunesLibArtworkFormatGIF = 4,
ITunesLibArtworkFormatPNG = 5,
ITunesLibArtworkFormatBMP = 6,
ITunesLibArtworkFormatTIFF = 7,
ITunesLibArtworkFormatPICT = 8





GDI_SaveBitmap( ClipboardGet_DIB(), "filename.bmp" )

*/
