extends RefCounted
class_name CrystalState

const SAVE = "user://cristaux_v1.json"
const DIRS = [Vector2i(1,0),Vector2i(1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,1)]
const BASES = [Vector2i(0,-9),Vector2i(9,-9),Vector2i(-9,0),Vector2i(9,0),Vector2i(-9,9),Vector2i(0,9)]
const TERRAIN = ["Plaine","Forêt","Montagne","Désert","Mer / lac"]
var data: Dictionary
var s: Dictionary = {}
var rng = RandomNumberGenerator.new()
var error = ""

func _init():
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/factions.json"))

func new_game(human: int, seed_value: int = 0):
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	s = {"version":1,"human":human,"turn":0,"round":1,"seed":rng.seed,"units":[],"factions":[],"cells":{},"crystals":[],"battles":[],"log":[],"deck":[],"discard":[],"winner":-1,"ai_wait":false,"tutorial":0,"truces":[],"next_bid":0,"setup":true}
	for q in range(-9,10):
		for r in range(-9,10):
			if absi(q+r)>9: continue
			var px=(sqrt(3.0)*(q+r/2.0)*21+345)/690.0
			var py=(1.5*r*21+304)/608.0
			var terrain=0
			if py<0.42:terrain=1 if px<0.5 else 2
			elif py>0.58 and px<0.48:terrain=3
			elif py>0.62 and px>=0.5:terrain=4
			s.cells[key(Vector2i(q,r))] = {"q":q,"r":r,"t":terrain,"cache":false}
	for f in range(6):
		var h = []
		for _a in data.factions[f].heroes: h.append({"alive":true,"battle":-1})
		s.factions.append({"money":900,"crystals":[],"alive":true,"heroes":h,"hand":[],"don":false,"priest":[],"heal_turn":-3,"turns":0,"label":data.factions[f].name})
		for k in range(3):
			s.units.append({"f":f,"k":k,"q":BASES[f].x,"r":BASES[f].y,"money":500 if k<2 else 100,"crystals":[],"mp":0,"locked":-1,"battle":-1,"alive":true,"safe":{}})
		var cp = [Vector2i(-1,-5),Vector2i(6,-6),Vector2i(-5,0),Vector2i(-5,6),Vector2i(1,5),Vector2i(0,0)][f]
		if f<5:s.crystals.append({"q":int(cp.x),"r":int(cp.y),"holder":"map","owner":-1,"rewarded":false})
		var rp = [Vector2i(4,-8),Vector2i(8,-4),Vector2i(4,4),Vector2i(-4,8),Vector2i(-8,4),Vector2i(-4,-4)][f]
		s.cells[key(rp)].cache = true
	for i in range(data.cards.size()):
		for _n in range(int(data.cards[i][2])):s.deck.append(i)
	shuffle_deck()
	for f in range(6):
		for _n in range(2):s.factions[f].hand.append(s.deck.pop_back())
	s.turn = 0
	start_turn()
	log_event("Six factions • cinq cristaux. Les Elfes ouvrent la partie.")

