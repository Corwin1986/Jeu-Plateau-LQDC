extends SceneTree
var app
var checks=0
var failures=0
func check(ok:bool,msg:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",msg)
func click(prefix:String,node:Node)->bool:
	for c in node.get_children():
		if c is Button and c.text.begins_with(prefix) and not c.disabled:c.pressed.emit();return true
		if click(prefix,c):return true
	return false
func _initialize():call_deferred("run")
func run():
	app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true
	await process_frame
	for f in range(6):
		app.close_modal();app.begin_game(f);app.start_play(true)
		check(app.coach_phase()==0 and app.game.s.setup,"resource lesson starts before map")
		check(click("Ouvrir Ressources",app.modal),"resource CTA")
		check(click("Effectuer le transfert",app.modal),"real setup transfer")
		check(app.coach_phase()==1 and app.game.s.units[f*3+2].money==200 and app.game.s.factions[f].money==800,"actual reserves updated")
		check(click("2 · Découvrir",app.modal),"continue to map")
		check(app.guided() and app.game.s.turn==f,"human starts assisted lesson")
		app.game.s.onboarding.step=1;app.select_unit(f*3)
		for _i in range(40):
			match int(app.game.s.onboarding.step):
				2,6:app.pick_cell(app.guide_target())
				3,7:app.move_selected(true)
				4,5,8:app.end_turn()
				9:break
		check(app.game.s.factions[f].crystals.size()==1,"first crystal returned")
		app.finish_guide();app.close_modal();check(app.coach_phase()==2 and app.coach_paused(),"coach continues beyond crystal")
		app.select_unit(f*3+2);check(app.selected==-1,"wrong unit does not advance")
		app.select_unit(f*3+1);check(app.coach_phase()==3,"E2 selected")
		var target=app.coach_target();app.pick_cell(Vector2i(99,99));check(app.coach_phase()==3,"wrong destination does not advance")
		app.pick_cell(target);app.move_selected(true);check(app.coach_phase()==5 and app.game.pos(app.game.s.units[f*3+1])==target,"E2 moved")
		app.select_unit(f*3+2);app.pick_cell(app.coach_target());app.move_selected(true);check(app.coach_phase()==8 and app.game.pos(app.game.s.units[f*3+2])==target,"messenger meets E2")
		app.show_transfer();check(click("Effectuer le transfert",app.modal),"supply transfer")
		check(app.coach_phase()==9 and app.game.s.units[f*3+1].money==600 and app.game.s.units[f*3+2].money==100,"supply money conserved")
		app.close_modal();app.show_diplomacy();var other=(f+1)%6;app.confirm_coach_truce(other)
		check(click("Proposer la trêve",app.modal),"truce confirmation")
		check(app.coach_phase()==10 and app.game.truce(f,other) and app.game.s.factions[f].money==1100,"truce real and paid")
		app.game.save_game();check(app.game.load_game() and app.coach_phase()==10,"discovery resumes after reload")
		app.end_turn();check(app.coach_phase()==11 and not app.coach_paused(),"normal opponents resume, coach stays")
		# First battle uses normal engine, with a non-allied opponent.
		app.game.s.turn=f;app.game.start_turn();var enemy=((f+2)%6)*3
		var p=app.game.pos(app.game.s.units[f*3]);app.game.s.units[enemy].q=p.x;app.game.s.units[enemy].r=p.y
		app.selected=f*3;app.start_war(enemy,false)
		check(app.game.s.discovery.combat_intro and is_instance_valid(app.modal),"first battle intro")
		check(click("Préparer mon armée",app.modal),"deploy instruction")
		check(click("Valider le déploiement",app.modal),"deploy real troops")
		app.perform_attack(0,0);click("Confirmer mon action",app.modal);check(app.game.s.discovery.first_attack,"first actual battle action observed")
		app.leave_discovery();check(not app.has_coach(),"can leave without losing game")
		print("DISCOVERY faction ",f," completed")
	# Nonstandard initial allocation: obtain resources without resetting user choices.
	app.begin_game(2);app.game.s.factions[2].money=0;app.game.s.units[6].money=2000;app.game.s.units[7].money=0;app.game.s.units[8].money=0;app.start_play(true)
	var plan=app.coach_transfer_plan();check(plan.source=="u6" and plan.target=="u8" and plan.amount==100,"custom reserves respected")
	app.close_modal();app.queue_free();await process_frame
	print("DISCOVERY CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
