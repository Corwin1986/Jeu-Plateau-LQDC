extends RefCounted
# Guided actions use the real engine, positions, movement budgets and reserves.
var h
var g
func _init(host):h=host;g=host.game
func active()->bool:return not g.s.is_empty() and g.s.get("expedition",{}).get("active",false)
func begin():
	g.s.setup=false;g.s.turn=g.s.human
	if int(g.s.factions[g.s.human].turns)==0:g.start_turn()
	g.s.onboarding={"active":false};g.s.discovery={"active":true,"phase":11,"combat_intro":false,"first_attack":false}
	var ci=0;var best=999
	for i in range(g.s.crystals.size()):
		var d=g.distance(g.BASES[g.s.human],g.pos(g.s.crystals[i]))
		if d<best:best=d;ci=i
	g.s.expedition={"active":true,"phase":"out","crystal":ci,"preview":false,"second_done":false}
	h.selected=int(g.s.human)*3;h.destination=Vector2i(99,99);g.save_game();h.show_map()
func unit_id()->int:return int(g.s.human)*3+(1 if g.s.expedition.phase in ["second","wait"] else 0)
func goal()->Vector2i:
	var e=g.s.expedition;var u=g.s.units[unit_id()]
	if e.phase=="out":return g.pos(g.s.crystals[int(e.crystal)])
	if e.phase=="second":
		var best=999;var p=g.BASES[g.s.human]
		for c in g.s.cells.values():
			if not c.cache:continue
			var d=g.path(g.pos(u),g.pos(c)).size()
			if d<best:best=d;p=g.pos(c)
		return p
	return g.BASES[g.s.human]
func target()->Vector2i:
	var u=g.s.units[unit_id()];var route=g.path(g.pos(u),goal())
	if route.is_empty():return goal()
	return route[mini(route.size(),maxi(1,int(u.mp)))-1]
func copy()->Array:
	var e=g.s.expedition;var u=g.s.units[unit_id()]
	if e.phase=="collected":return ["Le cristal est porté, pas encore en sécurité.","Votre éclaireur s’arrête et sera immobilisé au prochain tour. Pendant ce temps, envoyez le deuxième chercher des ressources.","Jouer mon deuxième éclaireur"]
	if e.phase=="done":return ["Votre premier cristal est au sanctuaire !","Le village reçoit 400 R pour ce premier dépôt. Vous pouvez poursuivre l’exploration, ravitailler vos éclaireurs ou préparer un conflit.","Choisir la suite au village"]
	if e.phase=="second_end":return ["Votre deuxième expédition a avancé.","Les ressources trouvées restent dans sa propre réserve. Terminez votre tour : le porteur restera immobilisé au tour suivant.","Terminer mon tour"]
	if e.phase=="wait_end":return ["L’autre éclaireur a joué pendant l’attente.","Terminez ce tour pour rendre ses déplacements au porteur. Aucun tour n’est passé sans votre action.","Terminer mon tour"]
	if int(u.mp)==0:return ["Les pas de cet éclaireur sont utilisés.","Terminez votre tour pour renouveler ses déplacements et poursuivre le trajet.","Terminer mon tour"]
	if e.get("preview",false):
		var n=g.path(g.pos(u),h.destination).size()
		return ["Un trajet de %d pas."%n,"La collecte d’un cristal arrête ce pion et l’immobilise au prochain tour." if e.phase=="out" else ("Les ressources collectées restent à cet éclaireur." if e.phase=="second" else "Le cristal sera déposé automatiquement à l’arrivée au village."),"Confirmer · %d pas"%n]
	if e.phase=="out":return ["Touchez la case dorée vers le cristal.","Votre éclaireur 1 est sélectionné. Le chemin indique où aller ; confirmez ensuite le déplacement.",""]
	if e.phase=="second":return ["Touchez la case dorée vers la réserve.","Votre éclaireur 2 est sélectionné. Une réserve dorée contient 200 R. Le trajet respecte ses pas disponibles.",""]
	if e.phase=="wait":return ["Le porteur attend. Ramenez l’autre éclaireur.","Touchez la case dorée vers le village. Ses ressources restent avec lui : elles ne sont pas partagées automatiquement.",""]
	return ["Rapportez le cristal au village.","Le porteur avance de quatre cases par tour. Touchez la case dorée sur son chemin de retour.",""]
