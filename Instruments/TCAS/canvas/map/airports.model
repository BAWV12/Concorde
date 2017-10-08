# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var AirportModel = {};
AirportModel.new =  func make(AirportModel, LayerModel);

# FIXME: Just testing for now: This really shouldn't be part of the core LayerModel, needs to go to "AirportModel" instead
# FIXME: This will get called ONCE for EACH layer that uses the AirportModel, so VERY inefficient ATM! => should be shared among layers

AirportModel.init = func {
	me._view.reset();
	var id = getprop(me._input_property); # HACK: this needs to be handled via the controller - introduce "input_property"
	#print("ID is:", id);
	(id == "") and return;
	var apt=airportinfo(id); # FIXME: replace with controller call to update the model

	foreach(var a; [ apt ]) #FIXME: move to separate method: "populate"
		# print("storing:", a.id) and 
	me.push(a);
	#print("Work items in Model:", me.hasData() );
	#print("Model updated!!");

	# set RefPos and hdg to apt !! 
	me._map.setRefPos(apt.lat, apt.lon);

	#TODO: Notify view on update - use proper NOTIFICATIONS (INIT; UPDATE etc)
	me.notifyView();
}

