class_name MusicDef
extends Resource
## One music track (assets/audio/music/*.tres): the stream, its level, and the crossfade time.
## Played by the Music autoload — non-spatial, on the Music bus, one at a time. City-pop palette
## per AUDIO.md §7. The stream itself must LOOP (its `.ogg` import → Loop on, Offset 0); the player
## never re-triggers it, it just crossfades between tracks.

@export var id := ""
@export var stream: AudioStream
@export var volume_db := -14.0    ## LUFS-matched against the other tracks (AUDIO.md §1)
@export var fade := 1.5           ## seconds for the crossfade when this track comes or goes
