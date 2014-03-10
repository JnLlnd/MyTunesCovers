;===============================================
/*
	MyTunesCovers
	Written using AutoHotkey_L v1.1.09.03+ (http://l.autohotkey.net/)
	By Jean Lalonde (JnLlnd on AHKScript.org forum)

	BUGS
	- none (known)
	
	TODO
	- encode indexes
	- embed images folder in exe or zip?

	2014-03-## v0.6 ALPHA
	* moved source selection to options dialog box
	* added iTunes Playlist selection and saving index file according to current playlist selection
	* moved display only no cover and list only ablum with no cover checkboxes to option dialog box
	* moving index files to a subdirectory
	* display file name when loading/saving index cache, display file date when loading
	* display current playlist as default in playlist dropdown

	2014-03-07 v0.5 ALPHA
	* prompt before saving source
	* reload source if not matching the iTunes library
	* progress bar while creating, saving and loading source index
	* create cover cache folder if it does not exist
	* display error if images folder not present
	* when selecting all Artists drop down, preserve the selection of Albums
	* when selecting an albums, restrict the artists list to artists in this album
	* rearrange header buttons, make Select All and Unselect All the same button
	* progress bar while pasting to selected
	* button to delete all selected covers
	* checkbox to show in artists and album dropdowns only albums with at least one tune without cover
	* display links when no cover, linkes re-arranged, added track info duration, year and comment

	2014-02-15 v0.4 ALPHA
	* Use iTunes persistent IDs
	* Update only file track, handle error message for other kinds
	* Focus on artists or albums dropdown for easy keyboard navigation
	* Disable Gui during covers display
	* Checkbox to display only covers without artwork
	* Select all and unselect all covers buttons, single page or multipage
	* Display artwork count in cover
	* Search image links in covers
	* Covers buttons to display cover, clip cover to board
	* Board button to paste master cover to selected covers
	* Button to delete cover
	* Display Board with empty images, support resize
	* Board buttons to load board from clipboard or file, and remove cover from board
	* Move backup board cover to board top
	
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
;@Ahk2Exe-SetVersion 0.6
;@Ahk2Exe-SetOrigFilename MyTunesCovers.exe

;@Ahk2Exe-IgnoreBegin
; Piece of code for developement phase only - won't be compiled
Menu, Tray, Icon, %A_ScriptDir%\small_icons-256-RED.ico, 1
; / Piece of code for developement phase only - won't be compiled
;@Ahk2Exe-IgnoreEnd

;============================================================
; INITIALIZATION
;============================================================

#NoEnv
#SingleInstance force
#KeyHistory 0
#NoTrayIcon 
ListLines, Off

strCurrentVersion := "0.6 alpha" ; always "." between sub-versions, eg "0.1.2"

#Include %A_ScriptDir%\MyTunesCovers_LANG.ahk
#Include %A_ScriptDir%\lib\Cover.ahk
; lib\Cover.ahk is also calling lib\iTunes.ahk
; Also using Gdip.ahk (v1.45, modified 5/1/2013) in \AutoHotkey\Lib default lib folder

; Keep gosubs in this order
Gosub, Init
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
Init:
;-----------------------------------------------------------

SetWorkingDir, %A_ScriptDir%

strSkin := "night"
strSkinExtension := "png"

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

Hotkey, Up, DoNothing, Off
Hotkey, Down, DoNothing, Off
Hotkey, Left, DoNothing, Off
Hotkey, Right, DoNothing, Off
Hotkey, PgUp, DoNothing, Off
Hotkey, PgDn, DoNothing, Off
Hotkey, Home, DoNothing, Off
Hotkey, End, DoNothing, Off

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DoNothing:
;-----------------------------------------------------------
return
;-----------------------------------------------------------


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
strSourceType := "iTunes"
strSourceSelection := ""
strAlbumArtistDelimiter := chr(182)
strCoversCacheFolder := A_ScriptDir . "\covers_cache\"
intPictureSize := 160
strSearchLink1 := "http://www.google.ca/search?tbm=isch&q=~artist~ ""~album~"""
strSearchLink2 := "http://www.covermytunes.com/search.php?search_query=~artist~ ~album~"

IfNotExist, %strIniFile%
	FileAppend,
		(LTrim Join`r`n
			[Global]
			Source=%strSourceType%
			SourceSelection=%strSourceSelection%
			AlbumArtistDelimiter=%strAlbumArtistDelimiter%
			CoversCacheFolder=%strCoversCacheFolder%
			PictureSize=%intPictureSize%
			SearchLink1=%strSearchLink1%
			SearchLink2=%strSearchLink2%
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
IniRead, strSourceType, %strIniFile%, Global, Source, %strSourceType%
IniRead, strSourceSelection, %strIniFile%, Global, SourceSelection, %strSourceSelection%
IniRead, strCoversCacheFolder, %strIniFile%, Global, CoversCacheFolder, %strCoversCacheFolder%
IniRead, intPictureSize, %strIniFile%, Global, PictureSize, %intPictureSize%
IniRead, strSearchLink1, %strIniFile%, Global, SearchLink1, %strSearchLink1%
IniRead, strSearchLink2, %strIniFile%, Global, SearchLink2, %strSearchLink2%
IniRead, strLatestSkipped, %strIniFile%, Global, LatestVersionSkipped, 0.0

return
;------------------------------------------------------------


;-----------------------------------------------------------
InitPersistentCovers:
;-----------------------------------------------------------
if !FileExist(A_ScriptDir . "\images\")
{
	Oops(lCoverNoPersistentImages, A_ScriptDir . "\images\", lAppName)
	ExitApp
}
ptrBitmapNoCover := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\no_cover-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapFillCover := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\fill_cover-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapEmptyBoard := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\empty-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapCopyHere := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\copy_here-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapError := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\error-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapCoverButton1 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\clip-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapCoverButton2 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\select-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapCoverButton3 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\paste_here-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapCoverButton4 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\delete-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapBoardButton0 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\paste_to_selected-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapBoardButton1 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\make_master-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapBoardButton2 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\load_clipboard-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapBoardButton3 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\load_file-200x200.png") ; if absent, url download from repo ? ###
ptrBitmapBoardButton4 := Gdip_CreateBitmapFromFile(A_ScriptDir . "\images\remove-200x200.png") ; if absent, url download from repo ? ###

ptrBitmapBackgroundHeader := Gdip_CreateBitmapFromFile(A_ScriptDir . "\skins\" . strSkin . "\background_header." . strSkinExtension)
Gdip_GetImageDimensions(ptrBitmapBackgroundHeader, intWidthBackgroundHeader, intHeightBackgroundHeader)
ptrBitmapBackgroundBoard := Gdip_CreateBitmapFromFile(A_ScriptDir . "\skins\" . strSkin . "\background_board." . strSkinExtension)
Gdip_GetImageDimensions(ptrBitmapBackgroundBoard, intWidthBackgroundBoard, intHeightBackgroundBoard)
ptrBitmapBackgroundCovers := Gdip_CreateBitmapFromFile(A_ScriptDir . "\skins\" . strSkin . "\background_covers." . strSkinExtension)
Gdip_GetImageDimensions(ptrBitmapBackgroundCovers, intWidthBackgroundCovers, intHeightBackgroundCovers)
; ptrBitmapBackgroundFooter := Gdip_CreateBitmapFromFile(A_ScriptDir . "\skins\" . strSkin . "\background_footer." . strSkinExtension)
; Gdip_GetImageDimensions(ptrBitmapBackgroundFooter, intWidthBackgroundFooter, intHeightBackgroundFooter)

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
intBoardWidth := intPictureSize + intButtonSize + 20
intHeaderHeight := 60
intFooterHeight := 60
intStatusBarHeight := 24

Gui, 1:New, +Resize, % L(lGuiTitle, lAppName, lAppVersion)
Gui, 1:+Delimiter%strAlbumArtistDelimiter%

; Gui, Add, Picture, x0 y0 w1 h1 0xE vpicBackgroundHeader, % A_ScriptDir . "\skins\" . strSkin . "\background_header." . strSkinExtension
Gui, Add, Picture, % "x0 y0 w" . intWidthBackgroundHeader . " h" . intHeightBackgroundHeader, % A_ScriptDir . "\skins\" . strSkin . "\background_header." . strSkinExtension
; Gui, Add, Picture, x0 y0 w1 h1 0xE vpicBackgroundBoard, % A_ScriptDir . "\skins\" . strSkin . "\background_board." . strSkinExtension
Gui, Add, Picture, % "x0 y" . intHeaderHeight . " w" . intWidthBackgroundBoard . " h" . intHeightBackgroundBoard, % A_ScriptDir . "\skins\" . strSkin . "\background_board." . strSkinExtension
; Gui, Add, Picture, x0 y0 w1 h1 0xE vpicBackgroundCovers, % A_ScriptDir . "\skins\" . strSkin . "\background_covers." . strSkinExtension
Gui, Add, Picture, % "x" . intBoardWidth . " y" . intHeaderHeight . " w" . intWidthBackgroundCovers . " h" . intHeightBackgroundCovers . " 0xE vpicBackgroundCovers", % A_ScriptDir . "\skins\" . strSkin . "\background_covers." . strSkinExtension
; Gui, Add, Picture, x0 y0 w1 h1 0xE vpicBackgroundFooter, % A_ScriptDir . "\skins\" . strSkin . "\background_footer." . strSkinExtension
; Gui, Add, Picture, % "x0 y" . intHeaderHeight + (intMaxNbRow * intRowHeight) . " w" . intWidthBackgroundFooter . " h" . intHeightBackgroundFooter, % A_ScriptDir . "\skins\" . strSkin . "\background_footer." . strSkinExtension

Gui, Font, s12 w700, Verdana
Gui, Add, Text, x10 y10 w%intBoardWidth% center backgroundtrans, % L(lAppName)
Gui, Font
Gui, Add, Button, x+10 yp vbtnSelectAll gButtonSelectAllClicked w70, %lSelectAll%
Gui, Add, Button, x+10 yp vbtnDeleteSelected gButtonDeleteSelectedClicked w90, %lDeleteSelected%
Gui, Font, s10 w500, Verdana
Gui, Add, Text, x+20 yp gLabelAllArtistsClicked backgroundtrans, %lArtistsDropdownLabel%
Gui, Add, DropDownList, x+20 yp w300 vlstArtists gArtistsDropDownChanged Sort
Gui, Add, Text, x+20 yp gLabelAllAlbumsClicked backgroundtrans, %lAlbumsDropdownLabel%
Gui, Add, DropDownList, x+20 yp w300 vlstAlbums gAlbumsDropDownChanged Sort
Gui, Font
Gui, Add, Button, x+10 yp vbtnSettings gGuiSettings Disabled, %lSettings%

; Gui, Font, s10 w700, Verdana
; Gui, Add, Text, x10 w%intBoardWidth% center backgroundtrans, %lBoard%
; Gui, Font

/*
intVerticalLineX := intBoardWidth
intVerticalLineY := intHeaderHeight + 10
Gui, Add, Text, x%intVerticalLineX% y%intVerticalLineY% h10 0x11 vlblVerticalLine ; Vertical Line > Etched Gray
intHorizontalLineY := intHeaderHeight + intPictureSize + intNameLabelHeight
intHorizontalLineW := intPictureSize + intButtonSize
Gui, Add, Text, x10 y%intHorizontalLineY% w%intHorizontalLineW% 0x10 vlblHorizontalBoardLine ; Horizontal Line > Etched Gray
*/

