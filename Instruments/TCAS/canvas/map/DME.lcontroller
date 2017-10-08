# See: http://wiki.flightgear.org/MapStructure
# Class things:
var name = 'DME';
var parents = [SymbolLayer.Controller];
var __self__ = caller(0)[0];
SymbolLayer.Controller.add(name, __self__);
SymbolLayer.add(name, {
	parents: [NavaidSymbolLayer],
	type: name, # Symbol type
	df_controller: __self__, # controller to use by default -- this one
	df_style: {
		line_width: 3,
		scale_factor: 1,
		animation_test: 0,
		debug: 1,
		color_default: [0,0.6,0.85],
		color_tuned: [0,1,0],
	}
});
var new = func(layer) {
	var m = {
		parents: [__self__],
		layer: layer,
		map: layer.map,
		listeners: [],
		query_type:'dme',
	};
	m.addVisibilityListener();

	return m;
};

## TODO: also move this to generator helper
var del = func() {
	foreach (var l; me.listeners)
		removelistener(l);
};

var searchCmd = NavaidSymbolLayer.make(query:'dme');

