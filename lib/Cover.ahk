;===============================================
/*
	Library Cover.ahk
	Used by MyTunesCovers.ahk
	By Jean Lalonde (JnLlnd on AHKScript.org forum)

*/
;===============================================

global objArtistsIndex := Object()
global objAlbumsIndex := Object()
global objArtistsAlbumsIndex := Object()
global objAlbumsOfArtistsIndex := Object()
global objArtistsOfAlbumsIndex := Object()
global strSourceType ; "iTunes" currently implemented, "MP3" coming
global strSourceSelection
global strIndexFolder
global strIndexFilenameExtension := "Index.csv"

#Include %A_ScriptDir%\lib\iTunes.ahk ; Cover source (INCLUDE MUST BE AFTER GLOBAL DECLARATIONS)


;-----------------------------------------------------------
class Cover
{
    GUID := Cover_GenerateGUID()

	__New()
	{
		this.Selected := False
	}

	SetCoverTempFile(strFilePathName)
	{
		this.CoverTempFilePathName := strFilePathName
	}

	SetCoverProperties(strArtist, strAlbum, strName, intIndex, intTrackIDHigh, intTrackIDLow, intArtworkCount, intKind, strTime, strYear, strComment)
	/*
		IMPLEMENTED
			Artist ; Returns the Artist name.
			Album ; Returns the Album name.
			Name ; Returns the name (track title) of the object. 
			Index ; Returns the index of the object in internal application order. 
			TrackIDHigh ; Returns high part of the persistent ID of the track
			TrackIDLow ; Returns low part of the persistent ID of the track
			Artwork.Count ; Returns the number of pieces of artwork in the collection.
			Kind ; Returns the kind of the track. 
			Time ; Returns the length of the track (in MM:SS format). 
			Year ; Returns the year the track was recorded/released. 
			Comment ; Returns freeform notes about the track. 

		NOT IMPLEMENTED:
			Playlist ; Returns an IITPlaylist object corresponding to the playlist that contains the track. Use IITFileOrCDTrack::Playlists() or IITURLTrack::Playlists() to get the collection of all playlists that contain the song this track represents. 
			Album ; Returns the name of the album containing the track. 
			Artist ; Returns the name of the artist/source of the track. 
			Compilation ; Returns true if this track is from a compilation album. 
			KindAsString ; Returns the text description of the track (e.g. "AAC audio file"). 
			ModificationDate ([out, retval] DATE *dateModified) ; Returns the modification date of the content of the track. 
			Size ; Returns the size of the track (in bytes). 
			TrackCount ; Returns the total number of tracks on the source album. 
			TrackID ; Returns the ID that identifies the track within the playlist. 
			TrackDatabaseID ; Returns the ID that identifies the track, independent of its playlist. 
			TrackNumber ; Returns the index of the track on the source album. 
			Artwork ; Returns a collection containing the artwork for the track. 
			Artwork.Item(index) ; Returns an IITArtwork object corresponding to the given index (1-based).
	*/
	{
		this.Name := strName
		this.Artist := strArtist
		this.Album := strAlbum
		this.Index := intIndex
		this.TrackIDHigh := intTrackIDHigh
		this.TrackIDLow := intTrackIDLow
		this.ArtworkCount := intArtworkCount
		this.Kind := intKind
		this.Time := strTime
		this.Year := strYear
		this.Comment := strComment
	}

/*
	SaveCover(strFilePathName)
	{
		strResult := %strSourceType%_SetImageFile(this.Index, strFilePathName)
		return strResult
	}
*/

}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_InitCoversSource(strSource)
{
	strSourceType := strSource ; global variable

	if StrLen(strSourceType)
		 return %strSourceType%_InitCoversSource()
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_LoadIndex()
{
	if StrLen(strSourceType)
		return %strSourceType%_LoadIndex()
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_BuildArtistsAlbumsIndex()
{
	if StrLen(strSourceType)
		return %strSourceType%_BuildArtistsAlbumsIndex()
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_InitCoverScan(lstArtists, lstAlbums, blnOnlyNoCover)
{
	if StrLen(strSourceType)
		return %strSourceType%_InitCoverScan(lstArtists, lstAlbums, blnOnlyNoCover)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_GetCover(intTrackIndex)
{
	if StrLen(strSourceType)
		return %strSourceType%_GetCover(intTrackIndex)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_GetImage(objThisCover)
{
	if StrLen(strSourceType)
		return %strSourceType%_GetImage(objThisCover)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_GetArtworkCount(objThisCover)
{
	if StrLen(strSourceType)
		return %strSourceType%_GetArtworkCount(objThisCover)
	else
		return -1
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_ArtistOrAlbumHasNoCover(strTracks)
{
	if StrLen(strSourceType)
		return %strSourceType%_ArtistOrAlbumHasNoCover(strTracks)
	else
		return -1
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_SaveIndex(strSource, strIndexFolder, strSelection)
{
	if StrLen(strSourceType)
		return %strSourceType%_SaveIndex(strSource, strIndexFolder, strSelection)
	else
		return -1
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_SaveCoverToTune(ByRef objCover, strFile)
{
	if StrLen(strSourceType)
		return %strSourceType%_SaveCoverToTune(objCover, strFile, blnReplace)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_DeleteCoverFromTune(ByRef objCover)
{
	if StrLen(strSourceType)
		return %strSourceType%_DeleteCoverFromTune(objCover)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_Play(objCover)
{
	if StrLen(strSourceType)
		return %strSourceType%_Play(objCover)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_ReleaseSource(strSource, strIndexFolder, strSelection)
{
	global intInitResult
	
	if (intInitResult > 0) and !FileExist(A_ScriptDir . strIndexFolder . strSource . "_" . strSelection . "_" . strIndexFilenameExtension)
		if YesNoCancel(False, L(lSaveIndexTitle, lAppName)
			, L(lSaveIndexPrompt, strSource, lAppName, strSource . "_" . strSelection . "_" . strIndexFilenameExtension)) = "Yes"
			Cover_SaveIndex(strSource, strIndexFolder, strSelection)
	if StrLen(strSource)
		return %strSource%_ReleaseSource()
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_GenerateGUID()         ; 32 hex digits = 128-bit Globally Unique ID
; Source: Laszlo in http://www.autohotkey.com/board/topic/5362-more-secure-random-numbers/
{
   format = %A_FormatInteger%       ; save original integer format
   SetFormat Integer, Hex           ; for converting bytes to hex
   VarSetCapacity(A,16)
   DllCall("rpcrt4\UuidCreate","Str",A)
   Address := &A
   Loop 16
   {
      x := 256 + *Address           ; get byte in hex, set 17th bit
      StringTrimLeft x, x, 3        ; remove 0x1
      h = %x%%h%                    ; in memory: LS byte first
      Address++
   }
   SetFormat Integer, %format%      ; restore original format
   Return h
}
;-----------------------------------------------------------



;-----------------------------------------------------------
Cover_GetITunesPlaylist()
;-----------------------------------------------------------
{
	return iTunes_GetITunesPlaylist()
}
;-----------------------------------------------------------
