# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##
# Draw a altitude profile position on the route with text
#

var drawprofile =  func (group, property, disptext)
{
	var symNode = props.globals.getNode("autopilot/route-manager/vnav/"~property, 1);
	var lon = symNode.getNode("longitude-deg", 1).getValue();
	var lat = symNode.getNode("latitude-deg", 1).getValue();
	var sym_group = group.createChild("group", property);
	if(lon != nil)
	{
		var radius = 13;
		sym_group.createChild("path", property)
			.setStrokeLineWidth(5)
			.moveTo(-radius, 0)
		    .arcLargeCW(radius, radius, 0,  2 * radius, 0)
		    .arcLargeCW(radius, radius, 0,  -2 * radius, 0)
			.setColor(0.195,0.96,0.097);
		sym_group.createChild("text", property)
			.setDrawMode( canvas.Text.TEXT )
			.setText(disptext)
			.setFont("LiberationFonts/LiberationSans-Regular.ttf")
			.setFontSize(28)
			.setTranslation(25,35)
			.setColor(0.195,0.96,0.097);
		sym_group.setGeoPosition(lat, lon)
			.set("z-index",3);
	}
}

