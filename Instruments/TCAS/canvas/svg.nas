# Parse an xml file into a canvas group element
#
# @param group    The canvas.Group instance to append the parsed elements to
# @param path     The path of the svg file (absolute or relative to FG_ROOT)
# @param options  Optional hash of options
var parsesvg = func(group, path, options = nil)
{
  if( !isa(group, Group) )
    die("Invalid argument group (type != Group)");

  if( options == nil )
    options = {};

  if( typeof(options) != "hash" )
    die("Options need to be of type hash!");

  # resolve paths using standard SimGear logic
  var file_path = resolvepath(path);
  if (file_path == "")
    die("File not found: "~path);
  path = file_path;

  var _printlog = printlog;
  var printlog = func(level, msg)
  {
    _printlog(level, "parsesvg: " ~ msg ~ " [path='" ~ path ~ "']");
  };

  var custom_font_mapper = options['font-mapper'];
  var font_mapper = func(family, weight, style)
  {
    if( typeof(custom_font_mapper) == 'func' )
    {
      var font = custom_font_mapper(family, weight, style);
      if( font != nil )
        return font;
    }

    if( string.match(family,"Liberation*") ) {
      style = style == "italic" ? "Italic" : "";
      weight = weight == "bold" ? "Bold" : "";

      var s = weight ~ style;
      if( s == "" ) s = "Regular";

      return "LiberationFonts/" ~ string.replace(family," ", "") ~ "-" ~ s ~ ".ttf";
    }


    return "LiberationFonts/LiberationMono-Bold.ttf";
  };

  # Helper to get number without unit (eg. px)
  var evalCSSNum = func(css_num)
  {
    if( css_num.ends_with("px") )
      return substr(css_num, 0, size(css_num) - 2);
    else if( css_num.ends_with("%") )
      return substr(css_num, 0, size(css_num) - 1) / 100;

    return css_num;
  }

  var level = 0;
  var skip  = 0;
  var stack = [group];
  var close_stack = []; # helper for check tag closing

  var defs_stack = [];

  var text = nil;
  var tspans = nil;

  # lookup table for element ids (for <use> element)
  var id_dict = {};

  # lookup table for mask and clipPath element ids
  var clip_dict = {};
  var cur_clip = nil;

  # ----------------------------------------------------------------------------
  # Create a new child an push it onto the stack
  var pushElement = func(type, id = nil)
  {
    append(stack, stack[-1].createChild(type, id));
    append(close_stack, level);

    if( typeof(id) == 'scalar' and size(id) )
      id_dict[ id ] = stack[-1];

    if( cur_clip != nil )
    {
      if(     cur_clip['x'] != nil
          and cur_clip['y'] != nil
          and cur_clip['width'] != nil
          and cur_clip['height'] != nil )
      {
        var rect = sprintf(
          "rect(%f, %f, %f, %f)",
          cur_clip['y'],
          cur_clip['x'] + cur_clip['width'],
          cur_clip['y'] + cur_clip['height'],
          cur_clip['x']
        );

        stack[-1].set("clip", rect);
        stack[-1].set("clip-frame", canvas.Element.LOCAL);
      }
      else
        printlog(
          "warn",
          "Invalid or unsupported clip for element '" ~ id ~ "'"
        );

      cur_clip = nil;
    }
  }

  # ----------------------------------------------------------------------------
  # Remove the topmost element from the stack
  var popElement = func
  {
    stack[-1].updateCenter();
    # Create rotation matrix after all SVG defined transformations
    stack[-1].set("tf-rot-index", stack[-1].createTransform()._node.getIndex());

    pop(stack);
    pop(close_stack);
  }

  # ----------------------------------------------------------------------------
  # Parse a transformation (matrix)
  # http://www.w3.org/TR/SVG/coords.html#TransformAttribute
  var parseTransform = func(tf)
  {
    if( tf == nil )
      return;

    var end = 0;
    while(1)
    {
      var start_type = tf.find_first_not_of("\t\n ", end);
      if( start_type < 0 )
        break;

      var end_type = tf.find_first_of("(\t\n ", start_type + 1);
      if( end_type < 0 )
        break;

      var start_args = tf.find('(', end_type);
      if( start_args < 0 )
        break;

      var values = [];
      end = start_args + 1;
      while(1)
      {
        var start_num = tf.find_first_not_of(",\t\n ", end);
        if( start_num < 0 )
          break;
        if( tf[start_num] == `)` )
          break;

        end = tf.find_first_of("),\t\n ", start_num + 1);
        if( end < 0 )
          break;
        append(values, substr(tf, start_num, end - start_num));
      }

      if( end > 0 )
        end += 1;

      var type = substr(tf, start_type, end_type - start_type);

      # TODO should we warn if to much/wrong number of arguments given?
      if( type == "translate" )
      {
        # translate(<tx> [<ty>]), which specifies a translation by tx and ty. If
        # <ty> is not provided, it is assumed to be zero.
        stack[-1].createTransform().setTranslation
        (
          values[0],
          size(values) > 1 ? values[1] : 0,
        );
      }
      else if( type == "scale" )
      {
        # scale(<sx> [<sy>]), which specifies a scale operation by sx and sy. If
        # <sy> is not provided, it is assumed to be equal to <sx>.
        stack[-1].createTransform().setScale(values);
      }
      else if( type == "rotate" )
      {
        # rotate(<rotate-angle> [<cx> <cy>]), which specifies a rotation by
        # <rotate-angle> degrees about a given point.
        stack[-1].createTransform().setRotation
        (
          values[0] * D2R, # internal functions use rad
          size(values) > 1 ? values[1:] : nil
        );
      }
      else if( type == "matrix" )
      {
        if( size(values) == 6 )
          stack[-1].createTransform(values);
        else
          printlog(
            "warn",
            "Invalid arguments to matrix transform: " ~ debug.string(values, 0)
          );
      }
      else
        printlog("warn", "Unknown transform type: '" ~ type ~ "'");
    }
  };

  # ----------------------------------------------------------------------------
  # Parse a path
  # http://www.w3.org/TR/SVG/paths.html#PathData

  # map svg commands OpenVG commands
  var cmd_map = {
    z: Path.VG_CLOSE_PATH,
    m: Path.VG_MOVE_TO,
    l: Path.VG_LINE_TO,
    h: Path.VG_HLINE_TO,
    v: Path.VG_VLINE_TO,
    q: Path.VG_QUAD_TO,
    c: Path.VG_CUBIC_TO,
    t: Path.VG_SQUAD_TO,
    s: Path.VG_SCUBIC_TO
  };

  var parsePath = func(path_data)
  {
    if( path_data == nil )
      return;

    var pos = 0;
    var cmds = [];
    var coords = [];

    while(1)
    {
      # skip trailing spaces
      pos = path_data.find_first_not_of("\t\n ", pos);
      if( pos < 0 )
        break;

      # get command
      var cmd = substr(path_data, pos, 1);
      pos += 1;

      # and get all following arguments
      var args = [];
      while(1)
      {
        pos = path_data.find_first_not_of(",\t\n ", pos);
        if( pos < 0 )
          break;

        var start_num = pos;
        pos = path_data.find_first_not_of("e-.0123456789", start_num);
        if( start_num == pos )
          break;

        append(args, substr( path_data,
                             start_num,
                             pos > 0 ? pos - start_num : nil ));
      }

      # now execute the command
      var rel = string.islower(cmd[0]);
      var cmd = string.lc(cmd);
      if( cmd == 'a' )
      {
        for(var i = 0; i + 7 <= size(args); i += 7)
        {
          # SVG: (rx ry x-axis-rotation large-arc-flag sweep-flag x y)+
          # OpenVG: rh,rv,rot,x0,y0
          if( args[i + 3] )
            var cmd_vg = args[i + 4] ? Path.VG_LCCWARC_TO : Path.VG_LCWARC_TO;
          else
            var cmd_vg = args[i + 4] ? Path.VG_SCCWARC_TO : Path.VG_SCWARC_TO;
          append(cmds, rel ? cmd_vg + 1: cmd_vg);
          append(coords, args[i],
                         args[i + 1],
                         args[i + 2],
                         args[i + 5],
                         args[i + 6] );
        }

        if( math.mod(size(args), 7) > 0 )
          printlog(
            "warn",
            "Invalid number of coords for cmd 'a' "
            ~ "(" ~ size(args) ~ " mod 7 != 0)"
          );
      }
      else
      {
        var cmd_vg = cmd_map[cmd];
        if( cmd_vg == nil )
        {
          printlog("warn", "command not found: '" ~ cmd ~ "'");
          continue;
        }

        var num_coords = Path.num_coords[int(cmd_vg)];
        if( num_coords == 0 )
          append(cmds, cmd_vg);
        else
        {
          for(var i = 0; i + num_coords <= size(args); i += num_coords)
          {
            append(cmds, rel ? cmd_vg + 1: cmd_vg);
            for(var j = i; j < i + num_coords; j += 1)
              append(coords, args[j]);

            # If a moveto is followed by multiple pairs of coordinates, the
            # subsequent pairs are treated as implicit lineto commands.
            if( cmd == 'm' )
              cmd_vg = cmd_map['l'];
          }

          if( math.mod(size(args), num_coords) > 0 )
            printlog(
              "warn",
              "Invalid number of coords for cmd '" ~ cmd ~ "' "
              ~ "(" ~ size(args) ~ " mod " ~ num_coords ~ " != 0)"
            );
        }
      }
    }

    stack[-1].setData(cmds, coords);
  };

  # ----------------------------------------------------------------------------
  # Parse text styles (and apply them to the topmost element)
  var parseTextStyles = func(style)
  {
    # http://www.w3.org/TR/SVG/text.html#TextAnchorProperty
    var h_align = style["text-anchor"];
    if( h_align != nil )
    {
      if( h_align == "end" )
        h_align = "right";
      else if( h_align == "middle" )
        h_align = "center";
      else # "start"
        h_align = "left";
      stack[-1].set("alignment", h_align ~ "-baseline");
    }
    # TODO vertical align

    var fill = style['fill'];
    if( fill != nil )
      stack[-1].set("fill", fill);

    var font_family = style["font-family"];
    var font_weight = style["font-weight"];
    var font_style = style["font-style"];
    if( font_family != nil or font_weight != nil or font_style != nil )
      stack[-1].set("font", font_mapper(font_family, font_weight, font_style));

    var font_size = style["font-size"];
    if( font_size != nil )
      stack[-1].setDouble("character-size", evalCSSNum(font_size));

    var line_height = style["line-height"];
    if( line_height != nil )
      stack[-1].setDouble("line-height", evalCSSNum(line_height));
  }

  # ----------------------------------------------------------------------------
  # Parse a css style attribute
  var parseStyle = func(style)
  {
    if( style == nil )
      return {};

    var styles = {};
    foreach(var part; split(';', style))
    {
      if( !size(part = string.trim(part)) )
        continue;
      if( size(part = split(':',part)) != 2 )
        continue;

      var key = string.trim(part[0]);
      if( !size(key) )
        continue;

      var value = string.trim(part[1]);
      if( !size(value) )
        continue;

      styles[key] = value;
    }

    return styles;
  }

  # ----------------------------------------------------------------------------
  # Parse a css color
  var parseColor = func(s)
  {
    var color = [0, 0, 0];
    if( s == nil )
      return color;

    if( size(s) == 7 and substr(s, 0, 1) == '#' )
    {
      return [ std.stoul(substr(s, 1, 2), 16) / 255,
                std.stoul(substr(s, 3, 2), 16) / 255,
                std.stoul(substr(s, 5, 2), 16) / 255 ];
    }

    return color;
  };

  # ----------------------------------------------------------------------------
  # XML parsers element open callback
  var start = func(name, attr)
  {
    level += 1;

    if( skip )
      return;

    if( level == 1 )
    {
      if( name != 'svg' )
        die("Not an svg file (root=" ~ name ~ ")");
      else
        return;
    }

    if( size(defs_stack) > 0 )
    {
      if( name == "mask" or name == "clipPath" )
      {
        append(defs_stack, {'type': name, 'id': attr['id']});
      }
      else if( name == "rect" )
      {
        foreach(var p; ["x", "y", "width", "height"])
          defs_stack[-1][p] = evalCSSNum(attr[p]);
        skip = level;
      }
      else
      {
        printlog("info", "Skipping unknown element in <defs>: <" ~ name ~ ">");
        skip = level;
      }
      return;
    }

    var style = parseStyle(attr['style']);

    var clip_id = attr['clip-path'] or attr['mask'];
    if( clip_id != nil and clip_id != "none" )
    {
      if(     clip_id.starts_with("url(#")
          and clip_id[-1] == `)` )
        clip_id = substr(clip_id, 5, size(clip_id) - 5 - 1);

      cur_clip = clip_dict[clip_id];
      if( cur_clip == nil )
        printlog("warn", "Clip not found: '" ~ clip_id ~ "'");
    }

    if( style['display'] == 'none' )
    {
      skip = level;
      return;
    }
    else if( name == "g" )
    {
      pushElement('group', attr['id']);
    }
    else if( name == "text" )
    {
      text = {
        "attr": attr,
        "style": style,
        "text": ""
      };
      tspans = [];
      return;
    }
    else if( name == "tspan" )
    {
      append(tspans, {
        "attr": attr,
        "style": style,
        "text": ""
      });
      return;
    }
    else if( name == "path" or name == "rect" )
    {
      pushElement('path', attr['id']);

      if( name == "rect" )
      {
        var width = evalCSSNum(attr['width']);
        var height = evalCSSNum(attr['height']);
        var x = evalCSSNum(attr['x']);
        var y = evalCSSNum(attr['y']);
        var rx = attr['rx'];
        var ry = attr['ry'];

        if( ry == nil )
          ry = rx;
        else if( rx == nil )
          rx = ry;

        var cfg = {};
        if( rx != nil )
          cfg["border-radius"] = [evalCSSNum(rx), evalCSSNum(ry)];

        stack[-1].rect(x, y, width, height, cfg);
      }
      else
        parsePath(attr['d']);
      
      var fillOpacity = style['fill-opacity'];
      if( fillOpacity != nil)
        stack[-1].set('fill', style['fill'] ~ sprintf("%02x", int(style['fill-opacity']*255)));
      else
        stack[-1].set('fill', style['fill']);

      var w = style['stroke-width'];
      stack[-1].setStrokeLineWidth( w != nil ? evalCSSNum(w) : 1 );
      
      var strokeOpacity = style['stroke-opacity'];
      if(strokeOpacity != nil)
        stack[-1].set('stroke', (style['stroke']  ~ sprintf("%02x", int(style['stroke-opacity']*255))));
      else
        stack[-1].set('stroke', style['stroke'] or "none");
      
      var linecap = style['stroke-linecap'];
      if( linecap != nil )
        stack[-1].setStrokeLineCap(style['stroke-linecap']);

      var linejoin = style['stroke-linejoin'];
      if( linejoin != nil )
        stack[-1].setStrokeLineJoin(style['stroke-linejoin']);


      # http://www.w3.org/TR/SVG/painting.html#StrokeDasharrayProperty
      var dash = style['stroke-dasharray'];
      if( dash and size(dash) > 3 )
        # at least 2 comma separated values...
        stack[-1].setStrokeDashArray(split(',', dash));
    }
    else if( name == "use" )
    {
      var ref = attr["xlink:href"];
      if( ref == nil or size(ref) < 2 or ref[0] != `#` )
        return printlog("warn", "Invalid or missing href: '" ~ ref ~ '"');

      var el_src = id_dict[ substr(ref, 1) ];
      if( el_src == nil )
        return printlog("warn", "Reference to unknown element '" ~ ref ~ "'");

      # Create new element and copy sub branch from source node
      pushElement(el_src._node.getName(), attr['id']);
      props.copy(el_src._node, stack[-1]._node);

      # copying also overrides the id so we need to set it again
      stack[-1]._node.getNode("id").setValue(attr['id']);
    }
    else if( name == "defs" )
    {
      append(defs_stack, "defs");
      return;
    }
    else
    {
      printlog("info", "Skipping unknown element '" ~ name ~ "'");
      skip = level;
      return;
    }

    parseTransform(attr['transform']);

    var cx = attr['inkscape:transform-center-x'];
    if( cx != nil and cx != 0 )
      stack[-1].setDouble("center-offset-x", evalCSSNum(cx));

    var cy = attr['inkscape:transform-center-y'];
    if( cy != nil and cy != 0 )
      stack[-1].setDouble("center-offset-y", -evalCSSNum(cy));
  };

  # XML parsers element close callback
  var end = func(name)
  {
    level -= 1;

    if( skip )
    {
      if( level < skip )
        skip = 0;
      return;
    }

    if( size(defs_stack) > 0 )
    {
      if( name != "defs" )
      {
        var type = defs_stack[-1]['type'];
        if( type == "mask" or type == "clipPath" )
          clip_dict[defs_stack[-1]['id']] = defs_stack[-1];
      }

      pop(defs_stack);
      return;
    }

    if( size(close_stack) and (level + 1) == close_stack[-1] )
      popElement();

    if( name == "text" )
    {
      # Inkscape/SVG text is a bit complicated. If we only got a single tspan
      # or text without tspan we create just a single canvas.Text, otherwise
      # we create a canvas.Group with a canvas.Text as child for each tspan.
      # We need to take care to apply the transform attribute of the text
      # element to the correct canvas element, and also correctly inherit
      # the style properties.
      var character_size = 24;
      if( size(tspans) > 1 )
      {
        pushElement('group', text.attr['id']);
        parseTextStyles(text.style);
        parseTransform(text.attr['transform']);

        character_size = stack[-1].get("character-size", character_size);
      }

      # Helper for getting first number in space separated list of numbers.
      var first_num = func(str)
      {
        if( str == nil )
          return 0;
        var end = str.find_first_of(" \n\t");
        if( end < 0 )
          return str;
        else
          return substr(str, 0, end);
      }

      var line = 0;
      foreach(var tspan; tspans)
      {
        # Always take first number and ignore individual character placment
        var x = first_num(tspan.attr['x'] or text.attr['x']);
        var y = first_num(tspan.attr['y'] or text.attr['y']);

        # Sometimes Inkscape forgets writing x and y coordinates and instead
        # just indicates a multiline text with sodipodi:role="line".
        if( tspan.attr['y'] == nil and tspan.attr['sodipodi:role'] == "line" )
          # TODO should we combine multiple lines into a single text separated
          #      with newline characters?
          y += line
             * stack[-1].get("line-height", 1.25)
             * stack[-1].get("character-size", character_size);

        # Use id of text element with single tspan child, fall back to id of
        # tspan if text has no id.
        var id = text.attr['id'];
        if( id == nil or size(tspans) > 1 )
          id = tspan.attr['id'];

        pushElement('text', id);
        stack[-1].set("text", tspan.text);

        if( x != 0 or y != 0 )
          stack[-1].setTranslation(x, y);

        if( size(tspans) == 1 )
        {
          parseTextStyles(text.style);
          parseTransform(text.attr['transform']);
        }

        parseTextStyles(tspan.style);
        popElement();

        line += 1;
      }

      if( size(tspans) > 1 )
        popElement();

      text = nil;
      tspans = nil;
    }
  };

  # XML parsers element data callback
  var data = func(data)
  {
    if( skip )
      return;

    if( size(data) and tspans != nil )
    {
      if( size(tspans) == 0 )
        # If no tspan is found use text element itself
        append(tspans, text);

      # If text contains xml entities it gets split at each entity. So let's
      # glue it back into a single text...
      tspans[-1]["text"] ~= data;
    }
  };

  call(func parsexml(path, start, end, data), nil, var err = []);
  if( size(err) )
  {
    var msg = err[0];
    for(var i = 1; i + 1 < size(err); i += 2)
    {
      # err = ['error message', 'file', line]
      msg ~= (i == 1 ? "\n  at " : "\n  called from: ")
           ~ err[i] ~ ", line " ~ err[i + 1]
    }
    printlog("alert", msg ~ "\n ");

    return 0;
  }

  return 1;
}
