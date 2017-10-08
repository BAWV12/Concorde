################################################################################
## MapStructure mapping/charting framework for Nasal/Canvas, by Philosopher
## See: http://wiki.flightgear.org/MapStructure
###############################################################################


#######
## Dev Notes:
##
## - consider adding two types of SymbolLayers (sub-classes): Static (fixed positions, navaids/fixes) Dynamic (frequently updated, TFC/WXR, regardless of aircraft position)
## - FLT should be managed by aircraftpos.controller probably (interestign corner case actually)
## - consider adding an Overlay, i.e. for things like compass rose, lat/lon coordinate grid, but also tiled map data fetched on line
## - consider patching svg.nas to allow elements to be styled via the options hash by rewriting attributes, could even support animations that way
## - style handling/defaults should be moved to symbol files probably
## - consider pre-populating layer environments via bind() by providing APIs and fields for sane defaults:
##	- parents
##	- __self__
##	- del (managing all listeners and timers)
## 	- searchCmd -> filtering 
##
##  APIs to be wrapped for each layer:
##  printlog(), die(), debug.bt(), benchmark()

var _MP_dbg_lvl = "debug";
#var _MP_dbg_lvl = "alert";

var makedie = func(prefix) func(msg) globals.die(prefix~" "~msg);

var __die = makedie("MapStructure");

##
# Try to call a method on an object with no arguments. Should
# work for both ghosts and hashes; catches the error only when
# the method doesn't exist -- errors raised during the call
# are re-thrown.
#
var try_aux_method = func(obj, method_name) {
	var name = "<test%"~id(caller(0)[0])~">";
	call(compile("obj."~method_name~"()", name), nil, var err=[]); # try...
	#debug.dump(err);
	if (size(err)) # ... and either leave caght or rethrow
		if (err[1] != name)
			die(err[0]);
}

##
# Combine a specific hash with a default hash, e.g. for
# options/df_options and style/df_style in a SymbolLayer.
#
var default_hash = func(opt, df) {
	if (opt != nil and typeof(opt)=='hash') {
		if (df != nil and opt != df and !isa(opt, df)) {
			if (contains(opt, "parents"))
				opt.parents ~= [df];
			else
				opt.parents = [df];
		}
		return opt;
	} else return df;
}

##
# to be used for prototyping, performance & stress testing (especially with multiple instance driven by AI traffic)
#

var MapStructure_selfTest = func() {
	var temp = {};
	temp.dlg = canvas.Window.new([600,400],"dialog");
	temp.canvas = temp.dlg.createCanvas().setColorBackground(1,1,1,0.5);
	temp.root = temp.canvas.createGroup();
	var TestMap = temp.root.createChild("map");
	TestMap.setController("Aircraft position");
	TestMap.setRange(25); # TODO: implement zooming/panning via mouse/wheel here, for lack of buttons :-/
	TestMap.setTranslation(
		temp.canvas.get("view[0]")/2,
		temp.canvas.get("view[1]")/2
	);
	var r = func(name,vis=1,zindex=nil) return caller(0)[0];
	# TODO: we'll need some z-indexing here, right now it's just random
	# TODO: use foreach/keys to show all layers in this case by traversing SymbolLayer.registry direclty ?
	# maybe encode implicit z-indexing for each lcontroller ctor call ? - i.e. preferred above/below order ?
	foreach(var type; [r('TFC',0),r('APT'),r('DME'),r('VOR'),r('NDB'),r('FIX',0),r('RTE'),r('WPT'),r('FLT'),r('WXR'),r('APS'), ] ) 
		TestMap.addLayer(factory: canvas.SymbolLayer, type_arg: type.name,
					visible: type.vis, priority: type.zindex,
		);
}; # MapStructure_selfTest


##
# wrapper for each cached element: keeps the canvas and
# texture map coordinates for the corresponding raster image.
#
var CachedElement = {
	new: func(canvas_path, name, source, size, offset) {
		var m = {parents:[CachedElement] };
		if (isa(canvas_path, canvas.Canvas)) {
			canvas_path = canvas_path.getPath();
		}
		m.canvas_src = canvas_path;
		m.name = name;
		m.source = source;
		m.size = size;
		m.offset = offset;
		return m;
	},

	render: func(group, trans0=0, trans1=0) {
		# create a raster image child in the render target/group
		var n = group.createChild("image", me.name)
			.setFile(me.canvas_src)
			.setSourceRect(me.source, 0)
			.setSize(me.size)
			.setTranslation(trans0,trans1);
		n.createTransform().setTranslation(me.offset);
		return n;
	},
}; # of CachedElement

