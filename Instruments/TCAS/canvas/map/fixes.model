# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var FixModel = {};
FixModel.new = func make( LayerModel, FixModel );

FixModel.init = func {
	me._view.reset(); # wraps removeAllChildren() ATM

	var results = positioned.findWithinRange( me._controller['query_range']() ,"fix"); 
	var numNum = 0;
	foreach(result; results) {
		# Skip airport fixes
		if(string.match(result.id,"*[^0-9]")) { # this may need to be moved to FIX.lcontroller?
			me.push(result);
			numNum = numNum + 1;
		}
	}

	me.notifyView();
}
