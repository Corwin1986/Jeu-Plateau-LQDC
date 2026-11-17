extends Control
var host
var battle
var minis=preload("res://assets/miniatures.png")
var hero_art=preload("res://assets/heroes.png")
var clock=0.0
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta):
	clock+=delta if host.effects else 0.0;queue_redraw()
func _draw():
	if battle.is_empty():return
	for camp in range(2):
		var sd=battle.sides[camp]
		if not sd.deployed:continue
		for li in range(3):
			var line=sd.lines[li];var count=mini(5,int(line.n))
			var base=Vector2(50+camp*710,267+li*99)
			var row=2 if li==1 else 0
			var cell=minis.get_size()/Vector2(6,3)
			var region=Rect2(Vector2(sd.f,row)*cell,cell)
			for n in range(count):
				var at=base+Vector2(n*31,sin(clock*1.5+n)*1.5)
				var tint=Color.WHITE if line.hp>0 else Color(0.35,0.38,0.4,0.45)
				draw_circle(at+Vector2(24,64),17,Color(0,0,0,0.3))
				if li==2:
					var hero_id=int(line.heroes[n]) if n<line.heroes.size() else n
					var portrait_region=hero_region(int(sd.f),hero_id)
					draw_texture_rect_region(hero_art,Rect2(at+Vector2(5,2),Vector2(48,76)),portrait_region,tint)
				else:draw_texture_rect_region(minis,Rect2(at,Vector2(62,80)),region,tint)
				if li==2:draw_arc(at+Vector2(27,10),12,PI,TAU,12,Color("efd394"),2)

func hero_region(f:int,id:int)->Rect2:
	match f:
		0:return Rect2(65+mini(id,5)*82,105,82,310)
		1:return [Rect2(650,125,350,150),Rect2(640,300,340,130),Rect2(1000,100,180,325)][mini(id,2)]
		2:return Rect2([25,175,315,455][mini(id,3)],490,125,335)
		3:return Rect2([715,950][mini(id,1)],480,195,350)
		4:return Rect2(15+mini(id,5)*87,935,90,315)
		_:return [Rect2(615,920,240,340),Rect2(850,880,145,380),Rect2(1000,900,190,355)][mini(id,2)]
