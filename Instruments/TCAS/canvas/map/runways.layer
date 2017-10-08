# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
#TODO: use custom Model/DataProvider
var RunwayLayer = {}; # make(Layer);
RunwayLayer.new = func(group, name) {
	# print("Setting up new TestLayer");
	var m=Layer.new(group, name, AirportModel ); #FIXME: AirportModel can be shared by Taxiways, Runways etc!!
	m.setDraw( func draw_layer(layer: m, callback: draw_runways, lod:0 ) );
	return m;
}
register_layer("runways", RunwayLayer);

