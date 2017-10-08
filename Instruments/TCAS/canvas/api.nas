# Internal helper
var _getColor = func(color)
{
  if( size(color) == 1 )
    var color = color[0];

  if( typeof(color) == 'scalar' )
    return color;
  if( typeof(color) != "vector" )
    return debug.warn("Wrong type for color");

  if( size(color) < 3 or size(color) > 4 )
    return debug.warn("Color needs 3 or 4 values (RGB or RGBA)");

  var str = 'rgb';
  if( size(color) == 4 )
    str ~= 'a';
  str ~= '(';

  # rgb = [0,255], a = [0,1]
  for(var i = 0; i < size(color); i += 1)
    str ~= (i > 0 ? ',' : '') ~ (i < 3 ? int(color[i] * 255) : color[i]);

  return str ~ ')';
};

var _arg2valarray = func
{
  var ret = arg;
  while (    typeof(ret) == "vector"
            and size(ret) == 1 and typeof(ret[0]) == "vector" )
      ret = ret[0];
  return ret;
}

# Transform
# ==============================================================================
# A transformation matrix which is used to transform an #Element on the canvas.
# The dimensions of the matrix are 3x3 where the last row is always 0 0 1:
#
#  a c e
#  b d f
#  0 0 1
#
# See http://www.w3.org/TR/SVG/coords.html#TransformMatrixDefined for details.
#
var Transform = {
  new: func(node, vals = nil)
  {
    var m = {
      parents: [Transform],
      _node: node,
      a: node.getNode("m[0]", 1),
      b: node.getNode("m[1]", 1),
      c: node.getNode("m[2]", 1),
      d: node.getNode("m[3]", 1),
      e: node.getNode("m[4]", 1),
      f: node.getNode("m[5]", 1)
    };

    var use_vals = typeof(vals) == 'vector' and size(vals) == 6;

    # initialize to identity matrix
    m.a.setDoubleValue(use_vals ? vals[0] : 1);
    m.b.setDoubleValue(use_vals ? vals[1] : 0);
    m.c.setDoubleValue(use_vals ? vals[2] : 0);
    m.d.setDoubleValue(use_vals ? vals[3] : 1);
    m.e.setDoubleValue(use_vals ? vals[4] : 0);
    m.f.setDoubleValue(use_vals ? vals[5] : 0);

    return m;
  },
  setTranslation: func
  {
    var trans = _arg2valarray(arg);

    me.e.setDoubleValue(trans[0]);
    me.f.setDoubleValue(trans[1]);

    return me;
  },
  # Set rotation (Optionally around a specified point instead of (0,0))
  #
  #  setRotation(rot)
  #  setRotation(rot, cx, cy)
  #
  # @note If using with rotation center different to (0,0) don't use
  #       #setTranslation as it would interfere with the rotation.
  setRotation: func(angle)
  {
    var center = _arg2valarray(arg);

    var s = math.sin(angle);
    var c = math.cos(angle);

    me.a.setDoubleValue(c);
    me.b.setDoubleValue(s);
    me.c.setDoubleValue(-s);
    me.d.setDoubleValue(c);

    if( size(center) == 2 )
    {
      me.e.setDoubleValue( (-center[0] * c) + (center[1] * s) + center[0] );
      me.f.setDoubleValue( (-center[0] * s) - (center[1] * c) + center[1] );
    }

    return me;
  },
  # Set scale (either as parameters or array)
  #
  # If only one parameter is given its value is used for both x and y
  #  setScale(x, y)
  #  setScale([x, y])
  setScale: func
  {
    var scale = _arg2valarray(arg);

    me.a.setDoubleValue(scale[0]);
    me.d.setDoubleValue(size(scale) >= 2 ? scale[1] : scale[0]);

    return me;
  },
  getScale: func()
  {
    # TODO handle rotation
    return [me.a.getValue(), me.d.getValue()];
  }
};

