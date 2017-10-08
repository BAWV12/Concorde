# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
##    
# FIXME: until we have better instancing support for symbols, it would be better to return a functor here
# so that symbols are only parsed once
var NAVAID_CACHE = {};

var draw_navaid = func (group, navaid, lod) {
	#var group = group.createChild("group", "navaid");
	DEBUG and print("Drawing navaid:", navaid.id);                 
	var symbols = {NDB:"/gui/dialogs/images/ndb_symbol.svg"}; # TODO: add more navaid symbols here
	if (symbols[navaid.type] == nil) return print("Missing svg image for navaid:", navaid.type);
			 
	var symbol_navaid = group.createChild("group", "navaid");
	canvas.parsesvg(symbol_navaid, symbols[navaid.type]);
	symbol_navaid.setGeoPosition(navaid.lat, navaid.lon);
}

