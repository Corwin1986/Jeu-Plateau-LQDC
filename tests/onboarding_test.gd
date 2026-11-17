extends SceneTree
var app
var checks=0
var failed=false
func test(ok:bool,msg:String):
	checks+=1
	if not ok:failed=true;printerr("FAIL ",msg)
func _initialize():call_deferred("run")
func run():
	app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true
	await process_frame
	for f in range(6):
		app.game.new_game(f,42);app.start_play(true,false)
		test(app.guided() and app.game.s.turn==f,"guided human turn")
		var wallets=[]
		for u in app.game.s.units:wallets.append(u.money)
		app.game.s.onboarding.step=1;app.select_unit(f*3)
		test(app.game.s.onboarding.step==2,"select actual unit advances")
		var saw_crystal=false;var saw_wait=false
		for _i in range(30):
			var step=int(app.game.s.onboarding.step)
			if step==9:break
			if step in [2,6]:app.pick_cell(app.guide_target())
			elif step in [3,7]:app.move_selected(true)
			elif step in [4,5,8]:
				if step==4:saw_crystal=app.game.s.units[f*3].crystals.size()==1
				if step==5:saw_wait=app.game.s.units[f*3].mp==0
				app.end_turn()
			test(app.game.s.turn==f,"AI stays paused")
		test(saw_crystal and saw_wait,"pickup and waiting explained")
		test(app.game.s.onboarding.step==9,"first deposit completes lesson")
		test(app.game.s.factions[f].crystals.size()==1 and app.game.s.factions[f].money==1300,"first deposit reward correct")
		for uid in range(18):
			if int(uid/3)!=f:test(app.game.s.units[uid].money==wallets[uid] and app.game.pos(app.game.s.units[uid])==app.game.BASES[int(uid/3)],"AI unchanged during lesson")
		app.game.save_game();test(app.game.load_game() and app.game.s.onboarding.step==9,"guide progress survives save")
		app.finish_guide();test(not app.guided(),"can exit lesson")
		print("Guided first crystal and return PASS faction ",f)
	for i in range(9):
		app.tutorial_step=i;app.show_tutorial()
		await process_frame
		for c in app.modal.get_children():
			if c is RichTextLabel:
				test(c.size.x<=1000,"paragraph width constrained")
				test(c.position.x+c.size.x<=1280,"paragraph inside dialog")
				test(c.get_line_count()>=1,"tutorial text laid out")
	app.close_modal()
	var l=app.label(app.layer,"Long paragraph " .repeat(60),Rect2(0,0,300,400))
	await process_frame
	test(l.size.x<=300,"global label wraps within assigned width")
	print("ONBOARDING PASS ",checks," checks")
	quit(1 if failed else 0)
