# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##
# draw a single fix symbol
#

var draw_fix = func (group, fix, controller=nil, lod=0) {
	var lat = fix.lat;
	var lon = fix.lon;
	var name = fix.id;

	var fix_grp = group.createChild("group",'fix-'~name); # one group for each fix

	# the fix symbol
	var icon_fix = fix_grp.createChild("path", "fix-icon-"~ name)
		.moveTo(-15,15)
		.lineTo(0,-15)
		.lineTo(15,15)
		.close()
		.setStrokeLineWidth(3)
		.setColor(0,0.6,0.85);

	# the fix label
	var text_fix = fix_grp.createChild("text", 'fix-label-'~name)
		.setDrawMode( canvas.Text.TEXT )
		.setText(name)
		.setFont("LiberationFonts/LiberationSans-Regular.ttf")
		.setFontSize(28)
		.setTranslation(5,25);

	# the fix position
	fix_grp.setGeoPosition(lat, lon);

}
