;-----------------------------------------------------------
InitGDIP()
{
	If !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}
	return pToken
}
;-----------------------------------------------------------




;-----------------------------------------------------------
class Cover
{
    GUID := GenerateGUID()
    ; not used: static GUID3 := GenerateGUID()

	__New(strFilePathName)
	{
		this.FileNamePath := strFilePathName
	}

	SetCoverFile(strFilePathName)
	{
		this.CoverFilePathName := strFilePathName
	}

	SetCoverProperties(strName, strIndex, strTrackID, strTrackDatabaseID)
	{
		this.Name := strName
		this.Index := strIndex
		this.TrackID := strTrackID
		this.TrackDatabaseID := strTrackDatabaseID
	}

	SetCoverPropertiesZZZ(strName, strIndex, strAlbum)
	{
		this.Album := strAlbum
	}

/*
Name ; Returns the name of the object. 
Index ; Returns the index of the object in internal application order. 
TrackID ; Returns the ID that identifies the track within the playlist. 
TrackDatabaseID ; Returns the ID that identifies the track, independent of its playlist. 

Kind ; Returns the kind of the track. 
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
TrackNumber ; Returns the index of the track on the source album. 
Year ; Returns the year the track was recorded/released. 
Artwork ; Returns a collection containing the artwork for the track. 
*/

}
;-----------------------------------------------------------



;-----------------------------------------------------------
GenerateGUID()         ; 32 hex digits = 128-bit Globally Unique ID
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


