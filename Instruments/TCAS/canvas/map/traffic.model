# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var MPTrafficModel = {};
MPTrafficModel.new = func make(LayerModel, MPTrafficModel);

MPTrafficModel.init = func {
	var pos = geo.Coord.new(); # FIXME: all of these should be instance variables
	var myPosition = geo.Coord.new();
	var myPositionVec = me._controller['get_position']();
	myPosition.set_latlon( myPositionVec[0], myPositionVec[1]);
	var max_dist_nm = me._controller['query_range']();

	me._view.reset(); # hides: removeAllChildren()
	
	# AI traffic
	var traffic = props.globals.initNode("/ai/models/").getChildren( "aircraft" );
	foreach(var t; traffic) {
	  pos.set_latlon(	t.getNode("position/latitude-deg").getValue(),
				t.getNode("position/longitude-deg").getValue()
	  );

	  if (pos.distance_to( myPosition ) <= max_dist_nm*NM2M )
	    me.push(t);
	}
	# Multiplayer traffic
	var traffic = props.globals.initNode("/ai/models/").getChildren( "multiplayer" );
	foreach(var t; traffic) {
	  pos.set_latlon(	t.getNode("position/latitude-deg").getValue(),
				t.getNode("position/longitude-deg").getValue()
	  );

	  if (pos.distance_to( myPosition ) <= max_dist_nm*NM2M )
	    me.push(t);
	}

	me.notifyView();

	# update itself FIXME: this needs to be killed by the controller (e.g. when tcas layer is disabled)
	# and the interval needs to be configurable via the controller
	# so better use maketimer() here
	settimer(func me.init(), 2);
}