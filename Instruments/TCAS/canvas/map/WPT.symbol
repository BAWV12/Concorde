# See: http://wiki.flightgear.org/MapStructure
# Class things:
var name = 'WPT';
var parents = [DotSym];
var __self__ = caller(0)[0];
DotSym.makeinstance( name, __self__ );

SymbolLayer.get(name).df_style = { # style to use by default
	line_width: 3,
	scale_factor: 1,
	font: "LiberationFonts/LiberationSans-Regular.ttf",
	font_size: 28,
	font_color: [1,0,1],
	active_color: [1,0,1],
	inactive_color: [1,1,1],
};

var element_type = "group"; # we want a group, becomes "me.element"
var active = nil;

var init = func {
	me.path = me.element.createChild("path")
		.setStrokeLineWidth(me.style.line_width)
		.moveTo(0,-25)
		.lineTo(-5,-5)
		.lineTo(-25,0)
		.lineTo(-5,5)
		.lineTo(0,25)
		.lineTo(5,5)
		.lineTo(25,0)
		.lineTo(5,-5)
		.setColor(1,1,1)
		.close()
		.setScale(me.style.scale_factor);

	me.text = me.newText(me.model.name, me.style.font_color)
		.setTranslation(25,35)
		.setScale(me.style.scale_factor);

	me.draw();
};
var draw = func {
	var active = (getprop(me.options.current_wp_node) == me.model.idx);
	if (active != me.active) {
		me.path.setColor(
			active ?
			me.style.active_color :
			me.style.inactive_color
		);
		me.text.setColor(
			active ?
			me.style.active_color :
			me.style.inactive_color
		);
		me.active = active;
	}
};