var SymbolCache = {
	# We can draw symbols either with left/top, centered,
	# or right/bottom alignment. Specify two in a vector
	# to mix and match, e.g. left/centered would be
	#  [SymbolCache.DRAW_LEFT_TOP,SymbolCache.DRAW_CENTERED]
	DRAW_LEFT_TOP:     0.0,
	DRAW_CENTERED:     0.5,
	DRAW_RIGHT_BOTTOM: 1.0,
	new: func(dim...) {
		var m = { parents:[SymbolCache] };
		# to keep track of the next free caching spot (in px)
		m.next_free = [0, 0];
		# to store each type of symbol
		m.dict = {};
		if (size(dim) == 1 and typeof(dim[0]) == 'vector')
			dim = dim[0];
		# Two sizes: canvas and symbol
		if (size(dim) == 2) {
			var canvas_x = var canvas_y = dim[0];
			var image_x = var image_y = dim[1];
		# Two widths (canvas and symbol) and then height/width ratio
		} else if (size(dim) == 3) {
			var (canvas_x,image_x,ratio) = dim;
			var canvas_y = canvas_x * ratio;
			var image_y = image_x * ratio;
		# Explicit canvas and symbol widths/heights
		} else if (size(dim) == 4) {
			var (canvas_x,canvas_y,image_x,image_y) = dim;
		}
		m.canvas_sz = [canvas_x, canvas_y];
		m.image_sz = [image_x, image_y];

		# allocate a canvas
		m.canvas_texture = canvas.new( {
			"name": "SymbolCache"~canvas_x~'x'~canvas_y,
			"size": m.canvas_sz,
			"view": m.canvas_sz,
			"mipmapping": 1
		});
		m.canvas_texture.setColorBackground(0, 0, 0, 0); #rgba
		# add a placement
		m.canvas_texture.addPlacement( {"type": "ref"} );

		m.path = m.canvas_texture.getPath();
		m.root = m.canvas_texture.createGroup("entries");

		# TODO: register a reset/re-init listener to optionally purge/rebuild the cache ?

		return m;
	},
	##
	# Add a cached symbol based on a drawing callback.
	# @note this assumes that the object added by callback
	#       fits into the dimensions provided to the constructor,
	#       and any larger dimensionalities are liable to be cut off.
	#
	add: func(name, callback, draw_mode=0) {
		if (typeof(draw_mode) == 'scalar')
			var draw_mode0 = var draw_mode1 = draw_mode;
		else var (draw_mode0,draw_mode1) = draw_mode;

		# get canvas texture that we use as cache
		# get next free spot in texture (column/row)
		# run the draw callback and render into a new group
		var gr = me.root.createChild("group",name);
		# draw the symbol into the group
		callback(gr);

		gr.update(); # if we need sane output from getTransformedBounds()
		#debug.dump ( gr.getTransformedBounds() );
		gr.setTranslation( me.next_free[0] + me.image_sz[0]*draw_mode0,
		                   me.next_free[1] + me.image_sz[1]*draw_mode1);

		# get assumed the bounding box, i.e. coordinates for texture map
		var coords = me.next_free~me.next_free;
		foreach (var i; [0,1])
			coords[i+1] += me.image_sz[i];
		foreach (var i; [0,1])
			coords[i*2+1] = me.canvas_sz[i] - coords[i*2+1];
		# get the offset we used to position correctly in the bounds of the canvas
		var offset = [-me.image_sz[0]*draw_mode0, -me.image_sz[1]*draw_mode1];

		# update next free position in cache (column/row)
		me.next_free[0] += me.image_sz[0];
		if (me.next_free[0] >= me.canvas_sz[0])
		{ me.next_free[0] = 0; me.next_free[1] += me.image_sz[1] }
		if (me.next_free[1] >= me.canvas_sz[1])
			__die("SymbolCache: ran out of space after adding '"~name~"'");

		if (contains(me.dict, name)) print("MapStructure/SymbolCache Warning: Overwriting existing cache entry named:", name);

		# store texture map coordinates in lookup map using the name as identifier
		return me.dict[name] = CachedElement.new(
			canvas_path: me.path,
			name: name,
			source: coords,
			size:me.image_sz,
			offset: offset,
		);
	}, # add()
	get: func(name) {
		return me.dict[name];
	}, # get()
};

# Excerpt from gen module
var denied_symbols = [
	"", "func", "if", "else", "var",
	"elsif", "foreach", "for",
	"forindex", "while", "nil",
	"return", "break", "continue",
];
var issym = func(string) {
	foreach (var d; denied_symbols)
		if (string == d) return 0;
	var sz = size(string);
	var s = string[0];
	if ((s < `a` or s > `z`) and
		(s < `A` or s > `Z`) and
		(s != `_`)) return 0;
	for (var i=1; i<sz; i+=1)
		if (((s=string[i]) != `_`) and
			(s < `a` or s > `z`) and
			(s < `A` or s > `Z`) and
			(s < `0` or s > `9`)) return 0;
	return 1;
};
var internsymbol = func(symbol) {
	#assert("argument not a symbol", issym, symbol);
	if (!issym(symbol)) die("argument not a symbol");
	var get_interned = compile("""
		keys({"~symbol~":})[0]
	""");
	return get_interned();
};
var tryintern = func(symbol) issym(symbol) ? internsymbol(symbol) : symbol;

# End excerpt

# Helpers for below
var unescape = func(s) string.replace(s~"", "'", "\\'");
var hashdup = func(_,rkeys=nil) {
	var h={}; var k=rkeys!=nil?rkeys:members(_);
	foreach (var k;k) h[tryintern(k)]=member(_,k); h
}
var opt_member = func(h,k) {
	if (contains(h, k)) return h[k];
	if (contains(h, "parents")) {
		var _=h.parents;
		for (var i=0;i<size(_);i+=1){
			var v = opt_member(_[i], k);
			if (v != nil) return v;
		}
	}
	return nil;
}
var member = func(h,k) {
	if (contains(h, k)) return h[k];
	if (contains(h, "parents")) {
		var _=h.parents;
		for (var i=0;i<size(_);i+=1)
			if (contains(_[i], k)) return _[i][k];
			elsif (contains(_[i], "parents") and size(_[i].parents))
			{_=h.parents~_[i+1:];i=0}
	}
	die("member not found: '"~unescape(k)~"'");
}
var _in = func(vec,k) { foreach (var _;vec) if(_==k)return 1; 0; }
var members = func(h,vec=nil) {
	if (vec == nil) vec = [];
	foreach (var k; keys(h))
		if (k == "parents")
			foreach (var p; h[k])
				members(p,vec);
		elsif (!_in(vec,k))
			append(vec, k);
	return vec;
}
var serialize = func(m,others=nil) {
	var t = typeof(m);
	if (t == 'scalar')
		if (num(m) != nil)
			return m~"";
		else return "'" ~ unescape(m) ~ "'";
	if (others == nil) others = {};
	var i = id(m);
	if (contains(others, i)) return "...";
	others[i] = nil;
	if (t == 'vector') {
		var ret = "[";
		foreach (var l; m) {
			if (ret != "[") ret ~= ",";
			ret ~= serialize(l,others);
		}
		return ret~"]";
	} else die("type not supported for style serialization: '"~t~"'");
}

