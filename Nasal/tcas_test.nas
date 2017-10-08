setprop("/instrumentation/efis[0]/inputs/range-nm",40);

var my_canvas = canvas.new({
  "name": "PFD-Test",   # The name is optional but allow for easier identification
  "size": [1024, 1024], # Size of the underlying texture (should be a power of 2, required) [Resolution]
  "view": [1024, 1024],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                        # which will be stretched the size of the texture, required)
  "mipmapping": 1       # Enable mipmapping (optional)
});

my_canvas.addPlacement({"node": "TCAS"});

var group = my_canvas.createGroup();

var TestMap = group.createChild("map");
  TestMap.setController("Aircraft position");
  TestMap.setRange(40); 
  
  # this will center the map
  TestMap.setTranslation(512,512);
 var r = func(name,vis=1,zindex=nil) return caller(0)[0];
 foreach(var type; [r('TFC')] )
        TestMap.addLayer(factory: canvas.SymbolLayer, type_arg: type.name, visible: type.vis, priority: type.zindex,);

var txt_range = group.createChild("text")
	.setText("Range 40")
	.setFontSize(24,1)
        .setAlignment("center-center")
        .setTranslation(512,748)
	.setColor(0,1,1,1);

setlistener("instrumentation/efis/inputs/range-nm", func() {
trange=getprop("/instrumentation/efis/inputs/range-nm");
TestMap.setRange(trange);
txt_range.setText(sprintf("Range %i",trange));
});
