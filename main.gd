extends Control
const Advisor=preload("res://advisor.gd")
var battle_selected_line=-1
var map_full=false
var guide_folded=false
var camera_tween:Tween
var map_zoom=1.0
var map_pan=Vector2.ZERO
var effects=true
var pace=1.0
var audio
var previous_units=[]
var journeys={}
var event_text=""
var event_time=0.0
var event_label:Label
var last_log_count=0
var previous_battles=[]
var elapsed=0.0
var observation_clock=0.0
var game=preload("res://state.gd").new()
var layer:Control
var modal:Control
var screen="menu"
var selected=-1
var destination=Vector2i(99,99)
var bid=-1
var ai_moved=false
var ai_clock=0.0
var paused=false
var message=""
var mapview
var deploy_a:SpinBox
var deploy_b:SpinBox
var hero_checks=[]
var deploy_price:Label
var deployment_error=""
var tutorial_step=0
var tutorial_mode=false
var portrait=preload("res://assets/factions.png")
var hero_art=preload("res://assets/heroes.png")
var troop_art=preload("res://assets/troops.png")
var world=preload("res://assets/world.png")
const GOLD=Color("e2bf7e")
const WHITE=Color("eaf1f4")
const MUTED=Color("a8bbc7")
const BG=Color("0b1420")
const TIPS=[
["Votre royaume","Vous contrôlez une faction et deux éclaireurs. Les cinq autres factions sont jouées par l’ordinateur. Objectif : ramener les cinq cristaux au village, ou rester la dernière faction debout."],
["Répartir les ressources","Vous commencez avec 2 000 R réparties entre village, éclaireur 1, éclaireur 2 et messager. Le messager porte au maximum 400 R. Le bouton Ressources permet les transferts sur une même case."],
["Explorer la carte","1. Touchez « Éclaireur 1 » à droite.\n2. Touchez une case dans les contours clairs.\n3. Touchez « Déplacer ici » pour confirmer.\n\nCherchez les cristaux violets, puis rapportez-les à votre village entouré en blanc. Les points dorés donnent 200 ressources."],
["Ramener un cristal","Un cristal arrête le déplacement et immobilise l’éclaireur au prochain tour. Ensuite il avance de 4 cases, avec 2 cristaux maximum. Retour au village : dépôt automatique et prime de 400 R au premier dépôt de ce cristal."],
["Déclarer une guerre","Sélectionnez votre éclaireur puis touchez un adversaire : le panneau propose l’attaque à 4 cases maximum. Elle coûte 20 R. Un village peut être assiégé depuis une case adjacente. Chaque conflit a son plateau distinct."],
["Préparer une armée","Déployez au moins 2 fantassins et 2 cavaliers. Les héros sont facultatifs, mais un héros ne peut être engagé que sur un plateau à la fois. Gardez des ressources pour payer vos attaques !"],
["Combattre à son tour","Chaque camp agit à son tour de faction, en alternance. La première attaque vient de l’infanterie. Les dégâts restent sur la ligne ciblée jusqu’à sa destruction ; les statistiques ne baissent pas à chaque coup."],
["Dons, cartes et repli","Les commandes du plateau donnent accès aux cartes, aux soins et aux dons. Une ligne ordinaire tombée peut être redéployée une fois. Un repli coûte 20 R et cède les cristaux : il renvoie l’éclaireur sur la carte."],
["Revenir quand vous voulez","Le bouton Aide reste accessible pendant la partie. La partie est sauvegardée après les actions et les tours. Terminer le tour fait jouer les cinq adversaires. Consultez les conflits avant de passer !"]]
func _ready():
	get_tree().auto_accept_quit=false
	load_preferences()
	audio=Node.new();audio.set_script(preload("res://ambience.gd"));add_child(audio)
	var prefs=ConfigFile.new()
	if prefs.load("user://preferences.cfg")==OK:
		audio.music_volume=float(prefs.get_value("audio","music",0.35));audio.fx_volume=float(prefs.get_value("audio","fx",0.65));audio.apply_volume()
	make_theme()
	show_menu()
	var args=OS.get_cmdline_user_args()
	if "--test-factions" in args:show_factions()
	if "--test-map" in args:game.new_game(0,42);game.s.setup=false;selected=0;show_map()
	if "--test-battle" in args:
		game.new_game(0,42);game.s.setup=false;game.s.units[3].q=1;game.s.units[3].r=-8;game.declare_war(0,3);bid=0;show_battle()
	if "--test-ready" in args:
		game.new_game(1,42);game.s.turn=1;game.s.setup=false;game.s.units[0].q=8;game.s.units[0].r=-8;game.declare_war(3,0);bid=0;game.deploy(0,0,6,4,[0,1,2]);show_battle()
	if "--test-guide" in args:
		game.new_game(2,42);start_play(true)
	if "--test-guide-select" in args:
		game.new_game(2,42);start_play(true);game.s.onboarding.step=2;selected=6;show_map()
	if "--test-tutorial" in args:tutorial_step=2;show_tutorial()
	if "--test-discovery-resources" in args:begin_game(2);start_play(true)
	if "--test-discovery-transfer" in args:begin_game(2);start_play(true);close_modal();show_transfer()
	if "--test-discovery-map" in args:
		game.new_game(2,42);game.s.setup=false;game.s.turn=2;game.start_turn();game.s.discovery={"active":true,"phase":2};selected=-1;show_map()
	if "--test-discovery-diplomacy" in args:
		game.new_game(2,42);game.s.setup=false;game.s.turn=2;game.start_turn();game.s.discovery={"active":true,"phase":9};selected=-1;show_map()
	if "--test-deploy06" in args:
		game.new_game(1,42);game.s.turn=1;game.s.setup=false;game.start_turn();game.s.units[0].q=8;game.s.units[0].r=-8;game.declare_war(3,0);bid=0;show_battle();show_deploy();apply_composition(2)
	if "--test-preview06" in args:
		game.new_game(0,42);game.s.setup=false;game.s.units[3].q=1;game.s.units[3].r=-8;game.declare_war(0,3);bid=0;game.deploy(0,0,6,4,[]);show_battle();show_attack_preview(0,0)
	if "--test-village" in args:begin_game(0)
	if "--test-village-orcs" in args:begin_game(4)
	if "--test-expedition" in args:begin_game(0);start_first_chapter();game.s.onboarding.step=2;selected=0;show_map();frame_expedition()
	if "--test-chapters" in args:
		begin_game(3);game.s.setup=false;game.s.discovery={"active":true,"phase":11};game.s["first_expedition_done"]=true;show_village()
	if "--test-settings" in args:show_settings()
	if "--test-wide" in args:game.new_game(3,42);game.s.setup=false;selected=9;map_full=true;show_map()
	if "--capture" in args:call_deferred("capture_test")
func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST or what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(modal):close_modal()
		else:game.save_game();show_menu()
func style(color:Color,border:Color=Color("294050"))->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=border
	s.set_border_width_all(1);s.set_corner_radius_all(10);s.content_margin_left=14;s.content_margin_right=14
	return s
func make_theme():
	var th=Theme.new();th.default_font_size=20
	th.set_color("font_color","Label",WHITE);th.set_color("font_color","Button",WHITE)
	th.set_stylebox("normal","Button",style(Color("1c3040")))
	th.set_stylebox("hover","Button",style(Color("304a5c"),GOLD))
	th.set_stylebox("pressed","Button",style(Color("435a63"),GOLD))
	th.set_stylebox("disabled","Button",style(Color("121d29")))
	th.set_color("font_disabled_color","Button",Color("586572"))
	th.set_stylebox("normal","LineEdit",style(Color("1c3040")))
	th.set_color("font_color","LineEdit",WHITE)
	th.set_font_size("font_size","SpinBox",22)
	theme=th
func clear():
	if is_instance_valid(layer):remove_child(layer);layer.queue_free()
	layer=Control.new();layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(layer)
	var bg=ColorRect.new();bg.color=BG;bg.size=Vector2(1440,810);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(bg)
	mapview=null
func panel(parent:Control,r:Rect2,color=Color("111f2e"))->Panel:
	var p=Panel.new();p.position=r.position;p.size=r.size;p.add_theme_stylebox_override("panel",style(color));parent.add_child(p);return p
func label(parent:Control,text:String,r:Rect2,font=20,color=WHITE)->Label:
	var l=Label.new()
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",font)
	l.add_theme_color_override("font_color",color)
	l.text=text
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position=r.position;l.size=r.size
	return l
func button(parent:Control,text:String,r:Rect2,fn:Callable,disabled=false)->Button:
	var b=Button.new();b.text=text;b.position=r.position;b.size=r.size;b.disabled=disabled;b.pressed.connect(func():audio.cue();fn.call());parent.add_child(b);return b
func art(parent:Control,texture:Texture2D,f:int,r:Rect2):
	var at=AtlasTexture.new();at.atlas=texture
	at.region=Rect2(12+(f%2)*594,[85,490,905][int(f/2)],570,365)
	var crop=Control.new();crop.position=r.position;crop.size=r.size;crop.clip_contents=true;crop.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(crop)
	var tr=TextureRect.new();tr.texture=at;tr.position=Vector2.ZERO;tr.size=r.size;tr.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tr.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;tr.mouse_filter=Control.MOUSE_FILTER_IGNORE;crop.add_child(tr)
func header(title:String,subtitle:String):
	label(layer,title,Rect2(28,16,1080,44),30,GOLD)
	label(layer,subtitle,Rect2(28,61,1100,30),18,MUTED)
	button(layer,"Son",Rect2(1132,24,56,48),show_settings)
	button(layer,"Aide",Rect2(1200,24,92,48),func():show_help())
	button(layer,"Menu",Rect2(1304,24,108,48),func():game.save_game();show_menu())
func show_menu():
	screen="menu";clear()
	var tr=TextureRect.new();tr.texture=world;tr.position=Vector2(0,-240);tr.size=Vector2(1440,1600);tr.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tr.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;tr.modulate=Color(0.4,0.45,0.5);layer.add_child(tr)
	panel(layer,Rect2(70,100,660,610),Color(0.035,0.07,0.11,0.95))
	label(layer,"LA QUÊTE\nDES CRISTAUX",Rect2(110,140,580,145),52,GOLD)
	label(layer,"Six peuples. Un monde à conquérir.",Rect2(112,300,570,45),24)
	label(layer,"VERSION 0.6 · VOS DÉCISIONS PRENNENT VIE",Rect2(112,350,570,35),17,MUTED)
	button(layer,"Nouvelle partie",Rect2(112,410,530,62),show_factions)
	button(layer,"Reprendre la partie",Rect2(112,488,530,62),func():
		if game.load_game():
			selected=int(game.s.human)*3;ai_moved=game.s.get("ai_wait",false)
			show_village()
	,not FileAccess.file_exists(game.SAVE))
	button(layer,"Tutoriel et règles",Rect2(112,566,530,62),func():tutorial_step=0;show_tutorial())
	button(layer,"Réglages",Rect2(112,635,180,46),show_settings)
	add_atmosphere()
	label(layer,"Mode solo • hors connexion • sauvegarde locale",Rect2(312,646,380,44),17,MUTED)
func show_factions():
	screen="factions";clear();header("Choisissez votre faction","Les cinq autres peuples seront dirigés par l’ordinateur.")
	for f in range(6):
		var x=28+(f%3)*465;var y=110+int(f/3)*333
		panel(layer,Rect2(x,y,450,315),Color(0.06,0.11,0.16));art(layer,portrait,f,Rect2(x+8,y+8,434,140))
		atlas_art(layer,preload("res://assets/capitals.png"),f,3,2,Rect2(x+326,y+65,106,98))
		label(layer,game.fname(f),Rect2(x+16,y+151,415,30),25,game.faction_color(f))
		label(layer,Advisor.STYLES[f][0]+"\n"+Advisor.STYLES[f][1],Rect2(x+16,y+186,418,66),17,MUTED)
		button(layer,"Choisir ce peuple",Rect2(x+16,y+260,418,44),func():begin_game(f))
	add_atmosphere()
	transition_in()
