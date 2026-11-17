extends SceneTree
var app
var checks=0
func check(value:bool):
	checks+=1
	assert(value)
func _initialize():call_deferred("run")
func run():
	app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true
	await process_frame
	app.begin_game(0);app.start_play(false);app.selected=0;app.show_map()
	for z in [0.8,1.0,1.6,2.8]:
		app.map_zoom=z;app.map_pan=Vector2(120,-50)
		for c in app.game.s.cells.values():check(app.mapview.cell(app.mapview.point(app.game.pos(c)))==app.game.pos(c))
	app.map_zoom=1;app.map_pan=Vector2.ZERO
	var original=app.mapview.cell(Vector2(500,300));app.mapview.zoom_at(1.4,Vector2(500,300));check(original==app.mapview.cell(Vector2(500,300)))
	var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=Vector2(400,300);app.mapview._gui_input(down)
	var motion=InputEventMouseMotion.new();motion.position=Vector2(450,340);motion.relative=Vector2(50,40);app.mapview._gui_input(motion);check(app.mapview.dragged)
	var zoom=app.map_zoom
	for i in range(2):
		var touch=InputEventScreenTouch.new();touch.index=i;touch.pressed=true;touch.position=Vector2(300+i*100,300);app.mapview._gui_input(touch)
	for x in [420,450]:
		var drag=InputEventScreenDrag.new();drag.index=1;drag.position=Vector2(x,300);app.mapview._gui_input(drag)
	check(app.map_zoom>zoom)
	app.previous_units=[];app.observe_changes(0);app.game.move_unit(0,Vector2i(-1,-5));app.observe_changes(0);check(app.journeys.has(0));check(app.visual_pos(0)!=Vector2(app.game.pos(app.game.s.units[0])))
	app.elapsed+=5;check(app.visual_pos(0)==Vector2(app.game.pos(app.game.s.units[0])))
	app.effects=false;app.show_settings();check(is_instance_valid(app.modal));app.close_modal();app.effects=true
	app.map_full=true;app.show_map();check(app.mapview.size.x==1400)
	app.map_full=false;app.start_play(true,false);check(app.mapview.size.x==1000)
	check(app.audio.music.stream!=null);check(app.audio.fx.stream!=null)
	app.queue_free();await process_frame
	print("PRESENTATION PASS ",checks," checks: transforms, drag, pinch, animation, settings, extended map, guided layout, audio")
	quit()