# Drawing functions have the form:
#   func(group) { group.createChild(...).set<Option>(<option>); ... }
# The style is passed as (essentially) their local namespace/variables,
# while the group is a regular argument.
var call_draw = func(draw, style, arg=nil, relevant_keys=nil) {
	return call(draw, arg, nil, hashdup(style,relevant_keys));
}

# Serialize a style into a string.
var style_string = func(style, relevant_keys=nil) {
	if (relevant_keys == nil) relevant_keys = members(style);
	relevant_keys = sort(relevant_keys, cmp);
	var str = "";
	foreach (var k; relevant_keys) {
		var m = member(style,k);
		if (m == nil) continue;
		if (str) str ~= ";";
		str ~= k ~ ":";
		str ~= serialize(m);
	}
	return str;
}

##
# A class to mix styling and caching. Using the above helpers it
# serializes style hashes.
#
var StyleableCacheable = {
	##
	# Construct an object.
	# @param name Prefix to use for entries in the cache
	# @param draw_func Function for the cache that will draw the
	#                  symbol onto a group using the style parameters.
	# @param cache The #SymbolCache to use for these symbols.
	# @param draw_mode See #SymbolCache
	# @param relevant_keys A list of keys for the style used by the
	#                      draw_func. Although it defaults to all
	#                      available keys, it is highly recommended
	#                      that it be specified.
	#
	new: func(name, draw_func, cache, draw_mode=0, relevant_keys=nil) {
		return {
			parents: [StyleableCacheable],
			_name: name,
			_draw_func: draw_func,
			_cache: cache,
			_draw_mode: draw_mode,
			relevant_keys: relevant_keys,
		};
	},
	# Note: configuration like active/inactive needs
	# to also use the passed style hash, unless it is
	# chosen not to cache symbols that are, e.g., active.
	request: func(style) {
		var s = style_string(style, me.relevant_keys);
		#debug.dump(style, s);
		var s1 = me._name~s;
		var c = me._cache.get(s1);
		if (c != nil) return c;
		return me.draw(style,s1);
	},
	render: func(element, style) {
		var c = me.request(style);
		c.render(element);
	},
	draw: func(style,s1) {
		var fn = func call_draw(me._draw_func, style, arg, me.relevant_keys);
		me._cache.add(s1, fn, me._draw_mode);
	},
};

##
# A base class for Symbols placed on a map.
#
# Note: for the derived objects, the element is stored as obj.element.
# This is also part of the object's parents vector, which allows
# callers to use obj.setVisible() et al. However, for code that
# manipulates the element's path (if it is a Canvas Path), it is best
# to use obj.element.addSegmentGeo() et al. for consistency.
#
var Symbol = {
# Static/singleton:
	registry: {},
	add: func(type, class)
		me.registry[type] = class,
	get: func(type)
		if ((var class = me.registry[type]) == nil)
			__die("Symbol.get():unknown type '"~type~"'");
		else return class,
	# Calls corresonding symbol constructor
	# @param group #Canvas.Group to place this on.
	# @param layer The #SymbolLayer this is a child of.
	new: func(type, group, layer, arg...) {
		var ret = call((var class = me.get(type)).new, [group, layer]~arg, class);
		ret.element.set("symbol-type", type);
		return ret;
	},
	# Private constructor:
	_new: func(m) {
		m.style = m.layer.style;
		m.options = m.layer.options;
		if (m.controller != nil) {
			temp = m.controller.new(m,m.model);
			if (temp != nil)
				m.controller = temp;
		}
		else __die("Symbol._new(): default controller not found");
	},
# Non-static:
	df_controller: nil, # default controller -- Symbol.Controller by default, see below
	# Update the drawing of this object (position and others).
	update: func()
		__die("Abstract Symbol.update(): not implemented for this symbol type!"),
	draw: func() ,
	del: func() {
		if (me.controller != nil)
			me.controller.del(me, me.model);
		try_aux_method(me.model, "del");
	},

	# Add a text element with styling
	newText: func(text=nil, color=nil) {
		var t = me.element.createChild("text")
			.setDrawMode( canvas.Text.TEXT )
			.setText(text)
			.setFont(me.layer.style.font)
			.setFontSize(me.layer.style.font_size);
		if (color != nil)
			t.setColor(color);
		return t;
	},
	# Helper method that can be used to create a formatted String using
	# values extracted from the current model.
	#
	# SYNOPSIS:
	#
	#   symbol.formattedString(format, model_property_names)
	#
	#   Arguments:
	#       - format: string
	#       - model_property_names: a vector of strings representing the model
	#                               property names to be used as arguments
	#
	# EXAMPLE:
	#
	#   var label = waypoint.formattedString('Waypoint %s: lat %.4f, lng %.4f', [model.id, model.lat, model.lon]);
	formattedString: func(frmt, model_props){
		if(me.model == nil) return frmt;
		var args = [];
		foreach(var prop; model_props){
			if(contains(me.model, prop)){
				var val = me.model[prop];
				var tp = typeof(val);
				if(tp != 'scalar'){
					val = '';
					#printlog("warn", "formattedString: invalid type for "~prop~" (" ~ tp ~ ")");
				} else {
					append(args, val);
				}
			}
		}
		return call(sprintf, [frmt] ~ args);
	},

	# Wrapper method for accessing options. It allows to pass a default value
	# if the requested option is not defined.
	#
	# EXAMPLE:
	#      var ok = (contains(me.options, 'enabled') ? me.options.enabled : 0);
	#      var ok = me.getOption('enabled', 0);
	getOption: func(name,  default = nil){
		var opt = me.options;
		if(opt == nil)
			opt = me.layer.options;
		if(opt == nil) return default;
		var val = opt_member(opt, name);
		if(val == nil) return default;
		return val;
	},

	# Wrapper method for accessing style. It allows to pass a default value
	# if the requested style is not defined.
	# It also automatically resolves style properties when they're defined as
	# functions, by calling the corresponding function using the 'me' context
	#
	# EXAMPLE:
	#
	#   me.style = {
	#       color: [1,1,1],
	#       line_color: func(){
	#           me.model.tuned ? [0,0,1] : [1,1,1]
	#       }
	#   }
	#   var color = me.getStyle('color'); # --> [1,1,1]
	#   me.model.tuned = 1;
	#   var line_color = me.getStyle('line_color'); # --> [0,0,1]
	#   var txt_color = me.getStyle('text_color', [1,1,1]); # --> [1,1,1]
	getStyle: func(name, default = nil){
		var st = me.style;
		if(st == nil)
			st = me.layer.style;
		if(st == nil) return default;
		var val = opt_member(st, name);
		if(typeof(val) == 'func'){
			val = (call(val,[],me));
		}
		if(val == nil) return default;
		return val;
	},
	getLabelFromModel: func(default_val = nil){
		if(me.model == nil) return default_val;
		if(default_val == nil and contains(me.model, 'id'))
		default_val = me.model.id;
		var label_content = me.getOption('label_content');
		if(label_content == nil) return default_val;
		if(typeof(label_content) == 'scalar')
			label_content = [label_content];
		var format_s = me.getOption('label_format');
		var label = '';
		if(format_s == nil){
			format_s = "%s";
		}
		return me.formattedString(format_s, label_content);
	},
	# Executes callback function specified by the first argument with
	# variable arguments. The callback is executed within the 'me' context.
	# Callbacks must be defined inside the options hash.
	#
	# EXAMPLE:
	#
	#   me.options = {
	#       dump_callback: func(){
	#           print('Waypoint '~ me.model.id);
	#       }
	#   }
	#   me.callback('dump');
	callback: func(name, args...){
		name = name ~'_callback';
		var f = me.getOption(name);
		if(typeof(f) == 'func'){
			return call(f, args, me);
		}
	}
}; # of Symbol


