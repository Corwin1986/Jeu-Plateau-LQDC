extends RefCounted
# Presentation-only advice. The rules engine remains authoritative.
const STYLES=[
["Forêt, économie et redéploiement.","Surveillez le coût de vos renforts hors forêt."],
["Montagne et héros spécialisés.","Les pouvoirs demandent une réserve disponible."],
["Infanterie forte et attaque adverse annulable.","La corruption exige de pouvoir payer son coût."],
["Résistance, soins et transfert de dégâts.","Les soins coûtent des ressources et imposent un délai."],
["Effectifs nombreux, trolls et désert favorable.","Gardez de quoi financer les attaques des héros."],
["Chamans solidaires et avantages en mer.","Le soutien dépend des héros encore vivants."]]
static func situation(g)->Dictionary:
	var f=int(g.s.human)
	if g.s.turn!=f:return {"title":"Les autres royaumes jouent", "text":"Observez les déplacements. Vos nouvelles actions seront disponibles à votre tour.","action":"Observer le monde","kind":"map","uid":f*3}
	for b in g.s.battles:
		var si=g.side_index(b,f)
		if b.done or si<0:continue
		if not b.sides[si].deployed:return {"title":"Une armée attend vos ordres", "text":"Le conflit %d demande un déploiement. La réserve engagée est de %d R."%[b.id+1,g.wallet(b.sides[si])],"action":"Préparer cette armée","kind":"battle","bid":b.id}
		if g.can_act(b,si):return {"title":"Une décision sur le plateau", "text":"Vous pouvez agir dans le conflit %d. Déplacez et ravitaillez vos autres pions avant de combattre."%(b.id+1),"action":"Voir ce combat","kind":"battle","bid":b.id}
	for k in range(2):
		var uid=f*3+k;var u=g.s.units[uid]
		if u.alive and not u.crystals.is_empty() and int(u.locked)>=int(g.s.factions[f].turns):return {"title":"Votre porteur sécurise son cristal", "text":"Éclaireur %d est immobilisé ce tour. Vous pouvez utiliser l’autre éclaireur ou préparer le messager."%(k+1),"action":"Voir le porteur","kind":"map","uid":uid}
	for k in range(2):
		var uid=f*3+k;var u=g.s.units[uid]
		if not u.alive or u.battle>=0:continue
		for enemy in g.s.units:
			if enemy.f!=f and enemy.alive and enemy.k!=2 and enemy.battle<0 and not g.truce(f,enemy.f) and g.distance(g.pos(u),g.pos(enemy))<=4:return {"title":"Un adversaire à portée", "text":"Un éclaireur %s est à quatre cases ou moins de votre éclaireur %d. Vérifiez le risque avant de poursuivre."%[g.fname(enemy.f),k+1],"action":"Voir mon expédition","kind":"map","uid":uid}
	if not g.s.get("combat_phase",false):
		for k in [1,0]:
			var u=g.s.units[f*3+k]
			if u.alive and u.battle<0 and u.mp>0:return {"title":"Éclaireur %d peut encore avancer"%(k+1),"text":"%d pas disponibles et %d R dans sa réserve. Choisissez une destination pour poursuivre l’expédition."%[u.mp,u.money],"action":"Jouer cet éclaireur","kind":"map","uid":f*3+k}
	return {"title":"Faites le point sur votre tour", "text":"Consultez vos conflits, puis terminez le tour lorsque vous avez joué vos actions disponibles.","action":"Voir mes conflits","kind":"conflicts"}
static func attack_preview(g,bid:int,si:int,li:int,spell:int=0,target:int=-1,hero:int=-1)->Dictionary:
	var b=g.battle_by_id(bid);var sd=b.sides[si];var ln=sd.lines[li];var cost=int(ln.cost)
	if li==2 and ln.has("members"):
		for member in ln.members:
			if member.hp>0 and member.atk>0 and (hero<0 or member.id==hero):cost=int(member.cost);break
	if sd.f==3 and li==2:cost=[20,40,60][clampi(spell,0,2)]+(1 if b.terrain==2 else 0)
	if sd.free or (li==2 and sd.freehero):cost=0
	var sim=load("res://state.gd").new();sim.s=g.s.duplicate(true)
	if not sim.attack(bid,si,li,spell,target,hero):return {"ok":false,"error":sim.error}
	var after=sim.battle_by_id(bid);var text="";var names=["Infanterie","Cavalerie","Héros"]
	for n in range(3):
		var before_hp=int(b.sides[1-si].lines[n].hp);var hp=int(after.sides[1-si].lines[n].hp)
		if hp!=before_hp:text+="%s adverse : %d → %d de défense (%d perdus).\n"%[names[n],before_hp,hp,before_hp-hp]
	for n in range(3):
		var before_hp=int(sd.lines[n].hp);var hp=int(after.sides[si].lines[n].hp)
		if hp!=before_hp:text+="Votre %s : %d → %d de défense.\n"%[names[n].to_lower(),before_hp,hp]
	if text=="":text="Aucun dégât appliqué : une protection peut annuler cette attaque.\n"
	if after.done:text+="Issue prévue : "+after.result+"\n"
	var target_index=target if sd.pierce and target>=0 else g.front(b.sides[1-si])
	return {"ok":true,"cost":cost,"remaining":g.wallet(sd)-cost,"target":names[maxi(0,target_index)],"text":text,"snapshot":after}
static func composition(g,bid:int,si:int,mode:int)->Dictionary:
	var b=g.battle_by_id(bid);var sd=b.sides[si];var f=int(sd.f);var budget=g.wallet(sd)
	var best={"a":2,"b":2,"heroes":[],"score":-1.0};var available=g.available_heroes(f)
	if mode==0:return best
	for n1 in range(2,g.data.factions[f].lines[0].size()+1):
		for n2 in range(2,g.data.factions[f].lines[1].size()+1):
			var a=g.stats(f,0,n1,b.terrain);var c=g.stats(f,1,n2,b.terrain)
			for mask in range(1<<available.size()):
				var hs=[]
				for i in range(available.size()):
					if mask&(1<<i):hs.append(available[i])
				var h=g.hero_stats(f,hs,b.terrain);var cost=a[0]+c[0]+h[0]
				var hero_attack=20+(1 if b.terrain==2 else 0) if f==3 and not hs.is_empty() else h[1]
				var reserve=maxi(int(budget*0.3),2*int(a[1])+int(c[1])+int(hero_attack))
				if cost+reserve>budget:continue
				var score=float(a[2]+c[2]+h[2]) if mode==1 else float(a[3]+c[3]+h[3])
				if mode==2 and f==1 and hs.has(2):score+=30
				score-=float(cost)*0.05
				if score>best.score:best={"a":n1,"b":n2,"heroes":hs,"score":score}
	return best
