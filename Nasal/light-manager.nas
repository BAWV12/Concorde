# provides relative vectors from eye-point to aircraft lights
# in east/north/up coordinates the renderer uses

var light_manager = {

    lat_to_m: 110952.0,
    lon_to_m: 0.0,

    light1_xpos: 0.0,
    light1_ypos: 0.0,
    light1_zpos: 0.0,
    light1_r: 0.0,
    light1_g: 0.0,
    light1_b: 0.0,
    light1_size: 0.0,
    light1_stretch: 0.0,

    light2_xpos: 0.0,
    light2_ypos: 0.0,
    light2_zpos: 0.0,
    light2_r: 0.0,
    light2_g: 0.0,
    light2_b: 0.0,
    light2_size: 0.0,
    light2_stretch: 0.0,

    flcpt: 0,
    prev_view : 1,

    init: func {
        # define your lights here

	setprop("controls/lighting/external/main-landing[0]/on1",0);
	setprop("controls/lighting/external/main-landing[1]/on1",0);

	setprop("sim/rendering/als-secondary-lights/flash-radius",13);

	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m",-0.7);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m",0.1);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m",-0.4);

	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[1]",-0.7);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[1]",0.8);
	setprop("sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[1]",-0.4);

	setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-r",0);
	setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-g",0);
	setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-b",0);
	setprop("sim/rendering/als-secondary-lights/lightspot/size",0.4);

	setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-r[1]",0);
	setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-g[1]",0);
	setprop("sim/rendering/als-secondary-lights/lightspot/lightspot-b[1]",0);
	setprop("sim/rendering/als-secondary-lights/lightspot/size[1]",0.4);

	var alslt=setlistener("systems/electrical/outputs/specific", func() {
	  pow=getprop("systems/electrical/outputs/specific");
	  if (pow>20){ 
	    setprop("sim/rendering/als-secondary-lights/num-lightspots",2);
	    } else {
	    setprop("sim/rendering/als-secondary-lights/num-lightspots",0);
	  };
	});

	var intextv=setlistener("sim/current-view/internal", func() {
  		type_of_view=getprop("sim/current-view/internal");
		if (type_of_view == 0) {
			me.flcpt=getprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-r");	
			me.prev_view=0;		
		};				

		if (type_of_view == 1) {
			if (me.prev_view==0) {
				setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-r", me.flcpt);			
			};
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-g", 0);
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-b", 0);
			setprop("sim/rendering/als-secondary-lights/lightspot/size",0);
			setprop("sim/rendering/als-secondary-lights/lightspot/stretch",0);
			me.prev_view=1;
		};				
	});

        me.light_manager_timer = maketimer(0.0, func{me.update()});
        
        me.start();
    },

    start: func {
        me.light_manager_timer.start();
    },

    stop: func {
        me.light_manager_timer.stop();
    },

    update: func {

  	type_of_view=getprop("sim/current-view/internal");
	if (type_of_view == 0) {
		ll1=getprop("controls/lighting/external/main-landing[0]/on");
		ll2=getprop("controls/lighting/external/main-landing[1]/on");
		ll3=getprop("controls/lighting/external/landing-taxi[0]/on");
		ll4=getprop("controls/lighting/external/landing-taxi[1]/on");

		ll5=getprop("controls/lighting/external/main-landing[0]/norm");
		ll6=getprop("controls/lighting/external/main-landing[1]/norm");
		ll7=getprop("controls/lighting/external/landing-taxi[0]/norm");
		ll8=getprop("controls/lighting/external/landing-taxi[1]/norm");

        	# light 1 ########
        	# offsets to aircraft center
        	me.light1_xpos = 150.0;
        	me.light1_ypos =  0.0;
        	me.light1_zpos =  2.0;

        	# color values
        	me.light1_r = 0.5;
        	me.light1_g = 0.5;
        	me.light1_b = 0.5;

        	# spot size
        	me.light1_size = 50.0;
        	me.light1_stretch = 2;
        	me.light2_size = 16;
        	me.light2_stretch = 10;

        	var apos = geo.aircraft_position();
	        var vpos = geo.viewer_position();

	        me.lon_to_m = math.cos(apos.lat()*math.pi/180.0) * me.lat_to_m;

	        var heading = getprop("/orientation/heading-deg") * math.pi/180.0;

	        var lat = apos.lat();
	        var lon = apos.lon();
	        var alt = apos.alt();

	        var sh = math.sin(heading);
	        var ch = math.cos(heading);

	        # light 1 position
	        var alt_agl = getprop("/position/altitude-agl-ft");

	        var proj_x = alt_agl;
	        var proj_z = alt_agl/10.0;

	        apos.set_lat(lat + ((me.light1_xpos + proj_x) * ch + me.light1_ypos * sh) / me.lat_to_m);
	        apos.set_lon(lon + ((me.light1_xpos + proj_x)* sh - me.light1_ypos * ch) / me.lon_to_m);

	        var delta_x = (apos.lat() - vpos.lat()) * me.lat_to_m;
	        var delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
	        var delta_z = apos.alt()- proj_z - vpos.alt();

	        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m", delta_x);
	        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m", delta_y);
	        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m", delta_z);
	        setprop("/sim/rendering/als-secondary-lights/lightspot/dir", heading);

		if ((ll3==1 or ll4==1) and (ll7>0.9 or ll8>0.9)){
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-r", 0.5);
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-g", 0.5);
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-b", 0.5);
			setprop("sim/rendering/als-secondary-lights/lightspot/size",me.light2_size);
			setprop("sim/rendering/als-secondary-lights/lightspot/stretch",me.light2_stretch);
		};

		if ((ll1==1 or ll2==1) and (ll5>0.9 or ll6>0.9)){
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-r", 0.5);
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-g", 0.5);
	        	setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-b", 0.5);
			setprop("sim/rendering/als-secondary-lights/lightspot/size",me.light1_size);
			setprop("sim/rendering/als-secondary-lights/lightspot/stretch",me.light1_stretch);
		};
	};
    },   


};

