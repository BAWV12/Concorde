# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure

var RouteModel = {route_monitor:nil};
RouteModel.new = func make(LayerModel, RouteModel);

RouteModel.init = func {
	me._view.reset();
	if (!getprop("/autopilot/route-manager/active"))
		return;

	## TODO: all the model stuff is still inside the draw file for now, this just ensures that it will be called once
	foreach(var t; [nil] )		 
		me.push(t);

	me.notifyView();

	#FIXME: segfault of the day: use this layer once without a route, and then with a route - and  BOOM, need to investigate.

	# TODO: should register a route manager listener here to update itself whenever the route/active WPT changes!
	# also, if the layer is used in a dialog, the listener should be removed when the dialog is closed
	if (me.route_monitor == nil) # FIXME: remove this listener durint reinit
		me.route_monitor=setlistener("/autopilot/route-manager/active", func me.init() ); # this can probably be shared (singleton), because all canvases will be displaying same route ??? 
}


