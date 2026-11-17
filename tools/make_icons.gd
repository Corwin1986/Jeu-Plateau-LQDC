extends SceneTree
func _initialize():
	var out=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/tmp/crystal_icons"
	DirAccess.make_dir_recursive_absolute(out)
	var svg=FileAccess.get_file_as_string("res://icon.svg")
	var img=Image.new();img.load_svg_from_string(svg,2.25);img.save_webp(out+"/icon.webp")
	var foreground=Image.new();foreground.load_svg_from_string(svg.replace('viewBox="0 0 192 192"','viewBox="-52 -52 296 296"'),2.25);foreground.save_webp(out+"/icon_foreground.webp")
	var bg=Image.create(432,432,false,Image.FORMAT_RGBA8);bg.fill(Color("101d2b"));bg.save_webp(out+"/icon_background.webp")
	var mono=Image.new();mono.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="-52 -52 296 296"><path d="m96 28 44 55-44 78-44-78Z" fill="white"/></svg>');mono.save_webp(out+"/icon_monochrome.webp")
	quit()
