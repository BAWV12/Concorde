io.include('A3XX_ND.nas');

io.include('A3XX_ND_drivers.nas');
canvas.NDStyles['Airbus'].options.defaults.route_driver = A3XXRouteDriver.new();

var nd_display = {};

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
		'toggle_traffic': 		{path: '/inputs/tfc',value:0, type:'BOOL'},
		'toggle_centered': 		{path: '/inputs/nd-centered',value:0, type:'BOOL'},
		'toggle_lh_vor_adf':	{path: '/input/lh-vor-adf',value:0, type:'INT'},
		'toggle_rh_vor_adf':	{path: '/input/rh-vor-adf',value:0, type:'INT'},
		'toggle_display_mode': 	{path: '/nd/canvas-display-mode', value:'MAP', type:'STRING'},
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

var _list = setlistener("sim/signals/fdm-initialized", func() {
	var ND = canvas.NavDisplay;

	# TODO: is this just an object decsribing a ND? Can we move this out of the listener?
	# Also applies below and to the 777.
	var NDCpt = ND.new("instrumentation/tablet",myCockpit_switches,'Airbus');
	
	nd_display.cpt = canvas.new({
		"name": "ND",
		"size": [1024, 1024],
		"view": [1024, 1024],
		"mipmapping": 1
	});

	nd_display.cpt.addPlacement({"node": "tablet"});
	nd_display.cpt.addPlacement({"node": "tablet_center"});
	var group = nd_display.cpt.createGroup();
	NDCpt.newMFD(group, nd_display.cpt);
	NDCpt.update();

	
	removelistener(_list); # run ONCE
});


