# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var AirportsNDLayer =  {};
AirportsNDLayer.new = func(group, name) {
	var m = Layer.new(group, name, AirportsNDModel );
	m.setDraw(func draw_layer(layer:m, callback:draw_apt, lod:0) );
	return m;
}

##
# airport-nd lookup key
register_layer("airports-nd", AirportsNDLayer);

