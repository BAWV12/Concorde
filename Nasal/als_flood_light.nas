setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m",-0.7);
setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m",0.1);
setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m",-0.4);

setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[1]",-0.7);
setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[1]",0.8);
setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[1]",-0.4);

setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[2]",1.5);
setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[2]",0.45);
setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[2]",0.27);

setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-r",0);
setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-g",0);
setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-b",0);
setprop("sim/rendering/als-secondary-lights/lightspot/size",0.4);

setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-r[1]",0);
setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-g[1]",0);
setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-b[1]",0);
setprop("sim/rendering/als-secondary-lights/lightspot/size[1]",0.4);

setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-r[2]",0);
setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-g[2]",0);
setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-b[2]",0);
setprop("sim/rendering/als-secondary-lights/lightspot/size[2]",3);


if (1>2){
var chgv=setlistener("sim/current-view/name", func() {
  type_of_view=getprop("sim/current-view/internal");
  if (type_of_view==1) {
    	x_o=7.38-getprop("sim/current-view/z-offset-m");
	y_o=-0.35-getprop("sim/current-view/x-offset-m");
	z_o=1.13-getprop("sim/current-view/y-offset-m");
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m",x_o);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m",y_o);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m",z_o);

	x_o1=7.38-getprop("sim/current-view/z-offset-m");
	y_o1=0.35-getprop("sim/current-view/x-offset-m");
	z_o1=1.13-getprop("sim/current-view/y-offset-m");
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[1]",x_o1);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[1]",y_o1);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[1]",z_o1);

	x_o2=9.48-getprop("sim/current-view/z-offset-m");
	y_o2=-getprop("sim/current-view/x-offset-m");
	z_o2=1.8-getprop("sim/current-view/y-offset-m");
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[2]",x_o2);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[2]",y_o2);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[2]",z_o2);
  };
});
};

var alslt=setlistener("systems/electrical/outputs/specific", func() {
  pow=getprop("systems/electrical/outputs/specific");
  if (pow>20){ 
    setprop("sim/rendering/als-secondary-lights/num-lightspots",3);
    } else {
    setprop("sim/rendering/als-secondary-lights/num-lightspots",0);
  };
});
