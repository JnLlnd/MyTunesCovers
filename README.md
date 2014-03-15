# iTunesCoverManager - Read me

MyTunesCoverManager. Freeware.

Written using AHKScript v1.1.09.03+ (http://www.ahkscript.org)  
By JnLlnd on [AHKScript forum](http://ahkscript.org/boards/memberlist.php?mode=viewprofile&u=66)

## Links

* [Application home][http://code.jeanlalonde.ca/mytunescovernamager/ ) (not created yet)
* [Download 32-bits / 64-bits]( http://code.jeanlalonde.ca/ahk/mytunescovernamager/mytunescovernamager.zip ) (not available yet)

## History

### 2014-03-14 v0.6 ALPHA
* moved source selection to options dialog box
* added iTunes Playlist selection and saving index file according to current playlist selection
* moved display only no cover and list only ablum with no cover checkboxes to option dialog box
* moving index files to a subdirectory
* display file name when loading/saving index cache, display file date when loading
* display current playlist as default in playlist dropdown
* add logo to gui
* add picture size selection to settings
* add skin selection in settings
* prepare 3 skins for initial shipping
* add custom button names to YesNoCancel function

### 2014-03-07 v0.5 ALPHA
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

### 2014-02-15 v0.4 ALPHA
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

### 2014-01-17 v0.3 ALPHA
* Reset all albums views when select All artists
* Implemented release, save cache and reload cache for iTunes source
* Source cache file saved by batch with error handling
* Retrieve tracks using GetITObjectByID with TrackID and TrackDatabaseID
* GuiResize reposition covers according to Gui size
* Covers paging with x of y, previous and next buttons in footer
* Loading persistent images (no cover, fill cover) only once at init

### 2014-01-08 v0.2 ALPHA
* Add properties to Covers class, POC for set image
* Show max covers for screen size, add paging buttons not functional
* Add dropdown lists for artists and albums, add info to cover label
* Library Cover_ and iTunes_ refactoring, add iTunes/MP3 sources radio buttons, iTunes source implemented

### 2014-01-05 v0.1 ALPHA
* First Alpha release. Not ready for alpha distribution yet. But you can take a look at sources
* Initialize script and language file, read ini file, implement check for update
* Base of iTunesLib as tracks source (a future version could also support MP3 source files in a directory - ie without the use of iTunes)
* Base of CoversLib libraries, rudimentary Gui with covers read from iTunes


## <a name="copyright"></a>Copyright

This software is provided 'as-is', without any express or implied warranty.  In no event will the authors be held liable for any damages arising from the use of this software.  
  
Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:  
  
1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.  
2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.  
3. This notice may not be removed or altered from any source distribution.  
  
Jean Lalonde, <A HREF="mailto:ahk@jeanlalonde.ca">ahk@jeanlalonde.ca</A>


