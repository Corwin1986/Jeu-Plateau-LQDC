extends SceneTree
var checks=0
var failures=0
func check(ok:bool,msg:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",msg)
func _initialize():call_deferred("run")
func run():
	var app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true;await process_frame
	for f in range(6):
		app.begin_game(f);app.expedition.begin()
		var g=app.game;var count=0;var second_moved=false;var turns=0
		var second_start=g.pos(g.s.units[f*3+1]);var before_total=2000
		while app.expedition.active() and count<80:
			count+=1
			var e=g.s.expedition;var phase=str(e.phase);var c=app.expedition.copy()
			if phase in ["out","second","wait","return"] and g.s.units[app.expedition.unit_id()].mp>0 and not e.preview:
				var before=JSON.stringify(g.s)
				app.pick_cell(Vector2i(99,99))
				check(before==JSON.stringify(g.s),"incorrect tap does not mutate")
				app.pick_cell(app.expedition.target())
				check(e.preview,"target previews before moving")
			else:
				var round_before=g.s.round
				app.expedition.primary()
				if g.s.round!=round_before:turns+=1
			if g.pos(g.s.units[f*3+1])!=second_start:second_moved=true
			check(g.s.units[f*3].money>=0 and g.s.units[f*3+1].money>=0,"reserves nonnegative")
		check(count<80,"chapter completes faction "+str(f))
		check(g.s.factions[f].crystals.size()==1,"real deposit")
		check(g.s.factions[f].money==1300,"deposit reward")
		check(second_moved,"active second expedition")
		check(g.s.units[f*3+1].money>=700,"second scout collected an actual cache")
		check(turns>=2,"explicit lock and movement turns")
		g.save_game();var restored=load("res://state.gd").new();check(restored.load_game(),"save loads")
		check(not restored.s.expedition.active,"completion persists")
		print("EXPEDITION faction ",f," actions ",count)
	app.queue_free();await process_frame
	print("EXPEDITION CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
