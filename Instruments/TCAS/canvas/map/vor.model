# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var VORModel = {};
VORModel.new = func make( LayerModel, VORModel );

VORModel.init = func {
	#debug.dump( me._controller );
	me._view.reset();

	var results = positioned.findWithinRange( me._controller.query_range()*2 ,"vor"); 
	foreach(result; results) {
		me.push(result);
	}

	me.notifyView();
}

