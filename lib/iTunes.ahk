;===============================================
/*
	Library iTunes.ahk
	Used by MyTunesCovers.ahk
	By Jean Lalonde (JnLlnd on AHKScript.org forum)

*/
;===============================================

global intTestLimit := 100000
global intLinesPerBatch := 5000
global intNbLines2Save := 0
global objITunesunesApp := Object()
global objITunesPlaylists := Object()
global objITunesTracks := Object()
global arrTracks
global intTracksArrayIndex := 0
global strITunesIndexFilename


;-----------------------------------------------------------
iTunes_InitCoversSource()
{
	ToolTip, % L(lAppLaunchingiTunes, lAppname)
	objITunesunesApp := ComObjCreate("iTunes.Application")
	; Creates a COM object for the iTunes application (iTunes will be launched if not running)
	if !(objITunesunesApp.Sources.Count)
		return -1
	objITunesLibrary := objITunesunesApp.Sources.Item(1)
	; iTunes library (named "LIBRARY" in English, "BIBLIOTHÈQUE" in French) - source #1 is the main library
	objITunesPlaylists := objITunesLibrary.Playlists
	if (strSourceSelection = "ERROR" or !StrLen(strSourceSelection))
		strSourceSelection := objITunesPlaylists.Item(1).Name
		; iTunes main playlist (named "LIBRARY" in English, "BIBLIOTHÈQUE" in French) - playlist #1 is the library
	objITunesPlaylist := objITunesPlaylists.ItemByName(strSourceSelection)
	objITunesTracks := objITunesPlaylist.Tracks

	strITunesIndexFilename := A_ScriptDir . strIndexFolder . strSourceType . "_" . strSourceSelection . "_" . strIndexFilenameExtension
	ToolTip

	return objITunesTracks.Count
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_BuildArtistsAlbumsIndex()
{
	global strAlbumArtistDelimiter
	
	objArtistsIndex := Object()
	objAlbumsIndex := Object()
	objArtistsAlbumsIndex := Object()
	objAlbumsOfArtistsIndex := Object()
	objArtistsOfAlbumsIndex := Object()
	intNbLines2Save := 0

	ProgressStart(1, L(lProgressInitArtistsAlbums, 0, objITunesTracks.Count), objITunesTracks.Count)

	Loop, % objITunesTracks.Count ; around 75 sec./10k tracks to build 3 index for 27 k tracks
	{
		objITunesTrack := objITunesTracks.Item(A_Index)
		if !Mod(A_Index,100)
			ProgressUpdate(1, A_Index, objITunesTracks.Count, L(lProgressInitArtistsAlbums, A_Index, objITunesTracks.Count))

		intIDHigh := objITunesunesApp.ITObjectPersistentIDHigh(objITunesTrack)
		intIDLow := objITunesunesApp.ITObjectPersistentIDLow(objITunesTrack)
		intArtworkcount := objITunesTrack.Artwork.Count
		strTrackIDs := intIDHigh . ";" . intIDLow . ";" . intArtworkcount

		strArtist := Trim(objITunesTracks.Item(A_Index).Artist)
		if !StrLen(strArtist)
			strArtist := A_Space . lArtistUnknown
		StringReplace, strArtist, strArtist, %strAlbumArtistDelimiter%, _
		if !StrLen(objArtistsIndex[strArtist])
		{
			objArtistsIndex.Insert(strArtist, "")
			intNbLines2Save := intNbLines2Save + 1
		}
		objArtistsIndex[strArtist] := objArtistsIndex[strArtist] . strTrackIDs . ","
		; we will ignore the "," in surplus only if/when we will access the value

		strAlbum := Trim(objITunesTracks.Item(A_Index).Album)
		if !StrLen(strAlbum)
			strAlbum := lUnknown
		StringReplace, strAlbum, strAlbum, %strAlbumArtistDelimiter%, _
		if !StrLen(objAlbumsIndex[strAlbum])
		{
			objAlbumsIndex.Insert(strAlbum, "")
			intNbLines2Save := intNbLines2Save + 1
		}
		objAlbumsIndex[strAlbum] := objAlbumsIndex[strAlbum] . strTrackIDs . ","
		; we will ignore the "," in surplus only if/when we will access the value
		
		strArtistAlbum := strArtist . strAlbumArtistDelimiter . strAlbum
		if !StrLen(objArtistsAlbumsIndex[strArtistAlbum])
		{
			objArtistsAlbumsIndex.Insert(strArtistAlbum, "")
			intNbLines2Save := intNbLines2Save + 1
		}
		objArtistsAlbumsIndex[strArtistAlbum] := objArtistsAlbumsIndex[strArtistAlbum] . strTrackIDs . ","
		; we will ignore the "," in surplus only if/when we will access the value

		if !StrLen(objAlbumsOfArtistsIndex[strArtist])
		{
			objAlbumsOfArtistsIndex.Insert(strArtist, "")
			intNbLines2Save := intNbLines2Save + 1
		}
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

		if !StrLen(objArtistsOfAlbumsIndex[strAlbum])
		{
			objArtistsOfAlbumsIndex.Insert(strAlbum, "")
			intNbLines2Save := intNbLines2Save + 1
		}
		blnArtistFound := False
		strTempArtistList := objArtistsOfAlbumsIndex[strAlbum]
		Loop, Parse, strTempArtistList, %strAlbumArtistDelimiter%
			if (A_LoopField = strArtist)
			{
				blnArtistFound := True
				break
			}
		if (!blnArtistFound)
			objArtistsOfAlbumsIndex[strAlbum] := objArtistsOfAlbumsIndex[strAlbum] . strArtist . strAlbumArtistDelimiter
			; we will ignore the strAlbumArtistDelimiter in surplus only if/when we will access the value

		if (A_Index = intTestLimit)
			break
	}

	ProgressUpdate(1, objITunesTracks.Count, objITunesTracks.Count, L(lProgressInitArtistsAlbums, objITunesTracks.Count, objITunesTracks.Count))
	ProgressStop(1)

	return true

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
iTunes_LoadIndex()
{
	Loop, Read, %strITunesIndexFilename%
	{
		if (A_Index = 1)
		{
			objArtistsIndex := Object()
			objAlbumsIndex := Object()
			objArtistsAlbumsIndex := Object()
			objAlbumsOfArtistsIndex := Object()
			objArtistsOfAlbumsIndex := Object()
		}
		arrRecord := StrSplit(A_LoopReadLine, "`t")
		strObjName := arrRecord[1]
		%strObjName%.Insert(arrRecord[2], arrRecord[3])
    }
	return true
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_InitCoverScan(strArtist := "", strAlbum := "", blnOnlyNoCover := false)
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

	if (blnOnlyNoCover)
	{
		intCurrentTrackIndex := 1
		loop, % arrTracks.MaxIndex() - 1 ; last item always empty
		{
			arrTrackIDs := StrSplit(arrTracks[intCurrentTrackIndex], ";") ; "intIDHigh ; intIDLow ; intArtworkCount"
			objTrack := objITunesTracks.ItemByPersistentID(arrTrackIDs[1], arrTrackIDs[2])
			if (objTrack.Artwork.Count) ; do not use arrTrackIDs[3] because we want most up-to-date info
				arrTracks.Remove(intCurrentTrackIndex)
			else
				intCurrentTrackIndex := intCurrentTrackIndex + 1
		}
	}

	intTracksArrayIndex := 0
	/*
	for k, v in arrTracks
		###_D("k: " . k . " / v: " . v)
	*/

	return arrTracks.MaxIndex()
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_GetCover(intTrackIndex)
{
	if (arrTracks.MaxIndex() = "" ; if arrTracks has no items, it returns an empty string
		or intTrackIndex => arrTracks.MaxIndex()) ; the last item if the array is always empty
		return false

	; ###_D("arrTracks[" . intTrackIndex . "]: " . arrTracks[intTrackIndex])
	; objTrack := objITunesTracks.Item(arrTracks[intTrackIndex])

	arrTrackIDs := StrSplit(arrTracks[intTrackIndex], ";") ; "intIDHigh ; intIDLow ; intArtworkCount"
	objTrack := objITunesTracks.ItemByPersistentID(arrTrackIDs[1], arrTrackIDs[2])

	if !StrLen(objTrack.Name)
		return -1

	objThisCover := New Cover()
	
	; ###_D("objTrack.Kind: " . , objTrack.Kind)
	objThisCover.SetCoverProperties(objTrack.Artist, objTrack.Album, objTrack.Name, objTrack.Index, arrTrackIDs[1], arrTrackIDs[2], objTrack.Artwork.Count, objTrack.Kind, objTrack.Time, objTrack.Year, objTrack.Comment)
	; ###_D("objThisCover.Index: " . objThisCover.Index)

	return objThisCover
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_GetImage(objThisCover)
{
	objTrack := objITunesTracks.ItemByPersistentID(objThisCover.TrackIDHigh, objThisCover.TrackIDLow)

	strCoverFile := iTunes_GetTempImageFile(objTrack, objThisCover.GUID)
	objThisCover.SetCoverTempFile(strCoverFile)
	; ###_D("objThisCover.CoverTempFilePathName: " . objThisCover.CoverTempFilePathName)

	return strCoverFile
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_GetArtworkCount(objThisCover)
{
	objTrack := objITunesTracks.ItemByPersistentID(objThisCover.TrackIDHigh, objThisCover.TrackIDLow)

	return objTrack.Artwork.Count
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_ArtistOrAlbumHasNoCover(strTracks)
{
	arrTracks := StrSplit(strTracks, ",")

	iTunes_ArtistOrAlbumHasNoCover := true
	loop
	{
		arrTrackIDs := StrSplit(arrTracks[A_Index], ";") ; "intIDHigh ; intIDLow ; intArtworkCount"
		if (!arrTrackIDs[3])
			break
		if (A_Index = arrTracks.MaxIndex() - 1) ; last item always empty
		{
			iTunes_ArtistOrAlbumHasNoCover := false
			break
		}
	}
	
	return iTunes_ArtistOrAlbumHasNoCover
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_ReleaseSource()
{
	ptrObjITunesunesApp := Object(objITunesunesApp)
	ObjRelease(ptrObjITunesunesApp)
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_SaveIndex(strSource, strIndexFolder, strSelection)
{
	ProgressStart(1, L(lProgressSavingIndex, 0), intNbLines2Save)

	strFilename := A_ScriptDir . strIndexFolder . strSource . "_" . strSelection . "_" . strIndexFilenameExtension
	FileDelete, %strFilename%
	intLines := 0

	strData := "Index`tKey`tValue`n"
	for strArtist, strTracks in objArtistsIndex
	{
		intLines := intLines + 1
		if !Mod(intLines,100)
			ProgressUpdate(1, intLines, intNbLines2Save, L(lProgressSavingIndex, Round(intLines / intNbLines2Save * 100, 0)))
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData, strFilename)
			strData := ""
		}
		strData := strData . "objArtistsIndex`t" . strArtist . "`t" . strTracks . "`n"
	}

	; TrayTip, % L(lliTunesSavingIndexTitle, lAppName), %liTunesSavingIndex2%
	for strAlbum, strTracks in objAlbumsIndex
	{
		intLines := intLines + 1
		if !Mod(intLines,100)
			ProgressUpdate(1, intLines, intNbLines2Save, L(lProgressSavingIndex, Round(intLines / intNbLines2Save * 100, 0)))
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData, strFilename)
			strData := ""
		}
		strData := strData . "objAlbumsIndex`t" . strAlbum . "`t" . strTracks . "`n"
	}
	
	; TrayTip, % L(lliTunesSavingIndexTitle, lAppName), %liTunesSavingIndex3%
	for strArtistAlbum, strTracks in objArtistsAlbumsIndex
	{
		intLines := intLines + 1
		if !Mod(intLines,100)
			ProgressUpdate(1, intLines, intNbLines2Save, L(lProgressSavingIndex, Round(intLines / intNbLines2Save * 100, 0)))
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData, strFilename)
			strData := ""
		}
		strData := strData . "objArtistsAlbumsIndex`t" . strArtistAlbum . "`t" . strTracks . "`n"
	}

	; TrayTip, % L(lliTunesSavingIndexTitle, lAppName), %liTunesSavingIndex4%
	for strArtist, strAlbums in objAlbumsOfArtistsIndex
	{
		intLines := intLines + 1
		if !Mod(intLines,100)
			ProgressUpdate(1, intLines, intNbLines2Save, L(lProgressSavingIndex, Round(intLines / intNbLines2Save * 100, 0)))
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData, strFilename)
			strData := ""
		}
		strData := strData . "objAlbumsOfArtistsIndex`t" . strArtist . "`t" . strAlbums . "`n"
	}

	; TrayTip, % L(lliTunesSavingIndexTitle, lAppName), %liTunesSavingIndex4%
	for strAlbum, strArtists in objArtistsOfAlbumsIndex
	{
		intLines := intLines + 1
		if !Mod(intLines,100)
			ProgressUpdate(1, intLines, intNbLines2Save, L(lProgressSavingIndex, Round(intLines / intNbLines2Save * 100, 0)))
		if !Mod(intLines, intLinesPerBatch)
		{
			SaveBatch(strData, strFilename)
			strData := ""
		}
		strData := strData . "objArtistsOfAlbumsIndex`t" . strAlbum . "`t" . strArtists . "`n"
	}

	ProgressUpdate(1, intNbLines2Save, intNbLines2Save, L(lProgressInitArtistsAlbums, 100))
	
	SaveBatch(strData, strFilename)
	
	ProgressStop(1)
	TrayTip
}
;-----------------------------------------------------------


