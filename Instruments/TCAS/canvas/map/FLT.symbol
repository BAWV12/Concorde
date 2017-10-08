# See: http://wiki.flightgear.org/MapStructure

# Class things:
var name = 'FLT';
var parents = [LineSymbol];
var __self__ = caller(0)[0];
LineSymbol.makeinstance( name, __self__ );

SymbolLayer.get(name).df_style = { # style to use by default
	line_width: 5,
	color: [0,0,1]
};

var init = func {
	me.element.setColor(me.layer.style.color)
	.setStrokeLineWidth(me.layer.style.line_width);
	me.needs_update = 0;
};

