extends SceneTree
var app
var checks=0
var failures=0
func check(value:bool,detail:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL ",detail)
func click(prefix:String,node:Node)->bool:
	if not is_instance_valid(node):return false
	for c in node.get_children():
		if c is Button and c.text.begins_with(prefix) and not c.disabled:c.pressed.emit();return true
		if click(prefix,c):return true
	return false
func _initialize():call_deferred("run")
func run():
	app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true
	await process_frame
	for f in range(6):
		app.close_modal();app.begin_game(f)
		check(app.screen=="village" and app.game.s.setup,"new game opens village")
		check(click("Préparer mon expédition",app.layer),"village preparation CTA")
		check(click("Commencer avec le guide",app.layer),"chapter entry")
		check(app.guided() and app.coach_phase()==11 and app.game.s.chapter_mode,"short chapter without mandatory supply")
		check(app.map_zoom>1.5,"close world view")
		app.game.s.onboarding.step=1;app.select_unit(f*3)
		var warned=false
		for i in range(50):
			match int(app.game.s.onboarding.step):
				2,6:
					app.pick_cell(app.guide_target())
				3,7:
					var preview=app.travel_preview()
					if preview.warning!="":warned=true
					app.move_selected()
					check(not is_instance_valid(app.modal),"route advice does not interrupt movement")
				4,5,8:app.end_turn()
				9:break
		check(warned,"crystal warning shown")
		check(app.game.s.factions[f].crystals.size()==1,"real first deposit")
		app.finish_guide();app.close_modal()
		check(app.screen=="village" and not app.guided() and not app.coach_paused(),"chapter complete returns village and unlocks play")
		check(app.game.s.factions[f].money==1300,"unchanged deposit amount")
		app.open_supply_chapter();app.close_modal()
		check(app.coach_phase()==2,"optional supply chapter")
		app.select_unit(f*3+1);app.pick_cell(app.coach_target());app.move_selected(true)
		app.select_unit(f*3+2);app.pick_cell(app.coach_target());app.move_selected(true)
		app.show_transfer();check(click("Effectuer le transfert",app.modal),"real supply transfer")
		app.close_modal()
		check(app.game.s.get("supply_learned",false) and app.screen=="village" and not app.coach_paused(),"supply does not force diplomacy")
		check(app.game.s.units[f*3+1].money==600 and app.game.s.units[f*3+2].money==0,"supply balances")
		app.open_diplomacy_chapter();check(is_instance_valid(app.modal),"optional diplomacy accessible")
		app.close_modal();app.game.save_game();app.game.load_game()
		check(app.game.s.first_expedition_done and app.game.s.supply_learned,"chapter progress saved")
		app.enter_world();app.guide_folded=true;app.show_map();check(app.mapview.size.y==650,"folded advice restores map area")
		app.guide_folded=false
		# First war action must warn before consuming the remaining units' moves.
		app.game.s.turn=f;app.game.start_turn();var enemy=((f+2)%6)*3
		var pos=app.game.pos(app.game.s.units[f*3]);app.game.s.units[enemy].q=pos.x;app.game.s.units[enemy].r=pos.y
		app.selected=f*3;app.start_war(enemy,false);click("Préparer mon armée",app.modal);click("Valider le déploiement",app.modal)
		app.perform_attack(0,0)
		check(not app.game.s.get("combat_phase",false),"war confirmation precedes phase switch")
		check(click("Confirmer mon action",app.modal),"war confirmation button")
		check(app.game.s.get("combat_phase",false),"confirmed war action locks movement")
		print("VILLAGE faction ",f," passed")
	app.close_modal();app.queue_free();await process_frame
	print("VILLAGE CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