# Element
# ==============================================================================
# Baseclass for all elements on a canvas
#
var Element = {
  # Reference frames (for "clip" coordinates)
  GLOBAL: 0,
  PARENT: 1,
  LOCAL:  2,

  # Constructor
  #
  # @param ghost  Element ghost as retrieved from core methods
  new: func(ghost)
  {
    return {
      parents: [PropertyElement, Element, ghost],
      _node: props.wrapNode(ghost._node_ghost)
    };
  },
  # Get parent group/element
  getParent: func()
  {
    var parent_ghost = me._getParent();
    if( parent_ghost == nil )
      return nil;

    var type = props.wrapNode(parent_ghost._node_ghost).getName();
    var factory = me._getFactory(type);
    if( factory == nil )
      return parent_ghost;

    return factory(parent_ghost);
  },
  # Get the canvas this element is placed on
  getCanvas: func()
  {
    wrapCanvas(me._getCanvas());
  },
  # Check if elements represent same instance
  #
  # @param el Other Element or element ghost
  equals: func(el)
  {
    return me._node.equals(el._node_ghost);
  },
  # Hide/Show element
  #
  # @param visible  Whether the element should be visible
  setVisible: func(visible = 1)
  {
    me.setBool("visible", visible);
  },
  getVisible: func me.getBool("visible"),
  # Hide element (Shortcut for setVisible(0))
  hide: func me.setVisible(0),
  # Show element (Shortcut for setVisible(1))
  show: func me.setVisible(1),
  # Toggle element visibility
  toggleVisibility: func me.setVisible( !me.getVisible() ),
  #
  setGeoPosition: func(lat, lon)
  {
    me._getTf()._node.getNode("m-geo[4]", 1).setValue("N" ~ lat);
    me._getTf()._node.getNode("m-geo[5]", 1).setValue("E" ~ lon);
    return me;
  },
  # Create a new transformation matrix
  #
  # @param vals Default values (Vector of 6 elements)
  createTransform: func(vals = nil)
  {
    var node = me._node.addChild("tf", 1); # tf[0] is reserved for
                                           # setRotation
    return Transform.new(node, vals);
  },
  # Shortcut for setting translation
  setTranslation: func { me._getTf().setTranslation(arg); return me; },
  # Get translation set with #setTranslation
  getTranslation: func()
  {
    if( me['_tf'] == nil )
      return [0, 0];

    return [me._tf.e.getValue(), me._tf.f.getValue()];
  },
  # Set rotation around transformation center (see #setCenter).
  #
  # @note This replaces the the existing transformation. For additional scale or
  #       translation use additional transforms (see #createTransform).
  setRotation: func(rot)
  {
    if( me['_tf_rot'] == nil )
      # always use the first matrix slot to ensure correct rotation
      # around transformation center.
      # tf-rot-index can be set to change the slot to be used. This is used for
      # example by the SVG parser to apply the rotation after all
      # transformations defined in the SVG file.
      me['_tf_rot'] = Transform.new(
        me._node.getNode("tf[" ~ me.get("tf-rot-index", 0) ~ "]", 1)
      );

    me._tf_rot.setRotation(rot, me.getCenter());
    return me;
  },
  # Shortcut for setting scale
  setScale: func { me._getTf().setScale(arg); return me; },
  # Shortcut for getting scale
  getScale: func me._getTf().getScale(),
  # Set the fill/background/boundingbox color
  #
  # @param color  Vector of 3 or 4 values in [0, 1]
  setColorFill: func me.set('fill', _getColor(arg)),
  getColorFill: func me.get('fill'),
  #
  getTransformedBounds: func me.getTightBoundingBox(),
  # Calculate the transformation center based on bounding box and center-offset
  updateCenter: func
  {
    me.update();
    var bb = me.getTightBoundingBox();

    if( bb[0] > bb[2] or bb[1] > bb[3] )
      return;

    me._setupCenterNodes
    (
      (bb[0] + bb[2]) / 2 + (me.get("center-offset-x") or 0),
      (bb[1] + bb[3]) / 2 + (me.get("center-offset-y") or 0)
    );
    return me;
  },
  # Set transformation center (currently only used for rotation)
  setCenter: func()
  {
    var center = _arg2valarray(arg);
    if( size(center) != 2 )
      return debug.warn("invalid arg");

    me._setupCenterNodes(center[0], center[1]);
    return me;
  },
  # Get transformation center
  getCenter: func()
  {
    var center = [0, 0];
    me._setupCenterNodes();

    if( me._center[0] != nil )
      center[0] = me._center[0].getValue() or 0;
    if( me._center[1] != nil )
      center[1] = me._center[1].getValue() or 0;

    return center;
  },
  # Internal Transform for convenience transform functions
  _getTf: func
  {
    if( me['_tf'] == nil )
      me['_tf'] = me.createTransform();
    return me._tf;
  },
  _setupCenterNodes: func(cx = nil, cy = nil)
  {
    if( me["_center"] == nil )
      me["_center"] = [
        me._node.getNode("center[0]", cx != nil),
        me._node.getNode("center[1]", cy != nil)
      ];

    if( cx != nil )
      me._center[0].setDoubleValue(cx);
    if( cy != nil )
      me._center[1].setDoubleValue(cy);
  }
};

