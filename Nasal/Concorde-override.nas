# put all code in comment to recover the default behaviour.


# ========================
# OVERRIDING NASAL GLOBALS
# ========================

# joystick may move until listener is triggered.
globals.Concorde.enginesystem = nil;


# one cannot override the joystick flight controls;
# but the mechanical channel should not fail.


# overrides the joystick axis handler to catch a goaround
override_throttleAxis = controls.throttleAxis;

controls.throttleAxis = func {
    if( globals.Concorde.enginesystem == nil ) {
        override_throttleAxis();
    }
    else {
        var val = cmdarg().getNode("setting").getValue();
        if(size(arg) > 0) { val = -val; }

        var position = (1 - val)/2;

        globals.Concorde.enginesystem.set_throttle( position );
    }
}


# overrides the gear handler to catch an hydraulic failure
override_gearDown = controls.gearDown;

controls.gearDown = func( sign ) {
    if( sign < 0 ) {
        if( globals.Concorde.gearsystem.can_up() ) {
            override_gearDown( sign );
        }

        # 2) neutral, once retracted
        if( getprop("/gear/gear[0]/position-norm") == globals.Concorde.constantaero.GEARUP ) {
            setprop("/controls/gear/hydraulic",globals.Concorde.constant.FALSE);
        }
    }
    elsif( sign > 0 ) {
        # remove neutral to get hydraulics
        setprop("/controls/gear/hydraulic",globals.Concorde.constant.TRUE);

        if( globals.Concorde.gearsystem.can_down() ) {
            override_gearDown( sign );
        }
    }
}


# overrides the flaps handler to catch an hydraulic failure
override_flapsDown = controls.flapsDown;

controls.flapsDown = func( sign ) {
    if( sign < 0 ) {
        if( globals.Concorde.noseinstrument.can_up() ) {
            override_flapsDown( sign );
        }
    }
    elsif( sign > 0 ) {
        if( globals.Concorde.noseinstrument.can_down() ) {
            override_flapsDown( sign );
        }
    }
}


# overrides the brake handler to catch an hydraulic failure
override_applyBrakes = controls.applyBrakes;

controls.applyBrakes = func(v, which = 0) {
    if( globals.Concorde.hydraulicsystem == nil ) {
        override_applyBrakes( v, which );
    }
    elsif( globals.Concorde.hydraulicsystem.brakes_pedals( v ) ) {
        # default
        override_applyBrakes( v, which );
    }
}


# overrides the parking brake handler to catch an hydraulic failure
override_applyParkingBrake = controls.applyParkingBrake;

controls.applyParkingBrake = func(v) {
    if (!v) { return; }
    globals.Concorde.hydraulicsystem.brakesparkingexport();
    var p = "/controls/gear/brake-parking-lever";
    var i = getprop(p);
    return i;
}


# overrides engine start
override_startEngine = controls.startEngine;

controls.startEngine = func {
    override_startEngine();

    globals.Concorde.enginesystem.cutoffexport();
}


# overrides keyboard for autopilot adjustment or floating view.

override_incElevator = controls.incElevator;

controls.incElevator = func {
    var sign = 1.0;
    
    if( arg[0] < 0.0 ) {
	sign = -1.0;
    }
    
    if( globals.Concorde.seatsystem == nil ) {
        override_incElevator(arg[0], arg[1]);
    }
    elsif( !globals.Concorde.seatsystem.movelengthexport(-0.01 * sign) ) {
        if( !globals.Concorde.autopilotsystem.datumapexport(1.0 * sign) ) {
            # default
            override_incElevator(arg[0], arg[1]);
        }
    }
}

override_incAileron = controls.incAileron;

controls.incAileron = func {
    var sign = 1.0;
    
    if( arg[0] < 0.0 ) {
	sign = -1.0;
    }
    
    if( globals.Concorde.seatsystem == nil ) {
        override_incAileron(arg[0], arg[1]);
    }
    elsif( !globals.Concorde.seatsystem.movewidthexport(0.01 * sign) ) {
        if( !globals.Concorde.autopilotsystem.headingknobexport(1.0 * sign) ) {
            # default
            override_incAileron(arg[0], arg[1]);
        }
    }
}

override_incThrottle = controls.incThrottle;

controls.incThrottle = func {
    var sign = 1.0;
    
    if( arg[0] < 0.0 ) {
	sign = -1.0;
    }
    
    if( globals.Concorde.seatsystem == nil ) {
        override_incThrottle(arg[0], arg[1]);
    }
    elsif( !globals.Concorde.seatsystem.moveheightexport(0.01 * sign) ) {
        if( !globals.Concorde.autothrottlesystem.datumatexport(1.0 * sign) ) {
            # default
            override_incThrottle(arg[0], arg[1]);
        }
    }
}
