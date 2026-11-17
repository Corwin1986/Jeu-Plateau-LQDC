extends Control
var host
var clock=0.0
var capitals=preload("res://assets/villages.png")
var miniatures=preload("res://assets/miniatures.png")
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
func _process(delta):
	if host.effects:clock+=delta
	queue_redraw()
func sprite(tex:Texture2D,index:int,cols:int,rows:int,rect:Rect2):
	var cell=tex.get_size()/Vector2(cols,rows)
	draw_texture_rect_region(tex,rect,Rect2(Vector2(index%cols,int(index/cols))*cell,cell))
func _draw():
	var f=int(host.game.s.human);var tint=host.game.faction_color(f)
	sprite(capitals,f,3,2,Rect2(0,0,940,710))
	# Patrol silhouettes remain local to the courtyard; expedition figures reflect actual presence.
	for i in range(3):
		var x=320+fposmod(i*130+clock*9,300)
		sprite(miniatures,f,6,3,Rect2(x,432,34,51))
	for k in range(3):
		var u=host.game.s.units[f*3+k]
		if not u.alive or host.game.pos(u)!=host.game.BASES[f]:continue
		var x=180+k*170
		draw_set_transform(Vector2(x+70,632),0,Vector2(1,0.24));draw_circle(Vector2.ZERO,50,Color(0,0,0,0.35));draw_set_transform(Vector2.ZERO)
		sprite(miniatures,f+(6 if k==2 else 0),6,3,Rect2(x,470+sin(clock+k)*1.5,145,170))
	# Sanctuary receives only deposited crystals, never those still carried.
	draw_rect(Rect2(730,526,150,10),Color(0.2,0.2,0.22,0.25))
	for i in range(5):
		var p=Vector2(745+i*28,500);var filled=i<host.game.s.factions[f].crystals.size()
		if filled:draw_circle(p,19,Color(0.75,0.5,1,0.12+0.06*sin(clock*2)))
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-17),p+Vector2(10,0),p+Vector2(0,17),p+Vector2(-10,0)]),Color("dab6ff") if filled else Color("4b5561"))
	if host.effects:
		for i in range(16):draw_circle(Vector2(fposmod(i*71+clock*5,920),fposmod(i*89-clock*12,600)),1.5,Color(tint,0.2))
