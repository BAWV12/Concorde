# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure

var draw_rwy_nd = func (group, rwy, controller=nil, lod=nil) {
 # print("drawing runways-nd");
 canvas._draw_rwy_nd(group,rwy.lat,rwy.lon,rwy.length,rwy.width,rwy.heading,rwy.id);
}


##
# TODO: this is not yet a real draw callback ... (wrong signature, not yet integrated)

var _draw_rwy_nd = func (group, lat, lon, length, width, rwyhdg, id) {
	var apt = airportinfo("EHAM");
	var rwy = apt.runway("18R");

	var crds = [];
	var coord = geo.Coord.new();
	width=width*20; # Else rwy is too thin to be visible
	coord.set_latlon(lat, lon);
	coord.apply_course_distance(rwyhdg, -14.2*NM2M);
	append(crds,"N"~coord.lat());
	append(crds,"E"~coord.lon());
	coord.apply_course_distance(rwyhdg, 28.4*NM2M+length);
	append(crds,"N"~coord.lat());
	append(crds,"E"~coord.lon());
	icon_rwy = group.createChild("path", "rwy-cl")
		.setStrokeLineWidth(3)
		.setDataGeo([2,4],crds)
		.setColor(1,1,1)
		.setStrokeDashArray([10, 20, 10, 20, 10]);
	var crds = [];
	coord.set_latlon(lat, lon);
    coord.apply_course_distance(rwyhdg + 90, width/2);
	append(crds,"N"~coord.lat());
	append(crds,"E"~coord.lon());
	coord.apply_course_distance(rwyhdg, length);
	append(crds,"N"~coord.lat());
	append(crds,"E"~coord.lon());
	icon_rwy = group.createChild("path", "rwy")
		.setStrokeLineWidth(3)
		.setDataGeo([2,4],crds)
		.setColor(1,1,1);
	var crds = [];
    coord.apply_course_distance(rwyhdg - 90, width);
	append(crds,"N"~coord.lat());
	append(crds,"E"~coord.lon());
	coord.apply_course_distance(rwyhdg, -length);
	append(crds,"N"~coord.lat());
	append(crds,"E"~coord.lon());
	icon_rwy = group.createChild("path", "rwy")
		.setStrokeLineWidth(3)
		.setDataGeo([2,4],crds)
		.setColor(1,1,1);
	group.createChild("text", "rwy-text")
		.setDrawMode( canvas.Text.TEXT )
		.setText(id)
		.setFont("LiberationFonts/LiberationSans-Regular.ttf")
		.setFontSize(28)
		.setTranslation(35,0)
		.setColor(1,1,1);
}
