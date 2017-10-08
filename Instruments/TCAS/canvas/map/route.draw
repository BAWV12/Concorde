# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##
# Draw a route with tracks and waypoints
#

## FIXME: encapsulate properly
var wp = [];
var text_wp = [];

# Change color of active waypoints
var updatewp = func(activeWp)
{
	forindex(var i; wp) {
		if(i == activeWp) {
			wp[i].setColor(1,0,1);
			#text_wp[i].setColor(1,0,1);
		} else {
			wp[i].setColor(1,1,1);
			#text_wp[i].setColor(1,1,1);
		}
	}
};

var draw_route =  func (group, theroute, controller=nil, lod=0)
	{
	#print("draw_route");
	var route_group = group;

	var route = route_group.createChild("path","route")
		.setStrokeLineWidth(5)
		.setColor(1,0,1)
		.set("z-index",1);
			
	var cmds = [];
	var coords = [];

	var fp = flightplan();
	var fpSize = fp.getPlanSize();
	
	wp = [];
	text_wp = [];
	setsize(wp,fpSize);
	setsize(text_wp,fpSize);
	
	# Retrieve route coordinates
	for (var i=0; i<(fpSize); i += 1)
	{
		if (i == 0) {
			var leg = fp.getWP(1);
			var j = 0;
			foreach (var pt; leg.path()) {
				append(coords,"N"~pt.lat);
				append(coords,"E"~pt.lon);
				if (j==0){
					append(cmds,2);
					j=1;
				} else
					append(cmds,4);
			}
			canvas.drawwp(group, leg.path()[0].lat, leg.path()[0].lon, fp.getWP(0).alt_cstr, fp.getWP(0).wp_name, i, wp);
			i+=1;
		}
		var leg = fp.getWP(i);
		foreach (var pt; leg.path()) {
			append(coords,"N"~pt.lat);
			append(coords,"E"~pt.lon);
			append(cmds,4);
		}
		canvas.drawwp(group, leg.path()[-1].lat, leg.path()[-1].lon, leg.alt_cstr, leg.wp_name, i, wp);
	}

	# Set Top Of Climb coordinate
	canvas.drawprofile(route_group, "tc", "T/C");
	# Set Top Of Descent coordinate
	canvas.drawprofile(route_group, "td", "T/D");
	# Set Step Climb coordinate
	canvas.drawprofile(route_group, "sc", "S/C");
	# Set Top Of Descent coordinate
	canvas.drawprofile(route_group, "ed", "E/D");

	# Update route coordinates
	debug.dump(cmds);
	debug.dump(coords);
	route.setDataGeo(cmds, coords);
    updatewp(getprop("/autopilot/route-manager/current-wp"));

}