setprop("controls/lighting/external/main-landing[0]/on1",0);
setprop("controls/lighting/external/main-landing[1]/on1",0);

setlistener("/sim/signals/fdm-initialized", func {
    light_manager.init();
});


setlistener("controls/lighting/external/main-landing[0]/norm", func {
    mln=getprop("controls/lighting/external/main-landing[0]/norm");
    mlo=getprop("controls/lighting/external/main-landing[0]/on");
    if (mln>0.9 and mlo==1) {setprop("controls/lighting/external/main-landing[0]/on1",1)} else {setprop("controls/lighting/external/main-landing[0]/on1",0);};
});
setlistener("controls/lighting/external/main-landing[1]/norm", func {
    mln=getprop("controls/lighting/external/main-landing[1]/norm");
    mlo=getprop("controls/lighting/external/main-landing[1]/on");
    if (mln>0.9 and mlo==1) {setprop("controls/lighting/external/main-landing[1]/on1",1)} else {setprop("controls/lighting/external/main-landing[1]/on1",0);};
});

setlistener("controls/lighting/external/main-landing[0]/on", func {
    mln=getprop("controls/lighting/external/main-landing[0]/norm");
    mlo=getprop("controls/lighting/external/main-landing[0]/on");
    if (mln>0.9 and mlo==1) {setprop("controls/lighting/external/main-landing[0]/on1",1)} else {setprop("controls/lighting/external/main-landing[0]/on1",0);};
});
setlistener("controls/lighting/external/main-landing[1]/on", func {
    mln=getprop("controls/lighting/external/main-landing[1]/norm");
    mlo=getprop("controls/lighting/external/main-landing[1]/on");
    if (mln>0.9 and mlo==1) {setprop("controls/lighting/external/main-landing[1]/on1",1)} else {setprop("controls/lighting/external/main-landing[1]/on1",0);};
});



