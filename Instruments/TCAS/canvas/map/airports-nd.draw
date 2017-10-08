# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##
# draws a single airport (ND style)
#
var draw_apt = func (group, apt, controller=nil, lod=0) {
	var lat = apt.lat;
	var lon = apt.lon;
	var name = apt.id;
	# print("drawing nd airport:", name);
	
	var apt_grp = group.createChild("group", name);

	# FIXME: conditions don't belong here, use the controller hash instead!
	# if (1 or getprop("instrumentation/efis/inputs/arpt")) {
		var icon_apt = apt_grp.createChild("path", name ~ " icon" )
			.moveTo(-17,0)
			.arcSmallCW(17,17,0,34,0)
			.arcSmallCW(17,17,0,-34,0)
			.close()
			.setColor(0,0.6,0.85)
			.setStrokeLineWidth(3);
		var text_apt = apt_grp.createChild("text", name ~ " label")
			.setDrawMode( canvas.Text.TEXT )
			.setTranslation(17,35)
			.setText(name)
			.setFont("LiberationFonts/LiberationSans-Regular.ttf")
			.setColor(0,0.6,0.85)
			.setFontSize(28);
		apt_grp.setGeoPosition(lat, lon); # FIXME: this needs to be configurable!!
	#}

	# draw routines should always return their canvas group to the caller for further processing
}
