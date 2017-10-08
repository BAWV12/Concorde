# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var MPTrafficLayer =  {};
MPTrafficLayer.new = func(group,name, controller=nil) {
	var m=Layer.new(group, name, MPTrafficModel);
	m._model._controller = controller;
	m.setDraw (func draw_layer(layer:m, callback: draw_traffic, lod:0) );
	return m;
}

register_layer("mp-traffic", MPTrafficLayer);
# TODO: also register AI traffic layer here 