# Group
# ==============================================================================
# Class for a group element on a canvas
#
var Group = {
# public:
  new: func(ghost)
  {
    return { parents: [Group, Element.new(ghost)] };
  },
  # Create a child of given type with specified id.
  # type can be group, text
  createChild: func(type, id = nil)
  {
    var ghost = me._createChild(type, id);
    var factory = me._getFactory(type);
    if( factory == nil )
      return ghost;

    return factory(ghost);
  },
  # Create multiple children of given type
  createChildren: func(type, count)
  {
    var factory = me._getFactory(type);
    if( factory == nil )
      return [];

    var nodes = props._addChildren(me._node._g, [type, count, 0, 0]);
    for(var i = 0; i < count; i += 1)
      nodes[i] = factory( me._getChild(nodes[i]) );

    return nodes;
  },
  # Create a path child drawing a (rounded) rectangle
  #
  # @param x    Position of left border
  # @param y    Position of top border
  # @param w    Width
  # @param h    Height
  # @param cfg  Optional settings (eg. {"border-top-radius": 5})
  rect: func(x, y, w, h, cfg = nil)
  {
    return me.createChild("path").rect(x, y, w, h, cfg);
  },
  # Get a vector of all child elements
  getChildren: func()
  {
    var children = [];

    foreach(var c; me._node.getChildren())
      if( me._isElementNode(c) )
        append(children, me._wrapElement(c));

    return children;
  },
  # Recursively get all children of class specified by first param
  getChildrenOfType: func(type, array = nil){
      var children = array;
      if(children == nil)
          children = [];
      var my_children = me.getChildren();
      if(typeof(type) != 'vector')
          type = [type];
      foreach(var c; my_children){
          foreach(var t; type){
              if(isa(c, t)){
                  append(children, c);
              }
          }
          if(isa(c, canvas.Group)){
              c.getChildrenOfType(type, children);
          }
      }
      return children;
  },
  # Set color to children of type Path and Text. It is possible to optionally
  # specify which types of children should be affected by passing a vector as
  # the last agrument, ie. my_group.setColor(1,1,1,[Path]);
  setColor: func(){
      var color = arg;
      var types = [Path, Text];
      var arg_c = size(color);
      if(arg_c > 1 and typeof(color[-1]) == 'vector'){
          types = color[-1];
          color = subvec(color, 0, arg_c - 1);
      }
      var children = me.getChildrenOfType(types);
      if(typeof(color) == 'vector'){
          var first = color[0];
          if(typeof(first) == 'vector')
              color = first;
      }
      foreach(var c; children)
      c.setColor(color);
  },
  # Get first child with given id (breadth-first search)
  #
  # @note Use with care as it can take several miliseconds (for me eg. ~2ms).
  #       TODO check with new C++ implementation
  getElementById: func(id)
  {
    var ghost = me._getElementById(id);
    if( ghost == nil )
      return nil;

    var node = props.wrapNode(ghost._node_ghost);
    var factory = me._getFactory( node.getName() );
    if( factory == nil )
      return ghost;

    return factory(ghost);
  },
  # Remove all children
  removeAllChildren: func()
  {
    foreach(var type; keys(me._element_factories))
      me._node.removeChildren(type, 0);
    return me;
  },
# private:
  _isElementNode: func(el)
  {
    # element nodes have type NONE and valid element names (those in the factory
    # list)
    return el.getType() == "NONE"
        and me._element_factories[ el.getName() ] != nil;
  },
  _wrapElement: func(node)
  {
    # Create element from existing node
    return me._element_factories[ node.getName() ]( me._getChild(node._g) );
  },
  _getFactory: func(type)
  {
    var factory = me._element_factories[type];

    if( factory == nil )
      debug.dump("canvas.Group.createChild(): unknown type (" ~ type ~ ")");

    return factory;
  }
};

