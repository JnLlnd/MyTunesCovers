global objITunesTracks := Object()
global objArtistsIndex := Object()
global objAlbumsIndex := Object()
global objArtistsAlbumsIndex := Object()
global objAlbumsOfArtistsIndex := Object()
global arrTracks
global intTracksArrayIndex

;-----------------------------------------------------------
InitCoversSource()
{
	objITunesunesApp := ComObjCreate("iTunes.Application")
	; Creates a COM object for the iTunes application (iTunes will be launched if not running)
	objITunesLibrary := objITunesunesApp.Sources.Item(1)
	; iTunes library (named "LIBRARY" in English, "BIBLIOTHÈQUE" in French) - source #1 is the main library
	objITunesPlaylist := objITunesLibrary.Playlists.Item(1)
	; iTunes main playlist (named "LIBRARY" in English, "BIBLIOTHÈQUE" in French) - playlist #1 is the library
	objITunesTracks := objITunesPlaylist.Tracks

 /*
	objTrack := objITunesTracks.Item(1)
	###_D("TrackDatabaseID: " . objTrack.TrackDatabaseID)
	###_D("SourceID: " . objTrack.SourceID)
	###_D("PlaylistID: " . objTrack.PlaylistID)
	###_D("TrackID: " . objTrack.TrackID)
	; IiTunes::ITObjectPersistentIDHigh() and IiTunes::ITObjectPersistentIDLow() properties -> DOES NOT WORK
*/
}
;-----------------------------------------------------------


;-----------------------------------------------------------
InitArtistsAlbumsIndex()
{
	global strAlbumArtistDelimiter
	
	Loop, % objITunesTracks.Count ; around 75 sec./10k tracks to build 3 index for 27 k tracks
	{
		objITunesTrack := objITunesTracks.Item(A_Index)
		if !Mod(A_Index,100)
			TrayTip, , % A_Index . " / " . objITunesTracks.Count

		strArtist := objITunesTracks.Item(A_Index).Artist
		if !StrLen(strArtist)
			continue
		StringReplace, strArtist, strArtist, %strAlbumArtistDelimiter%, -
		if !StrLen(objArtistsIndex[strArtist])
			objArtistsIndex.Insert(strArtist, "")
		objArtistsIndex[strArtist] := objArtistsIndex[strArtist] . objITunesTrack.Index . ","
		; we will strip the "," in surplus only if/when we access the value
		
		strAlbum := objITunesTracks.Item(A_Index).Album
		if !StrLen(strAlbum)
			strAlbum := "-"
		StringReplace, strAlbum, strAlbum, %strAlbumArtistDelimiter%, -
		if !StrLen(objAlbumsIndex[strAlbum])
			objAlbumsIndex.Insert(strAlbum, "")
		objAlbumsIndex[strAlbum] := objAlbumsIndex[strAlbum] . objITunesTrack.Index . ","
		; we will strip the "," in surplus only if/when we access the value
		
		strArtistAlbum := strArtist . strAlbumArtistDelimiter . strAlbum
		if !StrLen(objArtistsAlbumsIndex[strArtistAlbum])
			objArtistsAlbumsIndex.Insert(strArtistAlbum, "")
		objArtistsAlbumsIndex[strArtistAlbum] := objArtistsAlbumsIndex[strArtistAlbum] . objITunesTrack.Index . ","
		; we will strip the "," in surplus only if/when we access the value

		if !StrLen(objAlbumsOfArtistsIndex[strArtist])
			objAlbumsOfArtistsIndex.Insert(strArtist)
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
			; we will strip the strAlbumArtistDelimiter in surplus only if/when we access the value

		if (A_Index = 2000)
			break
	}
	
	/*
	for strAlbum, strTracks in objAlbumsIndex
	{
		s := strAlbum . "`n"
		loop, parse, strTracks, `,
			if StrLen(A_LoopField)
				s := s . "`n" . objITunesTracks.Item(A_LoopField).Name
		###_D(s)
	}
	for strArtist, strTracks in objArtistsIndex
	{
		s := strArtist . "`n"
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
AddAlbumToArtistIndex(strArtist := "", strAlbum := "")
{
}
;-----------------------------------------------------------


;-----------------------------------------------------------
InitCoverScan(strArtist := "", strAlbum := "")
{
	global strAlbumArtistDelimiter
	
	if (strArtist = lDropDownAllArtists)
		strArtist := ""
	if (strAlbum = lDropDownAllAlbums)
		strAlbum := ""

	if (StrLen(strArtist) > 0) and (StrLen(strAlbum) > 0)
		arrTracks := StrSplit(objArtistsAlbumsIndex[strArtist . strAlbumArtistDelimiter . strAlbum], ",")
	else if StrLen(strArtist)
		arrTracks := StrSplit(objArtistsIndex[strArtist], ",")
	else if StrLen(strAlbum)
		arrTracks := StrSplit(objAlbumsIndex[strAlbum], ",")
	else
		return 0
	intTracksArrayIndex := 0

	return arrTracks.MaxIndex()
}
;-----------------------------------------------------------


;-----------------------------------------------------------
NextCover()
{
	intTracksArrayIndex := intTracksArrayIndex + 1
	if (intTracksArrayIndex = arrTracks.MaxIndex()) ; the last item if the array is always empty
		return 0
	objThisCover := New Cover()
	; ###_D(arrTracks[intTracksArrayIndex])
	objTrack := objITunesTracks.Item(arrTracks[intTracksArrayIndex])
	strCoverFile := GetTempImageFile(objTrack, objThisCover.GUID)
	objThisCover.SetCoverTempFile(strCoverFile)

	objThisCover.SetCoverProperties(objTrack.Name, objTrack.Artist, objTrack.Album, objTrack.Index, objTrack.TrackID, objTrack.TrackDatabaseID)

	return objThisCover
}
;-----------------------------------------------------------


;-----------------------------------------------------------
GetTempImageFile(objTrack, strNameNoext)
{
	global strCoversCacheFolder
	
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
SetImageFile(intIndex, strFile)
{
	; ###_D("SetImageFile index: " . intIndex . "`nCount" . objITunesTracks.Count)
	objTrack := objITunesTracks.Item(intIndex)
	###_D("Name: " . objTrack.Name)
	
	objArtwork := objTrack.Artwork.Item(1)
	strResult := objArtwork.SetArtworkFromFile(strFile)   

	return %strResult%
}
;-----------------------------------------------------------