Symbol.Controller = {
# Static/singleton:
	registry: {},
	add: func(type, class)
		me.registry[type] = class,
	get: func(type)
		if ((var class = me.registry[type]) == nil)
			__die("Symbol.Controller.get(): unknown type '"~type~"'");
		else return class,
	# Calls corresonding symbol controller constructor
	# @param model Model to control this object (position and other attributes).
	new: func(type, symbol, model, arg...)
		return call((var class = me.get(type)).new, [symbol, model]~arg, class),
# Non-static:
	# Update anything related to a particular model. Returns whether the object needs updating:
	update: func(symbol, model) return 1,
	# Delete an object from this controller (or delete the controller itself):
	del: func(symbol, model) ,
	# Return whether this model/symbol is (should be) visible:
	isVisible: func(model) return 1,
	# Get the position of this symbol/object:
	getpos: func(model) , # default provided below
}; # of Symbol.Controller
# Add this to Symbol as the default controller, but replace the Static .new() method with a blank
Symbol.df_controller = { parents:[Symbol.Controller], new: func nil };

var getpos_fromghost = func(positioned_g)
	return [positioned_g.lat, positioned_g.lon];

# to add support for additional ghosts, just append them to the vector below, possibly at runtime:
var supported_ghosts = ['positioned','Navaid','Fix','flightplan-leg','FGAirport'];
var is_positioned_ghost = func(obj) {
	var gt = ghosttype(obj);
	foreach(var ghost; supported_ghosts) {
		if (gt == ghost) return 1; # supported ghost was found
	}
	return 0; # not a known/supported ghost
};

var register_supported_ghost = func(name) append(supported_ghosts, name);

# Generic getpos: get lat/lon from any object:
# (geo.Coord and positioned ghost currently)
Symbol.Controller.getpos = func(obj, p=nil) {
	if (obj == nil) __die("Symbol.Controller.getpos(): received nil");
	if (p == nil) {
		var ret = Symbol.Controller.getpos(obj, obj);
		if (ret != nil) return ret;
		if (contains(obj, "parents")) {
			foreach (var p; obj.parents) {
				var ret = Symbol.Controller.getpos(obj, p);
				if (ret != nil) return ret;
			}
		}
		debug.dump(obj);
		__die("Symbol.Controller.getpos(): no suitable getpos() found! Of type: "~typeof(obj));
	} else {
		if (typeof(p) == 'ghost')
			if ( is_positioned_ghost(p) )
				return getpos_fromghost(obj);
			else
				__die("Symbol.Controller.getpos(): bad/unsupported ghost of type '"~ghosttype(obj)~"' (see MapStructure.nas Symbol.Controller.getpos() to add new ghosts)");
		if (typeof(p) == 'hash')
			if (p == geo.Coord)
				return subvec(obj.latlon(), 0, 2);
			if (p == props.Node)
				return [
					obj.getValue("position/latitude-deg")  or obj.getValue("latitude-deg"),
					obj.getValue("position/longitude-deg") or obj.getValue("longitude-deg")
				];
			if (contains(p,'lat') and contains(p,'lon'))
				return [obj.lat, obj.lon];
		return nil;
	}
};