func begin_game(f:int):
	previous_units=[];previous_battles=[];journeys.clear();last_log_count=0;map_zoom=1.0;map_pan=Vector2.ZERO
	game.new_game(f);audio.music.pitch_scale=[1.0,0.89,0.75,1.12,0.8,0.94][f];selected=f*3;ai_moved=false;destination=Vector2i(99,99);message="";tutorial_mode=true
	show_village()
func show_setup():
	screen="setup";clear();header("Préparez votre royaume",game.fname(game.s.human)+" · 2 000 ressources initiales")
	art(layer,portrait,game.s.human,Rect2(30,120,650,420))
	atlas_art(layer,preload("res://assets/capitals.png"),int(game.s.human),3,2,Rect2(435,355,240,200))
	add_atmosphere()
	label(layer,"Vos 2 000 ressources sont réparties entre quatre réserves. Le village finance sa défense ; chaque éclaireur finance ses combats ; le messager les ravitaille.\nChoisissez votre répartition, puis partez chercher votre premier cristal. Le ravitaillement et la diplomatie se découvrent ensuite, à votre rythme.",Rect2(40,568,620,130),24)
	for k in range(4):
		var ref="b%d"%game.s.human if k==0 else "u%d"%(int(game.s.human)*3+k-1)
		label(layer,["Village","Éclaireur 1","Éclaireur 2","Messager (400 R max.)"][k],Rect2(740,135+k*92,430,32),24,GOLD)
		label(layer,"%d R"%game.reserve_money(ref),Rect2(1190,135+k*92,170,36),26)
	button(layer,"Ajuster les réserves",Rect2(740,530,620,62),show_transfer)
	button(layer,"Commencer avec le guide",Rect2(740,610,620,64),start_first_chapter)
	button(layer,"Jouer sans guide",Rect2(740,690,620,52),func():start_play(false);enter_world())
	label(layer,"Premier chapitre : préparer un éclaireur et rapporter un cristal.",Rect2(740,565,620,38),18,MUTED)
	transition_in()
func show_map():
	screen="map";clear()
	if game.s.is_empty():show_menu();return
	if guided() and int(game.s.onboarding.step) in [3,7]:destination=guide_target()
	header("LA QUÊTE DES CRISTAUX", "Manche %d · %s · %s"%[game.s.round,game.fname(game.s.human),"À vous de jouer" if game.s.turn==game.s.human else game.fname(game.s.turn)+" joue…"])
	for f in range(6):
		var x=28+f*166
		panel(layer,Rect2(x,102,157,48),Color("263e47") if game.s.turn==f else Color("111f2e"))
		label(layer,"%d %s  %d/5"%[f+1,["Elfes","Nains","Armemor","Ilunor","Orcs","Cèleras"][f],game.s.factions[f].crystals.size()],Rect2(x+6,108,146,34),14,game.faction_color(f) if game.s.factions[f].alive else MUTED)
	mapview=Control.new();mapview.set_script(preload("res://map.gd"));mapview.host=self;mapview.position=Vector2(20,304 if has_coach() and not guide_folded else 154);mapview.size=Vector2(1000,440 if has_coach() and not guide_folded else 650);mapview.target=destination
	if has_coach() and not guide_folded:mapview.radius=15.5;mapview.center=Vector2(500,232)
	if map_full and not has_coach():mapview.size=Vector2(1400,650);mapview.center=Vector2(580,320)
	layer.add_child(mapview)
	button(layer,"−",Rect2(850,308 if has_coach() and not guide_folded else 158,48,44),func():mapview.zoom_at(1.0/1.2,mapview.size/2))
	button(layer,"+",Rect2(906,308 if has_coach() and not guide_folded else 158,48,44),func():mapview.zoom_at(1.2,mapview.size/2))
	button(layer,"Vue",Rect2(962,308 if has_coach() and not guide_folded else 158,62,44),func():map_zoom=1.0;map_pan=Vector2.ZERO)
	panel(layer,Rect2(28,752,990,44),BG)
	button(layer,"Village",Rect2(28,752,118,44),show_village)
	button(layer,"Centrer E1",Rect2(154,752,138,44),func():focus_map(game.pos(game.s.units[int(game.s.human)*3])))
	button(layer,"Centrer E2",Rect2(300,752,138,44),func():focus_map(game.pos(game.s.units[int(game.s.human)*3+1])))
	button(layer,"Carte étendue" if not map_full else "Commandes",Rect2(446,752,190,44),func():map_full=not map_full;map_pan=Vector2.ZERO;show_map(),has_coach())
	var sidebar_start=layer.get_child_count()
	panel(layer,Rect2(1040,102,372,687))
	label(layer,"VOTRE EXPÉDITION",Rect2(1056,114,340,30),21,GOLD)
	for k in range(3):
		var uid=int(game.s.human)*3+k;var u=game.s.units[uid]
		button(layer,"%s · %d R · %d pas"%[["Éclaireur 1","Éclaireur 2","Messager"][k],u.money,u.mp],Rect2(1056,156+k*53,340,47),func():select_unit(uid),not u.alive or (guided() and uid!=int(game.s.onboarding.uid)) or not coach_unit_allowed(uid))
	var u=game.s.units[selected] if selected>=0 else {}
	var summary="Sélectionnez un éclaireur."
	if not u.is_empty():summary="%s · %d cristal(s)\n%s"%[["Éclaireur 1","Éclaireur 2","Messager"][u.k],u.crystals.size(),"Engagé dans le conflit %d"%(int(u.battle)+1) if u.battle>=0 else "Disponible · réserve indépendante"]
	label(layer,summary,Rect2(1056,320,340,64),19)
	if game.s.cells.has(game.key(destination)):
		label(layer,"%s · trajet %d pas"%[game.TERRAIN[game.terrain_at(destination)],game.path(game.pos(u),destination).size() if not u.is_empty() else 0],Rect2(1056,388,340,32),18,GOLD)
		button(layer,"Déplacer ici",Rect2(1056,426,162,46),move_selected,game.s.turn!=game.s.human or selected<0 or (guided() and int(game.s.onboarding.step) not in [3,7]) or (coach_paused() and coach_phase() not in [4,7]))
		button(layer,"Interactions",Rect2(1228,426,168,46),show_interactions,guided() or coach_paused())
	else:label(layer,"Touchez une case pour explorer.",Rect2(1056,393,340,60),19,MUTED)
	button(layer,"Ressources",Rect2(1056,488,162,46),show_transfer,guided() or (coach_paused() and coach_phase()!=8))
	button(layer,"Conflits",Rect2(1228,488,168,46),show_conflicts,guided() or coach_paused())
	button(layer,"Diplomatie",Rect2(1056,545,162,46),show_diplomacy,guided() or (coach_paused() and coach_phase()!=9))
	button(layer,"Journal",Rect2(1228,545,168,46),show_log)
	var route_note=message if message!="" else contextual_hint()
	if selected>=0 and game.s.cells.has(game.key(destination)) and destination!=game.pos(game.s.units[selected]):route_note=travel_preview().compact
	label(layer,route_note,Rect2(1056,603,340,100),16,MUTED)
	button(layer,"Terminer le tour",Rect2(1056,710,340,60),end_turn,game.s.turn!=game.s.human or game.s.winner>=0 or game.pending_human()>=0)
	if game.s.has("supply_target") and not guided() and not coach_paused():button(layer,"Poursuivre ravitaillement",Rect2(650,752,368,44),func():supply_to(int(game.s.supply_target)),game.s.turn!=game.s.human)
	else:label(layer,"Cristaux → village  ·  Or : 200 R",Rect2(650,759,365,34),14,MUTED)
	if map_full and not has_coach():
		for i in range(sidebar_start,layer.get_child_count()):layer.get_child(i).hide()
		for k in range(3):
			var uid=int(game.s.human)*3+k
			button(layer,["Éclaireur 1","Éclaireur 2","Messager"][k],Rect2(1040,156+k*56,355,48),func():select_unit(uid))
		button(layer,"Déplacer ici",Rect2(1040,335,355,52),move_selected,selected<0 or not game.s.cells.has(game.key(destination)) or game.s.turn!=game.s.human)
		button(layer,"Interactions",Rect2(1040,398,355,52),show_interactions)
		if selected>=0 and game.s.cells.has(game.key(destination)):
			panel(layer,Rect2(1040,465,355,220),Color(0.05,0.1,0.15,0.94));label(layer,travel_preview().compact,Rect2(1055,480,325,190),19,MUTED)
		button(layer,"Terminer le tour",Rect2(1040,710,355,60),end_turn,game.s.turn!=game.s.human or game.pending_human()>=0)
	if has_coach() and guide_folded:button(layer,"Afficher ma consigne",Rect2(28,158,300,48),func():guide_folded=false;show_map();frame_expedition())
	elif guided():draw_guide()
	elif coach_active():draw_coach()
	else:button(layer,"Que faire maintenant ?",Rect2(28,156,278,44),show_next_help)
	attach_event_label()
	if int(game.s.winner)>=0:show_victory()
	elif not game.s.factions[game.s.human].alive:message="Votre village est tombé. Vous pouvez suivre la fin de la partie."
func pick_cell(p:Vector2i):
	if coach_paused():
		if coach_phase() not in [3,6]:return
		if p!=coach_target():message="Touchez la case entourée en doré, puis Déplacer ici.";show_map();return
		game.s.discovery.phase+=1
	if guided():
		var step=int(game.s.onboarding.step)
		if step not in [2,6]:return
		if p!=guide_target():
			message="Touchez la case entourée en doré sur la carte.";show_map();return
		game.s.onboarding.step=3 if step==2 else 7
		game.save_game()
	destination=p
	if selected<0:
		for uid in range(game.s.units.size()):
			if game.s.units[uid].f==game.s.human and game.pos(game.s.units[uid])==p:selected=uid;break
	show_map()
func act(fn:Callable,confirmed:bool=false):
	if screen=="battle" and not confirmed and not game.battle_by_id(bid).is_empty() and game.battle_by_id(bid).sides[game.side_index(game.battle_by_id(bid),game.s.human)].deployed and not game.s.get("combat_phase",false) and game.s.turn==game.s.human:
		var remaining=0
		for u in game.s.units:
			if u.f==game.s.human and u.alive and u.battle<0 and u.mp>0:remaining+=1
		if remaining>0:
			var m=overlay("Passer aux actions de guerre ?")
			rich(m,"%d pion(s) peuvent encore se déplacer. Une action de guerre terminera vos déplacements et vos transferts ordinaires pour ce tour.\n\nVous pouvez revenir à la carte pour les jouer, ou confirmer votre décision."%remaining,Rect2(205,175,1000,360))
			button(m,"Revenir aux déplacements",Rect2(205,620,480,62),func():close_modal();enter_world())
			button(m,"Confirmer mon action",Rect2(730,620,480,62),func():close_modal();act(fn,true));return
	if not fn.call():message=game.error;show_notice("Action impossible",message);return
	message=""
	if coach_active() and screen=="battle":
		var battle=game.battle_by_id(bid);var side=game.side_index(battle,game.s.human)
		if side>=0 and battle.sides[side].deployed and (battle.active!=side or battle.done):game.s.discovery.first_attack=true
	game.save_game()
	if screen=="battle":show_battle()
	elif screen=="setup":show_setup()
	elif screen=="village":show_village()
	else:show_map()
func end_turn():
	var from_village=screen=="village"
	if coach_paused():
		if coach_phase()!=10:show_coach_step();return
		game.s.discovery.phase=11
	if guided():
		var step=int(game.s.onboarding.step)
		if step not in [4,5,8]:
			show_notice("Une étape à terminer",guide_copy()[1]);return
		for _i in range(6):game.advance_turn()
		game.s.onboarding.step=5 if step==4 else (2 if game.s.units[game.s.onboarding.uid].crystals.is_empty() else 6)
		destination=Vector2i(99,99);game.save_game();show_map();frame_expedition();return
	game.advance_turn();ai_moved=false;game.save_game();message=""
	if from_village:show_village()
	else:show_map()
