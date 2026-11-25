extends Node
## Audio playback (filled in by the audio pass).
func play(_name: String, _vol: float = 0.0, _pitch: float = 1.0) -> void: pass
func music(_name: String, _fade: float = 1.5) -> void: pass
func ambience(_name: String) -> void: pass