Gui, Add, Button, x150 y+10 w80 vbtnPrevious gButtonPreviousClicked hidden, % "<- " . lPrevious
Gui, Add, Text, x+50 yp w60 vlblPage backgroundtrans
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

; GuiControl, Move, picBackgroundHeader, % "x0 y0 w" . intAvailWidth . " h" . intHeaderHeight
; GuiControl, Move, picBackgroundBoard, % "x0 y" . intHeaderHeight . " w" . intBoardWidth . " h" . (intMaxNbRow * intRowHeight)
; GuiControl, Move, picBackgroundCovers, % "x" . intBoardWidth . " y" . intHeaderHeight . " w" . (intAvailWidth - intBoardWidth + 10) . " h" . (intMaxNbRow * intRowHeight)
; GuiControl, Move, picBackgroundFooter, % "x0 y" . intHeaderHeight + (intMaxNbRow * intRowHeight) . " w" . intAvailWidth . " h" . (intFooterHeight + 200)

; intVerticalLineH := intMaxNbRow * intRowHeight
; GuiControl, Move, lblVerticalLine, h%intVerticalLineH%

intX := 0
intY := intHeaderHeight + 5
intRow := 1
intXPic := intX + 10
intYPic := intY + 5
intYNameLabel := intY + intPictureSize + 10

