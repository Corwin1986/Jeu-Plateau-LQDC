extends Control
var host
var radius=24.0
var center=Vector2(500,320)
var target=Vector2i(99,99)
var tex=preload("res://assets/terrain.png")
var capitals=preload("res://assets/capitals.png")
var minis=preload("res://assets/miniatures.png")
var held=false
var dragged=false
var origin=Vector2.ZERO
var fingers={}
var pinch_distance=0.0
var clock=0.0
var redraw_clock=0.0
func _ready():
	clip_contents=true
func _process(delta):
	clock+=delta if host.effects else 0.0
	redraw_clock+=delta
	if redraw_clock>=0.033:queue_redraw();redraw_clock=0.0
func world(p:Vector2)->Vector2:return Vector2(sqrt(3.0)*(p.x+p.y/2.0),1.5*p.y*0.76)*radius
func point(p:Vector2)->Vector2:return center+host.map_pan+world(p)*host.map_zoom
func cell(p:Vector2)->Vector2i:
	var a=(p-center-host.map_pan)/(radius*host.map_zoom)
	a.y/=0.76
	var q=sqrt(3.0)/3*a.x-a.y/3;var r=2.0/3*a.y
	var x=round(q);var z=round(r);var y=round(-q-r)
	if abs(x-q)>abs(y+q+r) and abs(x-q)>abs(z-r):x=-y-z
	elif abs(z-r)>abs(y+q+r):z=-x-y
	return Vector2i(int(x),int(z))
func zoom_at(factor:float,at:Vector2):
	var before=host.map_zoom
	host.map_zoom=clampf(before*factor,0.8,2.8)
	host.map_pan=at-center-(at-center-host.map_pan)*(host.map_zoom/before)
	bound_pan()
func bound_pan():
	host.map_pan=host.map_pan.clamp(Vector2(-700,-650),Vector2(700,650))
func _gui_input(e):
	if host.camera_tween and host.camera_tween.is_valid():host.camera_tween.kill()
	if e is InputEventScreenTouch:
		if e.pressed:fingers[e.index]=e.position
		else:fingers.erase(e.index)
		if fingers.size()<2:pinch_distance=0.0
	if e is InputEventScreenDrag:
		fingers[e.index]=e.position
		if fingers.size()==2:
			var pts=fingers.values();var dist=pts[0].distance_to(pts[1])
			if pinch_distance>0:zoom_at(dist/pinch_distance,(pts[0]+pts[1])/2)
			pinch_distance=dist;dragged=true
	if e is InputEventMouseButton:
		if e.pressed and e.button_index==MOUSE_BUTTON_WHEEL_UP:zoom_at(1.15,e.position)
		if e.pressed and e.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom_at(1.0/1.15,e.position)
		if e.button_index==MOUSE_BUTTON_LEFT:
			if e.pressed:held=true;origin=e.position;dragged=false
			else:
				held=false
				if not dragged and fingers.size()<2:
					var p=cell(e.position)
					if host.game.s.cells.has(host.game.key(p)):host.pick_cell(p)
	if e is InputEventMouseMotion and held and fingers.size()<2:
		if e.position.distance_to(origin)>10:dragged=true
		if dragged:host.map_pan+=e.relative;bound_pan()
func sprite(texture:Texture2D,index:int,columns:int,rows:int,dest:Rect2):
	var s=texture.get_size()/Vector2(columns,rows)
	draw_texture_rect_region(texture,dest,Rect2(Vector2(index%columns,int(index/columns))*s,s))
func crystal(at:Vector2,scale_value:float):
	draw_circle(at,14*scale_value,Color(0.65,0.4,1,0.16+0.08*sin(clock*2)))
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-12)*scale_value,at+Vector2(8,0)*scale_value,at+Vector2(0,12)*scale_value,at+Vector2(-8,0)*scale_value]),Color("dfb8ff"))
	draw_line(at+Vector2(0,-10)*scale_value,at+Vector2(-4,0)*scale_value,Color.WHITE,1.5)
