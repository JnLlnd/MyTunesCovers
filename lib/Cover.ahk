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
global strCoverSourceType ; "iTunes" currently implemented, "MP3" coming
global strSourceCacheFilenameExtension := "SourceCache.csv"

#Include %A_ScriptDir%\lib\iTunes.ahk ; Cover source (INCLUDE MUST BE AFTER GLOBAL DECLARATIONS)


;-----------------------------------------------------------
class Cover
{
    GUID := Cover_GenerateGUID()

	__New(strFilePathName)
	{
		this.FileNamePath := strFilePathName
	}

	SetCoverTempFile(strFilePathName)
	{
		this.CoverTempFilePathName := strFilePathName
	}

	SetCoverProperties(strArtist, strAlbum, strName, intIndex, intTrackIDHigh, intTrackIDLow, intArtworkCount, intKind)
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

		NOT IMPLEMENTED:
			Playlist ; Returns an IITPlaylist object corresponding to the playlist that contains the track. Use IITFileOrCDTrack::Playlists() or IITURLTrack::Playlists() to get the collection of all playlists that contain the song this track represents. 
			Album ; Returns the name of the album containing the track. 
			Artist ; Returns the name of the artist/source of the track. 
			Comment ; Returns freeform notes about the track. 
			Compilation ; Returns true if this track is from a compilation album. 
			KindAsString ; Returns the text description of the track (e.g. "AAC audio file"). 
			ModificationDate ([out, retval] DATE *dateModified) ; Returns the modification date of the content of the track. 
			Size ; Returns the size of the track (in bytes). 
			Time ; Returns the length of the track (in MM:SS format). 
			TrackCount ; Returns the total number of tracks on the source album. 
			TrackID ; Returns the ID that identifies the track within the playlist. 
			TrackDatabaseID ; Returns the ID that identifies the track, independent of its playlist. 
			TrackNumber ; Returns the index of the track on the source album. 
			Year ; Returns the year the track was recorded/released. 
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
	}

	SaveCover(strFilePathName)
	{
		strResult := %strCoverSourceType%_SetImageFile(this.Index, strFilePathName)
		return strResult
	}

}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_InitCoversSource(strSource)
{
	strCoverSourceType := strSource

	if (strCoverSourceType = "MP3")
	{
		###_D("Load MP3 not implemented") ; %strCoverSourceType%_LoadSource()
		return false
	}
	else
	{
		blnSourceOK := %strCoverSourceType%_InitCoversSource()
		if (blnSourceOK)
		{
			if FileExist(A_ScriptDir . "\" . strCoverSourceType . "_" . strSourceCacheFilenameExtension)
			{
				MsgBox, 36, %lAppName%, %lLoadCache% ; ### or if number of tracks changed
				IfMsgBox, Yes
					%strCoverSourceType%_LoadSource() ; use cache
				IfMsgBox, No
				{
					FileDelete, %A_ScriptDir%\%strCoverSourceType%_%strSourceCacheFilenameExtension%
					%strCoverSourceType%_InitArtistsAlbumsIndex() ; refresh lists
				}
			}
			else
				%strCoverSourceType%_InitArtistsAlbumsIndex() ; have to refresh lists
		}
		return blnSourceOK
	}
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_InitCoverScan(lstArtists, lstAlbums, blnOnlyNoCover)
{
	if StrLen(strCoverSourceType)
		return %strCoverSourceType%_InitCoverScan(lstArtists, lstAlbums, blnOnlyNoCover)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_GetCover(ByRef objCover, intTrackIndex)
{
	if StrLen(strCoverSourceType)
		return %strCoverSourceType%_GetCover(objCover, intTrackIndex)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_LoadSource() ; NOT USED
{
	###_D("Load: " . strCoverSourceType)
	return %strCoverSourceType%_LoadSource()
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_ReleaseSource()
{
	if (strCoverSourceType = "MP3")
		###_D("Save MP3 not implemented") ; %strCoverSourceType%_SaveSource()
	else
		if !FileExist(A_ScriptDir . "\" . strCoverSourceType . "_" . strSourceCacheFilenameExtension)
			%strCoverSourceType%_SaveSource()
}

;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_SaveCoverToTune(ByRef objCover, strFile, blnReplace)
{
	if StrLen(strCoverSourceType)
		return %strCoverSourceType%_SaveCoverToTune(objCover, strFile, blnReplace)
	else
		return false
}
;-----------------------------------------------------------


;-----------------------------------------------------------
Cover_DeleteCoverFromTune(ByRef objCover)
{
	if StrLen(strCoverSourceType)
		return %strCoverSourceType%_DeleteCoverFromTune(objCover)
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


