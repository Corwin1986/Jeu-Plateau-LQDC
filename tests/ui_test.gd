extends SceneTree
var app
func _initialize():call_deferred("run")
func click(text:String,node:Node)->bool:
	for child in node.get_children():
		if child is Button and child.text.begins_with(text):child.pressed.emit();return true
		if click(text,child):return true
	return false
func run():
	app=load("res://Main.tscn").instantiate();root.add_child(app);app.paused=true
	await process_frame
	assert(app.screen=="menu")
	app.show_factions();assert(click("Choisir ce peuple",app.layer));assert(app.screen=="village");app.show_setup()
	app.show_transfer();assert(click("Effectuer",app.modal));print("TRANSFER ",app.game.s.human," ",app.game.s.factions[0].money," ",app.game.error);assert(app.game.s.factions[0].money==800)
	assert(click("Jouer sans guide",app.layer));app.close_modal();assert(app.screen=="map")
	app.pick_cell(Vector2i(-1,-5));assert(click("Déplacer ici",app.layer));assert(app.game.s.units[0].crystals.size()==1)
	app.show_help();app.show_tables();app.close_modal();app.show_log();app.close_modal();app.show_diplomacy();app.close_modal();app.show_interactions();app.close_modal()
	for f in range(6):
		app.game.new_game(f,40+f);app.game.s.turn=f;app.game.start_turn();app.selected=f*3;app.game.s.setup=false
		var enemy=((f+1)%6)*3
		var p=app.game.BASES[f]+app.game.DIRS[(f+2)%6]
		if not app.game.s.cells.has(app.game.key(p)):p=app.game.BASES[f]
		app.game.s.units[enemy].q=p.x;app.game.s.units[enemy].r=p.y
		assert(app.game.declare_war(f*3,enemy));app.bid=0;app.show_battle();app.show_deploy()
		assert(click("Valider le",app.modal));assert(app.game.s.battles[0].sides[0].deployed)
		app.show_cards();app.close_modal();app.show_powers();app.close_modal();app.choose_attack(0,0);assert(click("Confirmer l’attaque",app.modal))
		assert(app.game.s.battles[0].active==1 or app.game.s.battles[0].done)
		app.show_conflicts();app.close_modal();app.show_map();app.end_turn()
		await process_frame
	print("UI PASS: six factions, setup transfer, tutorial, movement, panels, deploy, attack, end turn")
	quit()