# Map
# ==============================================================================
# Class for a group element on a canvas with possibly geopgraphic positions
# which automatically get projected according to the specified projection.
# Each map consists of an arbitrary number of layers (canvas groups)
#
var Map = {
  df_controller: nil,
  new: func(ghost)
  {
    return { parents: [Map, Group.new(ghost)], layers:{}, controller:nil }.setController();
  },
  del: func()
  {
    #print("canvas.Map.del()");
    if (me.controller != nil)
      me.controller.del(me);
    foreach (var k; keys(me.layers)) {
      me.layers[k].del();
      delete(me.layers, k);
    }
    # call inherited 'del'
    me.parents = subvec(me.parents,1);
    me.del();
  },
  setController: func(controller=nil, arg...)
  {
    if (me.controller != nil) me.controller.del(me);
    if (controller == nil)
      controller = Map.df_controller;
    elsif (typeof(controller) != 'hash')
      controller = Map.Controller.get(controller);
    
    if (controller == nil) {
      me.controller = nil;
    } else {
      if (!isa(controller, Map.Controller))
        die("OOP error: controller needs to inherit from Map.Controller");
      me.controller = call(controller.new, [me]~arg, controller, var err=[]); # try...
      if (size(err)) {
        if (err[0] != "No such member: new") # ... and either catch or rethrow
          die(err[0]);
        else
          me.controller = controller;
      } elsif (me.controller == nil) {
        me.controller = controller;
      } elsif (me.controller != controller and !isa(me.controller, controller))
        die("OOP error: created instance needs to inherit from or be the specific controller class");
    }

    return me;
  },
  addLayer: func(factory, type_arg=nil, priority=nil, style=nil, opts=nil, visible=1)
  {
    if(contains(me.layers, type_arg))
      printlog("warn", "addLayer() warning: overwriting existing layer:", type_arg);

    var options = opts;
    # Argument handling
    if (type_arg != nil) {
      var layer = factory.new(type:type_arg, group:me, map:me, style:style, options:options, visible:visible);
      var type = factory.get(type_arg);
      var key = type_arg;
    } else {
      var layer = factory.new(group:me, map:me, style:style, options:options, visible:visible);
      var type = factory;
      var key = factory.type;
    }
    me.layers[type_arg] = layer;

    if (priority == nil)
      priority = type.df_priority;
    if (priority != nil)
      layer.group.setInt("z-index", priority);

    return layer; # return new layer to caller() so that we can directly work with it, i.e. to register event handlers (panning/zooming)
  },
  getLayer: func(type_arg) me.layers[type_arg],

  setRange: func(range) me.set("range",range),
  getRange: func me.get('range'),

  setPos: func(lat, lon, hdg=nil, range=nil, alt=nil)
  {
    # TODO: also propage setPos events to layers and symbols (e.g. for offset maps)
    me.set("ref-lat", lat);
    me.set("ref-lon", lon);
    if (hdg != nil)
      me.set("hdg", hdg);
    if (range != nil)
      me.setRange(range);
    if (alt != nil)
      me.set("altitude", alt);
  },
  getPos: func
  {
    return [me.get("ref-lat"),
            me.get("ref-lon"),
            me.get("hdg"),
            me.get("range"),
            me.get("altitude")];
  },
  getLat: func me.get("ref-lat"),
  getLon: func me.get("ref-lon"),
  getHdg: func me.get("hdg"),
  getAlt: func me.get("altitude"),
  getRange: func me.get("range"),
  getLatLon: func [me.get("ref-lat"), me.get("ref-lon")],
  # N.B.: This always returns the same geo.Coord object,
  # so its values can and will change at any time (call
  # update() on the coord to ensure it is up-to-date,
  # which basically calls this method again).
  getPosCoord: func
  {
    var (lat, lon) = (me.get("ref-lat"),
                      me.get("ref-lon"));
    var alt = me.get("altitude");
    if (lat == nil or lon == nil) {
      if (contains(me, "coord")) {
        debug.warn("canvas.Map: lost ref-lat and/or ref-lon source");
      }
      return nil;
    }
    if (!contains(me, "coord")) {
      me.coord = geo.Coord.new();
      var m = me;
      me.coord.update = func m.getPosCoord();
    }
    me.coord.set_latlon(lat,lon,alt or 0);
    return me.coord;
  },
  # Update each layer on this Map. Called by
  # me.controller.
  update: func(predicate=nil)
  {
    var t = systime();
    foreach (var l; keys(me.layers)) {
      var layer = me.layers[l];
      # Only update if the predicate allows
      if (predicate == nil or predicate(layer))
        layer.update();
    }
    printlog(_MP_dbg_lvl, "Took "~((systime()-t)*1000)~"ms to update map()");
    me.setBool("update", 1); # update any coordinates that changed, to avoid floating labels etc.
    return me;
  },
};

