var gui = {
  widgets: {},
  focused_window: nil,
  region_highlight: nil,

  # Window/dialog stacking order
  STACK_INDEX: {
    "default": 0,
    "always-on-top": 1,
    "tooltip": 2
  }
};

var gui_dir = getprop("/sim/fg-root") ~ "/Nasal/canvas/gui/";
var loadGUIFile = func(file) io.load_nasal(gui_dir ~ file, "canvas");
var loadWidget = func(name) loadGUIFile("widgets/" ~ name ~ ".nas");
var loadDialog = func(name) loadGUIFile("dialogs/" ~ name ~ ".nas");

loadGUIFile("Config.nas");
loadGUIFile("Style.nas");
loadGUIFile("Widget.nas");
loadGUIFile("styles/DefaultStyle.nas");
loadWidget("Button");
loadWidget("CheckBox");
loadWidget("Label");
loadWidget("LineEdit");
loadWidget("ScrollArea");
loadDialog("InputDialog");
loadDialog("MessageBox");

var style = DefaultStyle.new("AmbianceClassic", "Humanity");
var WindowButton = {
  new: func(parent, name)
  {
    var m = {
      parents: [WindowButton, gui.widgets.Button.new(parent, nil, {"flat": 1})],
      _name: name
    };
    m._focus_policy = m.NoFocus;
    m._setView({_root: parent.createChild("image", "WindowButton-" ~ name)});
    return m;
  },
# protected:
  _onStateChange: func
  {
    var file = style._dir_decoration ~ "/" ~ me._name;
    var window_focus = me._windowFocus();
    file ~= window_focus ? "_focused" : "_unfocused";

    if( me._down )
      file ~= "_pressed";
    else if( me._hover )
      file ~= "_prelight";
    else if( window_focus )
      file ~= "_normal";

    me._view._root.set("src", file ~ ".png");
  }
};

