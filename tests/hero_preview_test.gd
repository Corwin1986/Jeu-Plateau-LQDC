extends SceneTree
func _initialize():call_deferred("run")
func texts(n:Node)->String:
	var t=""
	if n is Label or n is RichTextLabel:t+=n.text+"\n"
	for c in n.get_children():t+=texts(c)
	return t
func run():
	var app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true;await process_frame
	var g=app.game;g.new_game(1,42);g.s.setup=false;g.s.turn=1;g.start_turn();g.s.units[3].money=2000
	g.s.units[0].q=9;g.s.units[0].r=-8
	assert(g.declare_war(3,0));app.bid=0;assert(g.deploy(0,0,4,3,[0,1]))
	var b=g.battle_by_id(0);b.opening=false;b.active=0
	var expected=app.Advisor.attack_preview(g,0,0,2,0,-1,1);assert(expected.ok)
	var before=JSON.stringify(g.s);app.show_attack_preview(0,2,1)
	assert(JSON.stringify(g.s)==before)
	assert(texts(app.modal).contains(expected.text))
	assert(texts(app.modal).contains("Coût : %d R"%expected.cost))
	assert(g.attack(0,0,2,0,-1,1))
	assert(JSON.stringify(g.battle_by_id(0).sides)==JSON.stringify(expected.snapshot.sides))
	print("Chosen hero preview matches actual attack; opening preview does not mutate state.")
	app.queue_free();await process_frame;quit()