func _process(delta):
	elapsed+=delta
	observation_clock+=delta
	if observation_clock>=0.08 and screen in ["map","battle","village"]:
		observe_changes(observation_clock);observation_clock=0.0
	if is_instance_valid(deploy_price):update_deploy_price()
	if screen not in ["map","battle","village"] or game.s.is_empty() or game.s.setup or paused or is_instance_valid(modal):return
	if game.s.winner>=0:return
	if guided() or coach_paused():return
	var pending=game.pending_human()
	if pending>=0:
		bid=pending;show_battle()
		if coach_active() and not game.s.discovery.get("combat_intro",false):coach_combat_intro()
		else:show_deploy()
		return
	if game.s.turn==game.s.human and game.s.factions[game.s.human].alive:return
	ai_clock+=delta
	if ai_clock<1.25/pace:return
	ai_clock=0
	if not ai_moved:
		game.ai_move(game.s.turn);ai_moved=true;game.s.ai_wait=true;game.save_game()
		if screen=="map":show_map()
		elif screen=="village":show_village()
		return
	game.ai_combat(game.s.turn);game.advance_turn();ai_moved=false;game.s.ai_wait=false;game.save_game()
	if screen=="battle":show_battle()
	elif screen=="village":show_village()
	else:show_map()
func overlay(title:String)->Control:
	close_modal();modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(modal)
	var shade=ColorRect.new();shade.color=Color(0,0,0,0.8);shade.size=Vector2(1440,810);modal.add_child(shade)
	panel(modal,Rect2(160,55,1120,700),Color("132231"))
	label(modal,title,Rect2(190,75,910,66),28,GOLD)
	button(modal,"Fermer",Rect2(1130,76,120,46),close_modal)
	return modal
func close_modal():
	if is_instance_valid(modal):remove_child(modal);modal.queue_free()
	modal=null;deploy_price=null
func show_notice(title:String,body:String):
	var m=overlay(title);rich(m,body,Rect2(205,165,1010,520))
func show_transfer(source_ref:String="",target_ref:String=""):
	if coach_paused() and coach_phase()!=8:show_coach_step();return
	var m=overlay("Transférer des ressources")
	var a=OptionButton.new();var b=OptionButton.new();var refs=[]
	for k in range(4):
		var ref="b%d"%game.s.human if k==0 else "u%d"%(int(game.s.human)*3+k-1);refs.append(ref)
		var title="%s · %d R"%[["Village","Éclaireur 1","Éclaireur 2","Messager"][k],game.reserve_money(ref)]
		a.add_item(title);b.add_item(title)
	if refs.has(source_ref):a.selected=refs.find(source_ref)
	a.position=Vector2(205,230);a.size=Vector2(440,55);m.add_child(a)
	b.position=Vector2(760,230);b.size=Vector2(440,55);b.selected=refs.find(target_ref) if refs.has(target_ref) else 1;m.add_child(b)
	label(m,"DEPUIS",Rect2(205,185,440,36),23,GOLD);label(m,"VERS",Rect2(760,185,440,36),23,GOLD)
	var amount=SpinBox.new();amount.min_value=1;amount.max_value=10000;amount.step=1;amount.value=100;amount.position=Vector2(500,350);amount.size=Vector2(380,60);m.add_child(amount)
	var plan=coach_transfer_plan() if coach_active() and coach_phase() in [0,8] else {}
	if not plan.is_empty():
		a.selected=refs.find(plan.source);b.selected=refs.find(plan.target);amount.value=plan.amount
		label(m,"ÉTAPE GUIDÉE : vérifiez le départ, l’arrivée et le montant, puis validez.",Rect2(205,135,1000,40),20,GOLD)
	label(m,"Sur une même case uniquement. Le messager porte au maximum 400 R.\nLes ressources d’un éclaireur engagé financent directement son conflit.",Rect2(205,445,1000,100),23)
	if source_ref!="":amount.value=mini(100,game.reserve_money(source_ref))
	var preview=label(m,"",Rect2(205,545,1000,66),22,GOLD)
	var update_preview=func(_value=0):preview.text="Après transfert : %s → %d R   |   %s → %d R"%[reserve_title(refs[a.selected]),game.reserve_money(refs[a.selected])-int(amount.value),reserve_title(refs[b.selected]),game.reserve_money(refs[b.selected])+int(amount.value)]
	a.item_selected.connect(update_preview);b.item_selected.connect(update_preview);amount.value_changed.connect(update_preview);update_preview.call()
	button(m,"Effectuer le transfert",Rect2(420,620,600,62),func():
		if not plan.is_empty() and (refs[a.selected]!=plan.source or refs[b.selected]!=plan.target or int(amount.value)!=int(plan.amount)):
			show_notice("Suivez le transfert proposé",coach_transfer_text(plan)+"\n\nFermez cette fenêtre puis rouvrez Ressources pour retrouver les valeurs proposées.");return
		var ok=game.transfer(refs[a.selected],refs[b.selected],int(amount.value),game.s.setup)
		if not ok:show_notice("Transfert impossible",game.error)
		else:
			close_modal();game.save_game()
			if screen=="setup":show_setup()
			elif screen=="village":show_village()
		if ok and not plan.is_empty():
			if coach_phase()==8 and game.s.get("chapter_mode",false):
				game.s.discovery.phase=11;game.s["supply_learned"]=true;game.save_game();show_village();show_notice("Ravitaillement réussi", "Les ressources sont arrivées à votre éclaireur. Vous pouvez repartir explorer ou découvrir un pacte de non-agression depuis le village.");return
			game.s.discovery.phase=1 if coach_phase()==0 else 9;game.save_game()
			if screen!="setup":show_map()
			show_coach_step()
		elif ok and screen not in ["setup","village"]:show_map()
	)
func show_interactions():
	var m=overlay("Sur cette case")
	var y=150;var found=false
	for uid in range(game.s.units.size()):
		var u=game.s.units[uid]
		if not u.alive or game.pos(u)!=destination:continue
		found=true
		label(m,"%s · %s · %d R · %d cristaux"%[game.fname(u.f),["E1","E2","Messager"][u.k],u.money,u.crystals.size()],Rect2(205,y,700,45),21)
		if u.battle>=0:button(m,"Voir le conflit",Rect2(950,y,250,44),func():close_modal();bid=int(u.battle);show_battle())
		elif u.f!=game.s.human and u.k<2:button(m,"Attaquer · 20 R",Rect2(950,y,250,44),func():start_war(uid,false))
		else:button(m,"Sélectionner",Rect2(950,y,250,44),func():selected=uid if u.f==game.s.human else selected;close_modal();show_map(),u.f!=game.s.human)
		y+=58
	for f in range(6):
		if game.BASES[f]!=destination:continue
		found=true;label(m,"Village des %s · %d R · %d cristaux"%[game.fname(f),game.s.factions[f].money,game.s.factions[f].crystals.size()],Rect2(205,y,700,55),22,GOLD)
		if f!=game.s.human:button(m,"Assiéger · 20 R",Rect2(950,y,250,48),func():start_war(f,true))
		y+=66
	if selected>=0:
		for battle in game.s.battles:
			if not battle.done and game.side_index(battle,game.s.human)>=0:
				button(m,"Rejoindre le conflit %d en renfort"%(int(battle.id)+1),Rect2(205,y,995,45),func():close_modal();act(func():return game.reinforce(selected,battle.id)));y+=52
	if not found:label(m,"Aucun pion ni village ici. Utilisez Déplacer pour rejoindre cette case.",Rect2(205,200,995,150),25)
func show_conflicts():
	var m=overlay("Plateaux de combat")
	var scroll=ScrollContainer.new();scroll.position=Vector2(205,150);scroll.size=Vector2(1020,545);m.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);scroll.add_child(list)
	for b in game.s.battles:
		var btn=Button.new();btn.text="#%d · %s / %s\n%s"%[int(b.id)+1,game.fname(b.sides[0].f),game.fname(b.sides[1].f),b.result if b.done else "Conflit en cours · pot %d R"%b.pot];btn.custom_minimum_size=Vector2(980,78);list.add_child(btn);btn.pressed.connect(func():close_modal();bid=b.id;show_battle())
	if game.s.battles.is_empty():label(m,"Aucun conflit pour le moment. Explorez et cherchez les cristaux.",Rect2(205,200,1000,100),25)
func show_battle():
	screen="battle";clear()
	var b=game.battle_by_id(bid)
	if b.is_empty():show_map();return
	var si=game.side_index(b,game.s.human)
	var scenery=TextureRect.new();scenery.texture=preload("res://assets/terrain.png");scenery.position=Vector2(0,100);scenery.size=Vector2(1440,610);scenery.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;scenery.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;scenery.modulate=Color(0.55,0.58,0.6);scenery.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(scenery)
	var regions=[Rect2(550,300,450,500),Rect2(30,20,600,500),Rect2(850,10,650,500),Rect2(0,500,700,500),Rect2(850,500,650,500)]
	var atlas=AtlasTexture.new();atlas.atlas=scenery.texture;atlas.region=regions[int(b.terrain)];scenery.texture=atlas
	header("CONFLIT %d · %s"%[bid+1,game.TERRAIN[b.terrain]],b.result if b.done else "Pot : %d R · Tour de %s · %s"%[b.pot,game.fname(game.s.turn),"ouverture par l’infanterie" if b.opening else "alternance des camps"])
	for camp in range(2):
		var sd=b.sides[camp];var f=int(sd.f);var x=28+camp*710
		panel(layer,Rect2(x,106,682,470),Color(0.04,0.08,0.12,0.78));art(layer,hero_art,f,Rect2(x+10,116,180,125))
		label(layer,game.fname(f)+(" · VOUS" if f==game.s.human else ""),Rect2(x+208,118,450,42),24,game.faction_color(f))
		label(layer,"%s · %d R disponibles\n%s"%["Village" if sd.base else "Éclaireur(s)",game.wallet(sd),"À ce camp d’agir" if b.active==camp and not b.done else "En attente"],Rect2(x+208,165,450,68),21)
		if not sd.deployed:label(layer,"Armée à déployer",Rect2(x+25,300,630,120),28,GOLD);continue
		for li in range(3):
			var line=sd.lines[li];var y=260+li*99
			panel(layer,Rect2(x+15,y,650,87),Color(0.1,0.16,0.22,0.60))
			if camp==si and li==battle_selected_line:highlight_coach(Rect2(x+13,y-2,654,91))

			label(layer,"%s ×%d"%[["Infanterie","Cavalerie","Héros"][li],line.n],Rect2(x+205,y+6,170,28),19,GOLD if line.hp>0 else MUTED)
			label(layer,"%d ATQ · %d R"%[line.atk,line.cost],Rect2(x+205,y+40,170,40),15,MUTED)
			var bar=ProgressBar.new();bar.position=Vector2(x+380,y+14);bar.size=Vector2(250,24);bar.max_value=maxi(1,int(line.max));bar.value=line.hp;bar.show_percentage=false;bar.add_theme_stylebox_override("background",style(Color("0a1520")));bar.add_theme_stylebox_override("fill",style(game.faction_color(f)));layer.add_child(bar)
			label(layer,"Défense %d / %d"%[line.hp,line.max],Rect2(x+380,y+44,250,28),19)
	var stage=Control.new();stage.set_script(preload("res://battle_stage.gd"));stage.host=self;stage.battle=b;stage.size=Vector2(1440,810);layer.add_child(stage)
	for camp in range(2):
		if not b.sides[camp].deployed:continue
		for li in range(3):
			var row_button=button(layer,"",Rect2(43+camp*710,260+li*99,650,87),func():
				if camp==si and game.can_act(b,si):battle_selected_line=li;show_battle();choose_attack(si,li)
				else:show_line_detail(camp,li)
			)
			row_button.add_theme_stylebox_override("normal",StyleBoxEmpty.new());row_button.add_theme_stylebox_override("hover",style(Color(1,0.85,0.5,0.08)));row_button.add_theme_stylebox_override("pressed",style(Color(1,0.85,0.5,0.14)))
	attach_event_label()
	button(layer,"← Carte",Rect2(28,720,200,62),show_map)
	button(layer,"Fin du tour",Rect2(240,720,230,62),end_turn,game.s.turn!=game.s.human or game.pending_human()>=0)
	if si<0:label(layer,"Conflit entre deux adversaires : observation.",Rect2(500,730,880,50),23,MUTED);return
	if not b.sides[si].deployed:
		button(layer,"Déployer mon armée",Rect2(500,720,600,62),show_deploy);return
	if b.done:label(layer,b.result,Rect2(500,720,880,62),25,GOLD);return
	var enabled=game.can_act(b,si)
	for li in range(3):
		button(layer,"Attaque : "+["infanterie","cavalerie","héros"][li],Rect2(28+li*283,596,271,53),func():battle_selected_line=li;show_battle();choose_attack(si,li),not enabled)
	button(layer,"Cartes",Rect2(885,596,240,53),show_cards,not enabled and not b.opening)
	button(layer,"Renfort / soin",Rect2(1140,596,272,53),show_powers,not enabled)
	button(layer,"Don de faction",Rect2(500,720,260,62),func():act(func():return game.use_don(bid,si)),not enabled)
	button(layer,"Paix",Rect2(775,720,170,62),func():act(func():return game.peace(bid,si)),not enabled)
	button(layer,"Repli · 20 R",Rect2(960,720,220,62),func():confirm_retreat(si),not enabled or b.sides[si].base)
	button(layer,"Épuisé",Rect2(1195,720,217,62),func():act(func():return game.concede_if_broke(bid,si)),not enabled)
	if coach_active():draw_battle_coach(b,si)
	label(layer,"Touchez une ligne pour voir son action. Une action par tour de faction ; les dépenses alimentent le pot.",Rect2(32,692,1340,24),16,MUTED)