Symbol.Controller.equals = func(l, r, p=nil) {
	if (l == r) return 1;
	if (p == nil) {
		var ret = Symbol.Controller.equals(l, r, l);
		if (ret != nil) return ret;
		if (contains(l, "parents")) {
			foreach (var p; l.parents) {
				var ret = Symbol.Controller.equals(l, r, p);
				if (ret != nil) return ret;
			}
		}
		debug.dump(l);
		__die("Symbol.Controller: no suitable equals() found! Of type: "~typeof(l));
	} else {
		if (typeof(p) == 'ghost')
			if ( is_positioned_ghost(p) )
				return l.id == r.id;
			else
				__die("Symbol.Controller: bad/unsupported ghost of type '"~ghosttype(l)~"' (see MapStructure.nas Symbol.Controller.getpos() to add new ghosts)");
		if (typeof(p) == 'hash')
			# Somewhat arbitrary convention:
			#   * l.equals(r)         -- instance method, i.e. uses "me" and "arg[0]"
			#   * parent._equals(l,r) -- class method, i.e. uses "arg[0]" and "arg[1]"
			if (contains(p, "equals"))
				return l.equals(r);
			if (contains(p, "_equals"))
				return p._equals(l,r);
	}
	return nil; # scio correctum est
};


var assert_m = func(hash, member)
	if (!contains(hash, member))
		__die("assert_m: required field not found: '"~member~"'");
var assert_ms = func(hash, members...)
	foreach (var m; members)
		if (m != nil) assert_m(hash, m);

##
# Implementation for a particular type of symbol (for the *.symbol files)
# to handle details.
#
var DotSym = {
	parents: [Symbol],
	element_id: nil,
# Static/singleton:
	makeinstance: func(name, hash) {
		if (!isa(hash, DotSym))
			__die("DotSym: OOP error");
		return Symbol.add(name, hash);
	},
# For the instances returned from makeinstance:
	# @param group The #Canvas.Group to add this to.
	# @param layer The #SymbolLayer this is a child of.
	# @param model A correct object (e.g. positioned ghost) as
	#              expected by the .draw file that represents
	#              metadata like position, speed, etc.
	# @param controller Optional controller "glue". Each method
	#                   is called with the model as the only argument.
	new: func(group, layer, model, controller=nil) {
		if (me == nil) __die();
		var m = {
			parents: [me],
			group: group,
			layer: layer,
			model: model,
			map: layer.map,
			controller: controller == nil ? me.df_controller : controller,
			element: group.createChild(
				me.element_type, me.element_id
			),
		};
		append(m.parents, m.element);
		Symbol._new(m);

		m.init();
		return m;
	},
	del: func() {
		printlog(_MP_dbg_lvl, "DotSym.del()");
		me.deinit();
		call(Symbol.del, nil, me);
		me.element.del();
	},
# Default wrappers:
	init: func() me.draw(),
	deinit: func(),
	update: func() {
		if (me.controller != nil) {
			if (!me.controller.update(me, me.model)) return;
			elsif (!me.controller.isVisible(me.model)) {
				me.element.hide();
				return;
			}
		} else
		me.element.show();
		me.draw();
		if(me.getOption('disable_position', 0)) return;
		var pos = me.controller.getpos(me.model);
		if (size(pos) == 2)
			pos~=[nil]; # fall through
		if (size(pos) == 3)
			var (lat,lon,rotation) = pos;
		else __die("DotSym.update(): bad position: "~debug.dump(pos));
		# print(me.model.id, ": Position lat/lon: ", lat, "/", lon);
		me.element.setGeoPosition(lat,lon);
		if (rotation != nil)
			me.element.setRotation(rotation);
	},
}; # of DotSym

##
# Small wrapper for DotSym: parse a SVG on init().
#
var SVGSymbol = {
	parents:[DotSym],
	element_type: "group",
	cacheable: 0,
	init: func() {
		me.callback('init_before');
		var opt_path = me.getStyle('svg_path');
		if(opt_path != nil)
			me.svg_path = opt_path;
		if (!me.cacheable) {
			if(me.svg_path != nil and me.svg_path != '')
				canvas.parsesvg(me.element, me.svg_path);
			# hack:
			if (var scale = me.layer.style['scale_factor'])
				me.element.setScale(scale);
			if ((var transl = me.layer.style['translate']) != nil)
				me.element.setTranslation(transl);
		} else {
			__die("cacheable not implemented yet!");
		}
		me.callback('init_after');
		me.draw();
	},
	draw: func{
		me.callback('draw');
	},
}; # of SVGSymbol


##
# wrapper for symbols based on raster images (i.e. PNGs)
# TODO: generalize this and port WXR.symbol accordingly
#
var RasterSymbol = {
	parents:[DotSym],
	element_type: "group",
	cacheable: 0,
	size: [32,32], scale: 1,
	init: func() {
		if (!me.cacheable) {
			me.element.createChild("image", me.name)
			.setFile(me.file_path)
			.setSize(me.size)
			.setScale(me.scale);
		} else {
			__die("cacheable not implemented yet!");
		}
		me.draw();
	},
	draw: func,

}; # of RasterSymbol



