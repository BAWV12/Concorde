# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var NavaidModel = {};
NavaidModel.new = func make(LayerModel, NavaidModel);
NavaidModel.init = func {
	me._view.reset();
	var navaids = findNavaidsWithinRange(me._controller.query_range());
	foreach(var n; navaids)
		me.push(n);
	me.notifyView();
}