io.include('A3XX_ND.nas');

io.include('A3XX_ND_drivers.nas');
canvas.NDStyles['Airbus'].options.defaults.route_driver = A3XXRouteDriver.new();

var nd_display = {};

var myCockpit_switches1 = {
	# symbolic alias : relative property (as used in bindings), initial value, type
	'toggle_range': 	{path: '/inputs/range-nm', value:40, type:'INT'},
	'toggle_weather': 	{path: '/inputs/wxr', value:0, type:'BOOL'},
	'toggle_airports': 	{path: '/inputs/arpt', value:0, type:'BOOL'},
	'toggle_stations': 	{path: '/inputs/sta', value:0, type:'BOOL'},
	'toggle_waypoints': 	{path: '/inputs/wpt', value:0, type:'BOOL'},
	'toggle_position': 	{path: '/inputs/pos', value:0, type:'BOOL'},
	'toggle_data': 		{path: '/inputs/data',value:0, type:'BOOL'},
	'toggle_terrain': 	{path: '/inputs/terr',value:0, type:'BOOL'},
	'toggle_traffic': 	{path: '/inputs/tfc',value:0, type:'BOOL'},
	'toggle_centered': 	{path: '/inputs/nd-centered',value:0, type:'BOOL'},
	'toggle_lh_vor_adf':	{path: '/inputs/lh-vor-adf',value:0, type:'INT'},
	'toggle_rh_vor_adf':	{path: '/inputs/rh-vor-adf',value:0, type:'INT'},
	'toggle_display_mode': 	{path: '/mfd/display-mode', value:'MAP', type:'STRING'},
	'toggle_display_type': 	{path: '/mfd/display-type', value:'CRT', type:'STRING'},
	'toggle_true_north': 	{path: '/mfd/true-north', value:0, type:'BOOL'},
    	'toggle_rangearc':      {path: '/mfd/rangearc', value:0, type:'BOOL'},
    	'toggle_track_heading': {path: '/trk-selected', value:0, type:'BOOL'},
	# add new switches here
};

var _list = setlistener("sim/signals/fdm-initialized", func() {
	setprop("instrumentation/airspeed-indicator/true-speed-kt",0);
	var ND1 = canvas.NavDisplay;

	# TODO: is this just an object decsribing a ND? Can we move this out of the listener?
	# Also applies below and to the 777.
	var CNDCpt = ND1.new("instrumentation/efis[1]",myCockpit_switches1,'Airbus');
	
	nd_display.ndcpt = canvas.new({
		"name": "ND",
		"size": [1024, 1024],
		"view": [1024, 1024],
		"mipmapping": 1
	});

	nd_display.ndcpt.addPlacement({"node": "CND"});
	var group = nd_display.ndcpt.createGroup();
	CNDCpt.newMFD(group, nd_display.ndcpt);
	CNDCpt.update();
	
	removelistener(_list); # run ONCE
});