var LineSymbol = {
	parents:[Symbol],
	element_id: nil,
	needs_update: 1,
# Static/singleton:
	makeinstance: func(name, hash) {
		if (!isa(hash, LineSymbol))
			__die("LineSymbol: OOP error");
		return Symbol.add(name, hash);
	},
# For the instances returned from makeinstance:
	new: func(group, layer, model, controller=nil) {
		if (me == nil) __die("Need me reference for LineSymbol.new()");
		if (typeof(model) != 'vector') {
			if(typeof(model) == 'hash'){
				if(!contains(model, 'path'))
					__die("LineSymbol.new(): model hash requires path");
			}
			else __die("LineSymbol.new(): need a vector of points or a hash");
		}
		var m = {
			parents: [me],
			group: group,
			layer: layer,
			model: model,
			controller: controller == nil ? me.df_controller : controller,
			element: group.createChild(
				"path", me.element_id
			),
		};
		append(m.parents, m.element);
		Symbol._new(m);

		m.init();
		return m;
	},
# Non-static:
	draw: func() {
		if (!me.needs_update) return;
		me.callback('draw_before');
		printlog(_MP_dbg_lvl, "redrawing a LineSymbol "~me.layer.type);
		me.element.reset();
		var cmds = [];
		var coords = [];
		var cmd = canvas.Path.VG_MOVE_TO;
		var path = me.model;
		if(typeof(path) == 'hash'){
			path = me.model.path;
			if(path == nil) 
				__die("LineSymbol model requires a 'path' member (vector)");
		}
		foreach (var m; path) {
			if(size(keys(m)) >= 2){
				var (lat,lon) = me.controller.getpos(m);
				append(coords,"N"~lat);
				append(coords,"E"~lon);
				append(cmds,cmd); 
				cmd = canvas.Path.VG_LINE_TO;
			} else {
				cmd = canvas.Path.VG_MOVE_TO;
			}
		}
		me.element.setDataGeo(cmds, coords);
		me.element.update(); # this doesn't help with flickering, it seems
		me.callback('draw_after');
	},
	del: func() {
		printlog(_MP_dbg_lvl, "LineSymbol.del()");
		me.deinit();
		call(Symbol.del, nil, me);
		me.element.del();
	},
# Default wrappers:
	init: func() me.draw(),
	deinit: func(),
	update: func() {
		if (me.controller != nil) {
			if (!me.controller.update(me, me.model)) return;
			elsif (!me.controller.isVisible(me.model)) {
				me.element.hide();
				return;
			}
		} else
		me.element.show();
		me.draw();
	},
}; # of LineSymbol

##
# Base class for a SymbolLayer, e.g. MultiSymbolLayer or SingleSymbolLayer.
#
var SymbolLayer = {
# Default implementations/values:
	df_controller: nil, # default controller
	df_priority: nil, # default priority for display sorting
	df_style: nil,
	df_options: nil,
	type: nil, # type of #Symbol to add (MANDATORY)
	id: nil, # id of the group #canvas.Element (OPTIONAL)
# Static/singleton:
	registry: {},
	add: func(type, class)
		me.registry[type] = class,
	get: func(type) {
		foreach(var invalid; var invalid_types = [nil,'vector','hash'])
			if ( (var t=typeof(type)) == invalid) __die(" invalid SymbolLayer type (non-scalar) of type:"~t);
		if ((var class = me.registry[type]) == nil)
			__die("SymbolLayer.get(): unknown type '"~type~"'");
		else return class;
	},
	# Calls corresonding layer constructor
	# @param group #Canvas.Group to place this on.
	# @param map The #Canvas.Map this is a member of.
	# @param controller A controller object.
	# @param style An alternate style.
	# @param options Extra options/configurations.
	# @param visible Initially set it up as visible or invisible.
	new: func(type, group, map, controller=nil, style=nil, options=nil, visible=1, arg...) {
		# XXX: Extra named arguments are (obviously) not preserved well...
		var ret = call((var class = me.get(type)).new, [group, map, controller, style, options, visible]~arg, class);
		ret.group.set("layer-type", type);
		return ret;
	},
	# Private constructor:
	_new: func(m, style, controller, options) {
		# print("SymbolLayer setup options:", m.options!=nil);
		m.style = default_hash(style, m.df_style);
		m.options = default_hash(options, m.df_options);
		
		if (controller == nil)
			controller = m.df_controller;
		assert_m(controller, "parents");
		if (controller.parents[0] == SymbolLayer.Controller)
			controller = controller.new(m);
		assert_m(controller, "parents");
		assert_m(controller.parents[0], "parents");
		if (controller.parents[0].parents[0] != SymbolLayer.Controller)
			__die("MultiSymbolLayer: OOP error");
		if(options != nil){
			var listeners = opt_member(controller, 'listeners');
			var listen = opt_member(options, 'listen');
			if (listen != nil and listeners != nil){
				var listen_tp = typeof(listen);
				if(listen_tp != 'vector' and listen_tp != 'scalar')
					__die("Options 'listen' cannot be a "~ listen_tp);
				if(typeof(listen) == 'scalar')
					listen = [listen];
				foreach(var node_name; listen){
					var node = opt_member(options, node_name);
					if(node == nil)
						node = node_name;
					append(controller.listeners,
						   setlistener(node, func call(m.update,[],m),0,0));
				}
			}
		}
		m.controller = controller;
	},
# For instances:
	del: func() if (me.controller != nil) { me.controller.del(); me.controller = nil },
	update: func() __die("Abstract SymbolLayer.update() not implemented for this Layer"),
};

# Class to manage controlling a #SymbolLayer.
# Currently handles:
#  * Searching for new symbols (positioned ghosts or other objects with unique id's).
#  * Updating the layer (e.g. on an update loop or on a property change).
SymbolLayer.Controller = {
# Static/singleton:
	registry: {},
	add: func(type, class)
		me.registry[type] = class,
	get: func(type)
		if ((var class = me.registry[type]) == nil)
			__die("unknown type '"~type~"'");
		else return class,
	# Calls corresonding controller constructor
	# @param layer The #SymbolLayer this controller is responsible for.
	new: func(type, layer, arg...)
		return call((var class = me.get(type)).new, [layer]~arg, class),
# Default implementations for derived classes:
	# @return List of positioned objects.
	searchCmd: func()
		__die("Abstract method searchCmd() not implemented for this SymbolLayer.Controller type!"),
	addVisibilityListener: func() {
		var m = me;
		append(m.listeners, setlistener(
			m.layer._node.getNode("visible"),
			func m.layer.update(),
			#compile("m.layer.update()", "<layer visibility on node "~m.layer._node.getNode("visible").getPath()~" for layer "~m.layer.type~">"),
			0,0
		));
	},
# Default implementations for derived objects:
	# For SingleSymbolLayer: retreive the model object
	getModel: func me._model, # assume they store it here - otherwise they can override this
}; # of SymbolLayer.Controller

