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

strCurrentVersion := "0.2 alpha" ; always "." between sub-versions, eg "0.1.2"

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
Gosub, PopulateDropdownLists
; Gosub, DisplayArtistAlbumCovers

/*
if InitCoverScan("", "Les duos improbables")
	loop, 20
	{
		objCover%A_Index% := NextCover()
		###_D(A_Index . " " . objCover%A_Index%.Name)
		if !(objCover%A_Index%)
			break
		strResult := objCover%A_Index%.SaveCover(A_ScriptDir  . "\no_cover-200x200.png")
		###_D("objCover.SaveCover result: " . strResult)
	}
else
	###_D("Oops ###")
*/

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
BuildGui:
;-----------------------------------------------------------
Gui, New, +Resize, % L(lGuiTitle, lAppName, lAppVersion)
Gui, Font, s12 w700, Verdana
Gui, Add, Text, x10, % L(lAppName)

Gui, Font, s10 w500, Verdana
Gui, Add, Text, x+50 yp, %lArtists%
Gui, Add, DropDownList, x+50 yp vlstArtists gArtistsDropDownChanged Sort
Gui, Add, Text, x+20 yp, %lAlbums%
Gui, Add, DropDownList, x+50 yp vlstAlbums gAlbumsDropDownChanged Sort
Gui, Font

gosub, PreparePicPreviews

Gui, Add, Button, x150 y+10 vbtnPrevious gButtonPreviousClicked, <-
Gui, Add, Button, x+50 yp vbtnNext gButtonNextClicked, ->

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
PreparePicPreviews:
;-----------------------------------------------------------
SysGet, intMonWork, MonitorWorkArea
intPicWidth := 150
intPicHeight := 150
intNameLabelHeight := 30
intColWidth := intPicWidth + 10
intRowHeight := intPicHeight + intNameLabelHeight + 10

intClipboardWidth := 160
intMaxNbCol := Floor((intMonWorkRight - intClipboardWidth) / (intColWidth + 10))
intHeaderHeight := 60
intFooterHeight := 60
intMaxNbRow := Floor((intMonWorkBottom - intHeaderHeight - intFooterHeight) / (intRowHeight + 10))

intX := intClipboardWidth + 5
intY := intHeaderHeight + 5
intCol := 1
intRow := 1
intXPic := intX + 5
intYPic := intY + 5
intYNameLabel := intY + intPicHeight + 5
loop
{
	Gui, Add, Picture, x%intXPic% y%intYPic% w%intPicWidth% h%intPicHeight% 0xE vpicPreview%A_Index% gPicPreviewClicked ; 0xE ?
	GuiControlGet, Pos%A_Index%, Pos, picPreview%A_Index% ; required?
	GuiControlGet, hwnd%A_Index%, hwnd, picPreview%A_Index% ; required?
	Gui, Font, s8 w500, Arial
	Gui, Add, Text, x%intXPic% y%intYPic% w%intPicWidth% h%intPicHeight% vlblCoverLabel%A_Index% gCoverLabelClicked border hidden
	Gui, Font, s8 w700, Arial
	Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPicWidth% h%intNameLabelHeight% center vlblNameLabel%A_Index% gNameLabelClicked
	Gui, Font
	
	if (intCol = intMaxNbCol)
	{
		if (intRow = intMaxNbRow)
		{
			intNbPicPreviewsOnScreen := A_Index
			break
		}
		intRow := intRow + 1
		intY := intY + intRowHeight
		intYPic := intY + 5
		intYNameLabel := intY + intPicHeight + 5
		
		intCol := 0
		intX := 5 - intColWidth + intClipboardWidth
	}
	intCol := intCol + 1
	intX := intX + intColWidth
	intXPic := intX + 5
	if (A_Index > 1000)
	{
		###_D("Infinite Loop Error :-)")
		ExitApp
	}
}

return
;-----------------------------------------------------------


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
PopulateDropdownLists:
;-----------------------------------------------------------
strArtistsDropDownList := "|"
for strArtist, strTracks in objArtistsIndex
	strArtistsDropDownList := strArtistsDropDownList . "|" . strArtist
GuiControl, , lstArtists, %strArtistsDropDownList%

strAlbumsDropDownList := "|"
for strAlbum, strTracks in objAlbumsIndex
	strAlbumsDropDownList := strAlbumsDropDownList . "|" . strAlbum