;-----------------------------------------------------------
SaveBatch(strData, strFilename)
{
	loop
	{
		FileAppend, %strData%, %strFilename%
		if ErrorLevel
			Sleep, 20
	}
	until !ErrorLevel or (A_Index > 50) ; after 1 second (20ms x 50), we have a problem
	
	if (ErrorLevel)
		Oops(lErrorWritingIndexFile, strITunesIndexFilename)
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
			strExtension := "jpg"
		else if (objArtwork.Format = 2)
			strExtension := "png"
		else if (objArtwork.Format = 3)
			strExtension := "bmp"
		else
			strExtension := ""
		strPathNameExt := strPathNameNoext . "." . strExtension
		objArtwork.SaveArtworkToFile(strPathNameExt)
		return %strPathNameExt%
	}
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_SaveCoverToTune(ByRef objThisCover, strFile)
{
	objTrack := objITunesTracks.ItemByPersistentID(objThisCover.TrackIDHigh, objThisCover.TrackIDLow)
	if (objTrack.Artwork.Count)
	{
		objArtwork := objTrack.Artwork.Item(1)
		strResult := objArtwork.SetArtworkFromFile(strFile)
	}
	else
		strResult := objTrack.AddArtworkFromFile(strFile)
	
	; strResult is always empty even when errors occur
	return true
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_DeleteCoverFromTune(ByRef objThisCover)
{
	objTrack := objITunesTracks.ItemByPersistentID(objThisCover.TrackIDHigh, objThisCover.TrackIDLow)
	if (objTrack.Artwork.Count)
	{
		; ###_D(objTrack.Artwork.Count .  " delete 1")
		objArtwork := objTrack.Artwork.Item(1)
		strResult := objArtwork.Delete()
	}
	return true
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_Play(objThisCover)
{
	objTrack := objITunesTracks.ItemByPersistentID(objThisCover.TrackIDHigh, objThisCover.TrackIDLow)
	objTrack.Play
	
	return true
}
;-----------------------------------------------------------


;-----------------------------------------------------------
iTunes_GetITunesPlaylist()
;-----------------------------------------------------------
{
	global strAlbumArtistDelimiter
	global strSourceSelection
	
	strPlaylists := ""
	loop, % objITunesPlaylists.Count
		strPlaylists := strPlaylists . strAlbumArtistDelimiter . objITunesPlaylists.Item(A_Index).Name

	return strPlaylists
}
;-----------------------------------------------------------