# Text
# ==============================================================================
# Class for a text element on a canvas
#
var Text = {
  new: func(ghost)
  {
    return { parents: [Text, Element.new(ghost)] };
  },
  # Set the text
  setText: func(text)
  {
    me.set("text", typeof(text) == 'scalar' ? text : "");
  },
  # enable reduced property I/O update function
  enableUpdate: func ()
  {
    me._lasttext = "INIT_BLANK";
    me.updateText = func (text)
    {
      if (text == me._lasttext) {return;}
      me._lasttext = text;
      me.set("text", typeof(text) == 'scalar' ? text : "");
    };
  },
  # reduced property I/O text update template
  updateText: func (text)
  {
    die("updateText() requires enableUpdate() to be called first");
  },
     
  # enable fast setprop-based text writing
  enableFast: func ()
  {
    me._node_path = me._node.getPath()~"/text";
    me.setTextFast = func(text)
    {
      setprop(me._node_path, text);
    };

  },
  # fast, setprop-based text writing template
  setTextFast: func (text)
  {
    die("setTextFast() requires enableFast() to be called first");
  },
  # append text to an existing string
  appendText: func(text)
  {
    me.set("text", (me.get("text") or "") ~ (typeof(text) == 'scalar' ? text : ""));
  },
  # Set alignment
  #
  #  @param align String, one of:
  #   left-top
  #   left-center
  #   left-bottom
  #   center-top
  #   center-center
  #   center-bottom
  #   right-top
  #   right-center
  #   right-bottom
  #   left-baseline
  #   center-baseline
  #   right-baseline
  #   left-bottom-baseline
  #   center-bottom-baseline
  #   right-bottom-baseline
  #
  setAlignment: func(align)
  {
    me.set("alignment", align);
  },
  # Set the font size
  setFontSize: func(size, aspect = 1)
  {
    me.setDouble("character-size", size);
    me.setDouble("character-aspect-ratio", aspect);
  },
  # Set font (by name of font file)
  setFont: func(name)
  {
    me.set("font", name);
  },
  # Enumeration of values for drawing mode:
  TEXT:               0x01, # The text itself
  BOUNDINGBOX:        0x02, # A bounding box (only lines)
  FILLEDBOUNDINGBOX:  0x04, # A filled bounding box
  ALIGNMENT:          0x08, # Draw a marker (cross) at the position of the text
  # Set draw mode. Binary combination of the values above. Since I haven't found
  # a bitwise or we have to use a + instead.
  #
  #  eg. my_text.setDrawMode(Text.TEXT + Text.BOUNDINGBOX);
  setDrawMode: func(mode)
  {
    me.setInt("draw-mode", mode);
  },
  # Set bounding box padding
  setPadding: func(pad)
  {
    me.setDouble("padding", pad);
  },
  setMaxWidth: func(w)
  {
    me.setDouble("max-width", w);
  },
  setColor: func me.set('fill', _getColor(arg)),
  getColor: func me.get('fill'),

  setColorFill: func me.set('background', _getColor(arg)),
  getColorFill: func me.get('background'),
};

