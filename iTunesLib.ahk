global objITunesTracks := Object()
global objArtistsIndex := Object()
global objAlbumsIndex := Object()
global objArtistsAlbumsIndex := Object()
global arrTracks
global intTracksArrayIndex

;-----------------------------------------------------------
InitCoversSource()
{
	; Creates a COM object for the iTunes application (iTunes will be launched if not running)
	objITunesunesApp := ComObjCreate("iTunes.Application")
	; iTunes library (named "LIBRARY" in English, "BIBLIOTHÈQUE" in French) - source #1 is the main library
	; objLibrary := objITunesunesApp.Sources.ItemByName("Bibliothèque")
	objITunesLibrary := objITunesunesApp.Sources.Item(1)
	; Retrieve by its name the strPlaylist from the Playlists collection
	objITunesPlaylist := objITunesLibrary.Playlists.ItemByName("! iTunesCovers") ; objPlaylist := objLibrary.Playlists.Item(2)
	objITunesTracks := objITunesPlaylist.Tracks
}
;-----------------------------------------------------------


;-----------------------------------------------------------
InitArtistsAlbumsIndex()
{
	global strAlbumArtistDelimiter
	
	intArtistID := 0
	intAlbumID := 0
	intArtistAlbumID := 0

	Loop, % objITunesTracks.Count ; around 75 sec./10k tracks to build 3 index for 27 k tracks
	{
		objITunesTrack := objITunesTracks.Item(A_Index)
		if !Mod(A_Index,100)
			TrayTip, , % A_Index . " / " . objITunesTracks.Count

		strArtist := objITunesTracks.Item(A_Index).Artist
		StringReplace, strArtist, strArtist, %strAlbumArtistDelimiter%
		if !StrLen(objArtistsIndex[strArtist])
		{
			intArtistID := intArtistID + 1
			objArtistsIndex.Insert(strArtist, "")
		}
		objArtistsIndex[strArtist] := objArtistsIndex[strArtist] . objITunesTrack.Index . ","
		
		strAlbum := objITunesTracks.Item(A_Index).Album
		StringReplace, strAlbum, strAlbum, %strAlbumArtistDelimiter%
		if !StrLen(objAlbumsIndex[strAlbum])
		{
			intAlbumID := intAlbumID + 1
			objAlbumsIndex.Insert(strAlbum, "")
		}
		objAlbumsIndex[strAlbum] := objAlbumsIndex[strAlbum] . objITunesTrack.Index . ","
		
		strArtistAlbum := strArtist . strAlbumArtistDelimiter . strAlbum
		if !StrLen(objArtistsAlbumsIndex[strArtistAlbum])
		{
			intArtistAlbumID := intArtistAlbumID + 1
			objArtistsAlbumsIndex.Insert(strArtistAlbum, "")
		}
		objArtistsAlbumsIndex[strArtistAlbum] := objArtistsAlbumsIndex[strArtistAlbum] . objITunesTrack.Index . ","

		; ###_D(strArtistAlbum . " : " . objArtistsAlbumsIndex[strArtistAlbum])
		; ###_D(objITunesTrack.Index . " " . objAlbumsIndex[strAlbum])
		; ###_D(objITunesTrack.Index . " " . objTracksAndAlbumID[objITunesTrack.Index])
		if (A_Index = 200)
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
InitCoverScan(strArtist := "", strAlbum := "")
{
	if (StrLen(strArtist) > 0) and (StrLen(strAlbum) > 0)
		arrTracks := StrSplit(objArtistsAlbumsIndex[strArtist . strAlbumArtistDelimiter . strAlbum], ",")
	else if StrLen(strArtist)
		arrTracks := StrSplit(objArtistsIndex[strArtist], ",")
	else if StrLen(strAlbum)
		arrTracks := StrSplit(objAlbumsIndex[strAlbum], ",")
	else
		return 0
	intTracksArrayIndex := 0

	return 1
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
	strCoverFile := GetImageFile(objTrack, objThisCover.GUID)
	objThisCover.SetCoverFile(strCoverFile)

	objThisCover.SetCoverProperties(objTrack.Name, objTrack.Index, objTrack.TrackID, objTrack.TrackDatabaseID)

	; objThisCover.SetCoverAlbum(objITunesTracks.Item(arrTracks[intTracksArrayIndex]).Album)
	return objThisCover
}
;-----------------------------------------------------------


;-----------------------------------------------------------
GetImageFile(objTrack, strNameNoext)
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