func pick(p:Vector2i):
	var e=g.s.expedition
	if e.phase in ["collected","done","second_end","wait_end"]:return
	if p!=target():h.announce("Touchez la case entourée en doré.");return
	h.destination=p;e.preview=true;g.save_game();h.show_map()
func primary():
	var e=g.s.expedition
	match e.phase:
		"collected":e.phase="second";h.selected=unit_id()
		"done":
			e.active=false;g.s.first_expedition_done=true;g.save_game();h.show_village();return
		"second_end","wait_end":end_turn();return
		_:
			if int(g.s.units[unit_id()].mp)==0:end_turn();return
			if not e.get("preview",false):return
			var previous_phase=str(e.phase)
			if not g.move_unit(unit_id(),h.destination):h.show_notice("Déplacement impossible",g.error);return
			e.preview=false
			if previous_phase=="out" and not g.s.units[int(g.s.human)*3].crystals.is_empty():e.phase="collected"
			elif previous_phase=="second":e.phase="second_end"
			elif previous_phase=="wait":e.phase="wait_end"
			elif g.s.factions[g.s.human].crystals.has(e.crystal):e.phase="done"
	h.destination=Vector2i(99,99);g.save_game();h.show_map()
func end_turn():
	var e=g.s.expedition;var phase=str(e.phase)
	# Training explicitly pauses the other kingdoms. Normal play resumes after the deposit.
	for i in range(6):g.advance_turn()
	if phase=="second_end":e.phase="wait"
	elif phase=="wait_end":e.phase="return"
	e.preview=false;h.selected=unit_id();h.destination=Vector2i(99,99);g.save_game();h.show_map()
func draw_village():
	h.screen="village";h.clear()
	var scene=Control.new();scene.set_script(load("res://village.gd"));scene.host=h;scene.size=Vector2(1440,810);h.layer.add_child(scene)
	h.panel(h.layer,Rect2(0,0,1440,105),Color(0.025,0.07,0.05,0.9))
	h.header("VOTRE VILLAGE · "+g.fname(g.s.human),"Première expédition · rapporter un cristal")
	h.panel(h.layer,Rect2(28,126,690,110),Color(0.025,0.07,0.05,0.88))
	h.label(h.layer,"Un cristal attend votre royaume.",Rect2(48,140,650,40),30,h.GOLD)
	h.label(h.layer,"Envoyez votre éclaireur le chercher, puis rapportez-le au sanctuaire.",Rect2(48,185,650,44),21)
	h.button(h.layer,"Éclaireur 1 · prêt à partir",Rect2(260,590,340,58),begin)
	h.panel(h.layer,Rect2(24,690,1392,100),Color(0.025,0.07,0.05,0.96))
	h.label(h.layer,"Une action à la fois. Le guide vous accompagne sur la carte.",Rect2(46,709,790,56),24)
	h.button(h.layer,"Partir avec mon éclaireur",Rect2(960,710,432,60),begin)
	h.button(h.layer,"Réserves et partie sans guide",Rect2(995,128,397,50),h.show_setup)
	h.transition_in()