# Path
# ==============================================================================
# Class for an (OpenVG) path element on a canvas
#
var Path = {
  # Path segment commands (VGPathCommand)
  VG_CLOSE_PATH:     0,
  VG_MOVE_TO:        2,
  VG_MOVE_TO_ABS:    2,
  VG_MOVE_TO_REL:    3,
  VG_LINE_TO:        4,
  VG_LINE_TO_ABS:    4,
  VG_LINE_TO_REL:    5,
  VG_HLINE_TO:       6,
  VG_HLINE_TO_ABS:   6,
  VG_HLINE_TO_REL:   7,
  VG_VLINE_TO:       8,
  VG_VLINE_TO_ABS:   8,
  VG_VLINE_TO_REL:   9,
  VG_QUAD_TO:       10,
  VG_QUAD_TO_ABS:   10,
  VG_QUAD_TO_REL:   11,
  VG_CUBIC_TO:      12,
  VG_CUBIC_TO_ABS:  12,
  VG_CUBIC_TO_REL:  13,
  VG_SQUAD_TO:      14,
  VG_SQUAD_TO_ABS:  14,
  VG_SQUAD_TO_REL:  15,
  VG_SCUBIC_TO:     16,
  VG_SCUBIC_TO_ABS: 16,
  VG_SCUBIC_TO_REL: 17,
  VG_SCCWARC_TO:    20, # Note that CC and CCW commands are swapped. This is
  VG_SCCWARC_TO_ABS:20, # needed  due to the different coordinate systems used.
  VG_SCCWARC_TO_REL:21, # In OpenVG values along the y-axis increase from bottom
  VG_SCWARC_TO:     18, # to top, whereas in the Canvas system it is flipped.
  VG_SCWARC_TO_ABS: 18,
  VG_SCWARC_TO_REL: 19,
  VG_LCCWARC_TO:    24,
  VG_LCCWARC_TO_ABS:24,
  VG_LCCWARC_TO_REL:25,
  VG_LCWARC_TO:     22,
  VG_LCWARC_TO_ABS: 22,
  VG_LCWARC_TO_REL: 23,

  # Number of coordinates per command
  num_coords: [
    0, 0, # VG_CLOSE_PATH
    2, 2, # VG_MOVE_TO
    2, 2, # VG_LINE_TO
    1, 1, # VG_HLINE_TO
    1, 1, # VG_VLINE_TO
    4, 4, # VG_QUAD_TO
    6, 6, # VG_CUBIC_TO
    2, 2, # VG_SQUAD_TO
    4, 4, # VG_SCUBIC_TO
    5, 5, # VG_SCCWARC_TO
    5, 5, # VG_SCWARC_TO
    5, 5, # VG_LCCWARC_TO
    5, 5  # VG_LCWARC_TO
  ],

  #
  new: func(ghost)
  {
    return {
      parents: [Path, Element.new(ghost)],
      _first_cmd: 0,
      _first_coord: 0,
      _last_cmd: -1,
      _last_coord: -1
    };
  },
  # Remove all existing path data
  reset: func
  {
    me._node.removeChildren('cmd', 0);
    me._node.removeChildren('coord', 0);
    me._node.removeChildren('coord-geo', 0);
    me._first_cmd = 0;
    me._first_coord = 0;
    me._last_cmd = -1;
    me._last_coord = -1;
    return me;
  },
  # Set the path data (commands and coordinates)
  setData: func(cmds, coords)
  {
    me.reset();
    me._node.setValues({cmd: cmds, coord: coords});
    me._last_cmd = size(cmds) - 1;
    me._last_coord = size(coords) - 1;
    return me;
  },
  setDataGeo: func(cmds, coords)
  {
    me.reset();
    me._node.setValues({cmd: cmds, 'coord-geo': coords});
    me._last_cmd = size(cmds) - 1;
    me._last_coord = size(coords) - 1;
    return me;
  },
  # Add a path segment
  addSegment: func(cmd, coords...)
  {
    var coords = _arg2valarray(coords);
    var num_coords = me.num_coords[cmd];
    if( size(coords) != num_coords )
      debug.warn
      (
        "Invalid number of arguments (expected " ~ num_coords ~ ")"
      );
    else
    {
      me.setInt("cmd[" ~ (me._last_cmd += 1) ~ "]", cmd);
      for(var i = 0; i < num_coords; i += 1)
        me.setDouble("coord[" ~ (me._last_coord += 1) ~ "]", coords[i]);
    }

    return me;
  },
  addSegmentGeo: func(cmd, coords...)
  {
    var coords = _arg2valarray(coords);
    var num_coords = me.num_coords[cmd];
    if( size(coords) != num_coords )
      debug.warn
      (
        "Invalid number of arguments (expected " ~ num_coords ~ ")"
      );
    else
    {
      me.setInt("cmd[" ~ (me._last_cmd += 1) ~ "]", cmd);
      for(var i = 0; i < num_coords; i += 1)
        me.set("coord-geo[" ~ (me._last_coord += 1) ~ "]", coords[i]);
    }

    return me;
  },
  # Remove first segment
  pop_front: func me._removeSegment(1),
  # Remove last segment
  pop_back: func me._removeSegment(0),
  # Get the number of segments
  getNumSegments: func()
  {
    return me._last_cmd - me._first_cmd + 1;
  },
  # Get the number of coordinates (each command has 0..n coords)
  getNumCoords: func()
  {
    return me._last_coord - me._first_coord + 1;
  },
  # Move path cursor
  moveTo: func me.addSegment(me.VG_MOVE_TO_ABS, arg),
  move:   func me.addSegment(me.VG_MOVE_TO_REL, arg),
  # Add a line
  lineTo: func me.addSegment(me.VG_LINE_TO_ABS, arg),
  line:   func me.addSegment(me.VG_LINE_TO_REL, arg),
  # Add a horizontal line
  horizTo: func me.addSegment(me.VG_HLINE_TO_ABS, arg),
  horiz:   func me.addSegment(me.VG_HLINE_TO_REL, arg),
  # Add a vertical line
  vertTo: func me.addSegment(me.VG_VLINE_TO_ABS, arg),
  vert:   func me.addSegment(me.VG_VLINE_TO_REL, arg),
  # Add a quadratic Bézier curve
  quadTo: func me.addSegment(me.VG_QUAD_TO_ABS, arg),
  quad:   func me.addSegment(me.VG_QUAD_TO_REL, arg),
  # Add a cubic Bézier curve
  cubicTo: func me.addSegment(me.VG_CUBIC_TO_ABS, arg),
  cubic:   func me.addSegment(me.VG_CUBIC_TO_REL, arg),
  # Add a smooth quadratic Bézier curve
  squadTo: func me.addSegment(me.VG_SQUAD_TO_ABS, arg),
  squad:   func me.addSegment(me.VG_SQUAD_TO_REL, arg),
  # Add a smooth cubic Bézier curve
  scubicTo: func me.addSegment(me.VG_SCUBIC_TO_ABS, arg),
  scubic:   func me.addSegment(me.VG_SCUBIC_TO_REL, arg),
  # Draw an elliptical arc (shorter counter-clockwise arc)
  arcSmallCCWTo: func me.addSegment(me.VG_SCCWARC_TO_ABS, arg),
  arcSmallCCW:   func me.addSegment(me.VG_SCCWARC_TO_REL, arg),
  # Draw an elliptical arc (shorter clockwise arc)
  arcSmallCWTo: func me.addSegment(me.VG_SCWARC_TO_ABS, arg),
  arcSmallCW:   func me.addSegment(me.VG_SCWARC_TO_REL, arg),
  # Draw an elliptical arc (longer counter-clockwise arc)
  arcLargeCCWTo: func me.addSegment(me.VG_LCCWARC_TO_ABS, arg),
  arcLargeCCW:   func me.addSegment(me.VG_LCCWARC_TO_REL, arg),
  # Draw an elliptical arc (shorter clockwise arc)
  arcLargeCWTo: func me.addSegment(me.VG_LCWARC_TO_ABS, arg),
  arcLargeCW:   func me.addSegment(me.VG_LCWARC_TO_REL, arg),
  # Close the path (implicit lineTo to first point of path)
  close: func me.addSegment(me.VG_CLOSE_PATH),

  # Add a (rounded) rectangle to the path
  #
  # @param x    Position of left border
  # @param y    Position of top border
  # @param w    Width
  # @param h    Height
  # @param cfg  Optional settings (eg. {"border-top-radius": 5})
  rect: func(x, y, w, h, cfg = nil)
  {
    var opts = (cfg != nil) ? cfg : {};

    # resolve border-[top-,bottom-][left-,right-]radius
    var br = opts["border-radius"];
    if( typeof(br) == 'scalar' )
      br = [br, br];

    var _parseRadius = func(id)
    {
      if( (var r = opts["border-" ~ id ~ "-radius"]) == nil )
      {
        # parse top, bottom, left, right separate if no value specified for
        # single corner
        foreach(var s; ["top", "bottom", "left", "right"])
        {
          if( id.starts_with(s ~ "-") )
          {
            r = opts["border-" ~ s ~ "-radius"];
            break;
          }
        }
      }

      if( r == nil )
        return br;
      else if( typeof(r) == 'scalar' )
        return [r, r];
      else
        return r;
    };

    # top-left
    if( (var r = _parseRadius("top-left")) != nil )
    {
      me.moveTo(x, y + r[1])
        .arcSmallCWTo(r[0], r[1], 0, x + r[0], y);
    }
    else
      me.moveTo(x, y);

    # top-right
    if( (r = _parseRadius("top-right")) != nil )
    {
      me.horizTo(x + w - r[0])
        .arcSmallCWTo(r[0], r[1], 0, x + w, y + r[1]);
    }
    else
      me.horizTo(x + w);

    # bottom-right
    if( (r = _parseRadius("bottom-right")) != nil )
    {
      me.vertTo(y + h - r[1])
        .arcSmallCWTo(r[0], r[1], 0, x + w - r[0], y + h);
    }
    else
      me.vertTo(y + h);

    # bottom-left
    if( (r = _parseRadius("bottom-left")) != nil )
    {
      me.horizTo(x + r[0])
        .arcSmallCWTo(r[0], r[1], 0, x, y + h - r[1]);
    }
    else
      me.horizTo(x);

    return me.close();
  },

  setColor: func me.setStroke(_getColor(arg)),
  getColor: func me.getStroke(), 

  setColorFill: func me.setFill(_getColor(arg)),
  getColorFill: func me.getColorFill(),
  setFill: func(fill)
  {
    me.set('fill', fill);
  },
  setStroke: func(stroke)
  {
    me.set('stroke', stroke);
  },
  getStroke: func me.get('stroke'),

  setStrokeLineWidth: func(width)
  {
    me.setDouble('stroke-width', width);
  },
  # Set stroke linecap
  #
  # @param linecap String, "butt", "round" or "square"
  #
  # See http://www.w3.org/TR/SVG/painting.html#StrokeLinecapProperty for details
  setStrokeLineCap: func(linecap)
  {
    me.set('stroke-linecap', linecap);
  },
  # Set stroke linejoin
  #
  # @param linejoin String, "miter", "round" or "bevel"
  #
  # See http://www.w3.org/TR/SVG/painting.html#StrokeLinejoinProperty for details
  setStrokeLineJoin: func(linejoin)
  {
    me.set('stroke-linejoin', linejoin);
  },
  # Set stroke dasharray
  # Set stroke dasharray
  #
  # @param pattern Vector, Vector of alternating dash and gap lengths
  #  [on1, off1, on2, ...]
  setStrokeDashArray: func(pattern)
  {
    if( typeof(pattern) == 'vector' )
      me.set('stroke-dasharray', string.join(',', pattern));
    else
      debug.warn("setStrokeDashArray: vector expected!");

    return me;
  },

# private:
  _removeSegment: func(front)
  {
    if( me.getNumSegments() < 1 )
    {
      debug.warn("No segment available");
      return me;
    }

    var cmd = front ? me._first_cmd : me._last_cmd;
    var num_coords = me.num_coords[ me.get("cmd[" ~ cmd ~ "]") ];
    if( me.getNumCoords() < num_coords )
    {
      debug.warn("To few coords available");
    }

    me._node.removeChild("cmd", cmd);

    var first_coord = front ? me._first_coord : me._last_coord - num_coords + 1;
    for(var i = 0; i < num_coords; i += 1)
      me._node.removeChild("coord", first_coord + i);

    if( front )
    {
      me._first_cmd += 1;
      me._first_coord += num_coords;
    }
    else
    {
      me._last_cmd -= 1;
      me._last_coord -= num_coords;
    }

    return me;
  },
};