##
# A layer that manages a list of symbols (using delta positioned handling
# with a searchCmd to retreive placements).
#
var MultiSymbolLayer = {
	parents: [SymbolLayer],
# Default implementations/values:
	# @param group A group to place this on.
	# @param map The #Canvas.Map this is a member of.
	# @param controller A controller object (parents=[SymbolLayer.Controller])
	#                   or implementation (parents[0].parents=[SymbolLayer.Controller]).
	# @param style An alternate style.
	# @param options Extra options/configurations.
	# @param visible Initially set it up as visible or invisible.
	new: func(group, map, controller=nil, style=nil, options=nil, visible=1) {
		#print("Creating new SymbolLayer instance");
		if (me == nil) __die("MultiSymbolLayer constructor needs to know its parent class");
		var m = {
			parents: [me],
			map: map,
			group: group.createChild("group", me.type),
			list: [],
		};
		append(m.parents, m.group);
		m.setVisible(visible);
		# N.B.: this has to be here for the controller
		m.searcher = geo.PositionedSearch.new(me.searchCmd, me.onAdded, me.onRemoved, m);
		SymbolLayer._new(m, style, controller, options);

		m.update();
		return m;
	},
	update: func() {
		if (!me.getVisible())
			return;
		#debug.warn("update traceback for "~me.type);

		var updater = func {
			me.searcher.update();
			foreach (var e; me.list)
				e.update();
		}

		if (me.options != nil and me.options['update_wrapper'] !=nil) {
			me.options.update_wrapper( me, updater ); # call external wrapper (usually for profiling purposes)
		} else {
			updater();
		}
	},
	del: func() {
		printlog(_MP_dbg_lvl, "MultiSymbolLayer.del()");
		foreach (var e; me.list)
			e.del();
		call(SymbolLayer.del, nil, me);
	},
	delsym: func(model) {
		forindex (var i; me.list) {
			var e = me.list[i];
			if (Symbol.Controller.equals(e.model, model)) {
				# Remove this element from the list
				# TODO: maybe C function for this? extend pop() to accept index?
				var prev = subvec(me.list, 0, i);
				var next = subvec(me.list, i+1);
				me.list = prev~next;
				e.del();
				return 1;
			}
		}
		return 0;
	},
	searchCmd: func() { 
		if (me.map.getPosCoord() == nil or me.map.getRange() == nil) { 
			print("Map not yet initialized, returning empty result set!");
			return []; # handle maps not yet fully initialized
		}
		var result = me.controller.searchCmd();
		# some hardening
		var type=typeof(result);
		if(type != 'nil' and type != 'vector') 
			__die("MultiSymbolLayer: searchCmd() method MUST return a vector of valid positioned ghosts/Geo.Coord objects or nil! (was:"~type~")");
		return result;
	},
	# Adds a symbol.
	onAdded: func(model) {
		printlog(_MP_dbg_lvl, "Adding symbol of type "~me.type);
		if (model == nil) __die("MultiSymbolLayer: Model was nil for layer:"~debug.string(me.type)~ " Hint:check your equality check method!");
		append(me.list, Symbol.new(me.type, me.group, me, model));
	},
	# Removes a symbol.
	onRemoved: func(model) {
		printlog(_MP_dbg_lvl, "Deleting symbol of type "~me.type);
		if (!me.delsym(model)) __die("model not found");
		try_aux_method(model, "del");
		#call(func model.del(), nil, var err = []); # try...
		#if (size(err) and err[0] != "No such member: del") # ... and either catch or rethrow
		#	die(err[0]);
	},
}; # of MultiSymbolLayer

##
# A layer that manages a list of statically-positioned navaid symbols (using delta positioned handling
# with a searchCmd to retrieve placements).
# This is not yet supposed to work properly, it's just there to help get rid of all the identical boilerplate code
# in lcontroller files, so needs some reviewing and customizing still
#
var NavaidSymbolLayer = {
	parents: [MultiSymbolLayer],
# static generator/functor maker:
	make: func(query) {
		#print("Creating searchCmd() for NavaidSymbolLayer:", query);
		return func {
			printlog(_MP_dbg_lvl, "Running query:", query);
			var range = me.map.getRange();
			if (range == nil) return;
			return positioned.findWithinRange(me.map.getPosCoord(), range, query);
		};
	},
}; # of NavaidSymbolLayer



###
## TODO: wrappers for Horizontal vs. Vertical layers ?
## 

var SingleSymbolLayer = {
	parents: [SymbolLayer],
# Default implementations/values:
	# @param group A group to place this on.
	# @param map The #Canvas.Map this is a member of.
	# @param controller A controller object (parents=[SymbolLayer.Controller])
	#                   or implementation (parents[0].parents=[SymbolLayer.Controller]).
	# @param style An alternate style.
	# @param options Extra options/configurations.
	# @param visible Initially set it up as visible or invisible.
	new: func(group, map, controller=nil, style=nil, options=nil, visible=1) {
		#print("Creating new SymbolLayer instance");
		if (me == nil) __die("SingleSymbolLayer constructor needs to know its parent class");
		var m = {
			parents: [me],
			map: map,
			group: group.createChild("group", me.type),
		};
		append(m.parents, m.group);
		m.setVisible(visible);
		SymbolLayer._new(m, style, controller, options);

		m.symbol = Symbol.new(m.type, m.group, m, m.controller.getModel());
		m.update();
		return m;
	},
	update: func() {
		if (!me.getVisible())
			return;

		var updater = func {
			if (typeof(me.symbol.model) == 'hash') try_aux_method(me.symbol.model, "update");
			me.symbol.update();
		}

		if (me.options != nil and me.options['update_wrapper'] != nil) {
			me.options.update_wrapper( me, updater ); # call external wrapper (usually for profiling purposes)
		} else {
			updater();
		}
	},
	del: func() {
		printlog(_MP_dbg_lvl, "SymbolLayer.del()");
		me.symbol.del();
		call(SymbolLayer.del, nil, me);
	},
}; # of SingleSymbolLayer

