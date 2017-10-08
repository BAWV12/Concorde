# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var RouteLayer =  {};

RouteLayer.new = func(group,name) {
	var m=Layer.new(group, name, RouteModel);
	m.setDraw (func draw_layer(layer:m, callback: draw_route, lod:0) );
	return m;
}

register_layer("route", RouteLayer);