loop, %intNbBoardCreated%
{
	GuiControl, Hide, picBoard%A_Index%
	GuiControl, Hide, lblBoardNameLabel%A_Index%
	intIndex := A_Index
	loop, 4
		GuiControl, Hide, picBoardButton%A_Index%%intIndex%
}

loop, %intMaxNbRow%
{
	if (intNbBoardCreated < A_Index)
	{
		Gui, Add, Picture, x%intXPic% y%intYPic% w%intPictureSize% h%intPictureSize% 0xE vpicBoard%A_Index% gPicBoardClicked
		Gui, Font, s8 w500, Arial
		Gui, Add, Link, x%intXPic% y%intYPic% w%intPictureSize% h%intPictureSize% vlnkBoardLink%A_Index% gBoardLinkClicked border hidden
		intIndex := A_Index
		loop, 4
		{
			Gui, Add, Picture, % "x" . (intXPic + intPictureSize) . " y" . (intYPic + (intButtonSize * (A_Index - 1)))
				. " w" . intButtonSize . " h" . intButtonSize . " 0xE vpicBoardButton" . A_Index . intIndex . " gBoardButtonClicked "
				. (intIndex = 1 ? "" : "hidden")
			if (A_Index = 1) and (intIndex = 1)
				LoadPicControl(picBoardButton11, 14)
			else
				LoadPicControl(picBoardButton%A_Index%%intIndex%, (A_Index + 9))
		}
		Gui, Font, s8 w700, Arial
		Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPictureSize% h%intNameLabelHeight% center vlblBoardNameLabel%A_Index% backgroundtrans
		/*
		if (A_Index = 1)
			GuiControl, , lblBoardNameLabel%A_Index%, %lBoardMasterCover%
		else
			GuiControl, , lblBoardNameLabel%A_Index%, %lBoardBackupCover% #%A_Index%
		*/

		GuiControlGet, posBoard%A_Index%, Pos, picBoard%A_Index%
		if (A_Index > intNbBoardCreated)
			intNbBoardCreated := A_Index
	}
	else
		GuiControl, Show, picBoard%A_Index%
	
	intRow := intRow + 1
	intY := intY + intRowHeight
	intYPic := intY + 5
	intYNameLabel := intY + intPictureSize + 10
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
		GuiControl, Hide, picCoverButton%A_Index%%intIndex%
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
			Gui, Add, Picture, % "x" . (intXPic + intPictureSize) . " y" . (intYPic + (intButtonSize * (A_Index - 1))) . " w" . intButtonSize . " h" . intButtonSize . " 0xE vpicCoverButton" . A_Index . intIndex . " gCoverButtonClicked hidden"
			LoadPicControl(picCoverButton%A_Index%%intIndex%, (A_Index + 19))
		}
		Gui, Font, s8 w700, Arial
		Gui, Add, Text, x%intXPic% y%intYNameLabel% w%intPictureSize% h%intNameLabelHeight% center vlblNameLabel%A_Index% backgroundtrans
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
			GuiControl, Move, picCoverButton%A_Index%%intIndex%, % "x" . (intXPic + intPictureSize) . " y" . (intYPic + (intButtonSize * (A_Index - 1)))
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
Gosub, DisplayBoard
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


;------------------------------------------------------------
GuiSettings:
;------------------------------------------------------------

intGui1WinID := WinExist("A")
strPreviousSourceType := strSourceType
strPreviousSourceTypeSelection := strSourceSelection
blnPreviousOnlyNoCover := blnOnlyNoCover
blnPreviousListsWithNoCover := blnListsWithNoCover

; Build Gui header
Gui, 2:New, , % L(lSettingsGuiTitle, lAppName, lAppVersion)
Gui, 2:+Owner
Gui, 2:+OwnDialogs
Gui, 2:+Delimiter%strAlbumArtistDelimiter%

; Build options
Gui, 2:Add, Text, x10 y10, %lSettingsSource%
Gui, 2:Add, Radio, x+10 yp vradSourceITunes gClickedRadSource checked, %lSettingsSourceITunes%
Gui, 2:Add, Radio, x+10 yp vradSourceMP3 gClickedRadSource disabled, %lSettingsSourceMP3%

Gui, 2:Add, Text, x10 y30 w300 vlblSourceSelection, % (strSourceType = "iTunes" ? "Select the playlist" : "Select the root folder")
; MP3 Only
Gui, 2:Add, Edit, % "x10 y50 w220 vedtMP3Folder gSettingChanged " . (strSourceType = "iTunes" ? "hidden" : ""), %strSourceMP3Folder%
Gui, 2:Add, Button, % "x+10 yp vbtnMP3Folder " . (strSourceType = "iTunes" ? "hidden" : ""), %lSettingsButtonSelectFolder%
; iTunes Only
Gui, 2:Add, DropDownList, % "x10 y50 w300 vdrpITunesPlaylist gSettingChanged " . (strSourceType = "MP3" ? "hidden" : "")

Gui, 2:Add, Checkbox, % "x10 y+20 vchkOnlyNoCover gSettingChanged " . (blnOnlyNoCover ? "checked" : ""), %lOnlyNoCover%
Gui, 2:Add, Checkbox, % "x10 y+10 vchkListsWithNoCover gSettingChanged " . (blnListsWithNoCover ? "checked" : ""), %lListsWithNoCover%

; Build Gui footer
Gui, 2:Add, Button, x40 y+20 w100 gButtonDonate, %lDonateButton%
Gui, 2:Add, Button, x+60 yp w80 gButtonSettingsSave vbtnSettingsSave, %lSettingsClose%
GuiControl, 2:Focus, btnSettingsSave

Gosub, ClickedRadSource
Gui, 2:Show, AutoSize Center
Gui, 1:+Disabled

return
;------------------------------------------------------------


