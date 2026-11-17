extends SceneTree
var app
var checks=0
var failures=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)
func click(prefix:String,node:Node)->bool:
	if not is_instance_valid(node):return false
	for c in node.get_children():
		if c is Button and c.text.begins_with(prefix) and not c.disabled:c.pressed.emit();return true
		if click(prefix,c):return true
	return false
func _initialize():call_deferred("run")
func run():
	app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true;await process_frame
	for f in range(6):
		app.close_modal();app.begin_game(f);app.start_play(false);app.game.s.turn=f;app.game.start_turn()
		var mid=f*3+2;var uid=f*3+1;var base=app.game.BASES[f]
		app.supply_to(uid)
		check(click("Effectuer le transfert",app.modal),"direct colocated transfer")
		check(app.game.s.units[mid].money==0 and app.game.s.units[uid].money==600,"correct preselected source and recipient")
		app.supply_to(uid);check(click("Effectuer le transfert",app.modal),"refill empty messenger at base")
		check(app.game.s.units[mid].money==100 and app.game.s.factions[f].money==800,"refill uses village money")
		var goal=base
		for d in app.game.DIRS:
			if app.game.s.cells.has(app.game.key(base+d)):goal=base+d;break
		app.game.move_unit(uid,goal);app.supply_to(uid)
		check(app.selected==mid and app.destination==goal,"messenger and actual route preselected")
		check(app.game.pos(app.game.s.units[mid])==base,"command does not teleport")
		app.move_selected();app.supply_to(uid);click("Effectuer le transfert",app.modal)
		check(app.game.s.units[uid].money==700 and app.game.s.units[mid].money==0,"arrival enables real transfer")
		var advice=app.Advisor.situation(app.game);check(advice.has("action"),"live situation has action")
		app.game.s.units[uid].crystals=[0];app.game.s.units[uid].locked=app.game.s.factions[f].turns
		check(app.Advisor.situation(app.game).title.contains("sécurise"),"immobilized carrier advice")
		app.game.s.units[uid].crystals=[]
		# Prepare an actual conflict, then use optional compositions.
		var enemy=((f+1)%6)*3;var p=app.game.pos(app.game.s.units[f*3]);app.game.s.units[enemy].q=p.x;app.game.s.units[enemy].r=p.y
		app.selected=f*3;app.start_war(enemy,false);app.close_modal();app.show_deploy()
		var b=app.game.battle_by_id(app.bid);var money=app.game.wallet(b.sides[0])
		for mode in range(3):
			app.apply_composition(mode)
			check(app.deploy_a.value>=2 and app.deploy_b.value>=2,"legal minimum composition")
			check(app.game.wallet(b.sides[0])==money,"suggestion does not spend")
			var sim=load("res://state.gd").new();sim.s=app.game.s.duplicate(true);var heroes=[]
			for pair in app.hero_checks:
				if pair[1].button_pressed:heroes.append(pair[0])
			check(sim.deploy(app.bid,0,int(app.deploy_a.value),int(app.deploy_b.value),heroes),"suggested army accepted by rules engine")
			check(sim.wallet(sim.battle_by_id(app.bid).sides[0])>=sim.stats(f,0,int(app.deploy_a.value),b.terrain)[1],"suggestion preserves opening attack budget")
			check(app.deploy_price.text.contains("Réserve restante"),"remaining reserve shown")
		app.apply_composition(0);click("Valider le déploiement",app.modal)
		var before=JSON.stringify(app.game.s);var prediction=app.Advisor.attack_preview(app.game,app.bid,0,0)
		check(prediction.ok and JSON.stringify(app.game.s)==before,"preview is valid and read only")
		app.show_attack_preview(0,0)
		check(JSON.stringify(app.game.s)==before,"opening preview does not attack")
		check(click("Confirmer l’attaque",app.modal),"single attack confirmation")
		check(app.game.s.get("combat_phase",false),"confirmation enters war phase")
		for li in range(3):check(b.sides[1].lines[li].hp==prediction.snapshot.sides[1].lines[li].hp,"prediction matches actual defense")
		check(app.game.wallet(b.sides[0])==money-prediction.cost-app.game.stats(f,0,2,b.terrain)[0]-app.game.stats(f,1,2,b.terrain)[0],"real expenditure matches")
		print("DECISIONS faction ",f," passed")
	# Corruption must be reflected in previews, not guessed from attack strength.
	app.game.new_game(0,42);app.game.s.setup=false;app.game.s.units[6].q=0;app.game.s.units[6].r=-8;app.game.declare_war(0,6);app.bid=0;app.game.deploy(0,0,2,2,[])
	var b=app.game.battle_by_id(0);b.sides[1].priest=true
	var p=app.Advisor.attack_preview(app.game,0,0,0)
	check(p.ok and p.text.contains("Aucun dégât"),"corruption preview accounts for cancellation")
	check(b.sides[1].priest,"preview does not consume protection")
	app.close_modal();app.queue_free();await process_frame
	print("DECISIONS CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