func _draw():
	if host==null or host.game.s.is_empty():return
	var g=host.game;var z=host.map_zoom;var rr=radius*z
	# A raised tabletop edge, with fixed world UVs independent of camera.
	var edge=PackedVector2Array()
	for p in g.BASES:edge.append(point(p))
	# Bases are stored by faction, so explicitly walk the perimeter.
	edge=PackedVector2Array([point(Vector2(0,-9)),point(Vector2(9,-9)),point(Vector2(9,0)),point(Vector2(0,9)),point(Vector2(-9,9)),point(Vector2(-9,0))])
	var shadow=PackedVector2Array()
	for p in edge:shadow.append(p+Vector2(0,22*z))
	draw_colored_polygon(shadow,Color("030a10"));draw_colored_polygon(edge,Color("967849"))
	for c in g.s.cells.values():
		var p=g.pos(c);var at=point(p);var poly=PackedVector2Array();var uv=PackedVector2Array()
		for n in range(6):
			var v=Vector2(cos(deg_to_rad(60*n-30)),sin(deg_to_rad(60*n-30)))
			poly.append(at+Vector2(v.x,v.y*0.76)*(rr-0.45))
			var canonical=Vector2(sqrt(3.0)*(p.x+p.y/2.0),1.5*p.y)*21+v*21
			uv.append((canonical+Vector2(345,304))/Vector2(690,608))
		draw_polygon(poly,PackedColorArray([Color.WHITE]),uv,tex)
		poly.append(poly[0]);draw_polyline(poly,Color(0.85,0.8,0.65,0.22),1)
		if host.selected>=0:
			var u=g.s.units[host.selected]
			if g.distance(g.pos(u),p)<=int(u.mp) and u.battle<0 and int(u.locked)<int(g.s.factions[u.f].turns) and g.s.turn==g.s.human:
				draw_polyline(poly,Color(0.6,0.95,0.8,0.55),1.2)
		if p==target:draw_polyline(poly,Color("ffe7a1"),3)
		if c.cache:
			draw_circle(at,6*z,Color("352418"));draw_arc(at,5*z,0,TAU,16,Color("f7cf75"),2);draw_circle(at,2*z,Color("fff1b3"))
		# Restrained drifting lights and water glints never obscure the grid.
		if host.effects and (int(c.q)*7+int(c.r)*11)%13==0:
			var wave=sin(clock*0.8+float(c.q)*2)
			var color=Color(0.7,0.9,1,0.14+0.1*wave) if g.terrain_at(p)==4 else Color(1,0.85,0.5,0.12+0.09*wave)
			draw_circle(at+Vector2(sin(clock+c.r)*8,-8+wave*7)*z,2*z,color)
		if host.effects and g.terrain_at(p)==4 and (int(c.q)+int(c.r))%3==0:
			var shimmer=PackedVector2Array()
			for n in range(7):shimmer.append(at+Vector2((n-3)*2*z,sin(clock*1.3+n*0.7+c.q)*1.2*z))
			draw_polyline(shimmer,Color(0.65,0.94,1,0.14+0.07*sin(clock+c.r)),1.0)
	# Route previews show exact path, including the stop at a crystal.
	var goal=host.guide_target() if host.guided() else (host.coach_target() if host.coach_paused() else target)
	if host.selected>=0 and g.s.cells.has(g.key(goal)):
		var u=g.s.units[host.selected];var route=g.path(g.pos(u),goal);var last=point(g.pos(u));var steps=0
		for p in route:
			steps+=1
			if steps>int(u.mp):break
			var next=point(p);draw_line(last,next,Color("ffe1a0"),3);draw_circle(next,3,Color("fff2ca"));last=next
			var stop=false
			for c in g.s.crystals:
				if c.holder=="map" and g.pos(c)==p:stop=true
			if stop:break
	for f in range(6):
		var at=point(g.BASES[f]);var col=g.faction_color(f)
		draw_circle(at+Vector2(0,5*z),28*z,Color(0,0,0,0.45))
		draw_arc(at,25*z,0,TAU,32,Color.WHITE if f==int(g.s.human) else col,3)
		sprite(capitals,f,3,2,Rect2(at+Vector2(-48,-75)*z,Vector2(96,96)*z))
		if not g.s.factions[f].alive:draw_line(at+Vector2(-25,-35)*z,at+Vector2(25,5)*z,Color("fa7269"),4)
	for c in g.s.crystals:
		if c.holder=="map":crystal(point(g.pos(c))+Vector2(0,sin(clock*2+c.q)*2),z)
	var spots={}
	for uid in range(g.s.units.size()):
		var u=g.s.units[uid]
		if not u.alive:continue
		var k=g.key(g.pos(u));var offset=int(spots.get(k,0));spots[k]=offset+1
		var at=point(host.visual_pos(uid))+[Vector2(-19,8),Vector2(19,8),Vector2(0,30)][offset%3]*z+Vector2(0,int(offset/3)*34*z)
		var color=g.faction_color(u.f)
		draw_circle(at,12*z,Color("0c1721"));draw_arc(at,12*z,0,TAU,20,color,2)
		if uid==host.selected:draw_arc(at,16*z,0,TAU,32,Color("ffe9af"),3)
		sprite(minis,int(u.f)+(6 if u.k==2 else 0),6,3,Rect2(at+Vector2(-20,-46)*z,Vector2(40,46)*z))
		draw_circle(at+Vector2(11,2)*z,8*z,Color("0a1520"))
		draw_string(ThemeDB.fallback_font,at+Vector2(7,6)*z,["1","2","M"][u.k],HORIZONTAL_ALIGNMENT_LEFT,-1,int(12*z),Color.WHITE)
		if u.battle>=0:draw_line(at+Vector2(-9,-50)*z,at+Vector2(9,-32)*z,Color("ff7869"),3);draw_line(at+Vector2(9,-50)*z,at+Vector2(-9,-32)*z,Color("ff7869"),3)
		if int(u.locked)>=int(g.s.factions[u.f].turns):draw_arc(at,19*z,0,TAU,16,Color("e5aa55"),2)
		if not u.crystals.is_empty():crystal(at+Vector2(-13,-32)*z,0.5*z)
	if host.guided() or host.coach_paused():
		var at=point(goal);draw_arc(at,rr+7,0,TAU,32,Color("ffe6a0"),3)
	var home=point(g.BASES[g.s.human])
	var tag=Vector2(clampf(home.x-72,8,size.x-152),clampf(home.y+47*z if home.y<size.y*0.65 else home.y-100*z,8,size.y-32))
	draw_style_box(host.style(Color("101e2a"),Color("e2bf7e")),Rect2(tag,Vector2(144,27)))
	draw_string(ThemeDB.fallback_font,tag+Vector2(10,20),"VOTRE VILLAGE",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