func confirm_retreat(si:int):
	var m=overlay("Confirmer le repli")
	label(m,"Vous cédez les cristaux portés et le pot du conflit. Vous conservez votre réserve restante après les 20 R de repli et reculez sur une case voisine.",Rect2(205,200,1000,200),26)
	button(m,"Se replier",Rect2(430,580,580,65),func():close_modal();act(func():return game.retreat(bid,si)))
func spin(parent:Control,r:Rect2,minval:int,maxval:int,value:int)->SpinBox:
	var sp=SpinBox.new();sp.position=r.position;sp.size=r.size;sp.min_value=minval;sp.max_value=maxval;sp.value=value;parent.add_child(sp);return sp
func show_deploy():
	var b=game.battle_by_id(bid);var si=game.side_index(b,game.s.human)
	if si<0:return
	deployment_error=""
	var f=int(game.s.human);var m=overlay("Déployer l’armée · conflit %d"%(bid+1))
	label(m,"Infanterie",Rect2(205,240,300,35),24,GOLD);deploy_a=spin(m,Rect2(205,280,300,50),2,game.data.factions[f].lines[0].size(),2)
	label(m,"Cavalerie",Rect2(550,240,300,35),24,GOLD);deploy_b=spin(m,Rect2(550,280,300,50),2,game.data.factions[f].lines[1].size(),2)
	button(m,"−",Rect2(205,335,140,40),func():deploy_a.value-=1);button(m,"+",Rect2(365,335,140,40),func():deploy_a.value+=1)
	button(m,"−",Rect2(550,335,140,40),func():deploy_b.value-=1);button(m,"+",Rect2(710,335,140,40),func():deploy_b.value+=1)
	label(m,"Héros disponibles",Rect2(205,390,900,35),24,GOLD);hero_checks=[]
	for h in game.available_heroes(f):
		var cb=CheckBox.new();cb.text=game.data.factions[f].heroes[h][0];cb.position=Vector2(205+(h%3)*335,430+int(h/3)*44);cb.size=Vector2(325,42);m.add_child(cb);hero_checks.append([h,cb])
	for mode in range(3):
		button(m,["Économique","Offensive","Endurance"][mode],Rect2(205+mode*340,145,325,48),func():apply_composition(mode))
	label(m,"Suggestions modifiables : minimum / attaque / défense. Gardez une réserve pour agir.",Rect2(205,200,1000,43),18,MUTED)
	deploy_price=label(m,"",Rect2(205,530,1000,100),21)
	update_deploy_price()
	button(m,"Valider le déploiement",Rect2(205,640,750,60),func():
		var heroes=[]
		for pair in hero_checks:
			if pair[1].button_pressed:heroes.append(pair[0])
		if game.deploy(bid,si,int(deploy_a.value),int(deploy_b.value),heroes):close_modal();game.resolve_empty(b);game.save_game();show_battle()
		else:deployment_error=game.error
	)
	button(m,"Pas assez de R",Rect2(980,640,245,60),func():
		var cost=game.stats(f,0,2,b.terrain)[0]+game.stats(f,1,2,b.terrain)[0]
		if game.wallet(b.sides[si])<cost:game.resolve(b,1-si,"déploiement impossible");close_modal();game.save_game();show_battle()
		else:deployment_error="Vous pouvez déployer le minimum : 2 + 2."
	)
func update_deploy_price():
	var b=game.battle_by_id(bid);var si=game.side_index(b,game.s.human);var hs=[]
	for pair in hero_checks:
		if pair[1].button_pressed:hs.append(pair[0])
	var a=game.stats(game.s.human,0,int(deploy_a.value),b.terrain);var c=game.stats(game.s.human,1,int(deploy_b.value),b.terrain);var h=game.hero_stats(game.s.human,hs,b.terrain)
	deploy_price.text=deployment_error+"\n" if deployment_error!="" else ""
	var total=int(a[0]+c[0]+h[0]);var remaining=game.wallet(b.sides[si])-total
	deploy_price.text+="Déploiement : %d R · Réserve restante : %d R\nAttaque d’infanterie : %d R · cavalerie : %d R. "%[total,remaining,a[1],c[1]]
	if remaining<0:deploy_price.text+="Budget dépassé : réduisez l’armée."
	elif remaining<int(a[1]):deploy_price.text+="Attention : vous ne pourrez pas financer l’attaque d’ouverture."
	else:deploy_price.text+="Cette réserve finance %d attaque(s) d’infanterie au coût actuel."%int(remaining/maxi(1,int(a[1])))

func show_cards():
	var b=game.battle_by_id(bid);var si=game.side_index(b,game.s.human);var m=overlay("Vos cartes")
	var scroll=ScrollContainer.new();scroll.position=Vector2(205,145);scroll.size=Vector2(1020,440);m.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for k in range(game.s.factions[game.s.human].hand.size()):
		var c=game.data.cards[game.s.factions[game.s.human].hand[k]]
		var btn=Button.new();btn.text=c[0]+"\n"+c[1];btn.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;btn.custom_minimum_size=Vector2(980,94);list.add_child(btn)
		btn.pressed.connect(func():close_modal();act(func():return game.play_card(bid,si,k)))
	button(m,"Piocher · consomme l’action",Rect2(205,625,1015,64),func():close_modal();act(func():return game.draw_card(bid,si)),b.sides[si].drawn)
func show_powers():
	var b=game.battle_by_id(bid);var si=game.side_index(b,game.s.human);var f=int(game.s.human);var m=overlay("Renforts et pouvoirs")
	label(m,game.data.factions[f].don,Rect2(205,140,1000,90),21,GOLD)
	for li in range(2):
		var x=205+li*510
		label(m,["Infanterie","Cavalerie"][li],Rect2(x,250,480,35),24)
		var sp=spin(m,Rect2(x,295,190,55),2,game.data.factions[f].lines[li].size(),2)
		button(m,"Redéployer",Rect2(x+205,295,270,55),func():var n=int(sp.value);close_modal();act(func():return game.redeploy(bid,si,li,n)))
		if f==0:button(m,"Ancêtres · coût doublé",Rect2(x,365,475,52),func():var n=int(sp.value);close_modal();act(func():return game.redeploy(bid,si,li,n,true)))
	if f in [1,3]:
		for li in range(3):button(m,"Soigner "+["infanterie","cavalerie","héros"][li],Rect2(205+li*340,475,325,55),func():close_modal();act(func():return game.heal(bid,si,li)))
	if f==3:
		for spell in range(3):button(m,"Gardur · %d R / %d dégâts"%[[20,40,60][spell],[85,100,120][spell]],Rect2(205+spell*340,565,325,65),func():close_modal();act(func():return game.attack(bid,si,2,spell)))
func show_diplomacy():
	if coach_paused() and coach_phase()!=9:show_coach_step();return
	var m=overlay("Pacte de non-agression")
	label(m,"Dans cette version, l’accord disponible est une trêve : offrez 100 R depuis le village pour cinq manches sans nouveau conflit entre vous. Choisissez une faction ci-dessous. L’aide militaire entre alliés n’est pas encore disponible.",Rect2(205,145,1000,100),22)
	for f in range(6):
		if f==game.s.human:continue
		button(m,"%s · %s"%[game.fname(f),"trêve active" if game.truce(game.s.human,f) else "proposer 100 R"],Rect2(300,270+(f if f<game.s.human else f-1)*77,840,60),func():confirm_coach_truce(f),game.s.turn!=game.s.human or not game.s.factions[f].alive or game.truce(game.s.human,f))
func show_log():
	var m=overlay("Journal de la partie");var text=""
	for i in range(game.s.log.size()-1,-1,-1):text+=game.s.log[i]+"\n\n"
	rich(m,text,Rect2(205,145,1020,550))
func rich(parent:Control,text:String,r:Rect2):
	var rt=RichTextLabel.new()
	rt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rt.scroll_active=true;rt.fit_content=false
	rt.add_theme_font_size_override("normal_font_size",24)
	rt.text=text;parent.add_child(rt);rt.position=r.position;rt.size=r.size
	return rt
func show_help():
	if coach_active() and (guided() or coach_paused()):show_coach_step();return
	var m=overlay("Aide et règles de cette première version")
	button(m,"Lire les règles",Rect2(205,140,490,55),func():tutorial_step=0;show_tutorial())
	button(m,"Que faire maintenant ?",Rect2(715,140,505,55),show_next_help)
	var text="OBJECTIF\nRamener les cinq cristaux au village ou éliminer les cinq autres factions. Une faction est éliminée à la chute de son village.\n\nRESSOURCES\n2 000 R initiales : village 900, chaque éclaireur 500, messager 100. Toutes les réserves sont séparées. Transfert entre vos pions sur la même case. Messager limité à 400 R.\n\nCARTE\nÉclaireurs : 6 cases, 4 avec un cristal ; messager : 8. Une prise de cristal arrête le mouvement et immobilise au tour suivant. Deux cristaux maximum par éclaireur. Dépôt automatique au village, prime de 400 R au premier dépôt de chaque cristal.\n\nCOMBATS\nGuerre : 20 R, portée de 4 cases. Au moins 2 fantassins et 2 cavaliers. Une action par camp à son tour de faction, en alternance. L’attaquant ouvre avec son infanterie. La première ligne vivante reçoit les dégâts. Les dépenses vont au pot ; le vainqueur prend le pot et la réserve ennemie. Les éclaireurs vaincus retournent au village. Héros uniques, morts persistantes.\n\nREDÉPLOIEMENT\nUne fois par ligne ordinaire, après destruction, avec attaque immédiate payante. Illimité pour un village. Les Elfes peuvent utiliser les Ancêtres avec coût doublé. Renfort par le second éclaireur sur la même case.\n\nREPLI\n20 R, cristaux et pot cédés, réserve restante conservée. Déplacement vers une case voisine ; protection contre les éclaireurs adverses de ce conflit pendant deux de leurs tours.\n\nADAPTATIONS ACTUELLES À VALIDER\nCarte fixe de 271 hexagones inspirée des plateaux physiques ; ce n’est pas une reproduction case par case. Pas de portails ni de mode objectifs. Siège depuis toute case adjacente. Héros individuels pour Nains, Armemor et Cèleras ; groupes cumulables pour Elfes et Orcs. La cible héroïque est le premier héros vivant dans l’ordre de déploiement. Diplomatie simplifiée à une trêve de cinq manches contre 100 R. Repli automatique d’une case. Soin des héros d’Ilunor fixé à 60 R, valeur provisoire. Pioche : une par camp/conflit, consomme l’action. Les cartes de soutien ne consomment pas l’attaque. Mode solo : son et animations disponibles, pas encore de multijoueur.\n\nLes tableaux de déploiement, attaque et défense ont été transcrits des PDF. Les particularités sont accessibles ci-dessous. Les vidéos servent de référence visuelle ; leur audio n’a pas été intégralement transcrit."
	rich(m,text,Rect2(205,220,1020,400))
	button(m,"Tableaux et particularités des factions",Rect2(205,650,1015,54),show_tables)