###
# set up a cache for 32x32 symbols (initialized below in load_MapStructure)
var SymbolCache32x32 = nil;

var MapStructure = {
    # Generalized load methods used to load various symbols, layer controllers,...
    loadFile : func(file, name) {
        if (name == nil)
            var name = split("/", file)[-1];
        var code = io.readfile(file);
        var code = call(func compile(code, file), [code], var err=[]);
        if (size(err)) {
            if (substr(err[0], 0, 12) == "Parse error:") { # hack around Nasal feature
                var e = split(" at line ", err[0]);
                if (size(e) == 2)
                err[0] = string.join("", [e[0], "\n  at ", file, ", line ", e[1], "\n "]);
            }
            for (var i = 1; (var c = caller(i)) != nil; i += 1)
            err ~= subvec(c, 2, 2);
            debug.printerror(err);
            return;
        }
        #code=bind(
        call(code, nil, nil, var hash = {});

        # validate
        var url = ' http://wiki.flightgear.org/MapStructure#';
        # TODO: these rules should be extended for all main files lcontroller/scontroller and symbol
        var checks = [
            { extension:'symbol', symbol:'update', type:'func', error:' update() must not be overridden:', id:300},
            # Sorry, this one doesn't work with the new LineSymbol
            #					{ extension:'symbol', symbol:'draw', type:'func', required:1, error:' symbol files need to export a draw()             routine:', id:301},
            # Sorry, this one doesn't work with the new SingleSymbolLayer
            #					{ extension:'lcontroller', symbol:'searchCmd', type:'func', required:1, error:' lcontroller without searchCmd method:', id:100},
        ];


        var makeurl = func(scope, id) url ~ scope ~ ':' ~ id;
        var bailout = func(file, message, scope, id) __die(file~message~"\n"~makeurl(scope,id) );

        var current_ext = split('.', file)[-1];
        foreach(var check; checks) {
            # check if we have any rules matching the current file extension
            if (current_ext == check.extension) {
                # check for fields that must not be overridden
                if (check['error'] != nil and
                    hash[check.symbol]!=nil and !check['required']  and
                    typeof(hash[check.symbol])==check.type ) {
                    bailout(file,check.error,check.extension,check.id);
                }

                # check for required fields
                if (check['required'] != nil and
                    hash[check.symbol]==nil and
                    typeof( hash[check.symbol]) != check.type) {
                    bailout(file,check.error,check.extension,check.id);
                }
            }
        }

        return hash;
    }
};


var load_MapStructure = func {
	canvas.load_MapStructure = func; # disable any subsequent attempt to load

	Map.Controller = {
	# Static/singleton:
		registry: {},
		add: func(type, class)
			me.registry[type] = class,
		get: func(type)
			if ((var class = me.registry[type]) == nil)
				__die("unknown type '"~type~"'");
			else return class,
		# Calls corresonding controller constructor
		# @param map The #SymbolMap this controller is responsible for.
		new: func(type, map, arg...) {
			var m = call((var class = me.get(type)).new, [map]~arg, class);
			if (!contains(m, "map"))
				m.map = map;
			elsif (m.map != map and !isa(m.map, map) and (
			        m.get_position != Map.Controller.get_position
			     or m.query_range != Map.Controller.query_range
			     or m.in_range != Map.Controller.in_range))
			{ __die("m must store the map handle as .map if it uses the default method(s)"); }
		},
	# Default implementations:
		get_position: func() {
			debug.warn("get_position is deprecated");
			return me.map.getLatLon()~[me.map.getAlt()];
		},
		query_range: func() {
			debug.warn("query_range is deprecated");
			return me.map.getRange() or 30;
		},
		in_range: func(lat, lon, alt=0) {
			var range = me.map.getRange();
			if(range == nil) __die("in_range: Invalid query range!");
			# print("Query Range is:", range );
			if (lat == nil or lon == nil) __die("in_range: lat/lon invalid");
			var pos = geo.Coord.new();
			pos.set_latlon(lat, lon, alt or 0);
			var map_pos = me.map.getPosCoord();
			if (map_pos == nil)
				return 0; # should happen *ONLY* when map is uninitialized
			var distance_m = pos.distance_to( map_pos );
			var is_in_range = distance_m < range * NM2M;
			# print("Distance:",distance_m*M2NM," nm in range check result:", is_in_range);
			return is_in_range;
		},
	};

	####### LOAD FILES #######
	(func {
		var FG_ROOT = getprop("/sim/fg-root");

		# sets up a shared symbol cache, which will be used by all MapStructure maps and layers
		canvas.SymbolCache32x32 = SymbolCache.new(1024,32);

		# Find files and load them:
		var contents_dir = FG_ROOT~"/Nasal/canvas/map/";
		var dep_names = [
			# With these extensions, in this order:
			"lcontroller",
			"symbol",
			"scontroller",
			"controller",
		];
		var deps = {};
		foreach (var d; dep_names) deps[d] = [];
		foreach (var f; directory(contents_dir)) {
			var ext = size(var s=split(".", f)) > 1 ? s[-1] : nil;
			foreach (var d; dep_names) {
				if (ext == d) {
					append(deps[d], f);
					break
				}
			}
		}
		foreach (var d; dep_names) {
			foreach (var f; deps[d]) {
				var name = split(".", f)[0];
				MapStructure.loadFile(contents_dir~f, name);
			}
		}
	})();

}; # load_MapStructure

setlistener("/nasal/canvas/loaded", load_MapStructure); # end ugly module init listener hack. FIXME: do smart Nasal bootstrapping, quod est callidus!
# Actually, it would be even better to support reloading MapStructure files, and maybe even MapStructure itself by calling the dtor/del method for each Map and then re-running the ctor
