# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var AirportsNDModel = {};
AirportsNDModel.new =  func make(AirportsNDModel, LayerModel);

AirportsNDModel.init = func {
	me._view.reset();

	var results = positioned.findWithinRange(me._controller.query_range(), "airport");
	var numResults = 0;
	foreach(result; results) {
		var apt = airportinfo(result.id);
		var runways = apt.runways;
		var runway_keys = sort(keys(runways),string.icmp);
		var validApt = 0;
		foreach(var rwy; runway_keys){
			var r = runways[rwy];
			if (r.length > 1890) # Only display suitably large airports
				validApt = 1;
			if (result.id == getprop("autopilot/route-manager/destination/airport") or result.id == getprop("autopilot/route-manager/departure/airport"))
				validApt = 1;
		} 

		if(validApt) {
			#canvas.draw_apt(me.apt_group, result.lat,result.lon,result.id,i);
			me.push(result);
			numResults += 1;
		}
	}
	# set RefPos and hdg to apt !! 
	# me._map_handle.setRefPos(apt.lat, apt.lon);

	#TODO: Notify view on update - use proper NOTIFICATIONS (INIT; UPDATE etc)
	me.notifyView();
}

