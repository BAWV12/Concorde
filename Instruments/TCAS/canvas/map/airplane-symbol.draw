# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##
# draw a single airplane symbol
#

var draw_airplane_symbol = func (group, apl, controller=nil, lod=0) {
	var lat = apl.lat;
	var lon = apl.lon;
	var hdg = apl.hdg;
	
	var airplane_grp = group.createChild("group","airplane");
	canvas.parsesvg(airplane_grp, "Nasal/canvas/map/boeingAirplane.svg");
	var aplSymbol = airplane_grp.getElementById("airplane");

	aplSymbol.setTranslation(-45,-52)
		.setCenter(0,0);
	airplane_grp.setGeoPosition(lat, lon)
		.set("z-index",10)
		.setRotation(hdg*D2R);
}