# Image
# ==============================================================================
# Class for an image element on a canvas
#
var Image = {
  new: func(ghost)
  {
    return {parents: [Image, Element.new(ghost)]};
  },
  # Set image file to be used
  #
  # @param file Path to file or canvas (Use canvas://... for canvas, eg.
  #             canvas://by-index/texture[0])
  setFile: func(file)
  {
    me.set("src", file);
  },
  # Set rectangular region of source image to be used
  #
  # @param left   Rectangle minimum x coordinate
  # @param top    Rectangle minimum y coordinate
  # @param right  Rectangle maximum x coordinate
  # @param bottom Rectangle maximum y coordinate
  # @param normalized Whether to use normalized ([0,1]) or image
  #                   ([0, image_width]/[0, image_height]) coordinates
  setSourceRect: func
  {
    # Work with both positional arguments and named arguments.
    # Support first argument being a vector instead of four separate ones.
    if (size(arg) == 1)
      arg = arg[0];
    elsif (size(arg) and size(arg) < 4 and typeof(arg[0]) == 'vector')
      arg = arg[0]~arg[1:];
    if (!contains(caller(0)[0], "normalized")) {
      if (size(arg) > 4)
        var normalized = arg[4];
      else var normalized = 1;
    }
    if (size(arg) >= 3)
      var (left,top,right,bottom) = arg;

    me._node.getNode("source", 1).setValues({
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      normalized: normalized
    });
    return me;
  },
  # Set size of image element
  #
  # @param width
  # @param height
  # - or -
  # @param size ([width, height])
  setSize: func
  {
    me._node.setValues({size: _arg2valarray(arg)});
    return me;
  }
};

