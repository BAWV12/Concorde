# See: http://wiki.flightgear.org/MapStructure
# Class things:
var name = 'VOR';
var parents = [DotSym];
var __self__ = caller(0)[0];
DotSym.makeinstance( name, __self__ );

SymbolLayer.get(name).df_style = { # style to use by default
	line_width: 3,
	range_line_width: 3,
	radial_line_width: 3,
	range_dash_array: [5, 15, 5, 15, 5],
	radial_dash_array: [15, 5, 15, 5, 15],
	scale_factor: 1,
	active_color: [0, 1, 0],
	inactive_color: [0, 0.6, 0.85],
};

var element_type = "group"; # we want a group, becomes "me.element"
var icon_vor = nil;  # a handle to the cached icon
var range_vor = nil; # two elements that get drawn when needed
var radial_vor = nil; # if one is nil, the other has to be nil
var active = -1;

##
# Callback for drawing a new VOR based on styling
#
# NOTE: callbacks that create symbols for caching MUST render them using a 
# transparent background !!
#
var drawVOR = func(group) {
	group.createChild("path")
		.moveTo(-15,0)
		.lineTo(-7.5,12.5)
		.lineTo(7.5,12.5)
		.lineTo(15,0)
		.lineTo(7.5,-12.5)
		.lineTo(-7.5,-12.5)
		.close()
		.setStrokeLineWidth(line_width)
		.setColor(color)
		.set("z-index",-2);
};

var cache = StyleableCacheable.new(
	name:name, draw_func: drawVOR,
	cache: SymbolCache32x32,
	draw_mode: SymbolCache.DRAW_CENTERED,
	relevant_keys: ["line_width", "color"],
);

##
# TODO: make this a part of the framework, for use by other layers/symbols etc
#
var controller_check = func(layer, controller, arg...) {
	var ret = call(compile("call(layer.controller."~controller~", arg, layer.controller)", "<test>"), arg, var err=[]);

	if (size(err))
		if (err[0] == "No such member: "~controller)
			print("MapStructure Warning: Required controller not found: ", name, ":", controller);
		else die(err[0]); # rethrow

	return ret; # nil if not found
}

var draw = func {
	var active = controller_check(me.layer, 'isActive', me.model);
	if (active != me.active) {
		if (me.icon_vor != nil) me.icon_vor.del();
		# look up the correct symbol from the cache and render it into the group as a raster image
		#me.icon_vor = icon_vor_cached[active or 0].render(me.element);
		me.style.color = active ? me.style.active_color : me.style.inactive_color;
		me.icon_vor = cache.render(me.element, me.style).setScale(me.style.scale_factor);

		me.active = active; # update me.active flag
	}
	# Update (also handles non-cached stuff, such as text labels or animations)
	# TODO: we can use a func generator to pre-create the callback/data structure for this
	if (active) {
		if (me.range_vor == nil) {
			# initialize me.range and me.radial_vor
			var rangeNm = me.map.getRange();
			# print("VOR is tuned:", me.model.id);
			var radius = (me.model.range_nm/rangeNm)*345;
			me.range_vor = me.element.createChild("path")
				.moveTo(-radius,0)
				.arcSmallCW(radius,radius,0,2*radius,0)
				.arcSmallCW(radius,radius,0,-2*radius,0)
				.setStrokeLineWidth(me.style.range_line_width)
				.setStrokeDashArray(me.style.range_dash_array)
				.setColor(me.style.active_color)
				.set("z-index",-2);

			var course = me.map.controller.get_tuned_course(me.model.frequency/100);
			me.radial_vor = me.element.createChild("path")
				.moveTo(0,-radius)
				.vert(2*radius)
				.setStrokeLineWidth(me.style.radial_line_width)
				.setStrokeDashArray(me.style.radial_dash_array)
				.setColor(me.style.active_color)
				.setRotation(course*D2R)
				.set("z-index",-2);
		}
		me.range_vor.show();
		me.radial_vor.show();
	} else { # inactive station (not tuned)
		if (me.range_vor != nil) {
			me.range_vor.hide();
			me.radial_vor.hide();
		}
	}
};

