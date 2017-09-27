io.include('A3XX_ND.nas');

io.include('A3XX_ND_drivers.nas');
canvas.NDStyles['Airbus'].options.defaults.route_driver = A3XXRouteDriver.new();

var nd_display = {};

setprop("instrumentation/airspeed-indicator/true-speed-kt",0);

setlistener("sim/signals/fdm-initialized", func() {


	var myCockpit_switches = {
		# symbolic alias : relative property (as used in bindings), initial value, type
		'toggle_range': 	{path: '/inputs/range-nm', value:40, type:'INT'},
		'toggle_weather': 	{path: '/inputs/wxr', value:0, type:'BOOL'},
		'toggle_airports': 	{path: '/inputs/arpt', value:0, type:'BOOL'},
		'toggle_ndb': 	{path: '/inputs/NDB', value:0, type:'BOOL'},
		'toggle_stations':     {path: '/inputs/sta', value:0, type:'BOOL'},
		'toggle_vor': 	{path: '/inputs/VORD', value:0, type:'BOOL'},
		'toggle_dme': 	{path: '/inputs/DME', value:0, type:'BOOL'},
		'toggle_cstr': 	{path: '/inputs/CSTR', value:0, type:'BOOL'},
		'toggle_waypoints': 	{path: '/inputs/wpt', value:0, type:'BOOL'},
		'toggle_position': 	{path: '/inputs/pos', value:0, type:'BOOL'},
		'toggle_data': 		{path: '/inputs/data',value:0, type:'BOOL'},
		'toggle_terrain': 	{path: '/inputs/terr',value:0, type:'BOOL'},
		'toggle_traffic': 		{path: '/inputs/tfc',value:1, type:'BOOL'},
		'toggle_centered': 		{path: '/inputs/nd-centered',value:1, type:'BOOL'},
		'toggle_lh_vor_adf':	{path: '/input/lh-vor-adf',value:0, type:'INT'},
		'toggle_rh_vor_adf':	{path: '/input/rh-vor-adf',value:0, type:'INT'},
		'toggle_display_mode': 	{path: '/nd/canvas-display-mode', value:'NAV', type:'STRING'},
		'toggle_display_type': 	{path: '/mfd/display-type', value:'LCD', type:'STRING'},
		'toggle_true_north': 	{path: '/mfd/true-north', value:1, type:'BOOL'},
		'toggle_track_heading': 	{path: '/trk-selected', value:0, type:'BOOL'},
		'toggle_wpt_idx': {path: '/inputs/plan-wpt-index', value: -1, type: 'INT'},
		'toggle_plan_loop': {path: '/nd/plan-mode-loop', value: 0, type: 'INT'},
		'toggle_weather_live': {path: '/mfd/wxr-live-enabled', value: 0, type: 'BOOL'},
		'toggle_chrono': {path: '/inputs/CHRONO', value: 0, type: 'INT'},
		'toggle_xtrk_error': {path: '/mfd/xtrk-error', value: 0, type: 'BOOL'},
		'toggle_trk_line': {path: '/mfd/trk-line', value: 0, type: 'BOOL'},
		# add new switches here
	};

	# get a handle to the NavDisplay in canvas namespace (for now), see $FG_ROOT/Nasal/canvas/map/navdisplay.mfd
	var ND = canvas.NavDisplay;

	## TODO: We want to support multiple independent ND instances here!
	# foreach(var pilot; var pilots = [ {name:'cpt', path:'instrumentation/efis',
	#				     name:'fo',  path:'instrumentation[1]/efis']) {


	##
	# set up a  new ND instance, under 'instrumentation/efis' and use the
	# myCockpit_switches hash to map control properties
	var NDCpt = ND.new("instrumentation/efis", myCockpit_switches, 'TCAS');

	nd_display.main = canvas.new({
		"name": "ND",
		"size": [1024, 1024],
		"view": [1024, 1024],
		"mipmapping": 1
	});

	nd_display.main.addPlacement({"node": "TCAS"});

	var group = nd_display.main.createGroup();
	NDCpt.newMFD(group);
	NDCpt.update();

	print("ND Canvas Initialized!");
}); # fdm-initialized listener callback

#setprop("instrumentation/efis/inputs/tfc","true");


