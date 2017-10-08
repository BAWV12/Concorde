# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var VORLayer =  {};
VORLayer.new = func(group,name, controller) {
	var m=Layer.new(group, name, VORModel );
	m._controller = controller;
	m.setDraw (func draw_layer(layer:m, callback: draw_vor, lod:0) );
	return m;
}

register_layer("vor", VORLayer);