# Element factories used by #Group elements to create children
Group._element_factories = {
  "group": Group.new,
  "map": Map.new,
  "text": Text.new,
  "path": Path.new,
  "image": Image.new
};

# Canvas
# ==============================================================================
# Class for a canvas
#
var Canvas = {
  # Place this canvas somewhere onto the object. Pass criterions for placement
  # as a hash, eg:
  #
  #  my_canvas.addPlacement({
  #    "texture": "EICAS.png",
  #    "node": "PFD-Screen",
  #    "parent": "Some parent name"
  #  });
  #
  # Note that we can choose whichever of the three filter criterions we use for
  # matching the target object for our placement. If none of the three fields is
  # given every texture of the model will be replaced.
  addPlacement: func(vals)
  {
    var placement = me._node.addChild("placement", 0, 0);
    placement.setValues(vals);
    return placement;
  },
  # Create a new group with the given name
  #
  # @param id Optional id/name for the group
  createGroup: func(id = nil)
  {
    return Group.new(me._createGroup(id));
  },
  # Get the group with the given name
  getGroup: func(id)
  {
    return Group.new(me._getGroup(id));
  },
  # Set the background color
  #
  # @param color  Vector of 3 or 4 values in [0, 1]
  setColorBackground: func me.set('background', _getColor(arg)),
  getColorBackground: func me.get('background'),
  # Get path of canvas to be used eg. in Image::setFile
  getPath: func()
  {
    return "canvas://by-index/texture[" ~ me._node.getIndex() ~ "]";
  },
  # Destructor
  #
  # releases associated canvas and makes this object unusable
  del: func
  {
    me._node.remove();
    me.parents = nil; # ensure all ghosts get destroyed
  }
};

# @param g Canvas ghost
var wrapCanvas = func(g)
{
  if( g != nil and g._impl == nil )
    g._impl = {
      parents: [PropertyElement, Canvas],
      _node: props.wrapNode(g._node_ghost)
    };
  return g;
}

# Create a new canvas. Pass parameters as hash, eg:
#
#  var my_canvas = canvas.new({
#    "name": "PFD-Test",
#    "size": [512, 512],
#    "view": [768, 1024],
#    "mipmapping": 1
#  });
var new = func(vals)
{
  var m = wrapCanvas(_newCanvasGhost());
  m._node.setValues(vals);
  return m;
};

# Get the first existing canvas with the given name
#
# @param name Name of the canvas
# @return #Canvas, if canvas with #name exists
#         nil, otherwise
var get = func(arg)
{
  if( isa(arg, props.Node) )
    var node = arg;
  else if( typeof(arg) == "hash" )
    var node = props.Node.new(arg);
  else
    die("canvas.new: Invalid argument.");

  return wrapCanvas(_getCanvasGhost(node._g));
};

var getDesktop = func()
{
  return Group.new(_getDesktopGhost());
};
