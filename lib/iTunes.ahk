;===============================================
/*
	Library iTunes.ahk
	Used by MyTunesCovers.ahk
	By Jean Lalonde (JnLlnd on AHKScript.org forum)

*/
;===============================================

global intTestLimit := 3000
global intLinesPerBatch := 5000
global objITunesunesApp := Object()
global objITunesTracks := Object()
global objITunesSourceIDs := Object()
global arrTracks
global intTracksArrayIndex := 0
global intSourceID := -1
global intPlaylistID := -1
global strITunesCacheFilename := "iTunes_" . strSourceCacheFilenameExtension


;-----------------------------------------------------------
iTunes_InitCoversSource()
{
	objITunesunesApp := ComObjCreate("iTunes.Application")
	; Creates a COM object for the iTunes application (iTunes will be launched if not running)
	objITunesLibrary := objITunesunesApp.Sources.Item(1)
	; iTunes library (named "LIBRARY" in English, "BIBLIOTHÈQUE" in French) - source #1 is the main library
	objITunesPlaylist := objITunesLibrary.Playlists.Item(1)
	; iTunes main playlist (named "LIBRARY" in English, "BIBLIOTHÈQUE" in French) - playlist #1 is the library
	objITunesTracks := objITunesPlaylist.Tracks

	intSourceID := objITunesLibrary.sourceID
	intPlaylistID := objITunesPlaylist.PlaylistID
	objITunesSourceIDs.Insert("intSourceID", intSourceID)
	objITunesSourceIDs.Insert("intPlaylistID", intPlaylistID)
	
	return objITunesTracks.Count
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_InitArtistsAlbumsIndex()
{
	global strAlbumArtistDelimiter
	
	Loop, % objITunesTracks.Count ; around 75 sec./10k tracks to build 3 index for 27 k tracks
	{
		objITunesTrack := objITunesTracks.Item(A_Index)
		if !Mod(A_Index,100)
			TrayTip, , % A_Index . " / " . objITunesTracks.Count

		strTrackIDs := objITunesTrack.TrackID . ";" . objITunesTrack.TrackDatabaseID

		strArtist := Trim(objITunesTracks.Item(A_Index).Artist)
		if !StrLen(strArtist)
			strArtist := A_Space . lArtistUnknown
		StringReplace, strArtist, strArtist, %strAlbumArtistDelimiter%, _
		if !StrLen(objArtistsIndex[strArtist])
			objArtistsIndex.Insert(strArtist, "")
		objArtistsIndex[strArtist] := objArtistsIndex[strArtist] . strTrackIDs . ","
		; we will ignore the "," in surplus only if/when we will access the value

		strAlbum := Trim(objITunesTracks.Item(A_Index).Album)
		if !StrLen(strAlbum)
			strAlbum := lUnknown
		StringReplace, strAlbum, strAlbum, %strAlbumArtistDelimiter%, _
		if !StrLen(objAlbumsIndex[strAlbum])
			objAlbumsIndex.Insert(strAlbum, "")
		objAlbumsIndex[strAlbum] := objAlbumsIndex[strAlbum] . strTrackIDs . ","
		; we will ignore the "," in surplus only if/when we will access the value
		
		strArtistAlbum := strArtist . strAlbumArtistDelimiter . strAlbum
		if !StrLen(objArtistsAlbumsIndex[strArtistAlbum])
			objArtistsAlbumsIndex.Insert(strArtistAlbum, "")
		objArtistsAlbumsIndex[strArtistAlbum] := objArtistsAlbumsIndex[strArtistAlbum] . strTrackIDs . ","
		; we will ignore the "," in surplus only if/when we will access the value

		if !StrLen(objAlbumsOfArtistsIndex[strArtist])
			objAlbumsOfArtistsIndex.Insert(strArtist, "")
		blnAlbumFound := False
		strTempAlbumList := objAlbumsOfArtistsIndex[strArtist]
		Loop, Parse, strTempAlbumList, %strAlbumArtistDelimiter%
			if (A_LoopField = strAlbum)
			{
				blnAlbumFound := True
				break
			}
		if (!blnAlbumFound)
			objAlbumsOfArtistsIndex[strArtist] := objAlbumsOfArtistsIndex[strArtist] . strAlbum . strAlbumArtistDelimiter
			; we will ignore the strAlbumArtistDelimiter in surplus only if/when we will access the value

		if (A_Index = intTestLimit)
			break
	}
	
	/*
	for strArtist, strTracks in objArtistsIndex
	{
		s := strArtist . "`n"
		loop, parse, strTracks, `,
			if StrLen(A_LoopField)
				s := s . "`n" . objITunesTracks.Item(A_LoopField).Name
		###_D(s)
	}
	for strAlbum, strTracks in objAlbumsIndex
	{
		s := strAlbum . "`n"
		loop, parse, strTracks, `,
			if StrLen(A_LoopField)
				s := s . "`n" . objITunesTracks.Item(A_LoopField).Name
		###_D(s)
	}
	for strArtistAlbum, strTracks in objArtistsAlbumsIndex
	{
		s := strArtistAlbum . "`n"
		loop, parse, strTracks, `,
			if StrLen(A_LoopField)
				s := s . "`n" . objITunesTracks.Item(A_LoopField).Name
		###_D(s)
	}
	*/
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_LoadSource()
{
	Loop, Read, %A_ScriptDir%\%strITunesCacheFilename%
	{
		if (A_Index = 1)
		{
			objArtistsIndex := Object()
			objAlbumsIndex := Object()
			objArtistsAlbumsIndex := Object()
			objAlbumsOfArtistsIndex := Object()
		}
		if !Mod(A_Index, intLinesPerBatch)
			TrayTip, % L(lliTunesSavingSourceIndexTitle, lAppName), % L(lliTunesSavingSourceIndexProgress, A_Index)
		arrRecord := StrSplit(A_LoopReadLine, "`t")
		strObjName := arrRecord[1]
		%strObjName%.Insert(arrRecord[2], arrRecord[3])
    }
	TrayTip
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_InitCoverScan(strArtist := "", strAlbum := "")
{
	global strAlbumArtistDelimiter

	if (strArtist = A_Space . lDropDownAllArtists)
		strArtist := ""
	if (strAlbum = A_Space . lDropDownAllAlbums)
		strAlbum := ""

	; ###_D("objArtistsIndex[" . strArtist . "] : " . objArtistsIndex[strArtist])
	if (StrLen(strArtist) > 0) and (StrLen(strAlbum) > 0)
		arrTracks := StrSplit(objArtistsAlbumsIndex[strArtist . strAlbumArtistDelimiter . strAlbum], ",")
	else if StrLen(strArtist)
		arrTracks := StrSplit(objArtistsIndex[strArtist], ",")
	else if StrLen(strAlbum)
		arrTracks := StrSplit(objAlbumsIndex[strAlbum], ",")
	else
		return 0

	intTracksArrayIndex := 0
	/*
	for k, v in arrTracks
		###_D("k: " . k . " / v: " . v)
	*/

	return arrTracks.MaxIndex()
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_GetCover(ByRef objThisCover, intTrackIndex)
{
	if (arrTracks.MaxIndex() = "" ; if arrTracks has no items, it returns an empty string
		or intTracksArrayIndex => arrTracks.MaxIndex()) ; the last item if the array is always empty
		return false

	objThisCover := New Cover()
	; ###_D("arrTracks[" . intTrackIndex . "]: " . arrTracks[intTrackIndex])
	; objTrack := objITunesTracks.Item(arrTracks[intTrackIndex])

	arrTrackIDs := StrSplit(arrTracks[intTrackIndex], ";") ; "TrackID ; DatabaseID"
	; ###_D(intSourceID . " " . intPlaylistID . " " . arrTrackIDs[1] . " " . arrTrackIDs[2])
	objTrack := objITunesunesApp.GetITObjectByID(intSourceID, intPlaylistID, arrTrackIDs[1], arrTrackIDs[2]) ; intTrackID, intDatabaseID
	if !StrLen(objTrack.Name)
		###_D("objTrack.Name empty. Need to recache the library?")

	strCoverFile := iTunes_GetTempImageFile(objTrack, objThisCover.GUID)
	objThisCover.SetCoverTempFile(strCoverFile)
	; ###_D("objThisCover.CoverTempFilePathName: " . objThisCover.CoverTempFilePathName)

	; ###_D("objTrack.Index: " . objTrack.Index)
	objThisCover.SetCoverProperties(objTrack.Artist, objTrack.Album, objTrack.Name, objTrack.Index, objTrack.TrackID, objTrack.TrackDatabaseID, objTrack.Artwork.Count)
	; ###_D("objThisCover.Index: " . objThisCover.Index)

	return true
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_ReleaseSource() ; NOT USED
{
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_SaveSource()
{
	FileDelete, %A_ScriptDir%\%strITunesCacheFilename%
	intLines := 0
	
	strData := "Index`tKey`tValue`n"
	for strIDType, strIDValue in objITunesSourceIDs
		strData := strData . "objITunesSourceIDs`t" . strIDType . "`t" . strIDValue . "`n"

	TrayTip, % L(lliTunesSavingSourceIndexTitle, lAppName), %liTunesSavingSourceIndex1%
	for strArtist, strTracks in objArtistsIndex
	{
		intLines := intLine + 1
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData)
			strData := ""
		}
		strData := strData . "objArtistsIndex`t" . strArtist . "`t" . strTracks . "`n"
	}

	TrayTip, % L(lliTunesSavingSourceIndexTitle, lAppName), %liTunesSavingSourceIndex2%
	for strAlbum, strTracks in objAlbumsIndex
	{
		intLines := intLine + 1
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData)
			strData := ""
		}
		strData := strData . "objAlbumsIndex`t" . strAlbum . "`t" . strTracks . "`n"
	}
	
	TrayTip, % L(lliTunesSavingSourceIndexTitle, lAppName), %liTunesSavingSourceIndex3%
	for strArtistAlbum, strTracks in objArtistsAlbumsIndex
	{
		intLines := intLine + 1
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData)
			strData := ""
		}
		strData := strData . "objArtistsAlbumsIndex`t" . strArtistAlbum . "`t" . strTracks . "`n"
	}

	TrayTip, % L(lliTunesSavingSourceIndexTitle, lAppName), %liTunesSavingSourceIndex4%
	for strArtist, strAlbums in objAlbumsOfArtistsIndex
	{
		intLines := intLine + 1
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData)
			strData := ""
		}
		strData := strData . "objAlbumsOfArtistsIndex`t" . strArtist . "`t" . strAlbums . "`n"
	}

	SaveBatch(strData)
	TrayTip
}
;-----------------------------------------------------------