func show_tables():
	var m=overlay("Valeurs des factions · déploiement / coût / attaque / défense")
	var text=""
	for f in range(6):
		var d=game.data.factions[f];text+=d.name.to_upper()+"\n"+d.description+"\nDON : "+d.don+"\n"
		for li in range(2):
			text+=["INFANTERIE","CAVALERIE"][li]+"\n"
			for n in range(d.lines[li].size()):text+="%d : %s\n"%[n+1,str(d.lines[li][n])]
		text+="HÉROS\n"
		for h in d.heroes:text+=str(h)+"\n"
		if f in [0,4]:text+="Valeurs collectives selon l’effectif :\n"+str(game.data.group_elf if f==0 else game.data.group_orc)+"\n"
		text+="\n"
	rich(m,text,Rect2(205,145,1020,550))
func show_tutorial():
	var tip=TIPS[tutorial_step];var m=overlay("Guide des règles · %d / %d"%[tutorial_step+1,TIPS.size()])
	label(m,tip[0],Rect2(205,165,1000,62),34,GOLD)
	rich(m,tip[1],Rect2(205,250,1000,325))
	button(m,"Précédent",Rect2(205,640,230,60),func():tutorial_step-=1;show_tutorial(),tutorial_step==0)
	button(m,"Suivant" if tutorial_step<TIPS.size()-1 else "Jouer",Rect2(960,640,260,60),func():
		if tutorial_step<TIPS.size()-1:tutorial_step+=1;show_tutorial()
		else:
			close_modal()
			if screen=="menu":show_factions()
	)

func start_war(target:int,is_base:bool):
	close_modal()
	if selected<0:show_notice("Sélection", "Sélectionnez votre éclaireur.");return
	if game.declare_war(selected,target,is_base):
		bid=int(game.s.next_bid)-1;game.save_game();show_battle()
		if coach_active() and not game.s.discovery.get("combat_intro",false):coach_combat_intro()
	else:show_notice("Guerre impossible",game.error)
func capture_test():
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/crystal_capture.png")
	get_tree().quit()

func choose_attack(si:int,li:int):
	var b=game.battle_by_id(bid);var ln=b.sides[si].lines[li]
	if li==2 and b.sides[si].f==3:
		var m=overlay("Choisir la puissance de l’attaque")
		for power in range(3):button(m,"%d dégâts · %d R"%[[85,100,120][power],[20,40,60][power]+(1 if b.terrain==2 else 0)],Rect2(205,185+power*120,1000,85),func():close_modal();show_attack_preview(si,li,-1,power))
		return
	if li!=2 or not ln.has("members"):
		show_attack_preview(si,li);return
	var m=overlay("Choisir le héros attaquant")
	for k in range(ln.members.size()):
		var member=ln.members[k];var title=game.data.factions[b.sides[si].f].heroes[member.id][0]
		button(m,"%s · %d R · %d dégâts · défense %d/%d"%[title,member.cost,member.atk,member.hp,member.max],Rect2(205,185+k*110,1010,85),func():close_modal();show_attack_preview(si,2,member.id),member.hp<=0 or member.atk<=0)

func perform_attack(si:int,li:int,hero_id:int=-1):
	var b=game.battle_by_id(bid)
	if not b.sides[si].pierce:act(func():return game.attack(bid,si,li,0,-1,hero_id));return
	var m=overlay("Attaque ciblée · choisir la ligne adverse")
	for target in range(3):
		button(m,["Infanterie","Cavalerie","Héros"][target],Rect2(240,200+target*120,960,85),func():close_modal();act(func():return game.attack(bid,si,li,0,target,hero_id)),b.sides[1-si].lines[target].hp<=0)

func guided()->bool:
	return not game.s.is_empty() and game.s.get("onboarding",{}).get("active",false)
func start_play(with_guide:bool,resources_lesson:bool=true):
	if with_guide and resources_lesson and (not coach_active() or coach_phase()==0):
		if not coach_active():game.s.discovery={"active":true,"phase":0,"combat_intro":false,"first_attack":false}
		game.save_game();show_coach_step();return
	if not with_guide:game.s["discovery"]={"active":false}
	game.s.setup=false;message="";ai_moved=false
	if with_guide:
		var f=int(game.s.human);var uid=f*3
		game.s.turn=f
		if int(game.s.factions[f].turns)==0:game.start_turn()
		var nearest=0;var best=999
		for i in range(game.s.crystals.size()):
			var distance=game.distance(game.BASES[f],game.pos(game.s.crystals[i]))
			if distance<best:best=distance;nearest=i
		game.s["onboarding"]={"active":true,"step":0,"uid":uid,"crystal":nearest}
		selected=-1
	else:game.s["onboarding"]={"active":false}
	destination=Vector2i(99,99);game.save_game();show_map()
func select_unit(uid:int):
	if not coach_unit_allowed(uid):return
	if coach_paused() and coach_phase() in [2,5]:game.s.discovery.phase+=1
	selected=uid;destination=game.pos(game.s.units[uid]);message=""
	if guided() and int(game.s.onboarding.step)==1:
		game.s.onboarding.step=2;destination=Vector2i(99,99)
	game.save_game();show_map();frame_expedition()
func guide_target()->Vector2i:
	if not guided():return Vector2i(99,99)
	var ob=game.s.onboarding;var u=game.s.units[ob.uid]
	if int(ob.step) in [0,1]:return game.BASES[game.s.human]
	var goal=game.pos(game.s.crystals[ob.crystal]) if u.crystals.is_empty() and int(ob.step)!=9 else game.BASES[game.s.human]
	var route=game.path(game.pos(u),goal)
	if route.is_empty():return goal
	return route[mini(route.size(),maxi(1,int(u.mp)))-1]
func guide_copy()->Array:
	var ob=game.s.onboarding;var u=game.s.units[ob.uid]
	match int(ob.step):
		0:return ["1 / 6 · Voici votre village", "C’est votre point de départ et le lieu où rapporter les cristaux. Les adversaires attendent pendant cet apprentissage."]
		1:return ["2 / 6 · Choisissez votre éclaireur", "Touchez « Éclaireur 1 » dans le panneau à droite. C’est le pion qui ira chercher votre premier cristal."]
		2:return ["3 / 6 · Choisissez la destination", "Touchez la case entourée en doré. Le tracé vous conduit vers le cristal violet, en plusieurs tours si nécessaire."]
		3:return ["3 / 6 · Confirmez le déplacement", "La case est sélectionnée. Touchez maintenant « Déplacer ici », à droite, pour envoyer votre éclaireur."]
		4:return ["4 / 6 · Vous avez pris un cristal !", "Il faut le rapporter au village. Votre éclaireur doit d’abord attendre un tour : touchez « Terminer le tour »."]
		5:return ["4 / 6 · Ce tour, l’éclaireur se repose", "La prise du cristal l’immobilise pendant ce tour. Touchez encore « Terminer le tour ». Il pourra ensuite repartir."]
		6:return ["5 / 6 · Retournez au village", "Avec un cristal, vous avancez de 4 cases par tour. Touchez la case dorée sur le chemin du retour."]
		7:return ["5 / 6 · Confirmez le retour", "Touchez « Déplacer ici ». Le cristal sera déposé automatiquement dès l’arrivée au village."]
		8:return ["Le trajet continue au prochain tour", "Vos déplacements sont utilisés. Touchez « Terminer le tour », puis suivez la prochaine case dorée."]
		_:return ["Cristal rapporté · poursuivons la découverte", "Votre village a reçu le cristal et 400 ressources. Objectif final : réunir les 5 cristaux. Touchez Continuer pour choisir la suite de votre aventure."]
func draw_guide():
	var copy=guide_copy();var step=int(game.s.onboarding.step)
	panel(layer,Rect2(28,158,990,134),Color("203241"))
	button(layer,"Replier",Rect2(850,270,152,30),func():guide_folded=true;show_map();frame_expedition())
	label(layer,copy[0],Rect2(44,164,750,35),23,GOLD)
	label(layer,copy[1],Rect2(44,202,750,80),18)
	if step==0:button(layer,"J’ai repéré",Rect2(817,190,185,64),func():game.s.onboarding.step=1;game.save_game();show_map())
	elif step==9:button(layer,"Continuer",Rect2(817,190,185,64),finish_guide)
	else:button(layer,"Quitter le guide",Rect2(817,190,185,64),confirm_skip_guide)
	var rect=Rect2()
	if step==1:rect=Rect2(1051,151,350,57)
	elif step in [3,7]:rect=Rect2(1051,421,172,56)
	elif step in [4,5,8]:rect=Rect2(1051,705,350,70)
	if rect.size!=Vector2.ZERO:
		var border=Panel.new();border.position=rect.position;border.size=rect.size
		var sb=style(Color(0,0,0,0),GOLD);sb.set_border_width_all(3)
		border.add_theme_stylebox_override("panel",sb);border.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(border)
func move_selected(confirmed:bool=false):
	if coach_paused() and coach_phase() not in [4,7]:show_coach_step();return
	if guided() and int(game.s.onboarding.step) not in [3,7]:return
	if not game.move_unit(selected,destination):show_notice("Déplacement impossible",game.error);return
	if guided():
		var u=game.s.units[game.s.onboarding.uid]
		if game.s.factions[game.s.human].crystals.has(game.s.onboarding.crystal):game.s.onboarding.step=9
		elif int(game.s.onboarding.step)==3:
			game.s.onboarding.step=4 if not u.crystals.is_empty() else 8
			if not u.crystals.is_empty():game.s.onboarding.crystal=int(u.crystals[0])
		else:game.s.onboarding.step=8 if int(u.mp)==0 else 6
	if coach_paused():
		game.s.discovery.phase=5 if coach_phase()==4 else 8
		selected=-1;destination=Vector2i(99,99)
	game.save_game();show_map();frame_expedition(true)
func confirm_skip_guide():
	var m=overlay("Quitter l’apprentissage ?")
	rich(m,"Votre partie est conservée. Les cinq adversaires commenceront à jouer lorsque vous terminerez votre tour. L’aide reste disponible à tout moment.",Rect2(205,180,1000,250))
	button(m,"Continuer à jouer librement",Rect2(350,610,740,64),leave_discovery)
func finish_guide():
	if game.s.get("chapter_mode",false) and guided() and int(game.s.onboarding.step)==9:
		close_modal();game.s.onboarding.active=false;game.s.discovery.phase=11;game.s["first_expedition_done"]=true;game.save_game();show_village()
		show_notice("Premier cristal au sanctuaire", "Votre expédition a réussi : un cristal est en sécurité et le premier dépôt a rapporté 400 R au village.\n\nVous pouvez explorer librement, ouvrir le chapitre Ravitaillement ou négocier un pacte. Les adversaires joueront lorsque vous terminerez votre tour.")
		return
	if coach_active() and guided() and int(game.s.onboarding.step)==9:
		close_modal();game.s.onboarding.active=false;game.s.discovery.phase=2;selected=-1;destination=Vector2i(99,99);map_zoom=1.0;map_pan=Vector2.ZERO;message="";game.save_game();show_map();show_coach_step();return
	close_modal();game.s.onboarding.active=false;game.s.ai_wait=false;ai_moved=false
	message="À vous de jouer : déplacez vos autres pions, puis terminez le tour pour faire jouer les adversaires."
	game.save_game();show_map()
