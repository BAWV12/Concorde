# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
#TODO: use custom Model/DataProvider
var TaxiwayLayer = {}; # make(Layer);
TaxiwayLayer.new = func(group, name) {
	# print("Setting up new TestLayer");
	var m=Layer.new(group, name, AirportModel ); #FIXME: AirportModel can be shared by Taxiways, Runways etc!!
	m.setDraw( func draw_layer(layer: m, callback: draw_taxiways, lod:0 ) );
	return m;
}

register_layer("taxiways", TaxiwayLayer);

