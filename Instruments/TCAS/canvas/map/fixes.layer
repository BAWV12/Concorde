# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var FixLayer =  {};
FixLayer.new = func(group,name, controller) {
	var m=Layer.new(group, name, FixModel);
	#print("new fix layer, dumping controller:");
	#debug.dump(controller);
	m._model._controller = controller; # set up the controller for the model !!!!!
	m.setDraw (func draw_layer(layer:m, callback: draw_fix, lod:0) );
	return m;
}

register_layer("fixes", FixLayer);