;-----------------------------------------------------------
SaveBatch(strData)
{
	loop
	{
		FileAppend, %strData%,  %A_ScriptDir%\%strITunesCacheFilename%
		if ErrorLevel
			Sleep, 20
	}
	until !ErrorLevel or (A_Index > 50) ; after 1 second (20ms x 50), we have a problem
	
	if (ErrorLevel)
		Oops("Error writing" . A_ScriptDir "\" . strITunesCacheFilename)
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_GetTempImageFile(objTrack, strNameNoext)
{
	global strCoversCacheFolder
	
	; ###_D("objTrack.Artwork.Count: " . objTrack.Artwork.Count)
	if !(objTrack.Artwork.Count)
		return
	else
	{
		objArtwork := objTrack.Artwork.Item(1)
		/*
		TrayTip, % "Track Index: " . objTrack.index
			, % "Artwork: " . 1 . "/" . objTrack.Artwork.Count . "`n"
			. "Format: " . objArtwork.Format  . "`n"
			. "IsDownloadedArtwork: " . objArtwork.IsDownloadedArtwork  . "`n"
			. "Description: " . objArtwork.Description
		*/
		strPathNameNoext := strCoversCacheFolder . strNameNoext
		if (objArtwork.Format = 1)
			strExtension := "bmp"
		else if (objArtwork.Format = 2)
			strExtension := "jpg"
		else if (objArtwork.Format = 4)
			strExtension := "gif"
		else if (objArtwork.Format = 5)
			strExtension := "png"
		else
			strExtension := ""
		strPathNameExt := strPathNameNoext . "." . strExtension
		objArtwork.SaveArtworkToFile(strPathNameExt)
		return %strPathNameExt%
	}
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_SetImageFile(intIndex, strFile)
{
	; ###_D("SetImageFile index: " . intIndex . "`nCount" . objITunesTracks.Count)
	objTrack := objITunesTracks.Item(intIndex)
	; ###_D("Name: " . objTrack.Name)
	
	objArtwork := objTrack.Artwork.Item(1)
	strResult := objArtwork.SetArtworkFromFile(strFile)   

	return %strResult%
}
;-----------------------------------------------------------
