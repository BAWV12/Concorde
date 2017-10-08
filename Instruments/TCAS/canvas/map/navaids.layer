# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var NavLayer =  {};
NavLayer.new = func(group,name) {
	var m=Layer.new(group, name, NavaidModel);
	m.setDraw (func draw_layer(layer:m, callback: draw_navaid, lod:0) );
	return m;
}

register_layer("navaids", NavLayer);