;------------------------------------------------------------
ClickedRadSource:
;------------------------------------------------------------
Gui, 2:Submit, NoHide
strSourceType := (radSourceITunes ? "iTunes" : "MP3")

if (strPreviousSourceType <> strSourceType)
{
	GuiControl, % (strSourceType = "MP3" ? "Show" : "Hide"), edtMP3Folder
	GuiControl, % (strSourceType = "MP3" ? "Show" : "Hide"), btnMP3Folder
	GuiControl, % (strSourceType = "iTunes" ? "Show" : "Hide"), drpITunesPlaylist
	GuiControl, 2:, lblSourceSelection, % (strSourceType = "iTunes" ? "Select the playlist" : "Select the root folder")
	GuiControl, 2:, btnSettingsSave, %lSettingsSave%
}
if (strSourceType = "iTunes")
{
	strITunesPlaylists := Cover_GetITunesPlaylist()
	StringReplace, strITunesPlaylists, strITunesPlaylists, %strSourceSelection%, %strSourceSelection%%strAlbumArtistDelimiter%
	GuiControl, 2:, drpITunesPlaylist, %strITunesPlaylists%
}

return
;------------------------------------------------------------


;------------------------------------------------------------
SettingChanged:
;------------------------------------------------------------
GuiControl, 2:, btnSettingsSave, %lSettingsSave%

return
;------------------------------------------------------------


;------------------------------------------------------------
ButtonSettingsSave:
;------------------------------------------------------------
Gui, 2:Submit, NoHide

blnOnlyNoCover := chkOnlyNoCover
blnListsWithNoCover := chkListsWithNoCover
strSourceSelection := drpITunesPlaylist

Gosub, 2GuiClose

return
;------------------------------------------------------------


;------------------------------------------------------------
ButtonDonate:
;------------------------------------------------------------
Run, https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=8UWKXDR5ZQNJW ; ### update Paypal code

return
; ------------------------------------------------


;------------------------------------------------------------
2GuiClose:
2GuiEscape:
;------------------------------------------------------------

Gui, 1:-Disabled
Gui, 2:Destroy
Gui, 1:Default ; REMEMBER!

WinActivate, ahk_id %intGui1WinID%

if (strPreviousSourceType <> strSourceType or strPreviousSourceTypeSelection <> strSourceSelection)
{
	IniWrite, %strSourceType%, %strIniFile%, Global, Source
	IniWrite, %strSourceSelection%, %strIniFile%, Global, SourceSelection
	Cover_ReleaseSource(strPreviousSourceType, strPreviousSourceTypeSelection)
	Gosub, InitSources
	Gosub, DisplayCovers ; initialize empty board
}

if (blnPreviousOnlyNoCover <> blnOnlyNoCover or blnPreviousListsWithNoCover <> blnListsWithNoCover)
{
	if (blnPreviousListsWithNoCover <> blnListsWithNoCover)
		Gosub, PopulateDropdownLists
	Gosub, DisplayCovers
}

return
;------------------------------------------------------------


;-----------------------------------------------------------
InitSources:
;-----------------------------------------------------------
Gui, Submit, NoHide

