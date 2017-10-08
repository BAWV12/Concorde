# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var TowerLayer = {};
TowerLayer.new = func(group, name) {
	var m=Layer.new(group, name, AirportModel ); #FIXME: AirportModel can be shared by Taxiways, Runways etc!!
	m.setDraw( func draw_layer(layer: m, callback: draw_tower, lod:0 ) );
	return m;
}

register_layer("towers", TowerLayer);

