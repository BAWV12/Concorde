# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var StormLayer =  {};
StormLayer.new = func(group,name, controller) {
	var m=Layer.new(group, name, StormModel);
	m._model._controller = controller; # set up the controller for the model !!!!!
	m.setDraw (func draw_layer(layer:m, callback: draw_storm, lod:0) );
	return m;
}

register_layer("storms", StormLayer);