if !FileExist(A_ScriptDir . "\index\")
	FileCreateDir, % A_ScriptDir . "\index\"

if !FileExist(strCoversCacheFolder)
{
	FileCreateDir, %strCoversCacheFolder%
	if (ErrorLevel)
	{
		Oops(lCoverErrorCreatingTempFolder, strCoversCacheFolder, lAppName)
		ExitApp
	}
}

if (Cover_InitCoversSource(strSourceType))
{
	if FileExist(A_ScriptDir . "\index\" . strSourceType . "_" . strSourceSelection . "_" . strIndexFilenameExtension)
	{
		FileGetTime, strIndexDate, % A_ScriptDir . "\index\" . strSourceType . "_" . strSourceSelection . "_" . strIndexFilenameExtension, C
		FormatTime, strIndexDate, %strIndexDate%
		strAnswer := YesNoCancel(True, L(lLoadIndexTitle, lAppName), L(lLoadIndexPrompt, strSourceType . "_" . strSourceSelection . "_" . strIndexFilenameExtension, strIndexDate))
		if (strAnswer  = "Yes")
			Cover_LoadIndex() ; use saved index
		else if (strAnswer = "No")
		{
			FileDelete, %A_ScriptDir%\index\%strSourceType%_%strSourceSelection%_%strIndexFilenameExtension%
			Cover_BuildArtistsAlbumsIndex() ; refresh lists
		}
	}
	else
		Cover_BuildArtistsAlbumsIndex() ; have to refresh lists
	
	Gosub, PopulateDropdownLists
}
else
	Oops(lInitSourceError)

GuiControl, Enable, btnSettings

return
;-----------------------------------------------------------


;-----------------------------------------------------------
PopulateDropdownLists:
;-----------------------------------------------------------

Gosub, PopulateArtistsDropdownList
Gosub, PopulateAlbumsDropdownList

GuiControl, Choose, lstArtists, 1
GuiControl, Choose, lstAlbums, 1

return
;-----------------------------------------------------------


;-----------------------------------------------------------
PopulateArtistsDropdownList:
;-----------------------------------------------------------
Gui, Submit, NoHide

strArtistsDropDownList := strAlbumArtistDelimiter . A_Space . lDropDownAllArtists
for strArtist, strTracks in objArtistsIndex
	if (!blnListsWithNoCover) or Cover_ArtistOrAlbumHasNoCover(strTracks)
		strArtistsDropDownList := strArtistsDropDownList . strAlbumArtistDelimiter . strArtist
GuiControl, , lstArtists, %strArtistsDropDownList%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
PopulateAlbumsDropdownList:
;-----------------------------------------------------------
strAlbumsDropDownList := strAlbumArtistDelimiter . A_Space . lDropDownAllAlbums
for strAlbum, strTracks in objAlbumsIndex
	if (!blnListsWithNoCover) or Cover_ArtistOrAlbumHasNoCover(strTracks)
		strAlbumsDropDownList := strAlbumsDropDownList . strAlbumArtistDelimiter . strAlbum
GuiControl, , lstAlbums, %strAlbumsDropDownList%

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
Gdip_Shutdown(objGdiToken)
Cover_ReleaseSource(strSourceType, strSourceSelection)
if StrLen(strCoversCacheFolder)
	FileDelete, %strCoversCacheFolder%\*.*

ExitApp
;-----------------------------------------------------------


;-----------------------------------------------------------
ArtistsDropDownChanged:
;-----------------------------------------------------------
Gui, Submit, NoHide

strPreviousAlbum := lstAlbums
if (lstArtists = A_Space . lDropDownAllArtists)
	Gosub, PopulateAlbumsDropdownList
else
	GuiControl, , lstAlbums, % strAlbumArtistDelimiter . A_Space
		. lDropDownAllAlbums . strAlbumArtistDelimiter . objAlbumsOfArtistsIndex[lstArtists]

GuiControl, ChooseString, lstAlbums, %strPreviousAlbum%
Gosub, DisplayCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
AlbumsDropDownChanged:
;-----------------------------------------------------------
Gui, Submit, NoHide

strPreviousArtist := lstArtists
if (lstAlbums = A_Space . lDropDownAllAlbums)
	Gosub, PopulateArtistsDropdownList
else
	GuiControl, , lstArtists, % strAlbumArtistDelimiter . A_Space
		. lDropDownAllArtists . strAlbumArtistDelimiter . objArtistsOfAlbumsIndex[lstAlbums]

GuiControl, ChooseString, lstArtists, %strPreviousArtist%
Gosub, DisplayCovers

return
;-----------------------------------------------------------


;-----------------------------------------------------------
AlbumsWithNoCoverClicked:
;-----------------------------------------------------------

Gosub, PopulateDropdownLists

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ButtonSelectAllClicked:
;-----------------------------------------------------------

GuiControlGet, strButtonSelectAllLabel, , btnSelectAll

if (strButtonSelectAllLabel = lSelectAll)
{
	if (intNbPages > 1)
	{
		strAnswer := YesNoCancel(True, L(lSelectAllCoversTitle, lAppName), lSelectAllCoversAllPagesPrompt)
		if (strAnswer = "Cancel")
			return
	}

	Loop, %intNbTracks%
		if (strAnswer = "Yes") or (PageOfTrack(A_Index) = intPage)
			arrTrackSelected[A_Index] := true
}
else
	arrTrackSelected := Object() ; create array or release previous selections

GuiControl, , btnSelectAll, % (strButtonSelectAllLabel = lSelectAll ? lUnSelectAll : lSelectAll)
Gosub, DisplayCoversPage

return
;-----------------------------------------------------------


;-----------------------------------------------------------
ButtonDeleteSelectedClicked:
;-----------------------------------------------------------

strAnswer := YesNoCancel(False, L(lDeleteAllSelectedTitle, lAppName), lDeleteAllSelectedPrompt)

if (strAnswer <> "Yes")
	return

ProgressStart(1, lBoardPastingProgress, arrTrackSelected.MaxIndex())
for intThisTrack, blnSelected in arrTrackSelected
	if (blnSelected)
	{
		Cover_DeleteCoverFromTune(objCovers[intThisTrack])
		objCovers[intThisTrack].CoverTempFilePathName := ""
		arrTrackSelected[intThisTrack] := false
		objCovers[intThisTrack].ArtworkCount := Cover_GetArtworkCount(objCovers[intThisTrack])
		ProgressUpdate(1, intThisTrack, arrTrackSelected.MaxIndex(), lBoardPastingProgress)
	}
ProgressStop(1)
Gosub, DisplayCoversPage ; ### display only affected Covers?

return
;-----------------------------------------------------------


;-----------------------------------------------------------
LabelAllArtistsClicked:
;-----------------------------------------------------------

GuiControl, Choose, lstArtists, 1 
Gosub, ArtistsDropDownChanged

return
;-----------------------------------------------------------


;-----------------------------------------------------------
LabelAllAlbumsClicked:
;-----------------------------------------------------------

GuiControl, Choose, lstAlbums, 1 
Gosub, AlbumsDropDownChanged

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
objCovers := Object()

Gui, Submit, NoHide

if !(blnResizeInProgress)
	Gosub, DisableGui ; protect display cover from user clicks

intNbTracks := Cover_InitCoverScan(lstArtists, lstAlbums, blnOnlyNoCover) - 1 ; -1 because of the last comma in lists

; if (intNbTracks < 0)
;	return

loop, %intNbTracks%
{
	objNewCover := Cover_GetCover(A_Index)
	if objNewCover = -1
	{
		if !(blnResizeInProgress)
			Gosub, EnableGui
		if YesNoCancel(False, L(lITunesNeedReindexTitle, lAppName), lITunesNeedReindexPrompt) = "Yes"
		{
			FileDelete, %A_ScriptDir%\index\%strSourceType%_%strSourceSelection%_%strIndexFilenameExtension%
			Cover_BuildArtistsAlbumsIndex()
			Gosub, PopulateDropdownLists
		}
		return
	}

	objCovers.Insert(A_Index, objNewCover)
}

intPage := 1
intNbPages := Ceil(intNbTracks / intCoversPerPage)

arrTrackSelected := Object() ; create array or release previous selections
GuiControl, , btnSelectAll, %lSelectAll%

Gosub, DisplayCoversPage

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayCoversPage:
;-----------------------------------------------------------
Gui, Submit, NoHide

GuiControlGet, strLstFocused, Focus
if !(blnResizeInProgress)
	Gosub, DisableGui ; protect display cover from user clicks

intPosition := 0
intTrack := TrackAtPosition(intPosition)
intNbPages := Ceil(intNbTracks / intCoversPerPage) ; can change when resize

if (intNbTracks > 0) ; do not check for boolean because intNbTracks can be -1
	loop
	{
		intPosition := intPosition + 1
		intTrack := intTrack + 1
		
		gosub, DisplayCover
		
	} until (A_Index = intCoversPerPage) or (intTrack = intNbTracks)

intRemainingCovers := intCoversDisplayedPrevious - intPosition
intCoversDisplayedPrevious := intPosition

loop, %intRemainingCovers%
{
	intPosition := intPosition + 1
	LoadPicControl(picCover%intPosition%, 3)
	
	GuiControl, , lblNameLabel%intPosition%
	GuiControl, , lnkCoverLink%intPosition%
	GuiControl, Hide, lnkCoverLink%intPosition%
	GuiControl, Show, picCover%intPosition%
	loop, 4
		GuiControl, Hide, picCoverButton%A_Index%%intPosition%
}

GuiControl, Hide, btnPrevious
GuiControl, Hide, btnNext
GuiControl, % (intPage > 1 ? "Show" : "Hide"), btnPrevious
GuiControl, % (intTrack < intNbTracks ? "Show" : "Hide"), btnNext
if (intNbPages)
	GuiControl, , lblPage, % L(lPageFooter, intPage, intNbPages)

if !(blnResizeInProgress)
	Gosub, EnableGui
if InStr(strLstFocused, "ComboBox")
	GuiControl, Focus, %strLstFocused%
else
	GuiControl, Focus, lstArtists

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayCover:
; in: intPosition and intTrack
;-----------------------------------------------------------

if !StrLen(objCovers[intTrack].CoverTempFilePathName) or !FileExist(objCovers[intTrack].CoverTempFilePathName)
	Cover_GetImage(objCovers[intTrack])

blnNoCover := false
if (arrTrackSelected[intTrack])
	LoadPicControl(picCover%intPosition%, 5) ; Copy here
else if StrLen(objCovers[intTrack].CoverTempFilePathName)
	if FileExist(objCovers[intTrack].CoverTempFilePathName)
		LoadPicControl(picCover%intPosition%, 1, objCovers[intTrack].CoverTempFilePathName)
	else
	{
		blnNoCover := true
		LoadPicControl(picCover%intPosition%, 6) ; Error
	}
else
{
	blnNoCover := true
	LoadPicControl(picCover%intPosition%, 2) ; No cover
}

GuiControl, , lblNameLabel%intPosition%, % objCovers[intTrack].Name
	. (objCovers[intTrack].ArtworkCount > 1 ? " (" . objCovers[intTrack].ArtworkCount . ")" : "")
GuiControl, , lnkCoverLink%intPosition%, % ""
	. "<A ID=""Search1"">" . lCoverSearch . "1</A>"
	. "  <A ID=""Search2"">" . lCoverSearch . "2</A>"
	. (blnNoCover ? "" : "`n<A ID=""ShowPic"">" . lCoverShowPic . "</A>")
	. (blnNoCover ? "" : "  <A ID=""ViewPic"">" . lCoverViewPic . "</A>")
	. "  <A ID=""Listen"">" . lCoverListen . "</A>" . "`n"
	; . "TrackID: " . objCovers[intTrack].TrackIDHigh . "/" . objCovers[intTrack].TrackIDLow . "`n"
	; . "ArtworkCount/Kind: " . objCovers[intTrack].ArtworkCount . " / " . objCovers[intTrack].Kind . "`n"
	. lArtist . ": " . objCovers[intTrack].Artist . "`n"
	. lAlbum . ": " . objCovers[intTrack].Album . "`n"
	. "Duration: " . objCovers[intTrack].Time . "  Year: " . objCovers[intTrack].Year . "`n"
	. "Comment: " . objCovers[intTrack].Comment
	
GuiControl, % (blnNoCover ? "Show" : "Hide"), lnkCoverLink%intPosition%
GuiControl, % (blnNoCover ? "Hide" : "Show"), picCover%intPosition%
	

if (objCovers[intTrack].Kind <> 1)
{
	GuiControl, Show, picCoverButton1%intPosition%
	loop, 3
		GuiControl, Hide, % "picCoverButton" . (A_Index + 1) . intPosition
}
else
	loop, 4
		GuiControl, Show, picCoverButton%A_Index%%intPosition%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisableGui:
;-----------------------------------------------------------
Hotkey, Up, , On
Hotkey, Down, , On
Hotkey, Left, , On
Hotkey, Right, , On
Hotkey, PgUp, , On
Hotkey, PgDn, , On
Hotkey, Home, , On
Hotkey, End, , On

Gui, +Disabled

return
;-----------------------------------------------------------


;-----------------------------------------------------------
EnableGui:
;-----------------------------------------------------------
Gui, -Disabled

Hotkey, Up, , Off
Hotkey, Down, , Off
Hotkey, Left, , Off
Hotkey, Right, , Off
Hotkey, PgUp, , Off
Hotkey, PgDn, , Off
Hotkey, Home, , Off
Hotkey, End, , Off


return
;-----------------------------------------------------------


;-----------------------------------------------------------
LoadPicControl(ByRef picControl, intPicType, strFile := "")
; intPicType =
; 1 regular cover / 2 no cover / 3 fill cover / 4 empty board / 5 copy here / 6 error
; 10 make master board button / 11 load clipboard board button / 12 load file board button / 13 remove board button / 14 paste to selected board button 1
; 20 clip cover button / 21 select cover button / 22 paste cover button / 23 delete cover button
{
	global ptrBitmapNoCover, ptrBitmapFillCover, ptrBitmapEmptyBoard, ptrBitmapCopyHere, ptrBitmapError
		, ptrBitmapCoverButton1, ptrBitmapCoverButton2, ptrBitmapCoverButton3, ptrBitmapCoverButton4
		, ptrBitmapBoardButton1, ptrBitmapBoardButton2, ptrBitmapBoardButton3, ptrBitmapBoardButton4
		, ptrBitmapBoardButton0

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
		ptrBitmap := ptrBitmapError
	if (intPicType = 10)
		ptrBitmap := ptrBitmapBoardButton1
	if (intPicType = 11)
		ptrBitmap := ptrBitmapBoardButton2
	if (intPicType = 12)
		ptrBitmap := ptrBitmapBoardButton3
	if (intPicType = 13)
		ptrBitmap := ptrBitmapBoardButton4
	if (intPicType = 14)
		ptrBitmap := ptrBitmapBoardButton0
	if (intPicType = 20)
		ptrBitmap := ptrBitmapCoverButton1
	if (intPicType = 21)
		ptrBitmap := ptrBitmapCoverButton2
	if (intPicType = 22)
		ptrBitmap := ptrBitmapCoverButton3
	if (intPicType = 23)
		ptrBitmap := ptrBitmapCoverButton4
	
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
	intNewWidth := intNewWidth + 2
	intNewHeight := intNewHeight + 2

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
StringReplace, intThisPosition, A_GuiControl, picCover

if (intThisPosition <= intCoversDisplayedPrevious)
{
	GuiControl, Hide, %A_GuiControl%
	GuiControl, Show, lnkCoverLink%intThisPosition%
}

return
;-----------------------------------------------------------


;-----------------------------------------------------------
CoverButtonClicked:
;-----------------------------------------------------------

StringReplace, strControl, A_GuiControl, picCoverButton
intCommand := SubStr(strControl, 1, 1)
intPosition := SubStr(strControl, 2)
intTrack := TrackAtPosition(intPosition)

; The first command can be executed on any kind of track
if (intCommand = 1) ; Clip
{
	if StrLen(objCovers[intTrack].CoverTempFilePathName)
	{
		arrBoardPicFiles.Insert(1, objCovers[intTrack].CoverTempFilePathName)
		Gosub, DisplayBoard
	}
	return
}

; The following commands can only be executed on file track
if !(objCovers[intTrack].Kind)
{
	Oops(lCoverUnknownTrackKind, lAppName)
	return
}
if (objCovers[intTrack].Kind > 1)
{
	intKind := objCovers[intTrack].Kind
	Oops(lCoverUnsupportedTrackKind, arrTrackKinds%intKind%, lAppName)
	return
}

; Now, we know kind is 1 (File track)
if (intCommand = 2) ; Select
	arrTrackSelected[intTrack] := !arrTrackSelected[intTrack]
else if (intCommand = 3) ; Paste here
{
	blnGo := !(objCovers[intTrack].ArtworkCount)
	if !(blnGo)
		blnGo := (YesNoCancel(False, L(lCoverPasteMaster, lAppName), lCoverOverwrite) = "Yes")
	if (blnGo)
		Cover_SaveCoverToTune(objCovers[intTrack], arrBoardPicFiles[1])
}
else if (intCommand = 4) ; Delete
{
	blnGo := !(objCovers[intTrack].ArtworkCount)
	if !(blnGo)
		blnGo := (YesNoCancel(False, L(lCoverDeleteTitle, lAppName), lCoverDeletePrompt) = "Yes")
	if (blnGo)
		Cover_DeleteCoverFromTune(objCovers[intTrack])
}

if (intCommand >= 3)
{
	objCovers[intTrack].CoverTempFilePathName := ""
	arrTrackSelected[intTrack] := false
	objCovers[intTrack].ArtworkCount := Cover_GetArtworkCount(objCovers[intTrack])
}

Gosub, DisplayCover

return
;-----------------------------------------------------------


;-----------------------------------------------------------
CoverLinkClicked:
;-----------------------------------------------------------
strCommand := ErrorLevel
StringReplace, intPosition, A_GuiControl, lnkCoverLink
intTrack := TrackAtPosition(intPosition)

if Instr(strCommand, "Search")
{
	strArtist := objCovers[intTrack].Artist
	StringReplace, strArtist, strArtist, &, `%26, All
	if (strCommand = "Search1")
		StringReplace, strSearchURL, strSearchLink1, ~artist~, %strArtist%, All
	else
		StringReplace, strSearchURL, strSearchLink2, ~artist~, %strArtist%, All
	strAlbum := objCovers[intTrack].Album
	StringReplace, strAlbum, strAlbum, &, `%26, All
	StringReplace, strSearchURL, strSearchURL, ~album~, %strAlbum%, All
	StringReplace, strSearchURL, strSearchURL, %A_Space%, +, All
	StringReplace, strSearchURL, strSearchURL, `", `%22, All
}
if (strCommand = "ShowPic")
{
	GuiControl, Hide, %A_GuiControl%
	GuiControl, Show, picCover%intPosition%
}
else if (strCommand = "ViewPic")
{
	strFilename := objCovers[intTrack].CoverTempFilePathName
	if FileExist(strFilename)
		Run, %strFilename%
	else
		Oops(lCoverFileNotFound, strFilename)
}
else if (strCommand = "Listen")
	Cover_PLay(objCovers[intTrack])
else if InStr(strCommand, "Search")
	Run, %strSearchURL%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
DisplayBoard:
;-----------------------------------------------------------
loop, 4
	if (A_Index = 1)
		LoadPicControl(picBoardButton11, 14)
	else
		LoadPicControl(picBoardButton%A_Index%1, (A_Index + 9))

loop, %intMaxNbRow%
{
	if (A_Index <= arrBoardPicFiles.MaxIndex())
	{
		LoadPicControl(picBoard%A_Index%, 1, arrBoardPicFiles[A_Index])
		intIndex := A_Index
		loop, 4
			GuiControl, Show, % "picBoardButton" . A_Index . intIndex
		strBoardLink := ""
			. "<A ID=""ShowPic" . A_Index . """>" . lBoardShowPic . "</A>" . "  "
			. "<A ID=""ViewPic" . A_Index . """>" . lBoardViewPic . "</A>" . "  "
		GuiControl, , lnkBoardLink%A_Index%, %strBoardLink%
		intIndex := A_Index
		loop, 4
			GuiControl, Show, % "picBoardButton" . A_Index . intIndex
	}
	else
		LoadPicControl(picBoard%A_Index%, 4)

	if (A_Index = 1)
		GuiControl, , lblBoardNameLabel%A_Index%, %lBoardMasterCover%
	else
		GuiControl, , lblBoardNameLabel%A_Index%, %lBoardBackupCover% #%A_Index%

	GuiControl, Hide, lnkBoardLink%A_Index%
	GuiControl, Show, picBoard%A_Index%
	GuiControl, Show, lblBoardNameLabel%A_Index%
}

return
;-----------------------------------------------------------


;-----------------------------------------------------------
PicBoardClicked:
;-----------------------------------------------------------
StringReplace, intThisPosition, A_GuiControl, picBoard

GuiControl, Hide, %A_GuiControl%
GuiControl, Show, lnkBoardLink%intThisPosition%

return
;-----------------------------------------------------------


;-----------------------------------------------------------
BoardButtonClicked:
;-----------------------------------------------------------

StringReplace, strControl, A_GuiControl, picBoardButton
intCommand := SubStr(strControl, 1, 1)
intThisPosition := SubStr(strControl, 2)

if (intCommand = 1)
{
	if (intThisPosition = 1) ; paste to selected
	{
		if !StrLen(arrBoardPicFiles[1])
			return
		
		blnOnOtherPages := false
		blnExistingArtwork := false
		for intThisTrack, blnSelected in arrTrackSelected
			if (blnSelected)
			{
				if PageOfTrack(intThisTrack) <> intPage
					blnOnOtherPages := true
				if (objCovers[intThisTrack].ArtworkCount)
					blnExistingArtwork := true
			}

		if (blnOnOtherPages)
		{
			strAnswer := YesNoCancel(True, L(lBoardPastingSelected, lAppName), lBoardPasteAllPagesPrompt)
			if (strAnswer = "Cancel")
				return
			else
				blnOnOtherPages := (strAnswer = "Yes")
		}
		
		blnWriteOK := !(blnExistingArtwork)
			or (YesNoCancel(False, L(lBoardPastingSelected, lAppName), lBoardOverwrite) = "Yes")
	
		ProgressStart(1, lBoardPastingProgress, arrTrackSelected.MaxIndex())
		for intThisTrack, blnSelected in arrTrackSelected
			if (blnSelected)
			{
				if (PageOfTrack(intThisTrack) = intPage or blnOnOtherPages)
					if (!objCovers[intThisTrack].ArtworkCount or blnWriteOK)
					{
						Cover_SaveCoverToTune(objCovers[intThisTrack], arrBoardPicFiles[1])
						FileDelete, % objCovers[intThisTrack].CoverTempFilePathName
						arrTrackSelected[intThisTrack] := false
					}
				ProgressUpdate(1, intThisTrack, arrTrackSelected.MaxIndex(), lBoardPastingProgress)
			}
		ProgressStop(1)
		GuiControl, , btnSelectAll, %lSelectAll%
		Gosub, DisplayCoversPage ; ### display only affected Covers?
	}
	else ; make master
	{
		arrBoardPicFiles.Insert(1, arrBoardPicFiles[intThisPosition])
		arrBoardPicFiles.Remove(intThisPosition + 1)
	}
}
else if (intCommand = 2) ; load clipboard
{
	ptrBitmapClipbpard := Gdip_CreateBitmapFromClipboard()
	if (ptrBitmapClipbpard < 0)
	{
		DllCall("CloseClipboard")
		Oops(lInvalidClipboardContent)
		return
	}
	strLoadClipboardFilename := strCoversCacheFolder . Cover_GenerateGUID() . ".JPG" ; ### jpg best format? make it option?
	Gdip_SaveBitmapToFile(ptrBitmapClipbpard, strLoadClipboardFilename, 95) ; quality
	ptrBitmapClipbpard :=

	if StrLen(strLoadClipboardFilename)
		arrBoardPicFiles.Insert(intThisPosition, strLoadClipboardFilename)
}
else if (intCommand = 3) ; load file
{
	FileSelectFile, strLoadMasterFilename, , , %lBoardLoadFromFilePrompt%, % lImageFiles . " (*.jpg; *.jpeg; *.png; *.bmp; *.gif; *.tiff; *.tif; *.mp3; *.m4a)"
	SplitPath, strLoadMasterFilename, , , strExtension
	if StrLen(strLoadMasterFilename)
		if InStr("mp3 m4a", strExtension)
			Oops(lBoardTuneFilesNotSupported) ; ###
		else
			arrBoardPicFiles.Insert(intThisPosition, strLoadMasterFilename)
}
else if (intCommand = 4) ; remove
	arrBoardPicFiles.Remove(intThisPosition)

if !(intCommand = 1 and intThisPosition = 1)
	Gosub, DisplayBoard ; ### display only current Board

return
;-----------------------------------------------------------


;-----------------------------------------------------------
BoardLinkClicked:
;-----------------------------------------------------------
strCommand := ErrorLevel
StringReplace, intThisPosition, A_GuiControl, lnkBoardLink
StringReplace, strCommand, strCommand, %intThisPosition%

if (strCommand = "ShowPic")
{
	GuiControl, Hide, %A_GuiControl%
	GuiControl, Show, picBoard%intThisPosition%
	return
}
else if (strCommand = "ViewPic")
{
	strFilename := arrBoardPicFiles[intThisPosition]
	if StrLen(strFilename)
		if FileExist(strFilename)
			Run, %strFilename%
		else
			Oops(lCoverFileNotFound, strFilename)
	else
		Oops(lBoardNoCoverToView)
}

Gosub, DisplayBoard

return
;-----------------------------------------------------------


;-----------------------------------------------------------
TrackAtPosition(intThisPosition)
{
	global intPage, intCoversPerPage
	
	return ((intPage - 1) * intCoversPerPage) + intThisPosition
}
;-----------------------------------------------------------


;-----------------------------------------------------------
PositionOfTrack(intThisTrack)
{
	global intCoversPerPage

	intThisPosition := Mod(intThisTrack, intCoversPerPage)
	
	if intThisPosition
		return intThisPosition
	else
		return intCoversPerPage
}
;-----------------------------------------------------------


;-----------------------------------------------------------
PageOfTrack(intThisTrack)
{
	global intCoversPerPage

	return Ceil(intThisTrack / intCoversPerPage)
	
}
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
Check4Update: ; ### NEED TEST
; ------------------------------------------------
Gui, +OwnDialogs 
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
	Gui, +OwnDialogs
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
	Gui, +OwnDialogs
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


; ------------------------------------------------
ProgressStart(intType, strText, intMax := "")
; ------------------------------------------------
{
	StringReplace, strText, strText, ##, 0
	if (intType = 1)
		Progress, R0-%intMax% FS8 A, %strText%, , , MS Sans Serif
	else
		SB_SetText(strText, -intType)
}
; ------------------------------------------------


; ------------------------------------------------
ProgressUpdate(intType, intActual, intMax, strText)
; ------------------------------------------------
{
	StringReplace, strText, strText, ##, % Round(intActual*100/intMax)
	if (intType = 1)
		Progress, %intActual%, %strText%
	else
		SB_SetText(strText, -intType)
}
; ------------------------------------------------


; ------------------------------------------------
ProgressStop(intType)
; ------------------------------------------------
{
	if (intType = 1)
		Progress, Off
	else
		SB_SetText("", -intType)
}
; ------------------------------------------------
