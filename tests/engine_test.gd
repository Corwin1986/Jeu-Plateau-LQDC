extends SceneTree
var failures=0
var checks=0
func check(value:bool,title:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+title)
func _initialize():
	var g=preload("res://state.gd").new();g.new_game(0,42)
	check(g.total_money()==12000,"Initial six wallets total")
	check(g.s.cells.size()==271,"Hex map size")
	check(g.s.crystals.size()==5,"Five crystals")
	check(g.s.deck.size()==50,"62 cards less 12 dealt")
	check(not g.transfer("b0","u2",301,true),"Messenger cap")
	check(g.transfer("b0","u2",300,true),"Messenger reaches 400")
	check(g.total_money()==12000,"Transfer conservation")
	check(not g.transfer("b0","u3",10,true),"No enemy transfer")
	check(g.move_unit(0,Vector2i(-1,-5)),"Reach crystal")
	check(g.s.units[0].crystals.size()==1 and g.s.units[0].mp==0,"Crystal picked stops movement")
	for n in range(6):g.advance_turn()
	check(g.s.units[0].mp==0,"Crystal immobilization next turn")
	for n in range(6):g.advance_turn()
	check(g.s.units[0].mp==4,"Carrier has 4 moves afterward")
	check(g.move_unit(0,g.BASES[0]),"Return home")
	check(g.s.factions[0].crystals.size()==1,"Crystal deposited")
	check(g.total_money()>=12400,"First deposit reward")
	g.new_game(0,43);g.s.units[3].q=1;g.s.units[3].r=-8
	check(g.declare_war(0,3),"War declaration")
	var b=g.s.battles[0]
	check(g.deploy(0,0,2,2,[0]),"Player army deployment")
	check(g.total_money()==12000,"War deployment conserves pot")
	check(not g.available_heroes(0).has(0),"Hero reserved")
	check(not g.attack(0,0,1),"Opening infantry only")
	check(g.attack(0,0,0),"Infantry attacks")
	check(not g.attack(0,0,0),"No second action same turn")
	g.save_game();var copy=preload("res://state.gd").new()
	check(copy.load_game(),"Save reload")
	check(copy.s.battles[0].pot==b.pot,"Battle roundtrip")
	check(copy.total_money()==g.total_money(),"Wallet roundtrip")
	var winners=0
	for seedval in range(10):
		g.new_game(0,100+seedval);g.s.human=-1
		for turn in range(1800):
			if g.s.winner>=0:break
			g.ai_move(g.s.turn);g.ai_combat(g.s.turn);g.advance_turn()
			for u in g.s.units:
				check(u.money>=0,"No negative wallet")
				check(u.k!=2 or u.money<=400,"Messenger cap throughout AI")
				check(u.crystals.size()<=2,"Scout crystal cap throughout AI")
			var ids=[]
			for fac in g.s.factions:
				check(fac.money>=0,"No negative base money")
				ids.append_array(fac.crystals)
			for u in g.s.units:ids.append_array(u.crystals)
			for ci in range(g.s.crystals.size()):
				if g.s.crystals[ci].holder=="map":ids.append(ci)
			check(ids.size()==5,"Five crystals conserved")
			for ci in range(5):check(ids.count(ci)==1,"Unique crystal ownership")
		if g.s.winner>=0:winners+=1
		print("seed ",seedval," rounds ",g.s.round," winner ",g.s.winner," conflicts ",g.s.battles.size())
	check(winners>=8,"AI games reach conclusion")
	print("CHECKS ",checks," FAILURES ",failures," COMPLETED ",winners,"/10")
	quit(0 if failures==0 else 1)
