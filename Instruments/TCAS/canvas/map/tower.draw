# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var draw_tower = func (group, apt,lod) {
	var group = group.createChild("group", "tower");
	# TODO: move to map_elements.nas (tower, runway, parking etc)
	# i.e.: set_element(group, "tower", "style");
	var icon_tower =
	group.createChild("path", "tower")
		.setStrokeLineWidth(1)
		.setScale(1.5)
		.setColor(0.2,0.2,1.0)
		.moveTo(-3, 0)
		.vert(-10)
		.line(-3, -10)
		.horiz(12)
		.line(-3, 10)
		.vert(10);

	icon_tower.setGeoPosition(apt.tower().lat, apt.tower().lon);
}

