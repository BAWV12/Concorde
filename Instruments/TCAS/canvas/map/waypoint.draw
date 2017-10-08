# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##
# Draw a waypoint symbol and waypoint name (Gijs' 744 ND.nas code)

#
var drawwp =  func (group, lat, lon, alt, name, i, wp) {
	var wp_group = group.createChild("group","wp");
	wp[i] = wp_group.createChild("path", "wp-" ~ i)
		.setStrokeLineWidth(3)
		.moveTo(0,-25)
		.lineTo(-5,-5)
		.lineTo(-25,0)
		.lineTo(-5,5)
		.lineTo(0,25)
		.lineTo(5,5)
		.lineTo(25,0)
		.lineTo(5,-5)
		.setColor(1,1,1)
		.close();
	#####
	# The commented code leads to a segfault when a route is replaced by a new one
	#####
	#
	# text_wp[i] = wp_group.createChild("text", "wp-text-" ~ i)
	#
	if (alt != 0)
		name ~= "\n"~alt;
	var text_wps = wp_group.createChild("text", "wp-text-" ~ i)
		.setDrawMode( canvas.Text.TEXT )
		.setText(name)
		.setFont("LiberationFonts/LiberationSans-Regular.ttf")
		.setFontSize(28)
		.setTranslation(25,35)
		.setColor(1,1,1);
	wp_group.setGeoPosition(lat, lon);
};
