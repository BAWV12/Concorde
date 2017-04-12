var tyresmoke_system0 = aircraft.tyresmoke_system.new(0, 1);
var tyresmoke_system1 = aircraft.tyresmoke_system.new(1, 1);
var tyresmoke_system2 = aircraft.tyresmoke_system.new(2, 1);
var tyresmoke_system3 = aircraft.tyresmoke_system.new(3, 1);
var tyresmoke_system4 = aircraft.tyresmoke_system.new(4, 1);


#============================ Rain ===================================
if( !getprop("/controls/environment/rain") ) {
    aircraft.rain.init();
}

var rain = func {
	aircraft.rain.update();
	settimer(rain, 0);
}

# == fire it up ===
if( !getprop("/controls/environment/rain") ) {
    rain();
}
# end
