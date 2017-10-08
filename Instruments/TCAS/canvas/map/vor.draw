# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var draw_vor = func (group, vor, controller=nil, lod = 0) {

	if (0) {
		if (controller == nil)
			print("Ooops, VOR controller undefined!");
		else
			debug.dump( controller );
	}

	var lat = vor.lat;
	var lon = vor.lon;
	var name = vor.id;
	var freq = vor.frequency;
	var range = vor.range_nm;

	# FIXME: Hack - implement a real controller for this!
	var rangeNm = (controller!=nil) ? controller['query_range']() : 50;

	var vor_grp = group.createChild("group",name);
	var icon_vor = vor_grp.createChild("path", "vor-icon-" ~ name)
		.moveTo(-15,0)
		.lineTo(-7.5,12.5)
		.lineTo(7.5,12.5)
		.lineTo(15,0)
		.lineTo(7.5,-12.5)
		.lineTo(-7.5,-12.5)
		.close()
		.setStrokeLineWidth(3)
		.setColor(0,0.6,0.85);

	# next check if the current VOR is tuned, if so show it
	# for this to work, we need a controller hash with an "is_tuned" member that points to a callback
	# (set up by the layer managing this view)
	# for an example, see the NavDisplay.newMFD() in navdisplay.mfd

	if (controller != nil and controller['is_tuned'](freq/100)) {
		# print("VOR is tuned:", name);
		var radius = (range/rangeNm)*345;
		var range_vor = vor_grp.createChild("path", "range-vor-" ~ name)
			.moveTo(-radius,0)
			.arcSmallCW(radius,radius,0,2*radius,0)
			.arcSmallCW(radius,radius,0,-2*radius,0)
			.setStrokeLineWidth(3)
			.setStrokeDashArray([5, 15, 5, 15, 5])
			.setColor(0,1,0);
	
		var course = controller['get_tuned_course'](freq/100);
		vor_grp.createChild("path", "radial-vor-" ~ name)
			.moveTo(0,-radius)
			.vert(2*radius)
			.setStrokeLineWidth(3)
			.setStrokeDashArray([15, 5, 15, 5, 15])
			.setColor(0,1,0)
			.setRotation(course*D2R);
		icon_vor.setColor(0,1,0);
	}
	vor_grp.setGeoPosition(lat, lon)
		.set("z-index",3);
}
