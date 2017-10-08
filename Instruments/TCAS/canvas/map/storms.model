# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var StormModel = {};
StormModel.new = func make( LayerModel, StormModel );

StormModel.init = func {
	me._view.reset(); # wraps removeAllChildren() ATM

	foreach (var n; props.globals.getNode("/instrumentation/wxradar",1).getChildren("storm")) {
		# Model 3 degree radar beam 
		var stormLat = n.getNode("latitude-deg").getValue();
		var stormLon = n.getNode("longitude-deg").getValue();

			# FIXME: once ported to MapStructure, these should use the encapsulated "aircraft source"/driver stuff
		var acLat = getprop("/position/latitude-deg");
		var acLon = getprop("/position/longitude-deg");
		var stormGeo = geo.Coord.new();
		var acGeo = geo.Coord.new();
		
		stormGeo.set_latlon(stormLat, stormLon);
		acGeo.set_latlon(acLat, acLon);
		
		var directDistance = acGeo.direct_distance_to(stormGeo);
		var beamH = 0.1719 * directDistance; # M2FT * tan(3deg)
		var beamBase = getprop("position/altitude-ft") - beamH;
		
		if (n.getNode("top-altitude-ft").getValue() > beamBase) {
			me.push( { lat: stormLat, lon : stormLon, radiusNm : n.getNode("radius-nm").getValue() } );
		}
	}
	
	me.notifyView();
}


