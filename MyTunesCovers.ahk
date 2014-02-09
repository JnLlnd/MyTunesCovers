;===============================================
/*
	MyTunesCovers
	Written using AutoHotkey_L v1.1.09.03+ (http://l.autohotkey.net/)
	By Jean Lalonde (JnLlnd on AHKScript.org forum)

	2014-02-## v0.4 ALPHA
	* Display Board with empty images, support resize
	* Links inside covers to display cover, clip cover to board
	* Display artwork count in cover
	* Move backup board cover to board top, load master from file or clipboard
	* Use iTunes persistent IDs
	* Checkbox to display only covers without artwork
	* Copy master to cover, delete cover
	* Update only file track, handle error message for other kinds
	
	2014-01-17 v0.3 ALPHA
	* Reset all albums views when select All artists
	* Implemented release, save cache and reload cache for iTunes source
	* Source cache file saved by batch with error handling
	* Retrieve tracks using GetITObjectByID with TrackID and TrackDatabaseID
	* GuiResize reposition covers according to Gui size
	* Covers paging with x of y, previous and next buttons in footer
	* Loading persistent images (no cover, fill cover) only once at init

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
;@Ahk2Exe-SetVersion 0.4
;@Ahk2Exe-SetOrigFilename MyTunesCovers.exe


;============================================================
; INITIALIZATION
;============================================================

#NoEnv
#SingleInstance force
#KeyHistory 0
ListLines, Off

strCurrentVersion := "0.4 alpha" ; always "." between sub-versions, eg "0.1.2"

#Include %A_ScriptDir%\MyTunesCovers_LANG.ahk
#Include %A_ScriptDir%\lib\Cover.ahk
; lib\Cover.ahk is also calling lib\iTunes.ahk
; Also using Gdip.ahk (v1.45, modified 5/1/2013) in \AutoHotkey\Lib default lib folder

SetWorkingDir, %A_ScriptDir%

strTrackKinds := "File track,CD track,URL track,Device track,Shared library or Cloud track"
StringSplit, arrTrackKinds, strTrackKinds, `,

strIniFile := A_ScriptDir . "\" . lAppName . ".ini"
;@Ahk2Exe-IgnoreBegin
; Piece of code for developement phase only - won't be compiled
if (A_ComputerName = "JEAN-PC") ; for my home PC
	strIniFile := A_ScriptDir . "\" . lAppName . "-HOME.ini"
else if InStr(A_ComputerName, "STIC") ; for my work hotkeys
	strIniFile := A_ScriptDir . "\" . lAppName . "-WORK.ini"
; / Piece of code for developement phase only - won't be compiled
;@Ahk2Exe-IgnoreEnd

arrBoardPicFiles := Object()

; Keep gosubs in this order
Gosub, InitGDIP
Gosub, LoadIniFile
Gosub, Check4Update
Gosub, InitPersistentCovers
Gosub, BuildGui
Gosub, InitSources

WinActivate, % "ahk_id " . strWinId

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
intPictureSize := 160

IfNotExist, %strIniFile%
	FileAppend,
		(LTrim Join`r`n
			[Global]
			AlbumArtistDelimiter=%strAlbumArtistDelimiter%
			CoversCacheFolder=%A_ScriptDir%\covers_cache\
			PictureSize=%intPictureSize%
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
IniRead, intPictureSize, %strIniFile%, Global, PictureSize, %intPictureSize%

return
;------------------------------------------------------------


;-----------------------------------------------------------
InitPersistentCovers:
;-----------------------------------------------------------
ptrBitmapNoCover := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\no_cover-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapFillCover := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\fill_cover-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapEmptyBoard := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\empty-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapCopyHere := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\copy_here-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapButton1 := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\clip-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapButton2 := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\select-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapButton3 := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\paste-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapButton4 := Gdip_CreateBitmapFromFile(A_ScriptDir  . "\images\delete-200x200.png") ; if absent, url download from repo ? ###

If !(ptrBitmapNoCover and ptrBitmapFillCover and ptrBitmapEmptyBoard and ptrBitmapCopyHere)
	Oops(lPersistentImagesFailed)

return
;-----------------------------------------------------------


;-----------------------------------------------------------
BuildGui:
;-----------------------------------------------------------
intCoversPerPage := 0
intNbCoversCreated := 0
intNbBoardCreated := 0

intButtonSize := intPictureSize // 4
intNameLabelHeight := 30
intColWidth := intPictureSize + intButtonSize + 10
intRowHeight := intPictureSize + intNameLabelHeight + 10
intBoardWidth := intPictureSize + 20
intHeaderHeight := 60
intFooterHeight := 60

Gui, New, +Resize, % L(lGuiTitle, lAppName, lAppVersion)
Gui, +Delimiter%strAlbumArtistDelimiter%
Gui, Font, s12 w700, Verdana
Gui, Add, Text, x10, % L(lAppName)
Gui, Font
Gui, Font, s10 w500, Verdana
Gui, Add, Text, x+30 yp, %lSource%
Gui, Font
Gui, Add, Radio, x+10 yp vradSourceITunes gClickedRadSource checked, % L(lSourceITunes)
Gui, Add, Radio, x+10 yp vradSourceMP3 gClickedRadSource, % L(lSourceMP3)
Gui, Font, s10 w500, Verdana
Gui, Add, Text, x+20 yp, %lArtistsDropdownLabel%
Gui, Add, DropDownList, x+20 yp w300 vlstArtists gArtistsDropDownChanged Sort
Gui, Add, Text, x+20 yp, %lAlbumsDropdownLabel%
Gui, Add, DropDownList, x+20 yp w300 vlstAlbums gAlbumsDropDownChanged Sort
Gui, Font
Gui, Add, Checkbox, x+50 yp vblnOnlyNoCover gOnlyNoCoverClicked, %lOnlyNoCover%
Gui, Font, s10 w700, Verdana
Gui, Add, Text, x10 w%intBoardWidth% center, %lBoard%
Gui, Font

intVerticalLineX := intBoardWidth
intVerticalLineY := intHeaderHeight + 10
Gui, Add, Text, x%intVerticalLineX% y%intVerticalLineY% h10 0x11 vlblVerticalLine ; Vertical Line > Etched Gray
intHorizontalLineY := intHeaderHeight + intPictureSize + intNameLabelHeight
Gui, Add, Text, x10 y%intHorizontalLineY% w%intPictureSize% 0x10 vlblHorizontalBoardLine ; Horizontal Line > Etched Gray

Gui, Add, Button, x150 y+10 w80 vbtnPrevious gButtonPreviousClicked hidden, % "<- " . lPrevious
Gui, Add, Text, x+50 yp w60 vlblPage
Gui, Add, Button, x+50 yp w80 vbtnNext gButtonNextClicked hidden, % lNext . " ->"

Gui, Add, StatusBar
SB_SetParts(200)
SB_SetText(L(lSBEmpty), 1)
if (A_IsCompiled)
	SB_SetIcon(A_ScriptFullPath)
else
	SB_SetIcon("C:\Dropbox\AutoHotkey\MyTunesCovers\small_icons-256-RED.ico")

SysGet, intMonWork, MonitorWorkArea
intAvailWidth := intMonWorkRight - 50
intAvailHeight := intMonWorkBottom - 50

Gosub, CalcMaxRowsAndCols ; calculate intMaxNbCol and intMaxNbRow
intTotalWidth := (intMaxNbCol * intColWidth) + intBoardWidth + 20
intTotalHeight := (intMaxNbRow * intRowHeight) + intHeaderHeight + intFooterHeight

intPage := 1

Gui, Show, w%intTotalWidth% h%intTotalHeight%
strWinId := WinExist("A")

return
;-----------------------------------------------------------


;-----------------------------------------------------------
GuiSize:
;-----------------------------------------------------------

intPage := 1 ; always come back to page 1 when resize

intAvailWidth := A_GuiWidth - 5
intAvailHeight := A_GuiHeight
Gosub, CalcMaxRowsAndCols ; calculate intMaxNbCol and intMaxNbRow

intVerticalLineH := intMaxNbRow * intRowHeight
GuiControl, Move, lblVerticalLine, h%intVerticalLineH%

intX := 0
intY := intHeaderHeight + 5
intRow := 1
intXPic := intX + 10
intYPic := intY + 5
intYNameLabel := intY + intPictureSize + 5

loop, %intNbBoardCreated%
{
	GuiControl, Hide, picBoard%A_Index%
	GuiControl, Hide, lblBoardNameLabel%A_Index%
}

loop, %intMaxNbRow%
{
	if (intNbBoardCreated < A_Index)
	{
		Gui, Add, Picture, x%intXPic% y%intYPic% w%intPictureSize% h%intPictureSize% 0xE vpicBoard%A_Index% gPicBoardClicked
		Gui, Font, s8 w500, Arial
		Gui, Add, Link, x%intXPic% y%intYPic% w%intPictureSize% h%intPictureSize% vlnkBoardLink%A_Index% gBoardLinkClicked border hidden
		Gui, Font, s8 w700, Arial
		Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPictureSize% h%intNameLabelHeight% center vlblBoardNameLabel%A_Index%
		if (A_Index = 1)
			GuiControl, , lblBoardNameLabel%A_Index%, %lBoardMasterCover%
		else
			GuiControl, , lblBoardNameLabel%A_Index%, %lBoardBackupCover% #%A_Index%

		strBoardLink := ""
			. "<A ID=""ShowPic" . intPosition . """>" . lBoardShowPic . "</A>" . "`n"
			. "<A ID=""Remove" . intPosition . """>" . lBoardRemove . "</A>" . "`n"

		if (A_Index = 1)
			strBoardLink := strBoardLink
			. "<A ID=""LoadFromFile" . intPosition . """>" . lBoardLoadFromFile . "</A>" . "`n"
			. "<A ID=""LoadFromClipboard" . intPosition . """>" . lBoardLoadFromClipboard . "</A>" . "`n"
			
			
		if (A_Index > 1)
			strBoardLink := strBoardLink
			. "<A ID=""MakeMaster" . intPosition . """>" . lBoardMakeMaster . "</A>" . "`n"

		GuiControl, , lnkBoardLink%A_Index%, %strBoardLink%

		GuiControlGet, posBoard%A_Index%, Pos, picBoard%A_Index%
		if (A_Index > intNbBoardCreated)
			intNbBoardCreated := A_Index
	}
	else
		GuiControl, Show, picBoard%A_Index%
	
	intRow := intRow + 1
	intY := intY + intRowHeight
	intYPic := intY + 5
	intYNameLabel := intY + intPictureSize + 5
}

intCoversPerPagePrevious := intCoversPerPage
intCoversPerPage := (intMaxNbCol * intMaxNbRow)

intX := intBoardWidth + 5
intY := intHeaderHeight + 5
intCol := 1
intRow := 1
intXPic := intX + 5
intYPic := intY + 5
intYNameLabel := intY + intPictureSize + 5

loop, %intCoversPerPagePrevious%
{
	GuiControl, Hide, picCover%A_Index%
	GuiControl, Hide, lnkCoverLink%A_Index%
	GuiControl, Hide, lblNameLabel%A_Index%
	intIndex := A_Index
	loop, 4
		GuiControl, Hide, picButton%A_Index%%intIndex%
}

loop, %intCoversPerPage%
{
	if (intNbCoversCreated < A_Index)
	{
		Gui, Add, Picture, x%intXPic% y%intYPic% w%intPictureSize% h%intPictureSize% 0xE vpicCover%A_Index% gPicCoverClicked
		GuiControlGet, posCover%A_Index%, Pos, picCover%A_Index%
		Gui, Font, s8 w500, Arial
		Gui, Add, Link, x%intXPic% y%intYPic% w%intPictureSize% h%intPictureSize% vlnkCoverLink%A_Index% gCoverLinkClicked border hidden
		intIndex := A_Index
		loop, 4
		{
			Gui, Add, Picture, % "x" . (intXPic + intPictureSize) . " y" . (intYPic + (intButtonSize * (A_Index - 1))) . " w" . intButtonSize . " h" . intButtonSize . " 0xE vpicButton" . A_Index . intIndex . " gCoverButtonClicked hidden"
			LoadPicControl(picButton%A_Index%%intIndex%, (A_Index + 5))
		}
		Gui, Font, s8 w700, Arial
		Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPictureSize% h%intNameLabelHeight% center vlblNameLabel%A_Index% gNameLabelClicked
		Gui, Font
		intNbCoversCreated := A_Index
	}
	else
	{
		GuiControl, Move, picCover%A_Index%, x%intXPic% y%intYPic%
		GuiControl, Show, picCover%A_Index%
		GuiControl, Move, lnkCoverLink%A_Index%, x%intXPic% y%intYPic%
		GuiControl, Move, lblNameLabel%A_Index%, x%intXPic% y%intYNameLabel%
		GuiControl, Show, lblNameLabel%A_Index%
		intIndex := A_Index
		loop, 4
			GuiControl, Move, picButton%A_Index%%intIndex%, % "x" . (intXPic + intPictureSize) . " y" . (intYPic + (intButtonSize * (A_Index - 1)))
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
		intYNameLabel := intY + intPictureSize + 5
		
		intCol := 0
		intX := 5 - intColWidth + intBoardWidth
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

intGuiMiddle := intBoardWidth + (A_GuiWidth - intBoardWidth) / 2
GuiControl, Move, btnPrevious, % "X" . (intGuiMiddle - 120) . " Y" . A_GuiHeight - 55
GuiControl, Move, lblPage, % "X" . (intGuiMiddle) . " Y" . A_GuiHeight - 55
GuiControl, Move, btnNext, % "X" . (intGuiMiddle + 105) . " Y" . A_GuiHeight - 55

blnResizeInProgress := True
Gosub, RefreshBoard
Gosub, DisplayCoversPage
blnResizeInProgress := False

return
;-----------------------------------------------------------


;-----------------------------------------------------------
CalcMaxRowsAndCols:
;-----------------------------------------------------------
intMaxNbCol := Floor((intAvailWidth - intBoardWidth) / intColWidth)
intMaxNbRow := Floor((intAvailHeight - intHeaderHeight - intFooterHeight) / intRowHeight)

if (!intMaxNbCol)
	intMaxNbCol := 1
if (!intMaxNbRow)
	intMaxNbRow := 1

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
;-----------------------------------------------------------


;-----------------------------------------------------------
ClickedRadSource:
;-----------------------------------------------------------
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
ArtistsDropDownChanged:
;-----------------------------------------------------------
Gui, Submit, NoHide
if (lstArtists = A_Space . lDropDownAllArtists)
	Gosub, PopulateAlbumDropdownList
else
	GuiControl, , lstAlbums, % strAlbumArtistDelimiter . A_Space
		. lDropDownAllAlbums . strAlbumArtistDelimiter . objAlbumsOfArtistsIndex[lstArtists]
GuiControl, Choose, lstAlbums, 1

Gosub, DisplayCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
AlbumsDropDownChanged:
;-----------------------------------------------------------
Gui, Submit, NoHide

Gosub, DisplayCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
OnlyNoCoverClicked:
;-----------------------------------------------------------

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

intNbCovers := Cover_InitCoverScan(lstArtists, lstAlbums, blnOnlyNoCover) - 1 ; -1 because of the last comma in lists

if (intNbCovers < 0)
{
	###_D("Oops ### : " . intNbCovers)
	return
}

intPage := 1
intNbPages := Ceil(intNbCovers / intCoversPerPage)

Gosub, DisplayCoversPage

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayCoversPage:
;-----------------------------------------------------------
Gui, Submit, NoHide
if !(blnResizeInProgress)
	Gui, +Disabled ; protect display cover from user clicks

intPosition := 0
intTrackIndexDisplayedNow := ((intPage - 1) * intCoversPerPage)
intNbPages := Ceil(intNbCovers / intCoversPerPage) ; can change when resize

if (intNbCovers)
	loop
	{
		intTrackIndexDisplayedNow := intTrackIndexDisplayedNow + 1
		if !Cover_GetCover(objThisCover, intTrackIndexDisplayedNow)
			break
		intPosition := intPosition + 1
		objCover%intPosition% := objThisCover
		
		GuiControl, Hide, lnkCoverLink%intPosition%
		GuiControl, Show, picCover%intPosition%
		
		GuiControl, , lblNameLabel%intPosition%, % objCover%intPosition%.Name . (objCover%intPosition%.ArtworkCount > 1 ? " (" . objCover%intPosition%.ArtworkCount . ")" : "")
		GuiControl, , lnkCoverLink%intPosition%, % lArtist . ": " . objCover%intPosition%.Artist . "`n"
			. lAlbum . ": " . objCover%intPosition%.Album . "`n"
			. "TrackID: " . objCover%intPosition%.TrackIDHigh . "/" . objCover%intPosition%.TrackIDLow . "`n"
			. "ArtworkCount/Kind: " . objCover%intPosition%.ArtworkCount . " / Kind: " . objCover%intPosition%.Kind . "`n"
			. "`n"
			. "<A ID=""ShowPic"">" . lCoverShowPic . "</A>   <A ID=""ViewPic"">" . lCoverViewPic . "</A>" . "`n"
			. "`n"
			. "<A ID=""Listen"">" . lCoverListen . "</A>" . "`n"

		; ptrBitmapPicCover := Gdip_CreateBitmap(intPictureSize, intPictureSize) ; (posCover%intPosition%w, posCover%intPosition%h)
		; ptrGraphicPicCover := Gdip_GraphicsFromImage(ptrBitmapPicCover)
		; Gdip_SetInterpolationMode(ptrGraphicPicCover, 7) ; using default instead of 7 (highest quality)
		
		if (arrPositionSelected%intPosition%)
			LoadPicControl(picCover%intPosition%, 5) ; Copy here
		else if StrLen(objCover%intPosition%.CoverTempFilePathName)
			LoadPicControl(picCover%intPosition%, 1, objCover%intPosition%.CoverTempFilePathName)
		else 
			LoadPicControl(picCover%intPosition%, 2) ; No cover

		if (objCover%intPosition%.Kind <> 1)
		{
			GuiControl, Show, picButton1%intPosition%
			loop, 3
				GuiControl, Hide, % "picButton" . (A_Index + 1) . intPosition
		}
		else
			loop, 4
				GuiControl, Show, picButton%A_Index%%intPosition%

		
	} until (A_Index = intCoversPerPage) or (intTrackIndexDisplayedNow = intNbCovers)

intRemainingCovers := intCoversDisplayedPrevious - intPosition
intCoversDisplayedPrevious := intPosition

loop, %intRemainingCovers%
{
	intPosition := intPosition + 1
	; ptrBitmapPicCover := Gdip_CreateBitmap(posCover%intPosition%w, posCover%intPosition%h)
	; ptrGraphicPicCover := Gdip_GraphicsFromImage(ptrBitmapPicCover)
	; Gdip_SetInterpolationMode(ptrGraphicPicCover, 7)
	LoadPicControl(picCover%intPosition%, 3)
	
	GuiControl, , lblNameLabel%intPosition%
	GuiControl, , lnkCoverLink%intPosition%
	GuiControl, Hide, lnkCoverLink%intPosition%
	GuiControl, Show, picCover%intPosition%
	loop, 4
		GuiControl, Hide, picButton%A_Index%%intPosition%
}

GuiControl, % (intPage > 1 ? "Show" : "Hide"), btnPrevious
GuiControl, % (intTrackIndexDisplayedNow < intNbCovers ? "Show" : "Hide"), btnNext
if (intNbPages)
	GuiControl, , lblPage, % L(lPageFooter, intPage, intNbPages)

if !(blnResizeInProgress)
	Gui, -Disabled
GuiControl, Focus, lstArtists

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayBoard:
;-----------------------------------------------------------
Gui, Submit, NoHide

loop, %intMaxNbRow%
{
	; ptrBitmapPicCover := Gdip_CreateBitmap(posBoard%A_Index%w, posBoard%A_Index%h)
	; ptrGraphicPicCover := Gdip_GraphicsFromImage(ptrBitmapPicCover)
	; Gdip_SetInterpolationMode(ptrGraphicPicCover, 7)
	LoadPicControl(picBoard%A_Index%, 4)
}

return
;-----------------------------------------------------------


;-----------------------------------------------------------
LoadPicControl(ByRef picControl, intPicType, strFile := "")
; intPicType = 1 regular cover / 2 no cover / 3 fill cover / 4 empty board / 5 copy here / 6 clip button / 7 select button / 8 paste button / 9 delete button
{
	global ptrBitmapNoCover, ptrBitmapFillCover, ptrBitmapEmptyBoard, ptrBitmapCopyHere, ptrBitmapButton1, ptrBitmapButton2, ptrBitmapButton3, ptrBitmapButton4

	GuiControlGet, posControl, Pos, picControl
	GuiControlGet, hwnd, hwnd, picControl

	if (intPicType = 1)
		If !ptrBitmap := Gdip_CreateBitmapFromFile(strFile)
			return
	if (intPicType = 2)
		ptrBitmap := ptrBitmapNoCover
	if (intPicType = 3)
		ptrBitmap := ptrBitmapFillCover
	if (intPicType = 4)
		ptrBitmap := ptrBitmapEmptyBoard
	if (intPicType = 5)
		ptrBitmap := ptrBitmapCopyHere
	if (intPicType = 6)
		ptrBitmap := ptrBitmapButton1
	if (intPicType = 7)
		ptrBitmap := ptrBitmapButton2
	if (intPicType = 8)
		ptrBitmap := ptrBitmapButton3
	if (intPicType = 9)
		ptrBitmap := ptrBitmapButton4
	
	intWidth := Gdip_GetImageWidth(ptrBitmap)
	intHeight := Gdip_GetImageHeight(ptrBitmap)
	
	if (posControlw/intWidth >= posControlh/intHeight)
	{
		intNewHeight := posControlh
		intNewWidth := Round(intWidth*(intNewHeight/intHeight))
	}
	else
	{
		intNewWidth := posControlw
		intNewHeight := Round(intHeight*(intNewWidth/intWidth))
	}

	ptrBitmapPicControl := Gdip_CreateBitmap(posControlw, posControlh)
	ptrGraphicPicControl := Gdip_GraphicsFromImage(ptrBitmapPicControl)
	Gdip_SetInterpolationMode(ptrGraphicPicControl, 7)

	Gdip_GraphicsClear(ptrGraphicPicControl)
	Gdip_DrawImage(ptrGraphicPicControl, ptrBitmap, (posControlw-intNewWidth)//2, (posControlh-intNewHeight)//2, intNewWidth, intNewHeight, 0, 0, intWidth, intHeight)
	
	hndlBitmap := Gdip_CreateHBITMAPFromBitmap(ptrBitmapPicControl)
	SetImage(hwnd, hndlBitmap)

	DeleteObject(hndlBitmap)
	if (intPicType = 1)
		Gdip_DisposeImage(ptrBitmap)
}
;-----------------------------------------------------------


;-----------------------------------------------------------
PicCoverClicked:
;-----------------------------------------------------------
StringReplace, intPosition, A_GuiControl, picCover

; objCover%intPosition%.Name

if (intPosition <= intCoversDisplayedPrevious)
{
	GuiControl, Hide, %A_GuiControl%
	GuiControl, Show, lnkCoverLink%intPosition%
}

return
;-----------------------------------------------------------


;-----------------------------------------------------------
CoverButtonClicked:
;-----------------------------------------------------------

StringReplace, strControl, A_GuiControl, picButton
intCommand := SubStr(strControl, 1, 1)
intPosition := SubStr(strControl, 2)

; The first command can be executed on any kind of track
if (intCommand = 1) ; Clip
{
	if StrLen(objCover%intPosition%.CoverTempFilePathName)
		arrBoardPicFiles.Insert(1, objCover%intPosition%.CoverTempFilePathName)
	Gosub, RefreshBoard
	return
}

; The following commands can only be executed on file track
if !(objCover%intPosition%.Kind)
{
	Oops(lCoverUnknownTrackKind, lAppName)
	return
}
if (objCover%intPosition%.Kind > 1)
{
	intKind := objCover%intPosition%.Kind
	Oops(lCoverUnsupportedTrackKind, arrTrackKinds%intKind%, lAppName)
	return
}

; Now, we know kind is 1 (File track)
if (intCommand = 2) ; Select
	arrPositionSelected%intPosition% := !arrPositionSelected%intPosition%
else if (intCommand = 3) ; Paste
{
	blnGo := !(objCover%intPosition%.ArtworkCount)
	if !(blnGo)
		blnGo := (YesNoCancel(False, L(lCoverPasteMaster, lAppName), L(lCoverOverwrite)) = "Yes")
	if (blnGo)
		Cover_SaveCoverToTune(objCover%intPosition%, arrBoardPicFiles[1], true)
}
else if (intCommand = 4) ; Delete
{
	blnGo := !(objCover%intPosition%.ArtworkCount)
	if !(blnGo)
		blnGo := (YesNoCancel(False, L(lCoverDeleteTitle, lAppName), L(lCoverDeletePrompt)) = "Yes")
	if (blnGo)
		Cover_DeleteCoverFromTune(objCover%intPosition%)
}

Gosub, DisplayCoversPage ; ### display only current cover

return
;-----------------------------------------------------------


;-----------------------------------------------------------
CoverLinkClicked:
;-----------------------------------------------------------
strCommand := ErrorLevel

if (strCommand = "ShowPic")
{
	GuiControl, Hide, %A_GuiControl%
	GuiControl, Show, picCover%intPosition%
} else if (strCommand = "ViewPic")
{
	strFilename := objCover%intPosition%.CoverTempFilePathName
	if FileExist(strFilename)
		Run, %strFilename%
}
else if (strCommand = "Listen")
{
	Cover_PLay(objCover%intPosition%)
}

return
;-----------------------------------------------------------


;-----------------------------------------------------------
NameLabelClicked:
;-----------------------------------------------------------
###_D("NameLabelClicked")

return
;-----------------------------------------------------------


;-----------------------------------------------------------
PicBoardClicked:
;-----------------------------------------------------------
StringReplace, intPosition, A_GuiControl, picBoard

GuiControl, Hide, %A_GuiControl%
GuiControl, Show, lnkBoardLink%intPosition%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
BoardLinkClicked:
;-----------------------------------------------------------
strCommand := ErrorLevel
StringReplace, intPosition, A_GuiControl, lnkBoardLink
StringReplace, strCommand, strCommand, %intPosition%

if (strCommand = "ShowPic")
{
	GuiControl, Hide, %A_GuiControl%
	GuiControl, Show, picBoard%intPosition%
	return
}

if (strCommand = "Remove")
	arrBoardPicFiles.Remove(intPosition)
else if (strCommand = "MakeMaster")
{
	arrBoardPicFiles.Insert(1, arrBoardPicFiles[intPosition])
	arrBoardPicFiles.Remove(intPosition + 1)
}
else if (strCommand = "LoadFromFile")
{
	FileSelectFile, strLoadMasterFilename, , , %lBoardLoadFromFilePrompt%, % lImageFiles . " (*.jpg; *.jpeg; *.png; *.bmp; *.gif; *.tiff; *.tif)"
	if StrLen(strLoadMasterFilename)
		arrBoardPicFiles.Insert(1, strLoadMasterFilename)
}
else if (strCommand = "LoadFromClipboard")
{
	ptrBitmapClipbpard := Gdip_CreateBitmapFromClipboard()
	if (ptrBitmapClipbpard < 0)
	{
		DllCall("CloseClipboard")
		Oops(lInvalidClipboardContent)
		return
	}
	strLoadClipboardFilename := strCoversCacheFolder . Cover_GenerateGUID() . ".jpg"
	Gdip_SaveBitmapToFile(ptrBitmapClipbpard, strLoadClipboardFilename, 95)
	ptrBitmapClipbpard :=

	if StrLen(strLoadClipboardFilename)
		arrBoardPicFiles.Insert(1, strLoadClipboardFilename)
}

Gosub, RefreshBoard

return
;-----------------------------------------------------------


;-----------------------------------------------------------
RefreshBoard:
;-----------------------------------------------------------
loop, %intMaxNbRow%
{
	if (A_Index <= arrBoardPicFiles.MaxIndex())
		LoadPicControl(picBoard%A_Index%, 1, arrBoardPicFiles[A_Index])
	else
		LoadPicControl(picBoard%A_Index%, 4)
	GuiControl, Hide, lnkBoardLink%A_Index%
	GuiControl, Show, picBoard%A_Index%
	GuiControl, Show, lblBoardNameLabel%A_Index%
}

return
;-----------------------------------------------------------


;-----------------------------------------------------------
SaveClipboardToImageFile:
;-----------------------------------------------------------


return
;-----------------------------------------------------------



;============================================================
; TOOLS
;============================================================


; ------------------------------------------------
ButtonCheck4Update: ; ### NEED TEST
; ------------------------------------------------
blnButtonCheck4Update := True ; ???
Gosub, Check4Update

return
; ------------------------------------------------


; ------------------------------------------------
ButtonDonate:
; ------------------------------------------------
Run, https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=8UWKXDR5ZQNJW ; ### update Paypal code

return
; ------------------------------------------------


; ------------------------------------------------
Check4Update: ; ### NEED TEST
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
ChangeButtonNames4Update: ; ### TEST
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
YesNoCancel(blnWithCancel, strTitle, strPrompt)
; ------------------------------------------------
{
	MsgBox, % 4 - blnWithCancel, %strTitle%, %strPrompt%
	IfMsgBox, Yes
		return "Yes"
	IfMsgBox, No
		return "No"
	IfMsgBox, Cancel ; Remind me
		return "Cancel"
}
; ------------------------------------------------


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
			StringReplace, strMessage, strMessage, ~%A_Index%~, % objVariables[A_Index], All
 		else
			break
	}
	
	return strMessage
}
; ------------------------------------------------



/*

BACKUP PIECES OF CODE


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