func shuffle_deck():
	for i in range(s.deck.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var a=s.deck[i];s.deck[i]=s.deck[j];s.deck[j]=a

func key(p: Vector2i) -> String:return "%d,%d" % [p.x,p.y]
func pos(u: Dictionary) -> Vector2i:return Vector2i(int(u.q),int(u.r))
func distance(a: Vector2i,b: Vector2i) -> int:return maxi(maxi(absi(a.x-b.x),absi(a.y-b.y)),absi(a.x+a.y-b.x-b.y))
func fname(f: int) -> String:return data.factions[f].name
func faction_color(f: int) -> Color:return Color(data.factions[f].color)
func terrain_at(p: Vector2i) -> int:return int(s.cells.get(key(p),{"t":0}).t)
func fail(msg: String) -> bool:error=msg;return false
func log_event(msg: String):
	s.log.append("T%d · %s" % [s.round,msg])
	if s.log.size()>150:s.log.pop_front()
func total_money() -> int:
	var n=0
	for f in s.factions:n+=int(f.money)
	for u in s.units:n+=int(u.money)
	for b in s.battles:
		if not b.done:n+=int(b.pot)
	return n
func start_turn():
	var f=int(s.turn)
	s.factions[f].turns+=1
	s["combat_phase"]=false
	for u in s.units:
		if int(u.f)!=f or not u.alive:continue
		u.mp=0
		if int(u.battle)>=0 or int(u.locked)>=int(s.factions[f].turns):continue
		u.mp=8 if int(u.k)==2 else (4 if not u.crystals.is_empty() else 6)
		if f==4 and terrain_at(pos(u))==1 and int(u.k)<2:u.mp=mini(u.mp,5)
func advance_turn():
	if int(s.winner)>=0:return
	for _n in range(6):
		s.turn=(int(s.turn)+1)%6
		if int(s.turn)==0:s.round+=1
		if s.factions[s.turn].alive:break
	start_turn()
	check_win()
func truce(a:int,b:int)->bool:
	for t in s.truces:
		if int(t.until)>=int(s.round) and ((int(t.a)==a and int(t.b)==b) or (int(t.a)==b and int(t.b)==a)):return true
	return false
func offer_truce(other:int)->bool:
	var f=int(s.turn)
	if other==f or not s.factions[other].alive:return fail("Faction indisponible.")
	if truce(f,other):return fail("Une trêve est déjà active.")
	for b in s.battles:
		if not b.done and side_index(b,f)>=0 and side_index(b,other)>=0:return fail("Concluez d’abord une paix dans ce conflit.")
	if int(s.factions[f].money)<100:return fail("Le village doit offrir 100 R.")
	s.factions[f].money-=100;s.factions[other].money+=100
	s.truces.append({"a":f,"b":other,"until":int(s.round)+5})
	log_event("%s et %s : trêve de cinq manches contre 100 R."%[fname(f),fname(other)])
	return true
func path(a:Vector2i,b:Vector2i)->Array:
	if not s.cells.has(key(b)):return []
	var todo=[a];var prev={key(a):a};var index=0
	while index<todo.size():
		var p:Vector2i=todo[index];index+=1
		if p==b:break
		for d in DIRS:
			var x=p+d
			if s.cells.has(key(x)) and not prev.has(key(x)):
				prev[key(x)]=p;todo.append(x)
	if not prev.has(key(b)):return []
	var out=[];var x=b
	while x!=a:out.push_front(x);x=prev[key(x)]
	return out
func move_unit(uid:int,target:Vector2i)->bool:
	var u=s.units[uid]
	if s.get("combat_phase",false):return fail("Les déplacements précèdent les actions de guerre. Terminez votre tour.")
	if int(u.f)!=int(s.turn) or not u.alive:return fail("Ce pion ne joue pas actuellement.")
	if int(u.battle)>=0:return fail("Éclaireur engagé : utilisez Repli pour quitter le conflit.")
	var pth=path(pos(u),target)
	if pth.is_empty():return fail("Choisissez une autre case de la carte.")
	if pth.size()>int(u.mp):return fail("Déplacement trop long : %d cases restantes."%int(u.mp))
	for p in pth:
		u.q=p.x;u.r=p.y;u.mp-=1
		if s.cells[key(p)].cache and (int(u.k)<2 or int(u.money)<=200):
			u.money+=200;s.cells[key(p)].cache=false;log_event("%s récupère 200 R."%fname(u.f))
		if int(u.k)<2:
			for ci in range(s.crystals.size()):
				var c=s.crystals[ci]
				if c.holder=="map" and pos(c)==p and u.crystals.size()<2:
					c.holder="unit";c.owner=uid;u.crystals.append(ci);u.locked=int(s.factions[u.f].turns)+1;u.mp=0
					log_event("%s prend un cristal : prochain tour immobile."%fname(u.f));break
		if p==BASES[u.f] and not u.crystals.is_empty():
			for ci in u.crystals:
				var c=s.crystals[ci];c.holder="base";c.owner=u.f;s.factions[u.f].crystals.append(ci)
				if not c.rewarded:s.factions[u.f].money+=400;c.rewarded=true
			u.crystals.clear();log_event("%s rapporte ses cristaux au village."%fname(u.f));check_win()
		if int(u.mp)==0:break
	return true
func reserve_money(ref:String)->int:
	return int(s.factions[int(ref.substr(1))].money) if ref.begins_with("b") else int(s.units[int(ref.substr(1))].money)
func reserve_set(ref:String,n:int):
	if ref.begins_with("b"):s.factions[int(ref.substr(1))].money=n
	else:s.units[int(ref.substr(1))].money=n
func reserve_pos(ref:String)->Vector2i:
	return BASES[int(ref.substr(1))] if ref.begins_with("b") else pos(s.units[int(ref.substr(1))])
func reserve_f(ref:String)->int:
	return int(ref.substr(1)) if ref.begins_with("b") else int(s.units[int(ref.substr(1))].f)
func transfer(a:String,b:String,n:int,setup=false)->bool:
	if a==b or n<=0:return fail("Choisissez deux réserves et un montant positif.")
	if reserve_f(a)!=int(s.human) or reserve_f(b)!=int(s.human):return fail("Transfert réservé à votre faction.")
	if not setup and s.get("combat_phase",false):return fail("Les transferts précèdent vos actions de guerre.")
	if not setup and int(s.turn)!=int(s.human):return fail("Attendez votre tour.")
	if reserve_pos(a)!=reserve_pos(b):return fail("Les réserves doivent être sur la même case.")
	if reserve_money(a)<n:return fail("Ressources insuffisantes.")
	if b.begins_with("u") and int(s.units[int(b.substr(1))].k)==2 and reserve_money(b)+n>400:return fail("Le messager transporte au maximum 400 R.")
	reserve_set(a,reserve_money(a)-n);reserve_set(b,reserve_money(b)+n)
	return true
func side_index(b:Dictionary,f:int)->int:
	for i in range(2):
		if int(b.sides[i].f)==f:return i
	return -1
func wallet(side:Dictionary)->int:
	if side.base:return int(s.factions[side.f].money)
	var n=0
	for uid in side.units:n+=int(s.units[uid].money)
	return n
func debit(side:Dictionary,n:int)->bool:
	if n<0 or wallet(side)<n:return false
	if side.base:s.factions[side.f].money-=n;return true
	for uid in side.units:
		var take=mini(int(s.units[uid].money),n);s.units[uid].money-=take;n-=take
	return true
func credit(side:Dictionary,n:int):
	if side.base:s.factions[side.f].money+=n
	else:s.units[side.units[0]].money+=n
func make_side(f:int,uid:int,is_base:bool)->Dictionary:
	return {"f":f,"units":[] if is_base else [uid],"base":is_base,"lines":[],"deployed":false,"last":-1,"redeploy":[0,0],"drawn":false,"damage":0,"don":false,"blocked":false,"free":false,"freehero":false,"pierce":false,"gift":false,"priest":false,"orc_power":false,"selfheal":false}
func battle_by_id(id:int)->Dictionary:
	for b in s.battles:
		if int(b.id)==id:return b
	return {}
func declare_war(uid:int,target:int,is_base:bool=false)->bool:
	var u=s.units[uid]
	if int(u.f)!=int(s.turn) or int(u.k)==2 or int(u.battle)>=0:return fail("Seul un éclaireur libre de votre faction peut attaquer.")
	var tf=target if is_base else int(s.units[target].f)
	if tf==int(u.f) or not s.factions[tf].alive or truce(u.f,tf):return fail("Cette faction ne peut pas être attaquée.")
	if is_base:
		if distance(pos(u),BASES[tf])>1:return fail("Approchez-vous du village ennemi à une case.")
		for old in s.battles:
			if not old.done:
				for sd in old.sides:
					if sd.base and int(sd.f)==tf:return fail("Ce village est déjà assiégé.")
	else:
		var v=s.units[target]
		if not v.alive or int(v.k)==2 or int(v.battle)>=0:return fail("Cet éclaireur n’est pas une cible disponible.")
		if distance(pos(u),pos(v))>4:return fail("Portée : trois cases intermédiaires maximum.")
		if int(v.safe.get(str(uid),-1))>=int(s.factions[u.f].turns):return fail("Cet éclaireur bénéficie de sa protection de repli.")
	if int(u.money)<20:return fail("Il faut 20 R pour déclarer la guerre.")
	u.money-=20
	var id=int(s.next_bid);s.next_bid+=1
	var p=pos(u)
	var b={"id":id,"sides":[make_side(u.f,uid,false),make_side(tf,target,is_base)],"pot":20,"terrain":terrain_at(p),"q":p.x,"r":p.y,"active":0,"opening":true,"done":false,"result":"","peace":false}
	s.battles.append(b);u.battle=id;u.mp=0
	if not is_base:s.units[target].battle=id;s.units[target].mp=0
	for si in range(2):
		if int(b.sides[si].f)!=int(s.human):auto_deploy(b,si)
	log_event("%s attaque %s : conflit %d."%[fname(u.f),fname(tf),id+1])
	return true
func stats(f:int,line:int,n:int,t:int)->Array:
	if n<=0:return [0,0,0,0]
	var a:Array=data.factions[f].lines[line][clampi(n-1,0,data.factions[f].lines[line].size()-1)].duplicate()
	if f==0 and t==1 and a[1]>=20:a[1]-=5
	if (f==0 and t==4) or (f==3 and t==2) or (f==5 and t==0):a[0]+=1;a[1]+=1
	if f==1:
		if t==2:a[2]+=n
		if t==4:a[3]=maxi(1,int(a[3])-1)
		if t==3:a[1]+=1
	if f==3 and t==1:a[3]+=5 if a[3]<50 else 10
	if f==4 and t==3 and n>=4:a[2]+=5;a[3]+=5
	if f==5 and t==4 and a[2]>30:a[2]+=10
	return a
func hero_stats(f:int,ids:Array,t:int)->Array:
	if ids.is_empty():return [0,0,0,0]
	var a=[0,0,0,0]
	if f==0 or f==4:a=(data.group_elf if f==0 else data.group_orc)[ids.size()-1].duplicate()
	else:
		for id in ids:
			var h=data.factions[f].heroes[id]
			for j in range(4):a[j]+=h[j+1]
	if f==0 and t==1 and a[1]>=20:a[1]-=5
	if (f==0 and t==4) or (f==3 and t==2) or (f==5 and t==0):a[0]+=1;a[1]+=1
	if f==1 and t==2:a[2]+=ids.size()
	if f==1 and t==3:a[1]+=1
	if f==1 and t==4:a[3]=maxi(1,a[3]-1)
	if f==3 and t==1:a[3]+=5 if a[3]<50 else 10
	if f==4 and t==3 and ids.size()>=4:a[2]+=5;a[3]+=5
	if f==5 and t==4 and a[2]>30:a[2]+=10
	return a
func available_heroes(f:int)->Array:
	var out=[]
	for i in range(s.factions[f].heroes.size()):
		var h=s.factions[f].heroes[i]
		if h.alive and int(h.battle)<0:out.append(i)
	return out
func make_line(n:int,a:Array,ids:Array=[])->Dictionary:
	return {"n":n,"cost":int(a[1]),"atk":int(a[2]),"max":int(a[3]),"hp":int(a[3]),"heroes":ids.duplicate()}
func deploy(bid:int,si:int,n1:int,n2:int,heroes:Array)->bool:
	var b=battle_by_id(bid);var side=b.sides[si];var f=int(side.f)
	if side.deployed:return fail("Armée déjà déployée.")
	if n1<2 or n2<2 or n1>data.factions[f].lines[0].size() or n2>data.factions[f].lines[1].size():return fail("Au moins 2 unités par ligne, dans les limites de la faction.")
	var avail=available_heroes(f)
	for h in heroes:
		if not avail.has(h):return fail("Héros mort ou engagé ailleurs.")
	var a=stats(f,0,n1,b.terrain);var c=stats(f,1,n2,b.terrain);var h=hero_stats(f,heroes,b.terrain)
	var cost=int(a[0]+c[0]+h[0])
	if wallet(side)<cost:return fail("Déploiement impossible : %d R nécessaires."%cost)
	debit(side,cost);b.pot+=cost
	side.lines=[make_line(n1,a),make_line(n2,c),make_line(heroes.size(),h,heroes)]
	side.deployed=true
	if f in [1,2,5]:
		side.lines[2]["members"]=[]
		for hi in heroes:
			var hs=hero_stats(f,[hi],b.terrain)
			side.lines[2].members.append({"id":hi,"hp":int(hs[3]),"max":int(hs[3]),"atk":int(hs[2]),"cost":int(hs[1])})
		sync_heroes(side.lines[2])
	for hi in heroes:s.factions[f].heroes[hi].battle=bid
	return true
func auto_deploy(b:Dictionary,si:int):
	var side=b.sides[si];var f=int(side.f);var money=wallet(side)
	var n1=2;var n2=2
	var mincost=int(stats(f,0,2,b.terrain)[0]+stats(f,1,2,b.terrain)[0])
	if money<mincost:
		side.deployed=true;side.lines=[make_line(0,[0,0,0,0]),make_line(0,[0,0,0,0]),make_line(0,[0,0,0,0])];return
	var budget=money/4
	for n in range(2,data.factions[f].lines[0].size()+1):
		var a=stats(f,0,n,b.terrain)
		if a[0]+a[1]*3<=budget:n1=n
	for n in range(2,data.factions[f].lines[1].size()+1):
		var a=stats(f,1,n,b.terrain)
		if a[0]+a[1]*3<=budget:n2=n
	var hs=[];var avail=available_heroes(f)
	for h in avail:
		var test=hs.duplicate();test.append(h)
		var a=hero_stats(f,test,b.terrain)
		if a[0]+a[1]*3 < money/2:hs=test
	deploy(b.id,si,n1,n2,hs)
func front(side:Dictionary)->int:
	for i in range(side.lines.size()):
		if int(side.lines[i].hp)>0:return i
	return -1
func ready(b:Dictionary)->bool:return b.sides[0].deployed and b.sides[1].deployed
func can_act(b:Dictionary,si:int)->bool:
	return not b.done and ready(b) and int(b.active)==si and int(b.sides[si].f)==int(s.turn) and int(b.sides[si].last)!=int(s.factions[s.turn].turns)
func next_action(b:Dictionary,si:int):
	s["combat_phase"]=true
	b.sides[si].last=int(s.factions[b.sides[si].f].turns);b.active=1-si;b.opening=false
func kill_line(b:Dictionary,si:int,li:int):
	var line=b.sides[si].lines[li]
	line.hp=0
	if li==2:
		for h in line.heroes:s.factions[b.sides[si].f].heroes[h].alive=false;s.factions[b.sides[si].f].heroes[h].battle=-1
func deal(b:Dictionary,si:int,li:int,amount:int):
	if li<0 or li>=b.sides[si].lines.size():return
	var line=b.sides[si].lines[li]
	if li==2 and line.has("members"):
		for member in line.members:
			if member.hp<=0:continue
			var hit=mini(int(member.hp),amount)
			member.hp=maxi(0,int(member.hp)-amount);b.sides[si].damage+=hit
			if member.hp==0:
				s.factions[b.sides[si].f].heroes[member.id].alive=false
				s.factions[b.sides[si].f].heroes[member.id].battle=-1
			break
		sync_heroes(line);return
	var hit=mini(int(line.hp),amount)
	line.hp=maxi(0,int(line.hp)-amount);b.sides[si].damage+=hit
	if int(line.hp)==0:kill_line(b,si,li)
func attack(bid:int,si:int,li:int,spell:int=0,target_line:int=-1,hero_id:int=-1)->bool:
	var b=battle_by_id(bid)
	if not can_act(b,si):return fail("Ce camp ne peut pas agir maintenant.")
	var side=b.sides[si];var other=b.sides[1-si];var f=int(side.f)
	if li<0 or li>2 or int(side.lines[li].hp)<=0:return fail("Cette ligne est tombée.")
	if b.opening and li!=0:return fail("La première attaque utilise l’infanterie.")
	var line=side.lines[li];var cost=int(line.cost);var damage=int(line.atk)
	var attacker={}
	if li==2 and line.has("members"):
		for member in line.members:
			if member.hp>0 and member.atk>0 and (hero_id<0 or int(member.id)==hero_id):
				attacker=member;break
		if attacker.is_empty():return fail("Ce héros ne peut pas attaquer.")
		cost=int(attacker.cost);damage=int(attacker.atk)
	if f==3 and li==2:
		cost=[20,40,60][clampi(spell,0,2)]+(1 if int(b.terrain)==2 else 0);damage=[85,100,120][clampi(spell,0,2)]
	if side.free or (li==2 and side.freehero):cost=0
	if wallet(side)<cost:return fail("Pas assez de ressources pour cette attaque.")
	if damage<=0:return fail("Cette ligne soigne : utilisez le bouton Soin.")
	var target=front(other)
	if target<0:resolve(b,si,"victoire");return true
	if side.pierce and target_line>=0 and target_line<3 and other.lines[target_line].hp>0:target=target_line
	debit(side,cost);b.pot+=cost;side.free=false
	if li==2:side.freehero=false
	if other.priest and wallet(other)>=cost:
		debit(other,cost);b.pot+=cost;other.priest=false;log_event("Corruption : attaque annulée, %d R payées par chaque camp."%cost);next_action(b,si);return true
	if f==4 and li==2 and side.orc_power:damage=200;side.orc_power=false
	deal(b,1-si,target,damage);side.pierce=false
	if f==2 and li==0 and int(line.n)==12 and target<2:deal(b,1-si,target+1,20)
	if f==0 and li==1 and int(line.n)>=11:
		for own in side.lines:
			if own.hp>0 and own.hp<own.max:own.hp=mini(own.max,own.hp+(20 if line.n==12 else 10));break
	if f==4 and li==1 and int(line.n)==4 and side.lines[0].hp>0:side.lines[0].hp=mini(side.lines[0].max,side.lines[0].hp+30)
	if f==5 and li==2 and not attacker.is_empty():
		if side.selfheal:attacker.hp=mini(attacker.max,attacker.hp+40);side.selfheal=false
		else:
			for member in line.members:
				if member.id!=attacker.id and member.hp>0 and member.hp<member.max:member.hp=mini(member.max,member.hp+40);break
		sync_heroes(line)
	if int(other.f)==0 and target==1 and int(other.lines[1].n)==12:deal(b,si,li,20)
	log_event("%s : %d dégâts, coût %d R (conflit %d)."%[fname(f),damage,cost,bid+1])
	next_action(b,si)
	if front(other)<0:
		# A base with resources or an unused ordinary redeployment can recover next turn.
		if not can_recover(b,1-si):resolve(b,si,"victoire")
	if not b.done and front(side)<0 and not can_recover(b,si):resolve(b,1-si,"victoire")
	return true
func can_recover(b:Dictionary,si:int)->bool:
	var side=b.sides[si]
	for li in range(2):
		var a=stats(side.f,li,2,b.terrain)
		if (side.base or int(side.redeploy[li])<1) and wallet(side)>=a[0]+a[1]:return true
	return false
func redeploy(bid:int,si:int,li:int,n:int,use_elf=false)->bool:
	var b=battle_by_id(bid)
	if not can_act(b,si) or li>1:return fail("Redéploiement indisponible.")
	var side=b.sides[si];var f=int(side.f)
	if side.lines[li].hp>0:return fail("La ligne doit être tombée.")
	if n<2 or n>data.factions[f].lines[li].size():return fail("Effectif hors limites.")
	var extra=use_elf and f==0 and not side.don and not side.blocked
	if not side.base and int(side.redeploy[li])>=1 and not extra:return fail("Redéploiement déjà utilisé pour cette ligne.")
	var a=stats(f,li,n,b.terrain);var cost=int(a[0])*(2 if extra else 1)
	if wallet(side)<cost+int(a[1]):return fail("Gardez aussi le coût de l’attaque obligatoire.")
	debit(side,cost);b.pot+=cost;side.lines[li]=make_line(n,a);side.redeploy[li]+=1
	if extra:side.don=true
	return attack(bid,si,li)
func heal(bid:int,si:int,li:int)->bool:
	var b=battle_by_id(bid)
	if not can_act(b,si):return fail("Attendez votre action dans ce conflit.")
	var side=b.sides[si];var f=int(side.f)
	if side.lines[li].hp<=0 or side.lines[li].hp==side.lines[li].max:return fail("Choisissez une ligne blessée encore debout.")
	var cost=0
	if f==3:
		if int(s.factions[f].turns)-int(s.factions[f].heal_turn)<3:return fail("Baldur doit attendre deux tours complets.")
		cost=[40,50,60][li]
	elif f==1:
		if not hero_present(side.lines[2],2):return fail("Le Prothésiste doit être présent.")
		cost=[30,50,100][li]
	else:return fail("Cette faction ne dispose pas de ce soin.")
	if side.free:cost=0
	if not debit(side,cost):return fail("Ressources insuffisantes pour soigner.")
	b.pot+=cost;side.free=false
	if li==2 and side.lines[li].has("members"):
		for member in side.lines[li].members:
			if member.hp>0 and member.hp<member.max:member.hp=member.max;break
		sync_heroes(side.lines[li])
	else:side.lines[li].hp=side.lines[li].max
	if f==3:s.factions[f].heal_turn=s.factions[f].turns
	next_action(b,si);log_event("%s soigne sa ligne %d."%[fname(f),li+1]);return true
func use_don(bid:int,si:int)->bool:
	var b=battle_by_id(bid);var side=b.sides[si];var f=int(side.f)
	if not can_act(b,si) or side.blocked:return fail("Don indisponible ou bloqué.")
	if f==0:return fail("Utilisez « Ancêtres » sur une ligne tombée dans le menu Renfort.")
	var used=side.don if f==5 else s.factions[f].don
	if f==2:used=s.factions[f].priest.has(int(b.sides[1-si].f))
	if used and not side.gift:return fail("Don déjà utilisé.")
	if f==1:side.free=true
	if f==2:side.priest=true
	if f==3:
		var remaining=100;var removed=0
		for line in side.lines:
			if line.hp>0:
				var n=mini(remaining,int(line.max-line.hp));line.hp+=n;removed+=n;remaining-=n
		if removed==0:return fail("Aucun dégât sur vos lignes encore debout.")
		var target=front(b.sides[1-si]);deal(b,1-si,target,removed)
		if front(b.sides[1-si])<0 and not can_recover(b,1-si):resolve(b,si,"victoire")
	if f==4:
		if side.lines[2].hp<=0:return fail("Il faut des trolls encore debout.")
		side.orc_power=true
	if f==5:
		if side.lines[2].hp<=0 or int(side.lines[2].n)!=1:return fail("Il faut exactement un chaman vivant sur ce plateau.")
		side.selfheal=true
	if not side.gift:
		if f==5:side.don=true
		elif f==2:s.factions[f].priest.append(int(b.sides[1-si].f))
		else:s.factions[f].don=true
	side.gift=false;log_event("%s active son don."%fname(f));return true
func reinforce(uid:int,bid:int)->bool:
	var b=battle_by_id(bid);var u=s.units[uid];var si=side_index(b,u.f)
	if b.done or si<0 or int(u.f)!=int(s.turn) or int(u.k)==2 or int(u.battle)>=0:return fail("Renfort impossible.")
	var side=b.sides[si]
	var p=BASES[u.f] if side.base else pos(s.units[side.units[0]])
	if pos(u)!=p:return fail("Le renfort doit rejoindre la case de son allié.")
	if side.base:
		s.factions[u.f].money+=u.money;u.money=0;return true
	side.units.append(uid);side.redeploy=[-1,-1];u.battle=bid;u.mp=0
	log_event("Un deuxième éclaireur renforce le conflit %d."%(bid+1));return true
func draw_card(bid:int,si:int)->bool:
	var b=battle_by_id(bid);var side=b.sides[si]
	if not can_act(b,si) or side.drawn:return fail("Une seule pioche par camp et par conflit.")
	if s.deck.is_empty():return fail("La pioche est épuisée.")
	side.drawn=true;s.factions[side.f].hand.append(s.deck.pop_back())
	next_action(b,si);return true
func play_card(bid:int,si:int,hand_index:int)->bool:
	var b=battle_by_id(bid);var side=b.sides[si];var hand=s.factions[side.f].hand
	if hand_index<0 or hand_index>=hand.size():return fail("Carte indisponible.")
	var c=int(hand[hand_index])
	if c==12 and ready(b) and b.opening:
		b.active=si
	elif not can_act(b,si):return fail("Attendez votre action.")
	match c:
		0,5,9:credit(side,{0:50,5:100,9:70}[c])
		1,2,3:
			var changed=false
			for li in range(2):
				if (c==1 and li==1) or (c==2 and li==0):continue
				if side.lines[li].hp>0:continue
				var n=5 if c==1 else (3 if c==2 else 2)
				side.lines[li]=make_line(n,stats(side.f,li,n,b.terrain));changed=true
			if not changed:return fail("La carte exige une ligne tombée.")
		4:side.free=true
		6:
			if side.base:return fail("Un village ne peut pas fuir.")
			retreat(bid,si,true)
		7:side.freehero=true
		8:
			var other=b.sides[1-si];var best={"atk":0,"cost":0}
			for ln in other.lines:
				if ln.hp>0 and ln.atk>best.atk:best=ln
			var cost=int(ceil(float(best.cost)/2))
			if best.atk<=0 or not debit(side,cost):return fail("Copie impossible ou trop coûteuse.")
			b.pot+=cost;deal(b,1-si,front(other),best.atk);next_action(b,si)
			if front(other)<0 and not can_recover(b,1-si):resolve(b,si,"victoire")
		10:
			var found=false
			for h in s.factions[side.f].heroes:
				if not h.alive:h.alive=true;h.battle=-1;found=true;break
			if not found:return fail("Aucun héros mort.")
			next_action(b,si)
		11:side.pierce=true
		12:pass
		13:
			for f in range(6):
				if f!=int(side.f) and s.factions[f].alive:
					var n=mini(60,int(s.factions[f].money));s.factions[f].money-=n;credit(side,n)
		14:side.gift=true
		15:b.sides[1-si].blocked=true
	hand.remove_at(hand_index);s.discard.append(c)
	log_event("%s joue %s."%[fname(side.f),data.cards[c][0]])
	return true
func retreat(bid:int,si:int,card=false)->bool:
	var b=battle_by_id(bid);var side=b.sides[si]
	if not can_act(b,si) or side.base:return fail("Repli impossible.")
	if not card and not debit(side,20):return fail("Le repli coûte 20 R.")
	if card:
		var half=int(b.pot)/2;credit(side,half);credit(b.sides[1-si],int(b.pot)-half);b.pot=0
	else:b.pot+=20
	resolve(b,1-si,"repli");return true
func peace(bid:int,si:int)->bool:
	var b=battle_by_id(bid)
	if not can_act(b,si):return fail("Attendez votre action.")
	var other=b.sides[1-si]
	if other.base:return fail("Le défenseur refuse de lever le siège par partage.")
	var mypower=0;var power=0
	for l in b.sides[si].lines:mypower+=l.hp
	for l in other.lines:power+=l.hp
	if power>mypower*2:return fail("L’adversaire pense gagner et refuse la paix.")
	var half=int(b.pot)/2
	credit(b.sides[si],half);credit(b.sides[1-si],int(b.pot)-half)
	b.pot=0;b.done=true;b.result="Paix négociée"
	release_battle(b);log_event("Conflit %d : paix et partage des dépenses."%(bid+1));return true
func release_battle(b:Dictionary):
	for sd in b.sides:
		for uid in sd.units:s.units[uid].battle=-1;s.units[uid].mp=0
		for h in s.factions[sd.f].heroes:
			if int(h.battle)==int(b.id):h.battle=-1
func take_crystal(ci:int,win:Dictionary,b:Dictionary):
	var c=s.crystals[ci]
	if win.base:
		c.holder="base";c.owner=win.f;s.factions[win.f].crystals.append(ci)
		if not c.rewarded:s.factions[win.f].money+=400;c.rewarded=true
	else:
		var u=s.units[win.units[0]]
		if u.crystals.size()<2:c.holder="unit";c.owner=win.units[0];u.crystals.append(ci)
		else:c.holder="map";c.owner=-1;c.q=b.q;c.r=b.r
func resolve(b:Dictionary,win_si:int,reason:String):
	if b.done:return
	b.done=true
	var win=b.sides[win_si];var lose=b.sides[1-win_si]
	var loot=int(b.pot);b.pot=0
	if reason!="repli":
		loot+=wallet(lose);debit(lose,wallet(lose))
	credit(win,loot)
	var crystals=[]
	if lose.base:
		crystals=s.factions[lose.f].crystals.duplicate();s.factions[lose.f].crystals.clear()
	else:
		for uid in lose.units:
			crystals.append_array(s.units[uid].crystals);s.units[uid].crystals.clear()
	for ci in crystals:take_crystal(ci,win,b)
	for uid in lose.units:
		var u=s.units[uid]
		if reason=="repli":
			var best=pos(u);var score=-10000
			for d in DIRS:
				var p=pos(u)+d
				if not s.cells.has(key(p)):continue
				var enemy=BASES[win.f] if win.base else pos(s.units[win.units[0]])
				var sc=distance(p,enemy)*10-distance(p,BASES[u.f])
				if sc>score:score=sc;best=p
			u.q=best.x;u.r=best.y
			for e in win.units:u.safe[str(e)]=int(s.factions[win.f].turns)+2
		else:u.q=BASES[u.f].x;u.r=BASES[u.f].y;u.locked=-1
	release_battle(b)
	b.result="%s : %s (+%d R)"%[fname(win.f),reason,loot]
	log_event("Conflit %d terminé : %s."%[int(b.id)+1,b.result])
	if lose.base:eliminate(lose.f,win,b)
	check_win()
func eliminate(f:int,win:Dictionary,b:Dictionary):
	s.factions[f].alive=false
	for u in s.units:
		if int(u.f)!=f:continue
		if int(u.battle)<0:
			credit(win,int(u.money));u.money=0
			for ci in u.crystals:take_crystal(ci,win,b)
			u.crystals.clear();u.alive=false
	for card in s.factions[f].hand:s.factions[win.f].hand.append(card)
	s.factions[f].hand.clear()
	for other in s.battles:
		if other.done:continue
		var si=side_index(other,f)
		if si>=0:resolve(other,1-si,"chute du village")
	for u in s.units:
		if int(u.f)==f:u.alive=false
func check_win():
	if int(s.winner)>=0:return
	var alive=[]
	for f in range(6):
		if s.factions[f].alive:alive.append(f)
		if s.factions[f].crystals.size()>=5:s.winner=f
	if alive.size()==1:s.winner=alive[0]
	if int(s.winner)>=0:log_event("%s remporte la partie !"%fname(s.winner))
func pending_human()->int:
	for b in s.battles:
		if b.done:continue
		var si=side_index(b,s.human)
		if si>=0 and not b.sides[si].deployed:return int(b.id)
	return -1
func resolve_empty(b:Dictionary):
	if not ready(b) or b.done:return
	for si in range(2):
		if front(b.sides[si])<0 and not can_recover(b,si):resolve(b,1-si,"victoire");return
func ai_move(f:int):
	# Scouts pursue visible objectives with the same movement rules as the player.
	for uid in range(f*3,f*3+2):
		var u=s.units[uid]
		if not u.alive or int(u.battle)>=0:continue
		if pos(u)==BASES[f] and int(u.money)<250:
			var take=mini(500-int(u.money),maxi(0,int(s.factions[f].money)-180));u.money+=take;s.factions[f].money-=take
		var target=BASES[f];var best=10000
		if u.crystals.is_empty():
			for c in s.crystals:
				if c.holder=="map":
					var dist=distance(pos(u),pos(c))
					if dist<best:best=dist;target=pos(c)
			if best==10000:
				for ef in range(6):
					if ef==f or not s.factions[ef].alive or truce(f,ef):continue
					var score=distance(pos(u),BASES[ef])-s.factions[ef].crystals.size()*4
					if score<best:best=score;target=BASES[ef]
				for e in s.units:
					if int(e.f)!=f and e.alive and not e.crystals.is_empty() and not truce(f,e.f):
						var score=distance(pos(u),pos(e))-10
						if score<best:best=score;target=pos(e)
		var pth=path(pos(u),target)
		if not pth.is_empty() and int(u.mp)>0:move_unit(uid,pth[mini(pth.size(),int(u.mp))-1])
		if int(s.winner)>=0:return
		if not u.crystals.is_empty():continue
		var chosen=-1;best=-9999
		for euid in range(s.units.size()):
			var e=s.units[euid]
			if int(e.f)==f or not e.alive or int(e.k)==2 or int(e.battle)>=0 or truce(f,e.f):continue
			if distance(pos(u),pos(e))>4:continue
			var score=e.crystals.size()*500+int(u.money)-int(e.money)
			if score>best and (e.crystals.size()>0 or (int(u.money)>int(e.money)+150 and distance(pos(u),pos(e))<=2)):best=score;chosen=euid
		if chosen>=0:declare_war(uid,chosen)
		else:
			for ef in range(6):
				if ef!=f and s.factions[ef].alive and not truce(f,ef) and distance(pos(u),BASES[ef])<=1 and int(u.money)>150:
					declare_war(uid,ef,true);break
	# Messenger follows the poorest scout, restocks at base and delivers at the same hex.
	var m=s.units[f*3+2]
	if not m.alive:return
	if pos(m)==BASES[f] and int(m.money)<400:
		var take=mini(400-int(m.money),maxi(0,int(s.factions[f].money)-100));m.money+=take;s.factions[f].money-=take
	var needy=f*3
	if s.units[f*3+1].money<s.units[needy].money:needy+=1
	var dest=BASES[f] if int(m.money)==0 else pos(s.units[needy])
	var route=path(pos(m),dest)
	if not route.is_empty() and int(m.mp)>0:move_unit(f*3+2,route[mini(route.size(),int(m.mp))-1])
	if pos(m)==pos(s.units[needy]) and int(m.money)>0:s.units[needy].money+=m.money;m.money=0
func ai_combat(f:int):
	for b in s.battles:
		if b.done:continue
		resolve_empty(b)
		if b.done:continue
		var si=side_index(b,f)
		if si<0 or not can_act(b,si):continue
		var sd=b.sides[si]
		if not sd.blocked and f!=0:use_don(b.id,si)
		if b.done:continue
		if wallet(sd)<70:
			for k in range(s.factions[f].hand.size()):
				if int(s.factions[f].hand[k]) in [0,5,9,13]:play_card(b.id,si,k);break
		var best=-1;var damage=-1
		for li in range(3):
			var ln=sd.lines[li]
			if b.opening and li!=0:continue
			var cost=0 if sd.free or (li==2 and sd.freehero) else int(ln.cost)
			if ln.hp>0 and cost<=wallet(sd) and ln.atk>damage and ln.atk>0:best=li;damage=ln.atk
		if best>=0:
			var hero_id=-1
			if best==2 and sd.lines[2].has("members"):
				var power=-1
				for member in sd.lines[2].members:
					if member.hp>0 and member.atk>power and (sd.free or sd.freehero or member.cost<=wallet(sd)):hero_id=member.id;power=member.atk
			attack(b.id,si,best,0,-1,hero_id);continue
		var recovered=false
		for li in range(2):
			if sd.lines[li].hp<=0 and (sd.base or sd.redeploy[li]<1 or (f==0 and not sd.don)):
				if redeploy(b.id,si,li,2,f==0 and sd.redeploy[li]>=1):recovered=true;break
		if recovered:continue
		if not sd.base and wallet(sd)>=20:retreat(b.id,si);continue
		var other=b.sides[1-si];var affordable=false
		for ln in other.lines:
			if ln.hp>0 and ln.atk>0 and int(ln.cost)<=wallet(other):affordable=true
		if not affordable:
			resolve(b,si if int(sd.damage)<int(other.damage) else 1-si,"épuisement")
		else:resolve(b,1-si,"épuisement")
func concede_if_broke(bid:int,si:int)->bool:
	var b=battle_by_id(bid)
	if not can_act(b,si):return false
	var sd=b.sides[si]
	for ln in sd.lines:
		if ln.hp>0 and ln.atk>0 and (sd.free or int(ln.cost)<=wallet(sd)):return fail("Une attaque est encore possible.")
	if can_recover(b,si):return fail("Un redéploiement est encore possible.")
	resolve(b,1-si,"épuisement");return true
func save_game():
	if s.is_empty():return
	var f=FileAccess.open(SAVE,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify(s))
func load_game()->bool:
	if not FileAccess.file_exists(SAVE):return false
	var loaded=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not loaded is Dictionary or int(loaded.get("version",0))!=1:return false
	s=loaded;rng.seed=int(s.seed);return true

func sync_heroes(line:Dictionary):
	line.hp=0;line.max=0;line.n=0;line.atk=0;line.cost=0
	for member in line.members:
		line.hp+=int(member.hp);line.max+=int(member.max)
		if member.hp>0:
			line.n+=1
			if member.atk>line.atk:line.atk=int(member.atk);line.cost=int(member.cost)
func hero_present(line:Dictionary,id:int)->bool:
	if line.has("members"):
		for member in line.members:
			if int(member.id)==id and member.hp>0:return true
		return false
	return line.hp>0 and line.heroes.has(id)
