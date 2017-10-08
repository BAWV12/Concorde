# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var AirplaneSymbolModel = {};
AirplaneSymbolModel.new = func make( LayerModel, AirplaneSymbolModel );

AirplaneSymbolModel.init = func {
	me._view.reset(); # wraps removeAllChildren() ATM

	me.push( { lat: getprop("/position/latitude-deg"), lon : getprop("/position/longitude-deg"), hdg : getprop("/orientation/heading-deg") } );
	
	me.notifyView();
}


