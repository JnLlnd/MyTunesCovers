/*
Next:
- bug Artist -M- donne McGarrigle & Beau d'hommage tandis que McGarrigle & Beau d'hommage donne rien
- bug Artist (|m&e|) de 16 pi�ces commence offset de 1 trop t�t et manque le dernier, et ler & est stripp� du non
- pagination

FAIT:
- commencr All... par un espace _ et terminer pas _ pour qu'il soit toujours en premier
- striper les espaces au d�but des artistes et albums
*/
;===============================================
/*
	MyTunesCovers
	Written using AutoHotkey_L v1.1.09.03+ (http://l.autohotkey.net/)
	By Jean Lalonde (JnLlnd on AHKScript.org forum)

	2014-01-## v0.3 ALPHA
	* implemented release, save cache and reload cache for iTunes source

	2014-01-08 v0.2 ALPHA
	* Add properties to Covers class, POC for set image
	* Show max covers for screen size, add paging buttons not functional
	* Add dropdown lists for artists and albums, add info to cover label
	* Library Cover_ and iTunes_ refactoring, add iTunes/MP3 sources radio buttons, iTunes source implemented

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

;@Ahk2Exe-SetName MyTunesCovers
;@Ahk2Exe-SetDescription iTunes Cover Manager. Freeware.
;@Ahk2Exe-SetVersion 0.3
;@Ahk2Exe-SetOrigFilename MyTunesCovers.exe


;============================================================
; INITIALIZATION
;============================================================

#NoEnv
#SingleInstance force
; #KeyHistory 0
; ListLines, Off
Thread, interrupt, 0 ; essai pour GDIP

strCurrentVersion := "0.3 alpha" ; always "." between sub-versions, eg "0.1.2"

#Include %A_ScriptDir%\MyTunesCovers_LANG.ahk
#Include %A_ScriptDir%\lib\Cover.ahk ; this lib is also calling lib\iTunes.ahk

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

Gosub, InitGDIP
Gosub, LoadIniFile
Gosub, Check4Update

intCoversPerPage := 0
intNbCoversCreated := 0
Gosub, BuildGui

Gosub, InitSources

OnExit, CleanUpBeforeQuit
return


;-----------------------------------------------------------
InitGDIP:
;-----------------------------------------------------------
objGdiToken := Gdip_Startup()
If !(objGdiToken)
{
	Oops(lGdiFailed, lAppName)
	ExitApp
}
return
;-----------------------------------------------------------


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
		Sleep, 20
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
Gui, +Delimiter%strAlbumArtistDelimiter%
Gui, Font, s12 w700, Verdana
Gui, Add, Text, x10, % L(lAppName)
Gui, Font
Gui, Font, s10 w500, Verdana
Gui, Add, Text, x+30 yp, %lSource%
Gui, Font
Gui, Add, Radio, x+10 yp vradSourceITunes gClickRadSource checked, % L(lSourceITunes)
Gui, Add, Radio, x+10 yp vradSourceMP3 gClickRadSource, % L(lSourceMP3)
Gui, Font, s10 w500, Verdana
Gui, Add, Text, x+20 yp, %lArtists%
Gui, Add, DropDownList, x+20 yp w300 vlstArtists gArtistsDropDownChanged Sort
Gui, Add, Text, x+20 yp, %lAlbums%
Gui, Add, DropDownList, x+20 yp w300 vlstAlbums gAlbumsDropDownChanged Sort
Gui, Font

; gosub, PreparePicPreviews

Gui, Add, Button, x150 y+10 w80 vbtnPrevious gButtonPreviousClicked hidden, % "<- " . lPrevious
Gui, Add, Text, x+50 yp w40 vlblPage
Gui, Add, Button, x+50 yp w80 vbtnNext gButtonNextClicked hidden, % lNext . " ->"

Gui, Add, StatusBar
SB_SetParts(200)
SB_SetText(L(lSBEmpty), 1)
if (A_IsCompiled)
	SB_SetIcon(A_ScriptFullPath)
else
	SB_SetIcon("C:\Dropbox\AutoHotkey\CSVBuddy\build\Ico - Visual Pharm\angel.ico") ; ###

intPicWidth := 350 ; 150
intPicHeight := 350 ; 150
intNameLabelHeight := 30
intColWidth := intPicWidth + 10
intRowHeight := intPicHeight + intNameLabelHeight + 10
intClipboardWidth := intPicWidth + 10
intHeaderHeight := 60
intFooterHeight := 60

SysGet, intMonWork, MonitorWorkArea
intAvailWidth := intMonWorkRight - 50
intAvailHeight := intMonWorkBottom - 50
Gosub, CalcMaxRowsAndCols ; calculate intMaxNbCol x intMaxNbRow
intTotalWidth := (intMaxNbCol * intColWidth) + intClipboardWidth + 20
intTotalHeight := (intMaxNbRow * intRowHeight) + intHeaderHeight + intFooterHeight

intPage := 1

Gui, Show, w%intTotalWidth% h%intTotalHeight%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
InitSources:
;-----------------------------------------------------------
Gui, Submit, NoHide

if (radSourceITunes)
	strSource := "iTunes"
else
	strSource := "MP3"

if (Cover_InitCoversSource(strSource))
	Gosub, PopulateDropdownLists
else
	Oops(lInitSourceError)

return
;-----------------------------------------------------------


;-----------------------------------------------------------
PopulateDropdownLists:
;-----------------------------------------------------------
strArtistsDropDownList := strAlbumArtistDelimiter . A_Space . lDropDownAllArtists
for strArtist, strTracks in objArtistsIndex
	strArtistsDropDownList := strArtistsDropDownList . strAlbumArtistDelimiter . strArtist
GuiControl, , lstArtists, %strArtistsDropDownList%
GuiControl, Choose, lstArtists, 1

Gosub, PopulateAlbumDropdownList

return
;-----------------------------------------------------------


;-----------------------------------------------------------
PopulateAlbumDropdownList:
;-----------------------------------------------------------
strAlbumsDropDownList := strAlbumArtistDelimiter . A_Space . lDropDownAllAlbums
for strAlbum, strTracks in objAlbumsIndex
	strAlbumsDropDownList := strAlbumsDropDownList . strAlbumArtistDelimiter . strAlbum
GuiControl, , lstAlbums, %strAlbumsDropDownList%
GuiControl, Choose, lstAlbums, 1

return
;-----------------------------------------------------------


;-----------------------------------------------------------
; !q::
GuiSize:
;-----------------------------------------------------------

; WinGetPos, intFoo, intFoo, intWinWidth, intWinHeight, A
; intAvailWidth := intWinWidth -16 - 5
; intAvailHeight := intWinHeight - 38
intAvailWidth := A_GuiWidth - 5
intAvailHeight := A_GuiHeight
Gosub, CalcMaxRowsAndCols ; calculate intMaxNbCol x intMaxNbRow
ToolTip, % "Resize: " . intMaxNbCol . " x " . intMaxNbRow . "`n" . intAvailWidth . " x " . intAvailHeight
intCoversPerPagePrevious := intCoversPerPage
intCoversPerPage := (intMaxNbCol * intMaxNbRow)

intX := intClipboardWidth + 5
intY := intHeaderHeight + 5
intCol := 1
intRow := 1
intXPic := intX + 5
intYPic := intY + 5
intYNameLabel := intY + intPicHeight + 5

loop, %intCoversPerPagePrevious%
{
	GuiControl, Hide, picPreview%A_Index%
	GuiControl, Hide, lblCoverLabel%A_Index%
	GuiControl, Hide, lblNameLabel%A_Index%
}

loop, %intCoversPerPage%
{
	if (intNbCoversCreated < A_Index)
	{
		; ###_D(intNbCoversCreated . " < " . A_Index . " intCoversPerPage: " . intCoversPerPage)
		Gui, Add, Picture, x%intXPic% y%intYPic% w%intPicWidth% h%intPicHeight% 0xE vpicPreview%A_Index% gPicPreviewClicked ; 0xE ?
		GuiControlGet, Pos%A_Index%, Pos, picPreview%A_Index% ; required?
		; GuiControlGet, hwnd%A_Index%, hwnd, picPreview%A_Index% ; required?
		Gui, Font, s8 w500, Arial
		Gui, Add, Text, x%intXPic% y%intYPic% w%intPicWidth% h%intPicHeight% vlblCoverLabel%A_Index% gCoverLabelClicked border hidden
		Gui, Font, s8 w700, Arial
		Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPicWidth% h%intNameLabelHeight% vlblNameLabel%A_Index% center vlblNameLabel%A_Index% gNameLabelClicked, %A_Index% C: %intCol% R: %intRow%
		Gui, Font
		intNbCoversCreated := A_Index
	}
	else
	{
		GuiControl, Move, picPreview%A_Index%, x%intXPic% y%intYPic%
		GuiControl, Show, picPreview%A_Index%
		; Gui, Add, Picture, x%intXPic% y%intYPic% w%intPicWidth% h%intPicHeight% 0xE vpicPreview%A_Index% gPicPreviewClicked ; 0xE ?
		GuiControl, Move, lblCoverLabel%A_Index%, x%intXPic% y%intYPic%
		; Gui, Add, Text, x%intXPic% y%intYPic% w%intPicWidth% h%intPicHeight% vlblCoverLabel%A_Index% gCoverLabelClicked border hidden
		GuiControl, Move, lblNameLabel%A_Index%, x%intXPic% y%intYNameLabel%
		GuiControl, Show, lblNameLabel%A_Index%
		; Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPicWidth% h%intNameLabelHeight% center vlblNameLabel%A_Index% gNameLabelClicked
	}
	
	if (intCol = intMaxNbCol)
	{
		if (intRow = intMaxNbRow)
		{
			intCoversDisplayedPrevious := intCoversPerPage
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
	if (A_Index > 200)
	{
		###_D("Infinite Loop Error :-)")
		ExitApp
	}
}
intGuiMiddle := intClipboardWidth + (A_GuiWidth - intClipboardWidth) / 2
GuiControl, Move, btnPrevious, % "X" . (intGuiMiddle - 120) . " Y" . A_GuiHeight - 55
; Gui, Add, Button, x150 y+10 vbtnPrevious gButtonPreviousClicked, <-
GuiControl, Move, lblPage, % "X" . (intGuiMiddle) . " Y" . A_GuiHeight - 55
GuiControl, , lblPage, % L(lPageFooter, intPage)
; Gui, Add, Button, x+50 yp vlblPage
GuiControl, Move, btnNext, % "X" . (intGuiMiddle + 105) . " Y" . A_GuiHeight - 55
; Gui, Add, Button, x+50 yp vbtnNext gButtonNextClicked, ->

ToolTip,

Gosub, DisplayCoversPage

return
;-----------------------------------------------------------


;-----------------------------------------------------------
CalcMaxRowsAndCols:
;-----------------------------------------------------------
intMaxNbCol := Floor((intAvailWidth - intClipboardWidth) / intColWidth)
intMaxNbRow := Floor((intAvailHeight - intHeaderHeight - intFooterHeight) / intRowHeight)

if (!intMaxNbCol)
	intMaxNbCol := 1
if (!intMaxNbRow)
	intMaxNbRow := 1

return
;-----------------------------------------------------------


;-----------------------------------------------------------
GuiClose:
;-----------------------------------------------------------
ExitApp ; will call CleanUpBeforeQuit
;-----------------------------------------------------------


;-----------------------------------------------------------
CleanUpBeforeQuit:
;-----------------------------------------------------------
Cover_ReleaseSource()
Gdip_Shutdown(objGdiToken)
ptrObjITunesunesApp := Object(objITunesunesApp)
ObjRelease(ptrObjITunesunesApp)
if StrLen(strCoversCacheFolder)
	FileDelete, %strCoversCacheFolder%\*.*
ExitApp
return
;-----------------------------------------------------------


;-----------------------------------------------------------
ClickRadSource:
;-----------------------------------------------------------
; GuiControl, Disable, id
; GuiControl, Enable, id

Cover_ReleaseSource()

Gui, Submit, NoHide

if (radSourceITunes)
	strSource := "iTunes"
else
	strSource := "MP3"

if (Cover_InitCoversSource(strSource))
	Gosub, PopulateDropdownLists
else
	Oops(lInitSourceError)

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ClickRadSourceMP3: ; NOT USED
;-----------------------------------------------------------
; GuiControl, Disable, id
; GuiControl, Enable, id

Cover_ReleaseSource()
Gui, Submit, NoHide
Cover_LoadSource()

GuiControl, , lstArtists, %strAlbumArtistDelimiter%
GuiControl, , lstAlbums, %strAlbumArtistDelimiter%


return
;-----------------------------------------------------------


;-----------------------------------------------------------
ArtistsDropDownChanged:
;-----------------------------------------------------------
Gui, Submit, NoHide
if (lstArtists = A_Space . lDropDownAllArtists)
	Gosub, PopulateAlbumDropdownList
else
	GuiControl, , lstAlbums, % strAlbumArtistDelimiter . A_Space . lDropDownAllAlbums . strAlbumArtistDelimiter . objAlbumsOfArtistsIndex[lstArtists]
GuiControl, Choose, lstAlbums, 1
Gosub, DisplayCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
AlbumsDropDownChanged:
;-----------------------------------------------------------
Gui, Submit, NoHide
; ###_D(lstArtists . " / " . lstAlbums)
Gosub, DisplayCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ButtonPreviousClicked:
;-----------------------------------------------------------
intPage := intPage - 1
Gosub,	DisplayCoversPage

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ButtonNextClicked:
;-----------------------------------------------------------
intPage := intPage + 1
Gosub,	DisplayCoversPage

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayCovers:
;-----------------------------------------------------------
Gui, Submit, NoHide
intNbCovers := Cover_InitCoverScan(lstArtists, lstAlbums) - 1 ; -1 because of the last comma in lists
if (intNbCovers < 1)
{
	###_D("Oops ###")
	return
}
intPage := 1
Gosub, DisplayCoversPage

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayCoversPage:
;-----------------------------------------------------------
intPosition := 0
intTrackIndexDisplayedNow := ((intPage - 1) * intCoversPerPage)
loop
{
	intTrackIndexDisplayedNow := intTrackIndexDisplayedNow + 1
	intPosition := intPosition + 1
	objCover%intPosition% := Cover_GetCover(intTrackIndexDisplayedNow)
	
	if (objCover%intPosition%)
		strTrackTitle := objCover%intPosition%.Name
	else
		strTrackTitle := ""
	if !StrLen(objCover%intPosition%.CoverTempFilePathName)
		strCoverTempFilePathName := A_ScriptDir  . "\no_cover-200x200.png" ; if absent, url download from repo ? ###
	else
		strCoverTempFilePathName := objCover%intPosition%.CoverTempFilePathName
	; TrayTip, %strTrackTitle%, %strCoverTempFilePathName%
	pBitmapPicPreview := Gdip_CreateBitmap(Pos%intPosition%w, Pos%intPosition%h)
	; ###_D(pBitmapPicPreview)
	GPicPreview := Gdip_GraphicsFromImage(pBitmapPicPreview)
	; ###_D(GPicPreview)
	Gdip_SetInterpolationMode(GPicPreview, 7)
	LoadPicPreview(picPreview%intPosition%, strCoverTempFilePathName)
	
	GuiControl, , lblNameLabel%intPosition%, % objCover%intPosition%.Name
	GuiControl, , lblCoverLabel%intPosition%, % lArtist . ": " . objCover%intPosition%.Artist . "`n"
		. lAlbum . ": " . objCover%intPosition%.Album . "`n"
		. "Index: " . objCover%intPosition%.Index . "`n"
		. "TrackID: " . objCover%intPosition%.TrackID . "`n"
		. "TrackDatabaseID: " . objCover%intPosition%.TrackDatabaseID
} until (A_Index = intCoversPerPage) or (intTrackIndexDisplayedNow = intNbCovers)
intRemainingCovers := intCoversDisplayedPrevious - intPosition
intCoversDisplayedPrevious := intPosition
loop, %intRemainingCovers%
{
	intPosition := intPosition + 1
	pBitmapPicPreview := Gdip_CreateBitmap(Pos%intPosition%w, Pos%intPosition%h)
	; ###_D(pBitmapPicPreview)
	GPicPreview := Gdip_GraphicsFromImage(pBitmapPicPreview)
	; ###_D(GPicPreview)
	Gdip_SetInterpolationMode(GPicPreview, 7)
	LoadPicPreview(picPreview%intPosition%, A_ScriptDir  . "\fill_cover-200x200.png")
	
	GuiControl, , lblNameLabel%intPosition%
	GuiControl, , lblCoverLabel%intPosition%
}

/*
	if intPage > 1, show btnPrevious, else hide
	if intTrackIndexDisplayedNow < intNbCovers, show btnNext, else cache
	
	check displayedNow vs PositionWithContentNow to calculate intRemainingCovers
*/
/*
###_D(""
	. "intTrackIndexDisplayedNow: " . intTrackIndexDisplayedNow . "`n"
	. "intNbCovers: " . intNbCovers . "`n"
	. "")
*/
GuiControl, % (intPage > 1 ? "Show" : "Hide"), btnPrevious
GuiControl, % (intTrackIndexDisplayedNow < intNbCovers ? "Show" : "Hide"), btnNext
GuiControl, , lblPage, % L(lPageFooter, intPage)

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
intHeaderHeight := 60
intFooterHeight := 60

intAvailWidth := intMonWorkRight - 50
intAvailHeight := intMonWorkBottom - 50
Gosub, CalcMaxRowsAndCols ; intMaxNbCol x intMaxNbRow
; ###_D("Init: " . intMaxNbCol . " x " . intMaxNbRow)

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
	GuiControlGet, Pos%A_Index%, Pos, picPreview%A_Index%
	; GuiControlGet, hwnd%A_Index%, hwnd, picPreview%A_Index%
	Gui, Font, s8 w500, Arial
	Gui, Add, Text, x%intXPic% y%intYPic% w%intPicWidth% h%intPicHeight% vlblCoverLabel%A_Index% gCoverLabelClicked border hidden
	Gui, Font, s8 w700, Arial
	Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPicWidth% h%intNameLabelHeight% center vlblNameLabel%A_Index% gNameLabelClicked
	Gui, Font
	
	if (intCol = intMaxNbCol)
	{
		if (intRow = intMaxNbRow)
		{
			intCoversPerPage := A_Index
			intNbCoversCreated := A_Index
			intCoversDisplayedPrevious := intCoversPerPagePrev
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



*/