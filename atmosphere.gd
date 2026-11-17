extends Control
var host
var clock=0.0
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta):
	if host.effects:clock+=delta;queue_redraw()
func _draw():
	if not host.effects:return
	for i in range(35):
		var x=fmod(i*137.3+sin(clock*0.18+i)*24,1440)
		var y=fposmod(i*83.7-clock*(6+i%5),810)
		draw_circle(Vector2(x,y),1.0+i%3,Color(0.96,0.77,0.4,0.06+0.12*(0.5+0.5*sin(clock+i))))