GuiControl, , lstAlbums, %strAlbumsDropDownList%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ArtistsDropDownChanged:
;-----------------------------------------------------------
GuiControl, Choose, lstAlbums, 0
Gui, Submit, NoHide
; ###_D(lstArtists . " / " . lstAlbums)
Gosub, DisplayArtistAlbumCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
AlbumsDropDownChanged:
;-----------------------------------------------------------
GuiControl, Choose, lstArtists, 0
Gui, Submit, NoHide
; ###_D(lstArtists . " / " . lstAlbums)
Gosub, DisplayArtistAlbumCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ButtonPreviousClicked:
;-----------------------------------------------------------

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ButtonNextClicked:
;-----------------------------------------------------------

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayArtistAlbumCovers:
;-----------------------------------------------------------
intNbCovers := InitCoverScan(lstArtists, lstAlbums)
if (intNbCovers)
	loop, %intNbPicPreviewsOnScreen%
	{
		objCover%A_Index% := NextCover()
		if (objCover%A_Index%)
			strTrackTitle := objCover%A_Index%.Name
		else
			strTrackTitle := ""
		if !StrLen(objCover%A_Index%.CoverTempFilePathName)
			strCoverTempFilePathName := A_ScriptDir  . "\no_cover-200x200.png" ; if absent, url download from repo ? ###
		else
			strCoverTempFilePathName := objCover%A_Index%.CoverTempFilePathName
		TrayTip, %strTrackTitle%, %strCoverTempFilePathName%
		pBitmapPicPreview := Gdip_CreateBitmap(Pos%A_Index%w, Pos%A_Index%h)
		; ###_D(pBitmapPicPreview)
		GPicPreview := Gdip_GraphicsFromImage(pBitmapPicPreview)
		; ###_D(GPicPreview)
		Gdip_SetInterpolationMode(GPicPreview, 7)
		LoadPicPreview(picPreview%A_Index%, strCoverTempFilePathName)
		
		GuiControl, , lblNameLabel%A_Index%, % objCover%A_Index%.Name
		GuiControl, , lblCoverLabel%A_Index%, % "Artist: " . objCover%A_Index%.Artist . "`n"
			. "Album: " . objCover%A_Index%.Album . "`n"
			. "Index: " . objCover%A_Index%.Index . "`n"
			. "TrackID: " . objCover%A_Index%.TrackID . "`n"
			. "TrackDatabaseID: " . objCover%A_Index%.TrackDatabaseID
	}
else
	###_D("Oops ###")

return
;-----------------------------------------------------------


;-----------------------------------------------------------
LoadPicPreview(ByRef Variable, File)
{
	global pBitmapPicPreview, GPicPreview

	GuiControlGet, Pos, Pos, Variable
	GuiControlGet, hwnd, hwnd, Variable
	
	If !pBitmap := Gdip_CreateBitmapFromFile(File)
		return
	Width := Gdip_GetImageWidth(pBitmap), Height := Gdip_GetImageHeight(pBitmap)
	
	if (Posw/Width >= Posh/Height)
		NewHeight := Posh, NewWidth := Round(Width*(NewHeight/Height))
	else
		NewWidth := Posw, NewHeight := Round(Height*(NewWidth/Width))
	
	Gdip_GraphicsClear(GPicPreview)
	Gdip_DrawImage(GPicPreview, pBitmap, (Posw-NewWidth)//2, (Posh-NewHeight)//2, NewWidth, NewHeight, 0, 0, Width, Height)
	
	hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmapPicPreview)
	SetImage(hwnd, hBitmap)

	DeleteObject(hBitmap)
	Gdip_DisposeImage(pBitmap)
}
;-----------------------------------------------------------



;-----------------------------------------------------------
PicPreviewClicked:
;-----------------------------------------------------------
StringReplace, strThisLabel, A_GuiControl, picPreview, lblCoverLabel
; ###_D("PicPreviewClicked, strThisLabel: " . strThisLabel)
GuiControl, Hide, %A_GuiControl%
GuiControl, Show, %strThisLabel%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
CoverLabelClicked:
;-----------------------------------------------------------
StringReplace, strThisPicPreview, A_GuiControl, lblCoverLabel, picPreview
; ###_D("CoverLabelClicked, strThisPicPreview: " . strThisPicPreview)
GuiControl, Hide, %A_GuiControl%
GuiControl, Show, %strThisPicPreview%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
NameLabelClicked:
;-----------------------------------------------------------
###_D("NameLabelClicked")

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