# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##
# draw a single storm symbol
#

var draw_storm = func (group, storm, controller=nil, lod=0) {
	var lat = storm.lat;
	var lon = storm.lon;
	var radiusNm = storm.radiusNm;

	var storm_grp = group.createChild("group","storm"); # one group for each storm

	storm_grp.createChild("image")
		.setFile("Nasal/canvas/map/Images/storm.png")
		.setSize(128*radiusNm,128*radiusNm)
		.setTranslation(-64*radiusNm,-64*radiusNm)
		.setCenter(0,0);
	
	# the storm position
	storm_grp.setGeoPosition(lat, lon)
		.set("z-index",0);

}
