# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var draw_parking = func(group, apt, lod) {
	var group = group.createChild("group", "apt-"~apt.id);
	foreach(var park; apt.parking()) {
	var icon_park =
	group.createChild("text", "parking-" ~ park.name)
		.setDrawMode( canvas.Text.ALIGNMENT
		            + canvas.Text.TEXT )
		.setText(park.name)
		.setFont("LiberationFonts/LiberationMono-Bold.ttf")
		.setGeoPosition(park.lat, park.lon)
		.setFontSize(15, 1.3);
	}
}

