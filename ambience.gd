extends Node
var music:AudioStreamPlayer
var fx:AudioStreamPlayer
var music_volume=0.35
var fx_volume=0.65
func _ready():
	music=AudioStreamPlayer.new();add_child(music)
	fx=AudioStreamPlayer.new();add_child(fx)
	music.stream=load("res://assets/ambience.wav")
	music.finished.connect(func():music.play())
	music.play();apply_volume()
func apply_volume():
	music.volume_db=linear_to_db(maxf(0.0001,music_volume));fx.volume_db=linear_to_db(maxf(0.0001,fx_volume))
func cue(kind="click"):
	fx.stream=load("res://assets/"+kind+".wav");fx.play()
