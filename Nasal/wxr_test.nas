setprop("/instrumentation/efis[1]/inputs/range-nm",40);

var my_canvas1 = canvas.new({
  "name": "WXR",   # The name is optional but allow for easier identification
  "size": [1024, 1024], # Size of the underlying texture (should be a power of 2, required) [Resolution]
  "view": [1024, 1024],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                        # which will be stretched the size of the texture, required)
  "mipmapping": 1       # Enable mipmapping (optional)
}).setColorBackground(0.1,0.05,0,1);

my_canvas1.addPlacement({"node": "CND"});

var group1 = my_canvas1.createGroup();

if (1>2){
var TestMap1 = group1.createChild("map");
  TestMap1.setController("Aircraft position");
  TestMap1.setRange(40); 
  
  # this will center the map
  TestMap1.setTranslation(512,512);
 var r1 = func(name,vis=1,zindex=nil) return caller(0)[0];
 foreach(var type; [r1('WXR')] )
        TestMap1.addLayer(factory: canvas.SymbolLayer, type_arg: type.name, visible: type.vis, priority: type.zindex,);
};
var txt_range1 = group1.createChild("text")
	.setText("Range 40")
	.setFontSize(24,1)
        .setAlignment("center-center")
        .setTranslation(512,748)
	.setColor(0.8,0.4,0,1);


setlistener("instrumentation/efis[1]/inputs/range-nm", func() {
wrange=getprop("/instrumentation/efis[1]/inputs/range-nm");
TestMap1.setRange(wrange);
txt_range1.setText(sprintf("Range %i",wrange));
});