func draw_map():
	h.screen="map";h.clear()
	var guided_now=active()
	if guided_now:h.selected=unit_id()
	var f=int(g.s.human);var ready=g.s.turn==f
	h.mapview=Control.new();h.mapview.set_script(load("res://map.gd"));h.mapview.host=h;h.mapview.size=Vector2(1440,810);h.mapview.center=Vector2(720,405);h.mapview.radius=29;h.mapview.target=target() if guided_now else h.destination;h.layer.add_child(h.mapview)
	if guided_now:
		var center_cell=(Vector2(g.pos(g.s.units[h.selected]))+Vector2(target()))/2
		var span=h.mapview.world(Vector2(target()))-h.mapview.world(Vector2(g.pos(g.s.units[h.selected])))
		h.map_zoom=minf(2.4,minf(300.0/maxf(absf(span.y),1.0),680.0/maxf(absf(span.x),1.0)));h.map_pan=Vector2(770,435)-h.mapview.center-h.mapview.world(center_cell)*h.map_zoom
	h.panel(h.layer,Rect2(0,0,1440,100),Color(0.025,0.07,0.06,0.94))
	h.header("LA QUÊTE DES CRISTAUX", "%s · Manche %d · %s"%[g.fname(f),g.s.round,"À vous de jouer" if ready else g.fname(g.s.turn)+" joue…"])
	h.panel(h.layer,Rect2(24,112,650,63),Color(0.025,0.07,0.06,0.94))
	h.label(h.layer,"Objectif : rapporter les cristaux · %d / 5"%g.s.factions[f].crystals.size(),Rect2(42,125,620,40),25,h.GOLD)
	if not guided_now:
		for k in range(3):
			var uid=f*3+k;var u=g.s.units[uid]
			h.button(h.layer,"%s · %d pas · %d R"%[["Éclaireur 1","Éclaireur 2","Messager"][k],u.mp,u.money],Rect2(24,186+k*58,295,50),func():h.select_unit(uid),not u.alive)
	else:
		var u=g.s.units[h.selected]
		h.label(h.layer,"Éclaireur %d · %d pas · %d R"%[int(u.k)+1,u.mp,u.money],Rect2(42,185,580,38),23)
		h.label(h.layer,"Découverte : les autres royaumes attendent.",Rect2(42,225,680,36),19,h.GOLD)
	h.button(h.layer,"Vue générale",Rect2(1190,112,224,48),func():h.map_zoom=1.0;h.map_pan=Vector2.ZERO)
	h.button(h.layer,"Recentrer",Rect2(1190,168,224,48),func():
		if guided_now:h.show_map()
		else:h.focus_map(g.pos(g.s.units[h.selected])) if h.selected>=0 else h.focus_map(g.BASES[f])
	)
	h.button(h.layer,"−",Rect2(1298,224,52,48),func():h.mapview.zoom_at(1.0/1.2,h.mapview.size/2))
	h.button(h.layer,"+",Rect2(1362,224,52,48),func():h.mapview.zoom_at(1.2,h.mapview.size/2))
	if guided_now:
		var c=copy();h.panel(h.layer,Rect2(24,640,1392,150),Color(0.025,0.07,0.06,0.97))
		h.label(h.layer,c[0],Rect2(44,654,900,42),28,h.GOLD)
		h.label(h.layer,c[1],Rect2(44,703,900,74),22)
		if c[2]!="":h.button(h.layer,c[2],Rect2(980,687,410,65),primary)
	else:
		h.panel(h.layer,Rect2(24,650,1392,140),Color(0.025,0.07,0.06,0.97))
		var note=h.travel_preview().compact if h.selected>=0 and g.s.cells.has(g.key(h.destination)) and h.destination!=g.pos(g.s.units[h.selected]) else h.contextual_hint()
		h.label(h.layer,note,Rect2(44,665,820,105),21)
		h.button(h.layer,"Déplacer ici",Rect2(910,668,228,50),h.move_selected,not ready or h.selected<0 or not g.s.cells.has(g.key(h.destination)))
		h.button(h.layer,"Terminer le tour",Rect2(1152,668,240,50),h.end_turn,not ready or g.pending_human()>=0)
		h.button(h.layer,"Village",Rect2(910,730,145,44),h.show_village)
		h.button(h.layer,"Actions",Rect2(1065,730,145,44),actions)
		h.button(h.layer,"Conseil",Rect2(1220,730,172,44),h.show_next_help)
	h.attach_event_label()
	if int(g.s.winner)>=0:h.show_victory()
func actions():
	var m=h.overlay("Vos actions sur le monde")
	var callbacks=[h.show_interactions,h.show_transfer,h.show_conflicts,h.show_diplomacy,h.show_log,h.open_supply_flow]
	var names=["Interactions / attaquer","Partager mes ressources","Ouvrir mes combats","Négocier un pacte","Journal des événements","Ravitailler un éclaireur"]
	for i in range(6):h.button(m,names[i],Rect2(210+(i%2)*510,185+int(i/2)*135,480,92),callbacks[i])