func contextual_hint()->String:
	if coach_active() and not guided():return "Suivez la consigne au-dessus de la carte. Touchez Voir l’étape ou Aide pour relire les détails."
	if guided():return "Départ accompagné : les adversaires attendent. Suivez la consigne au-dessus de la carte."
	if game.s.turn!=game.s.human:return "L’ordinateur joue. Attendez le retour de votre tour."
	if game.pending_human()>=0:return "Un combat vous attend : préparez votre armée."
	if selected<0:return "Choisissez Éclaireur 1 ou 2, puis une case avec un cristal violet."
	var u=game.s.units[selected]
	if u.battle>=0:return "Votre éclaireur est engagé. Ouvrez Conflits pour choisir votre action."
	if int(u.mp)==0:return "Ce pion ne peut plus bouger ce tour. Jouez un autre pion ou terminez le tour."
	if not u.crystals.is_empty():return "Ramenez ce cristal dans votre village, entouré en blanc. Dépôt automatique à l’arrivée."
	if u.k==2:return "Le messager transporte des ressources. Pour chercher un cristal, sélectionnez un éclaireur."
	return "Cherchez un cristal violet : touchez sa case, puis « Déplacer ici ». Les contours clairs indiquent votre portée."
func show_next_help():
	if game.s.is_empty() or screen in ["menu","factions"]:
		show_notice("Comment commencer", "Nouvelle partie → choisissez votre faction → gardez les réserves proposées → Commencer avec le guide.

Le guide vous accompagne : ressources, premier cristal, deuxième éclaireur, messager, diplomatie, puis premier combat.");return
	if coach_active() and (guided() or coach_paused()):show_coach_step();return
	if guided():show_notice(guide_copy()[0],guide_copy()[1]);return
	show_notice("Votre prochaine action",contextual_hint()+"\n\nBut du jeu : rapporter les cinq cristaux violets à votre village. Les pions 1 et 2 sont vos éclaireurs. M est votre messager.\n\n1. Touchez le bouton de votre éclaireur à droite.\n2. Touchez une case à portée sur la carte.\n3. Touchez Déplacer ici.\n4. Après avoir joué vos pions, touchez Terminer le tour.")

func load_preferences():
	var c=ConfigFile.new()
	if c.load("user://preferences.cfg")==OK:
		effects=bool(c.get_value("display","effects",true));pace=float(c.get_value("display","pace",1.0))
func save_preferences():
	var c=ConfigFile.new();c.set_value("display","effects",effects);c.set_value("display","pace",pace)
	c.set_value("audio","music",audio.music_volume);c.set_value("audio","fx",audio.fx_volume);c.save("user://preferences.cfg")
func show_settings():
	var m=overlay("Ambiance et confort")
	label(m,"Musique originale",Rect2(210,180,350,40),24,GOLD)
	var music=HSlider.new();music.position=Vector2(590,187);music.size=Vector2(570,36);music.min_value=0;music.max_value=1;music.step=0.05;music.value=audio.music_volume;m.add_child(music)
	music.value_changed.connect(func(v):audio.music_volume=v;audio.apply_volume();save_preferences())
	label(m,"Bruitages",Rect2(210,275,350,40),24,GOLD)
	var fx=HSlider.new();fx.position=Vector2(590,282);fx.size=Vector2(570,36);fx.min_value=0;fx.max_value=1;fx.step=0.05;fx.value=audio.fx_volume;m.add_child(fx)
	fx.value_changed.connect(func(v):audio.fx_volume=v;audio.apply_volume();audio.cue("crystal");save_preferences())
	var cb=CheckBox.new();cb.text="Animations et effets d’ambiance";cb.position=Vector2(210,380);cb.size=Vector2(900,55);cb.button_pressed=effects;m.add_child(cb)
	cb.toggled.connect(func(v):effects=v;save_preferences())
	label(m,"Vitesse des tours et animations",Rect2(210,465,850,40),24,GOLD)
	for i in range(3):
		var value=[0.65,1.0,2.0][i]
		button(m,["Contemplatif","Normal","Rapide"][i]+(" ✓" if is_equal_approx(pace,value) else ""),Rect2(210+i*330,525,310,58),func():pace=value;save_preferences();show_settings())
	label(m,"Carte : glissez pour déplacer la vue ; pincez pour zoomer.\nLes boutons +, − et Vue restent disponibles. Les réglages sont mémorisés.",Rect2(210,620,990,85),21,MUTED)
func add_atmosphere():
	var a=Control.new();a.set_script(preload("res://atmosphere.gd"));a.host=self;a.size=Vector2(1440,810);layer.add_child(a)
func focus_map(p:Vector2i):
	if not is_instance_valid(mapview):return
	map_zoom=1.6
	var dest=mapview.size/2-mapview.center-mapview.world(p)*map_zoom
	if effects:create_tween().tween_property(self,"map_pan",dest,0.4/pace).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:map_pan=dest
func visual_pos(uid:int)->Vector2:
	var u=game.s.units[uid]
	if not effects or not journeys.has(uid):return Vector2(game.pos(u))
	var j=journeys[uid];var t=clampf((elapsed-j.start)/j.duration,0,1)
	var points=j.points
	var progress=t*(points.size()-1);var index=mini(int(progress),points.size()-2)
	return Vector2(points[index]).lerp(Vector2(points[index+1]),progress-index)
func attach_event_label():
	if screen=="map":event_label=label(layer,event_text,Rect2(325,157 if not has_coach() else 308,490,65),18,GOLD)
	elif screen=="battle":event_label=label(layer,event_text,Rect2(30,650,1370,52),19,GOLD)
	if is_instance_valid(event_label):event_label.visible=event_time>0 and not has_coach()
func announce(text:String,kind="click"):
	event_text=text;event_time=4.5/pace
	if is_instance_valid(audio):audio.cue(kind)
	if is_instance_valid(event_label):event_label.text=text;event_label.visible=true
func observe_changes(delta):
	event_time=maxf(0,event_time-delta)
	if is_instance_valid(event_label):event_label.visible=event_time>0 and not has_coach()
	if game.s.is_empty():return
	if previous_units.size()!=game.s.units.size():
		previous_units=game.s.units.duplicate(true);last_log_count=game.s.log.size();previous_battles=game.s.battles.duplicate(true);set_meta("last_event",str(game.s.log.back()) if not game.s.log.is_empty() else "");return
	for uid in range(game.s.units.size()):
		var u=game.s.units[uid];var old=previous_units[uid]
		if game.pos(u)!=game.pos(old):
			var points=[game.pos(old)];points.append_array(game.path(game.pos(old),game.pos(u)))
			journeys[uid]={"points":points,"start":elapsed,"duration":maxf(0.3,0.16*(points.size()-1))/pace}
			if screen=="map":audio.cue("step")
	for i in range(mini(previous_battles.size(),game.s.battles.size())):
		var b=game.s.battles[i];var old=previous_battles[i]
		for camp in range(2):
			if not b.sides[camp].deployed or not old.sides[camp].deployed:continue
			for li in range(3):
				var hp=int(b.sides[camp].lines[li].hp);var before=int(old.sides[camp].lines[li].hp)
				if hp<before and screen=="battle" and int(b.id)==bid:impact(camp,li,before-hp,hp==0)
	previous_units=game.s.units.duplicate(true);previous_battles=game.s.battles.duplicate(true)
	if not game.s.log.is_empty():
		var latest=str(game.s.log.back())
		if latest!=get_meta("last_event","") and last_log_count>0:
			announce(latest,"crystal" if "cristal" in latest else ("battle" if "conflit" in latest or "dégâts" in latest else "click"))
		set_meta("last_event",latest);last_log_count=game.s.log.size()
func impact(camp:int,li:int,damage:int,fallen:bool):
	if not effects:return
	var flash=ColorRect.new();flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;flash.color=Color(1,0.36,0.18,0.24);flash.position=Vector2(43+camp*710,260+li*99);flash.size=Vector2(650,87);layer.add_child(flash)
	var tween=create_tween();tween.tween_property(flash,"modulate:a",0.0,0.55/pace);tween.tween_callback(flash.queue_free)
	var text=label(layer,"LIGNE DÉTRUITE" if fallen else "−%d défense"%damage,Rect2(250+camp*710,265+li*99,410,45),27,Color("ffb5a2"))
	var t=create_tween();t.set_parallel();t.tween_property(text,"position:y",text.position.y-24,0.8/pace);t.tween_property(text,"modulate:a",0.0,0.8/pace);t.chain().tween_callback(text.queue_free)
func atlas_art(parent:Control,texture:Texture2D,index:int,columns:int,rows:int,r:Rect2):
	var at=AtlasTexture.new();at.atlas=texture;var cell=texture.get_size()/Vector2(columns,rows);at.region=Rect2(Vector2(index%columns,int(index/columns))*cell,cell)
	var tr=TextureRect.new();tr.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tr.texture=at;tr.position=r.position;tr.size=r.size;tr.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tr.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(tr)
func show_victory():
	var m=overlay("La destinée des royaumes")
	atlas_art(m,preload("res://assets/capitals.png"),int(game.s.winner),3,2,Rect2(215,160,380,380))
	label(m,game.fname(game.s.winner)+" remporte la partie",Rect2(635,190,550,110),36,GOLD)
	label(m,"Les chroniques retiendront cette victoire.\n\nManche %d · %d cristaux au village\n\nLe journal conserve les événements de votre partie."%[game.s.round,game.s.factions[game.s.winner].crystals.size()],Rect2(635,330,550,220),24)
	button(m,"Consulter le journal",Rect2(220,620,470,62),show_log)
	button(m,"Une nouvelle aventure",Rect2(730,620,470,62),func():close_modal();show_factions())

func transition_in():
	if not effects:return
	layer.modulate.a=0.0
	create_tween().tween_property(layer,"modulate:a",1.0,0.35/pace)

# Discovery state follows real engine actions and is saved with the game.
func coach_active()->bool:
	return not game.s.is_empty() and game.s.get("discovery",{}).get("active",false)
func coach_phase()->int:
	return int(game.s.get("discovery",{}).get("phase",-1))
func coach_paused()->bool:
	return coach_active() and coach_phase() in [2,3,4,5,6,7,8,9,10]
func has_coach()->bool:return guided() or coach_active()
func coach_unit_allowed(uid:int)->bool:
	if not coach_paused():return true
	var k=1 if coach_phase() in [2,3,4] else 2
	return coach_phase() in [2,3,4,5,6,7] and uid==int(game.s.human)*3+k
func coach_target()->Vector2i:
	var f=int(game.s.human)
	if coach_phase() in [2,3,4]:
		var route=game.path(game.BASES[f],Vector2i.ZERO)
		return route[0] if not route.is_empty() else game.BASES[f]
	if coach_phase() in [5,6,7,8]:return game.pos(game.s.units[f*3+1])
	return game.BASES[f]
func coach_transfer_plan()->Dictionary:
	var f=int(game.s.human);var messenger="u%d"%(f*3+2)
	if coach_phase()==8:return {"source":messenger,"target":"u%d"%(f*3+1),"amount":mini(100,game.reserve_money(messenger))}
	var room=400-game.reserve_money(messenger)
	if room<=0:return {"source":messenger,"target":"u%d"%(f*3+1),"amount":100}
	var source="b%d"%f
	for ref in ["u%d"%(f*3),"u%d"%(f*3+1)]:
		if game.reserve_money(ref)>game.reserve_money(source):source=ref
	return {"source":source,"target":messenger,"amount":mini(100,mini(room,game.reserve_money(source)))}
func reserve_title(ref:String)->String:
	if ref.begins_with("b"):return "Village"
	return ["Éclaireur 1","Éclaireur 2","Messager"][int(ref.substr(1))%3]
func coach_transfer_text(plan:Dictionary)->String:
	return "Transférez %d R : %s → %s."%[plan.amount,reserve_title(plan.source),reserve_title(plan.target)]
func coach_copy()->Array:
	match coach_phase():
		0:return ["1 · Partagez vos ressources",coach_transfer_text(coach_transfer_plan())+" Le messager les apportera ensuite à un éclaireur. Chaque réserve a son rôle."]
		1:return ["Répartition validée", "Le transfert a bien eu lieu. Vos ressources ne sont pas communes : chaque éclaireur paie ses propres combats. Rejoignez maintenant la carte pour apprendre à vous déplacer."]
		2:return ["3 · Déplacez votre deuxième éclaireur", "Touchez Éclaireur 2 à droite. Il peut lui aussi explorer pendant votre tour. L’ordinateur attend encore pendant cet exercice."]
		3:return ["Choisissez sa destination", "Touchez la case entourée en doré près du village. Le tracé montre le déplacement prévu ; le pion n’a pas encore bougé."]
		4:return ["Confirmez le déplacement", "Touchez Déplacer ici, à droite. Votre deuxième éclaireur rejoint la case choisie. Nous allons maintenant lui apporter des ressources."]
		5:return ["4 · Envoyez votre messager", "Touchez Messager à droite. Il peut avancer de huit cases, transporter jusqu’à 400 R et ne peut pas être attaqué."]
		6:return ["Rejoignez l’éclaireur", "Touchez la case dorée occupée par Éclaireur 2. Le messager doit le rejoindre : les transferts exigent que les deux pions soient sur la même case."]
		7:return ["Déplacez le messager", "Touchez Déplacer ici. Une fois arrivé, il pourra donner une partie de ses ressources à Éclaireur 2."]
		8:return ["Ravitaillez votre éclaireur", "Touchez Ressources, puis validez le transfert proposé : Messager → Éclaireur 2. Ce dernier pourra utiliser cette réserve pour ses combats."]
		9:return ["Diplomatie · négociez un pacte", "Touchez Diplomatie. Dans cette version, vous pouvez proposer une trêve : 100 R du village contre cinq manches sans nouvelle attaque entre les deux factions."]
		10:return ["Accord conclu · terminez votre tour", "Votre trêve est active. Touchez Terminer le tour pour laisser jouer les autres factions. Le conseiller restera visible pour vous accompagner."]
		_:
			if game.s.turn!=game.s.human:return ["Observez les autres factions", "L’ordinateur joue. Attendez votre prochain tour : vos déplacements se renouvelleront. Si un conflit éclate, je vous guiderai dans le déploiement."]
			if game.pending_human()>=0:return ["6 · Préparez votre première bataille", "Un conflit vous concerne. Il faut déployer au moins deux fantassins et deux cavaliers, puis garder des ressources pour attaquer."]
			for b in game.s.battles:
				if not b.done and game.side_index(b,game.s.human)>=0:return ["6 · Jouez votre conflit", "Touchez Conflits et ouvrez votre plateau. Effectuez vos déplacements avant les actions de guerre. Chaque conflit autorise une action à votre tour."]
			if selected>=0:
				var u=game.s.units[selected]
				if not u.crystals.is_empty():return ["Rapportez votre cristal", "Sélectionnez une case vers votre village, puis Déplacer ici. Avec un cristal : quatre cases ; après sa prise : un tour d’attente obligatoire."]
				if int(u.mp)==0:return ["Ce pion a terminé son déplacement", "Choisissez un autre pion disponible, ou touchez Terminer le tour. Le conseiller reste accessible dans Aide."]
			return ["Votre mission : le prochain cristal", "Choisissez un éclaireur, touchez une case vers un cristal violet, puis Déplacer ici. Pour négocier : Diplomatie. Pour attaquer une cible à portée : Interactions."]
func show_coach_step():
	if guided():
		var copy=guide_copy();var m=overlay(copy[0]);rich(m,copy[1]+"\n\nLes adversaires attendent. Suivez la case et le bouton entourés en doré. Chaque étape est validée par votre action réelle.",Rect2(205,170,1000,350))
		button(m,"Retour à mon étape",Rect2(205,620,480,60),close_modal)
		button(m,"Quitter le guide",Rect2(730,620,480,60),confirm_skip_guide);return
	var copy=coach_copy();var m=overlay(copy[0])
	var text=copy[1]
	if coach_phase()==0:text+="\n\nVillage : défendre votre base. Éclaireurs : payer leurs propres armées et attaques. Messager : ravitailler vos pions.\n\nOuvrez Ressources. Le départ, l’arrivée et le montant seront proposés ; vérifiez-les puis touchez Effectuer le transfert."
	elif coach_phase()==9:text+="\n\nLes règles sur table prévoient aussi une aide militaire et des accords plus libres. Ils ne sont pas encore reproduits. L’accord proposé ici est uniquement une non-agression ; il ne donne ni soldats ni ressources partagées."
	else:text+="\n\nUne action à la fois : le cadre doré indique quoi toucher. Vous pouvez relire cette explication avec Aide."
	rich(m,text,Rect2(205,165,1000,395))
	var caption="Retour à la carte"
	if coach_phase() in [0,8]:caption="Ouvrir Ressources"
	elif coach_phase()==1:caption="2 · Découvrir la carte"
	elif coach_phase()==9:caption="Ouvrir Diplomatie"
	button(m,caption,Rect2(205,620,560,62),func():
		close_modal()
		match coach_phase():
			0,8:show_transfer()
			1:start_play(true)
			9:show_diplomacy()
	)
	button(m,"Quitter le guide",Rect2(815,620,390,62),confirm_skip_guide)
func highlight_coach(r:Rect2):
	var border=Panel.new();border.position=r.position;border.size=r.size
	var sb=style(Color(0,0,0,0),GOLD);sb.set_border_width_all(3)
	border.add_theme_stylebox_override("panel",sb);border.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(border)
func draw_coach():
	var copy=coach_copy();panel(layer,Rect2(28,158,990,134),Color("203241"))
	button(layer,"Replier",Rect2(850,270,152,30),func():guide_folded=true;show_map();frame_expedition())
	label(layer,copy[0],Rect2(44,164,750,35),23,GOLD);label(layer,copy[1],Rect2(44,202,750,80),18)
	button(layer,"Voir l’étape",Rect2(817,190,185,64),show_coach_step)
	match coach_phase():
		2:highlight_coach(Rect2(1051,204,350,57))
		5:highlight_coach(Rect2(1051,257,350,57))
		4,7:highlight_coach(Rect2(1051,421,172,56))
		8:highlight_coach(Rect2(1051,483,172,56))
		9:highlight_coach(Rect2(1051,540,172,56))
		10:highlight_coach(Rect2(1051,705,350,70))
func leave_discovery():
	close_modal()
	game.s["discovery"]={"active":false}
	game.s["onboarding"]={"active":false}
	game.s.ai_wait=false;ai_moved=false;message="L’aide reste accessible avec Aide."
	game.save_game()
	if game.s.setup:show_setup()
	else:show_map()
func confirm_coach_truce(f:int):
	var m=overlay("Confirmer la proposition à "+game.fname(f))
	rich(m,"Le village verse 100 R à cette faction. En échange, aucun nouveau conflit entre vous pendant cinq manches.\n\nCe pacte ne fournit pas de renfort militaire. Les autres factions peuvent toujours vous attaquer.\n\nRéserve du village avant l’accord : %d R. Après : %d R."%[game.s.factions[game.s.human].money,game.s.factions[game.s.human].money-100],Rect2(205,170,1000,350))
	button(m,"Proposer la trêve · 100 R",Rect2(300,620,840,62),func():
		if not game.offer_truce(f):show_notice("Proposition impossible",game.error);return
		close_modal()
		if coach_active() and coach_phase()==9:game.s.discovery.phase=10
		game.save_game();show_map()
	)
func coach_combat_intro():
	game.s.discovery.combat_intro=true;game.save_game()
	var b=game.battle_by_id(bid);var si=game.side_index(b,game.s.human)
	var m=overlay("6 · Votre premier plateau de combat")
	rich(m,"Vous quittez temporairement la carte pour gérer cette bataille. Chaque conflit a son propre plateau.\n\n1. Déployez au moins 2 fantassins et 2 cavaliers.\n2. Les héros sont facultatifs ; un héros engagé ailleurs est indisponible.\n3. Gardez des ressources : les attaques sont payantes.\n4. Vérifiez le prix du déploiement, puis validez.\n\nVotre réserve pour ce combat : %d R. Terrain : %s."%[game.wallet(b.sides[si]),game.TERRAIN[b.terrain]],Rect2(205,165,1000,420))
	button(m,"Préparer mon armée",Rect2(300,620,840,62),func():close_modal();show_deploy())
func draw_battle_coach(b:Dictionary,si:int):
	if si<0:return
	var text=""
	if b.done:text="Bataille terminée. Revenez à la Carte pour poursuivre votre expédition."
	elif not b.sides[si].deployed:text="Déployez 2 fantassins et 2 cavaliers minimum. Gardez une réserve pour payer vos attaques."
	elif not game.can_act(b,si):text="Votre action est terminée ou l’adversaire doit jouer. Touchez Fin du tour si c’est encore votre tour."
	else:
		var li=-1
		for candidate in range(3):
			var ln=b.sides[si].lines[candidate]
			if ln.hp>0 and ln.atk>0 and ln.cost<=game.wallet(b.sides[si]):li=candidate;break
		if li>=0:
			text="Touchez Attaque : %s. Coût : %d R. Vous viserez la première ligne ennemie encore debout."%[["infanterie","cavalerie","héros"][li],b.sides[si].lines[li].cost]
			highlight_coach(Rect2(23+li*283,591,281,63))
		else:text="Aucune attaque ordinaire abordable. Examinez vos cartes, Renfort / soin, le repli ou Épuisé."
	panel(layer,Rect2(28,654,1384,38),Color("203241"));label(layer,text,Rect2(40,659,1350,32),17,GOLD)

func show_village():
	if game.s.is_empty():show_menu();return
	screen="village";clear()
	var f=int(game.s.human)
	if game.s.factions[f].crystals.size()>0:game.s["first_expedition_done"]=true
	var scene=Control.new();scene.set_script(preload("res://village.gd"));scene.host=self;scene.position=Vector2(0,100);scene.size=Vector2(940,710);layer.add_child(scene)
	header("LE VILLAGE · "+game.fname(f),"Votre royaume · préparez, explorez, puis combattez" if game.s.setup else "Manche %d · %s"%[game.s.round,"À vous de jouer" if game.s.turn==f else game.fname(game.s.turn)+" joue…"])
	panel(layer,Rect2(28,120,870,120),Color(0.035,0.07,0.1,0.88))
	var advice=Advisor.situation(game)
	label(layer,"PREMIÈRE EXPÉDITION" if game.s.setup else advice.title,Rect2(46,131,830,28),19,GOLD)
	label(layer,"Un cristal vous attend au-delà des portes. Préparez votre éclaireur et rapportez-le au sanctuaire." if game.s.setup else advice.text,Rect2(46,166,830,66),21)
	if not game.s.setup:button(layer,advice.action,Rect2(46,252,360,52),func():follow_situation(advice))
	panel(layer,Rect2(945,108,467,680),Color("122431"))
	label(layer,"QUE VOULEZ-VOUS FAIRE ?",Rect2(966,126,420,35),23,GOLD)
	var turn_ready=game.s.setup or game.s.turn==f
	button(layer,"Préparer mon expédition",Rect2(966,179,423,62),func():
		if game.s.setup:show_setup()
		else:show_transfer()
	,not turn_ready)
	label(layer,"Quatre réserves distinctes · transferts locaux",Rect2(973,246,410,27),16,MUTED)
	button(layer,"Explorer le monde",Rect2(966,283,423,62),func():
		if game.s.setup:show_setup()
		else:enter_world()
	)
	label(layer,"Choisir un éclaireur et son trajet",Rect2(973,350,410,27),16,MUTED)
	button(layer,"Ravitailler mes éclaireurs",Rect2(966,388,423,62),open_supply_flow,game.s.setup or not turn_ready)
	button(layer,"Négocier un pacte",Rect2(966,466,423,62),open_diplomacy_chapter,game.s.setup or not turn_ready)
	button(layer,"Gérer mes combats",Rect2(966,544,423,62),func():
		if guided() or coach_paused():show_coach_step()
		else:show_conflicts()
	,game.s.setup)
	label(layer,"Préparez d’abord votre première expédition." if game.s.setup else ("L’ordinateur joue ; vous pouvez observer la carte." if not turn_ready else "Déplacez et ravitaillez avant vos actions de guerre."),Rect2(974,620,410,67),19,MUTED)
	button(layer,"Terminer le tour",Rect2(966,711,423,56),end_turn,game.s.setup or not turn_ready or game.pending_human()>=0)
	for k in range(4):
		var ref="b%d"%f if k==0 else "u%d"%(f*3+k-1)
		panel(layer,Rect2(28+k*220,722,208,65),Color(0.035,0.07,0.11,0.93))
		label(layer,["Village","Éclaireur 1","Éclaireur 2","Messager"][k]+" · %d R"%game.reserve_money(ref),Rect2(40+k*220,733,185,44),20,GOLD)
	label(layer,"SANCTUAIRE · %d / 5"%game.s.factions[f].crystals.size(),Rect2(655,735-100,230,35),20,GOLD)
	if not game.s.setup and game.s.get("first_expedition_done",false) and not game.s.get("supply_learned",false) and not guided() and not coach_paused():button(layer,"Apprendre le ravitaillement",Rect2(300,646,320,56),open_supply_chapter)
	if guided() or coach_paused():button(layer,"Reprendre mon étape",Rect2(300,646,320,56),func():enter_world();show_coach_step())
	transition_in()
	if int(game.s.winner)>=0:show_victory()
func start_first_chapter():
	game.s["chapter_mode"]=true
	game.s.discovery={"active":true,"phase":11,"combat_intro":false,"first_attack":false}
	guide_folded=false
	start_play(true,false)
	frame_expedition()
func enter_world():
	if game.s.setup:show_setup();return
	close_modal()
	if selected<0:selected=int(game.s.human)*3
	show_map();frame_expedition();transition_in()
func frame_expedition(animated:bool=false):
	if not is_instance_valid(mapview):return
	var p=Vector2(game.pos(game.s.units[selected])) if selected>=0 else Vector2(game.BASES[game.s.human])
	if guided():
		var target_cell=guide_target()
		if game.s.cells.has(game.key(target_cell)):p=(p+Vector2(target_cell))/2
	elif coach_paused():p=(p+Vector2(coach_target()))/2
	map_zoom=2.1 if not guide_folded else 1.8
	var next_pan=mapview.size/2-mapview.center-mapview.world(p)*map_zoom
	if camera_tween and camera_tween.is_valid():camera_tween.kill()
	if animated and effects:camera_tween=create_tween();camera_tween.tween_property(self,"map_pan",next_pan,0.55/pace).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:map_pan=next_pan
func open_supply_chapter():
	if guided() or coach_paused():enter_world();show_coach_step();return
	if not game.s.get("first_expedition_done",false) or game.s.get("supply_learned",false):
		show_notice("Ravitailler sur le terrain", "Ouvrez la carte, choisissez le messager et rejoignez votre éclaireur. Ouvrez ensuite Ressources : les deux réserves doivent être sur la même case. Le messager transporte au maximum 400 R.");return
	var uid=int(game.s.human)*3+1;var messenger=game.s.units[uid+1]
	if game.pos(game.s.units[uid])!=game.BASES[game.s.human] or game.pos(messenger)!=game.BASES[game.s.human] or game.s.get("combat_phase",false) or int(game.s.units[uid].mp)<1 or int(messenger.mp)<1 or messenger.money<1:
		show_notice("Préparez ce chapitre", "Pour cet exercice, le deuxième éclaireur et le messager doivent être au village avec des pas disponibles, avant le combat. Le messager doit porter au moins 1 R. Vous pouvez toujours ravitailler librement vos pions sur une même case.");return
	game.s.discovery={"active":true,"phase":2,"combat_intro":game.s.get("discovery",{}).get("combat_intro",false)}
	selected=-1;destination=Vector2i(99,99);game.save_game();show_map();frame_expedition();show_coach_step()
func open_diplomacy_chapter():
	if guided() or coach_paused():enter_world();show_coach_step();return
	show_diplomacy()
func travel_preview()->Dictionary:
	var u=game.s.units[selected];var route=game.path(game.pos(u),destination)
	var steps=route.size();var warning="";var actual=destination;var compact=""
	if steps>int(u.mp):return {"text":"Destination hors de portée.","warning":"","compact":"Hors de portée : %d pas nécessaires, %d disponibles. Choisissez une case plus proche."%[steps,u.mp]}
	for i in range(steps):
		for c in game.s.crystals:
			if c.holder=="map" and game.pos(c)==route[i] and int(u.k)!=2 and u.crystals.size()<2:
				warning="La collecte arrête le déplacement et immobilise l’éclaireur au prochain tour. Ensuite : 4 cases par tour.";compact="Cristal : arrêt ici, puis un tour immobilisé. Ensuite : 4 pas/tour.";actual=route[i];steps=i+1;break
		if warning!="":break
	var enemies=0
	for enemy in game.s.units:
		if enemy.alive and enemy.f!=u.f and enemy.k!=2 and enemy.battle<0 and not game.truce(u.f,enemy.f) and game.distance(actual,game.pos(enemy))<=4:enemies+=1
	if enemies>0:compact+=("\n" if compact!="" else "")+"%d adversaire(s) à portée près de l’arrivée."%enemies
	if compact=="":compact="%d pas consommés sur %d. Aucun éclaireur adverse non allié repéré à 4 cases de l’arrivée."%[steps,u.mp]
	return {"text":"Trajet prévu : %d pas sur %d disponibles."%[steps,u.mp],"warning":warning,"compact":compact}
func follow_situation(advice:Dictionary):
	close_modal()
	if guided() or coach_paused():enter_world();show_coach_step();return
	match advice.kind:
		"battle":
			bid=int(advice.bid);show_battle()
			var b=game.battle_by_id(bid);var si=game.side_index(b,game.s.human)
			if si>=0 and not b.sides[si].deployed:show_deploy()
		"conflicts":show_conflicts()
		_:
			selected=int(advice.uid);destination=Vector2i(99,99);enter_world()
func open_supply_flow():
	if guided() or coach_paused():enter_world();show_coach_step();return
	if game.s.get("combat_phase",false):show_notice("Ravitaillement au prochain tour", "Les actions de guerre ont commencé : les transferts et déplacements ordinaires sont fermés pour ce tour.");return
	var m=overlay("Quel éclaireur voulez-vous ravitailler ?");var f=int(game.s.human);var messenger=game.s.units[f*3+2]
	label(m,"Messager : %d R · %d pas. Aucun transfert à distance : il doit rejoindre l’éclaireur."%[messenger.money,messenger.mp],Rect2(205,155,1000,80),23)
	for k in range(2):
		var uid=f*3+k;var u=game.s.units[uid];var distance=game.distance(game.pos(messenger),game.pos(u))
		button(m,"Éclaireur %d · %d R · %s"%[k+1,u.money,"même case" if distance==0 else "%d cases du messager"%distance],Rect2(205,290+k*110,1000,85),func():close_modal();supply_to(uid),not u.alive or game.s.turn!=f)
	label(m,"Si le messager est vide, commencez par le recharger au village. La destination est proposée ; vous confirmez chaque déplacement.",Rect2(205,535,1000,90),22,MUTED)
func supply_to(uid:int):
	var mid=int(game.s.human)*3+2;var m=game.s.units[mid];var u=game.s.units[uid]
	game.s["supply_target"]=uid;game.save_game()
	if game.s.turn!=game.s.human or game.s.get("combat_phase",false):show_notice("Action indisponible", "Attendez votre tour et ravitaillez avant les actions de guerre.");return
	if m.money>0 and game.pos(m)==game.pos(u):show_transfer("u%d"%mid,"u%d"%uid);return
	var goal=game.BASES[game.s.human] if m.money==0 else game.pos(u)
	if m.money==0 and game.pos(m)==goal:
		if game.s.factions[game.s.human].money<1:show_notice("Village sans réserve", "Le village n’a plus de ressources à confier au messager. Vous pouvez réorganiser vos autres réserves lorsqu’elles sont réunies.");return
		show_transfer("b%d"%game.s.human,"u%d"%mid);return
	selected=mid;var route=game.path(game.pos(m),goal)
	destination=route[mini(route.size(),int(m.mp))-1] if not route.is_empty() and m.mp>0 else game.pos(m)
	message="Messager sélectionné. Confirmez le trajet proposé. Le ravitaillement reste soumis aux déplacements disponibles." if m.mp>0 else "Le messager n’a plus de pas. Terminez votre tour pour poursuivre le ravitaillement."
	show_map();frame_expedition()
func apply_composition(mode:int):
	var b=game.battle_by_id(bid);var si=game.side_index(b,game.s.human)
	var proposal=Advisor.composition(game,bid,si,mode)
	deploy_a.value=proposal.a;deploy_b.value=proposal.b
	for pair in hero_checks:pair[1].button_pressed=proposal.heroes.has(pair[0])
	deployment_error="";update_deploy_price()
func show_line_detail(camp:int,li:int):
	var b=game.battle_by_id(bid);var line=b.sides[camp].lines[li]
	show_notice(game.fname(b.sides[camp].f)+" · "+["Infanterie","Cavalerie","Héros"][li],"Effectif : %d\nDéfense : %d / %d\nAttaque de référence : %d\nCoût de référence : %d R\n\nPour votre armée, touchez la ligne pendant votre action pour choisir une attaque et voir son résultat prévu. Les héros individuels ont leurs propres valeurs."%[line.n,line.hp,line.max,line.atk,line.cost])
func show_attack_preview(si:int,li:int,hero_id:int=-1,spell:int=0,target:int=-1):
	var b=game.battle_by_id(bid)
	if b.sides[si].pierce and target<0:
		var chooser=overlay("Choisissez la ligne adverse")
		for t in range(3):button(chooser,["Infanterie","Cavalerie","Héros"][t],Rect2(205,200+t*120,1000,80),func():close_modal();show_attack_preview(si,li,hero_id,spell,t),b.sides[1-si].lines[t].hp<=0)
		return
	var result=Advisor.attack_preview(game,bid,si,li,spell,target)
	if not result.ok:show_notice("Attaque indisponible",result.error);return
	var m=overlay("Votre attaque · "+["Infanterie","Cavalerie","Héros"][li])
	label(m,"Cible : "+result.target+" adverse",Rect2(205,150,1000,45),26,GOLD)
	label(m,"Coût : %d R · Réserve après paiement : %d R"%[result.cost,result.remaining],Rect2(205,210,1000,45),25)
	rich(m,result.text+"\nPrévision à l’état actuel du plateau, protections et effets automatiques compris. Un éventuel butin n’est pas inclus dans la réserve après paiement.",Rect2(205,280,1000,250))
	var warns=false
	if not game.s.get("combat_phase",false):
		for u in game.s.units:
			if u.f==game.s.human and u.alive and u.battle<0 and u.mp>0:warns=true
	label(m,"Cette attaque ferme les déplacements et transferts ordinaires encore disponibles ce tour." if warns else "Cette attaque consomme votre action dans ce conflit.",Rect2(205,555,1000,55),21,GOLD)
	button(m,"Revenir au plateau",Rect2(205,640,470,60),close_modal)
	button(m,"Confirmer l’attaque",Rect2(730,640,475,60),func():close_modal();act(func():return game.attack(bid,si,li,spell,target,hero_id),true))