var Window = {
  # Constructor
  #
  # @param size ([width, height])
  new: func(size, type = nil, id = nil)
  {
    var ghost = _newWindowGhost(id);
    var m = {
      parents: [Window, PropertyElement, ghost],
      _ghost: ghost,
      _node: props.wrapNode(ghost._node_ghost),
      _focused: 0,
      _widgets: []
    };

    m.setInt("content-size[0]", size[0]);
    m.setInt("content-size[1]", size[1]);

    # TODO better default position
    m.move(0,0);
    m.setFocus();

    # arg = [child, listener_node, mode, is_child_event]
    setlistener(m._node, func m._propCallback(arg[0], arg[2]), 0, 2);
    if( type )
      m.set("type", type);

    return m;
  },
  # Destructor
  del: func
  {
    me.clearFocus();

    if( me["_canvas"] != nil )
    {
      var placements = me._canvas._node.getChildren("placement");
      # Do not remove canvas if other placements exist
      if( size(placements) > 1 )
        foreach(var p; placements)
        {
          if(     p.getValue("type") == "window"
              and p.getValue("id") == me.get("id") )
            p.remove();
        }
      else
        me._canvas.del();
      me._canvas = nil;
    }

    me._node.remove();
    me._node = nil;
  },
  setTitle: func(title)
  {
    return me.set("title", title);
  },
  # Create the canvas to be used for this Window
  #
  # @return The new canvas
  createCanvas: func()
  {
    var size = [
      me.get("content-size[0]"),
      me.get("content-size[1]")
    ];

    me._canvas = new({
      size: [size[0], size[1]],
      view: size,
      placement: {
        type: "window",
        id: me.get("id")
      },

      # Standard alpha blending
      "blend-source-rgb": "src-alpha",
      "blend-destination-rgb": "one-minus-src-alpha",

      # Just keep current alpha (TODO allow using rgb textures instead of rgba?)
      "blend-source-alpha": "zero",
      "blend-destination-alpha": "one"
    });

    me._canvas._focused_widget = nil;
    me._canvas.data("focused", me._focused);
    me._canvas.addEventListener("mousedown", func me.raise());

    return me._canvas;
  },
  # Set an existing canvas to be used for this Window
  setCanvas: func(canvas_)
  {
    if( ghosttype(canvas_) != "Canvas" )
      return debug.warn("Not a Canvas");

    canvas_.addPlacement({type: "window", "id": me.get("id")});
    me['_canvas'] = canvas_;

    canvas_._focused_widget = nil;
    canvas_.data("focused", me._focused);

    # prevent resizing if canvas is placed from somewhere else
    me.onResize = nil;
  },
  # Get the displayed canvas
  getCanvas: func(create = 0)
  {
    if( me['_canvas'] == nil and create )
      me.createCanvas();

    return me['_canvas'];
  },
  getCanvasDecoration: func()
  {
    return wrapCanvas(me._getCanvasDecoration());
  },
  setLayout: func(l)
  {
    if( me['_canvas'] == nil )
      me.createCanvas();

    me._canvas.update(); # Ensure placement is applied
    me._ghost.setLayout(l);
    return me;
  },
  #
  setFocus: func
  {
    if( me._focused )
      return me;

    if( gui.focused_window != nil )
      gui.focused_window.clearFocus();

    me._focused = 1;
#    me.onFocusIn();
    me._onStateChange();
    gui.focused_window = me;
    setInputFocus(me);
    return me;
  },
  #
  clearFocus: func
  {
    if( !me._focused )
      return me;

    me._focused = 0;
#    me.onFocusOut();
    me._onStateChange();
    gui.focused_window = nil;
    setInputFocus(nil);
    return me;
  },
  setPosition: func
  {
    if( size(arg) == 1 )
      var arg = arg[0];
    var (x, y) = arg;

    me.setInt("tf/t[0]", x);
    me.setInt("tf/t[1]", y);
  },
  setSize: func
  {
    if( size(arg) == 1 )
      var arg = arg[0];
    var (w, h) = arg;

    me.set("content-size[0]", w);
    me.set("content-size[1]", h);

    if( me.onResize != nil )
      me.onResize();

    return me;
  },
  move: func
  {
    if( size(arg) == 1 )
      var arg = arg[0];
    var (x, y) = arg;

    me.setInt("tf/t[0]", me.get("tf/t[0]", 10) + x);
    me.setInt("tf/t[1]", me.get("tf/t[1]", 30) + y);
  },
  # Raise to top of window stack
  raise: func()
  {
    # on writing the z-index the window always is moved to the top of all other
    # windows with the same z-index.
    me.setInt("z-index", me.get("z-index", gui.STACK_INDEX["default"]));

    me.setFocus();
  },
  onResize: func()
  {
    if( me['_canvas'] == nil )
      return;

    for(var i = 0; i < 2; i += 1)
    {
      var size = me.get("content-size[" ~ i ~ "]");
      me._canvas.set("size[" ~ i ~ "]", size);
      me._canvas.set("view[" ~ i ~ "]", size);
    }
  },
# protected:
  _onStateChange: func
  {
    var event = canvas.CustomEvent.new("wm.focus-" ~ (me._focused ? "in" : "out"));

    if( me._getCanvasDecoration() != nil )
    {
      # Stronger shadow for focused windows
      me.getCanvasDecoration()
        .set("image[1]/fill", me._focused ? "#000000" : "rgba(0,0,0,0.5)");

      var suffix = me._focused ? "" : "-unfocused";
      me._title_bar_bg.set("fill", style.getColor("title" ~ suffix));
      me._title.set(       "fill", style.getColor("title-text" ~ suffix));
      me._top_line.set(  "stroke", style.getColor("title-highlight" ~ suffix));

      me.getCanvasDecoration()
        .data("focused", me._focused)
        .dispatchEvent(event);
    }

    if( me.getCanvas() != nil )
      me.getCanvas()
        .data("focused", me._focused)
        .dispatchEvent(event);
  },
# private:
  _propCallback: func(child, mode)
  {
    if( !me._node.equals(child.getParent()) )
      return;
    var name = child.getName();

    # support for CSS like position: absolute; with right and/or bottom margin
    if( name == "right" )
      me._handlePositionAbsolute(child, mode, name, 0);
    else if( name == "bottom" )
      me._handlePositionAbsolute(child, mode, name, 1);

    # update decoration on type change
    else if( name == "type" )
    {
      if( mode == 0 )
        settimer(func me._updateDecoration(), 0, 1);
    }

    else if( name.starts_with("resize-") )
    {
      if( mode == 0 )
        me._handleResize(child, name);
    }
    else if( name == "size" )
    {
      if( mode == 0 )
        me._resizeDecoration();
    }
  },
  _handlePositionAbsolute: func(child, mode, name, index)
  {
    # mode
    #   -1 child removed
    #    0 value changed
    #    1 child added

    if( mode == 0 )
      me._updatePos(index, name);
    else if( mode == 1 )
      me["_listener_" ~ name] = [
        setlistener
        (
          "/sim/gui/canvas/size[" ~ index ~ "]",
          func me._updatePos(index, name)
        ),
        setlistener
        (
          me._node.getNode("content-size[" ~ index ~ "]"),
          func me._updatePos(index, name)
        )
      ];
    else if( mode == -1 )
      for(var i = 0; i < 2; i += 1)
        removelistener(me["_listener_" ~ name][i]);
  },
  _updatePos: func(index, name)
  {
    me.setInt
    (
      "tf/t[" ~ index ~ "]",
      getprop("/sim/gui/canvas/size[" ~ index ~ "]")
      - me.get(name)
      - me.get("content-size[" ~ index ~ "]")
    );
  },
  _handleResize: func(child, name)
  {
    var is_status = name == "resize-status";
    if( !is_status and !me["_resize"] )
      return;

    var min_size = [75, 100];

    var x = me.get("tf/t[0]");
    var y = me.get("tf/t[1]");
    var old_size = [me.get("size[0]"), me.get("size[1]")];

    var l = x + math.min(me.get("resize-left"), old_size[0] - min_size[0]);
    var t = y + math.min(me.get("resize-top"), old_size[1] - min_size[1]);
    var r = x + math.max(me.get("resize-right"), min_size[0]);
    var b = y + math.max(me.get("resize-bottom"), min_size[1]);

    if( is_status )
    {
      me._resize = child.getValue();

      if( me._resize and gui.region_highlight == nil )
        gui.region_highlight =
          getDesktop().createChild("path", "highlight")
                      .set("stroke", "#ffa500")
                      .set("stroke-width", 2)
                      .set("fill", "rgba(255, 165, 0, 0.15)")
                      .set("z-index", 100);
      else if( !me._resize and gui.region_highlight != nil )
      {
        gui.region_highlight.hide();
        me.setPosition(l, t);
        me.setSize
        (
          me.get("content-size[0]") + (r - l) - old_size[0],
          me.get("content-size[1]") + (b - t) - old_size[1],
        );
        if( me.onResize != nil )
          me.onResize();
        return;
      }
    }
    else if( !me["_resize"] )
      return;

    gui.region_highlight.reset()
                        .moveTo(l, t)
                        .horizTo(r)
                        .vertTo(b)
                        .horizTo(l)
                        .close()
                        .update()
                        .show();
  },
  _updateDecoration: func()
  {
    var border_radius = 9;
    me.set("decoration-border", "25 1 1");
    me.set("shadow-inset", int((1 - math.cos(45 * D2R)) * border_radius + 0.5));
    me.set("shadow-radius", 5);
    me.setBool("update", 1);

    var canvas_deco = me.getCanvasDecoration();
    canvas_deco.addEventListener("mousedown", func me.raise());
    canvas_deco.set("blend-source-rgb", "src-alpha");
    canvas_deco.set("blend-destination-rgb", "one-minus-src-alpha");
    canvas_deco.set("blend-source-alpha", "one");
    canvas_deco.set("blend-destination-alpha", "one");

    var group_deco = canvas_deco.getGroup("decoration");
    var title_bar = group_deco.createChild("group", "title_bar");
    me._title_bar_bg = title_bar.createChild("path");
    me._top_line = title_bar.createChild("path", "top-line");

    # close icon
    var x = 10;
    var y = 3;
    var w = 19;
    var h = 19;

    var button_close = WindowButton.new(title_bar, "close")
                                   .move(x, y);
    button_close.listen("clicked", func me.del());

    # title
    me._title = title_bar.createChild("text", "title")
                         .set("alignment", "left-center")
                         .set("character-size", 14)
                         .set("font", "LiberationFonts/LiberationSans-Bold.ttf")
                         .setTranslation( int(x + 1.5 * w + 0.5),
                                          int(y + 0.5 * h + 0.5) );

    var title = me.get("title", "Canvas Dialog");
    me._node.getNode("title", 1).alias(me._title._node.getPath() ~ "/text");
    me.set("title", title);

    title_bar.addEventListener("drag", func(e) me.move(e.deltaX, e.deltaY));

    me._resizeDecoration();
    me._onStateChange();
  },
  _resizeDecoration: func()
  {
    if( me["_title_bar_bg"] == nil )
      return;

    var border_radius = 9;
    me._title_bar_bg
        .reset()
        .rect( 0, 0,
               me.get("size[0]"), me.get("size[1]"),
               {"border-top-radius": border_radius} );

    me._top_line
        .reset()
        .moveTo(border_radius - 2, 2)
        .lineTo(me.get("size[0]") - border_radius + 2, 2);
  }
};

# Clear focus on click outside any window
getDesktop().addEventListener("mousedown", func {
  if( gui.focused_window != nil )
    gui.focused_window.clearFocus();
});

# Provide old 'Dialog' for backwards compatiblity (should be removed for 3.0)
var Dialog = {
  new: func(size, type = nil, id = nil)
  {
    debug.warn("'canvas.Dialog' is deprectated! (use canvas.Window instead)");
    return Window.new(size, type, id);
  }
};
