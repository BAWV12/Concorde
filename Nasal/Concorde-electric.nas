# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =================
# ELECTRICAL SYSTEM
# =================

Electrical = {};

Electrical.new = func {
   var obj = { parents : [Electrical,System],

               relight : EmergencyRelight.new(),
               parser : ElectricalXML.new(),
               csd : ConstantSpeedDrive.new(),
               voltmeterdc : DCVoltmeter.new(),
               voltmeterac : ACVoltmeter.new(),

               ELECSEC : 1.0,                                 # refresh rate

               SERVICEVOLT : 600.0,
               GROUNDVOLT : 110.0,                            # AC
               SPECIFICVOLT : 20.0,                           # DC or low AC
               NOVOLT : 0.0
         };

   obj.init();

   return obj;
};

Electrical.init = func {
   me.inherit_system("/systems/electrical");

   me.parser.init_ElectricalXML("/systems/electrical");

   me.csd.set_rate( me.ELECSEC );
}

Electrical.set_rate = func( rates ) {
   me.ELECSEC = rates;
   me.csd.set_rate( me.ELECSEC );
   me.voltmeterdc.set_rate( me.ELECSEC );
   me.voltmeterac.set_rate( me.ELECSEC );
}

Electrical.amber_electrical = func {
   var result = me.csd.amber_electrical();

   if( !result ) {
       for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
            if( !me.dependency["engine-ctrl"][i].getChild("master-alt").getValue() ) {
                result = constant.TRUE;
                break;
            }
       }
   }

   if( !result ) {
       if( !me.has_probe_ac( "ac-main", 0 ) or !me.has_probe_ac( "ac-main", 1 ) or
           !me.has_probe_ac( "ac-main", 2 ) or !me.has_probe_ac( "ac-main", 3 ) ) {
           result = constant.TRUE;
       }
       elsif( !me.has_probe_ac( "ac-essential", 0 ) or !me.has_probe_ac( "ac-essential", 1 ) or
              !me.has_probe_ac( "ac-essential", 2 ) or !me.has_probe_ac( "ac-essential", 3 ) ) {
           result = constant.TRUE;
       }
       elsif( !me.itself["dc"].getChild("master-bat", 0).getValue() or
              !me.itself["dc"].getChild("master-bat", 1).getValue() ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Electrical.red_electrical = func {
   var result = constant.FALSE;

   if( !me.has_probe_dc("dc-main-a") or !me.has_probe_dc("dc-main-b") or
       !me.has_probe_dc("dc-essential-a") or !me.has_probe_dc("dc-essential-b") ) {
       result = constant.TRUE;
   }

   return result;
}

Electrical.red_doors = func {
    var result = constant.FALSE;

    if( me.itself["ground"].getChild("door").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.groundserviceexport = func {
    if( !me.is_moving() ) {
        var supply = me.itself["ground"].getChild("door").getValue();
        var powervolt = me.NOVOLT;


        if( !supply ) {
            powervolt = me.SERVICEVOLT;
        }

        me.itself["ground"].getChild("door").setValue(!supply);
        me.itself["ground"].getChild("volts").setValue(powervolt);
    }
}

Electrical.emergencyrelightexport = func {
   me.relight.selectorexport();
}

Electrical.enginerelightexport = func( engine ) {
   me.relight.engineexport( engine );
}

Electrical.dcvoltmeterexport = func {
   me.voltmeterdc.selectorexport();
}

Electrical.acvoltmeterexport = func {
   me.voltmeterac.selectorexport();
}

Electrical.has_ground = func {
    var result = constant.FALSE;
    var volts = me.itself["ground"].getChild("volts").getValue();

    if( volts > me.GROUNDVOLT ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.schedule = func {
    me.csd.schedule();
    me.parser.schedule();
    me.voltmeterdc.schedule();
    me.voltmeterac.schedule();


    # no voltage at startup
    if( me.is_ready() ) {
        me.emergency_generation();
    }


    # flags for other systems
    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         me.itself["electric"].getChild("autopilot", i).setValue( me.has_autopilot(i) );
    }

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         me.itself["electric"].getChild("relight", i).setValue( me.has_probe_ac("ac-relight", i) );
    }

    me.itself["electric"].getChild("ground-service").setValue( me.has_probe_ac("ac-gpb") );
    me.itself["electric"].getChild("specific").setValue( me.has_dc("specific") );
    me.itself["electric"].getChild("inverter-blue").setValue( me.has_transformer_26ac("ac-inverter-blue") );
    me.itself["electric"].getChild("inverter-green").setValue( me.has_transformer_26ac("ac-inverter-green") );
    me.itself["electric"].getChild("flight-control-monitoring").setValue( me.has_probe_26ac("ac-flight-control-monitoring") );
    me.itself["electric"].getChild("channel-blue").setValue( me.has_probe_26ac("ac-flight-blue") );
    me.itself["electric"].getChild("channel-green").setValue( me.has_probe_26ac("ac-flight-green") );
}

Electrical.slowschedule = func {
    me.door();
    me.parser.slowschedule();
}

Electrical.emergency_generation = func {
    var engine12 = constant.TRUE;
    var auto = constant.FALSE;
    var bypass = constant.FALSE;
    var wow = constant.FALSE;
    var check = constant.FALSE;

    # loss of green hydraulics for emergency generator
    if( !me.dependency["engine"][constantaero.ENGINE1].getChild("running").getValue() and
        !me.dependency["engine"][constantaero.ENGINE2].getChild("running").getValue() ) {
        engine12 = constant.FALSE;
    }

    # disconnect 17 X, because RAT can provide power only for 16 X
    me.itself["emergency"].getChild("asb").setValue( engine12 );


    # automatic start of emergency generator
    if( me.itself["generator"].getChild("arm").getValue() and
        !me.itself["generator"].getChild("selected").getValue() ) {

        auto = me.itself["generator"].getChild("auto").getValue();
        bypass = me.itself["generator"].getChild("ground-bypass").getValue();
        wow = me.dependency["weight"].getChild("wow").getValue();

        # manual start
        if( !auto and !bypass ) {
            me.itself["generator"].getChild( "selected" ).setValue( constant.TRUE );
            check = constant.FALSE;
        }

        # automatic start on ground
        elsif( !auto and bypass ) {
            check = constant.TRUE;
        }

        # automatic start in flight
        elsif( auto and !wow ) {
            check = constant.TRUE;
        }

        # do nothing
        else {
            check = constant.FALSE;
        }


        # loss of engines 1 & 2
        if( check ) {
            if( !engine12 ) {
                me.itself["generator"].getChild( "selected" ).setValue( constant.TRUE );
                check = constant.FALSE;
            }
        }

        # fail of an AC Main busbar
        if( check ) {
            for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
                 if( !me.has_probe_ac( "ac-main", i ) ) {
                     me.itself["generator"].getChild( "selected" ).setValue( constant.TRUE );
                     break;
                 }
            }
        }
    }


    # automatic connection of a dead busbar
    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         me.itself["emergency"].getChild( "essential-auto", i ).setValue( me.has_probe_ac( "ac-main", i ) );
    }
}

# connection with delay by ground operator
Electrical.door = func {
    if( me.is_moving() ) {
        # door stays open, has forgotten to call for disconnection !
        me.itself["ground"].getChild("volts").setValue(me.NOVOLT);
    }
}

Electrical.has_dc = func( output ) {
    var result = constant.FALSE;
    var volts =  me.itself["outputs"].getChild(output).getValue();

    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.SPECIFICVOLT ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.has_probe_dc = func( output ) {
    var result = constant.FALSE;
    var volts =  me.itself["probe"].getChild(output).getValue();

    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.SPECIFICVOLT ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.has_autopilot = func( index ) {
    var result = constant.FALSE;

    # autopilot[0] reserved for FG autopilot
    var index = index + 1;

    volts =  me.itself["outputs"].getChild("autopilot", index).getValue();
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > 0 ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.has_probe_ac = func( output, index = -1 ) {
    var result = constant.FALSE;
    var volts =  me.NOVOLT;

    if( index < 0 ) {
        index = 0;
    }

    volts = me.itself["probe"].getChild(output,index).getValue();

    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.GROUNDVOLT ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.has_probe_26ac = func( output ) {
    var result = constant.FALSE;
    var volts =  me.itself["probe"].getChild(output).getValue();

    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.SPECIFICVOLT ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.has_transformer_26ac = func( output ) {
    var result = constant.FALSE;
    var volts =  me.itself["transformers"].getChild(output).getValue();

    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.SPECIFICVOLT ) {
        result = constant.TRUE;
    }

    return result;
}


# ===================
# CSD OIL TEMPERATURE
# ===================

ConstantSpeedDrive = {};

ConstantSpeedDrive.new = func {
   var obj = { parents : [ConstantSpeedDrive,System],

               ELECSEC : 1.0,                                 # refresh rate
   
               LOWPSI : 30.0
         };

   obj.init();

   return obj;
};

ConstantSpeedDrive.init = func {
   me.inherit_system("/systems/electrical");
}

ConstantSpeedDrive.set_rate = func( rates ) {
   me.ELECSEC = rates;
}

ConstantSpeedDrive.amber_electrical = func {
   var result = constant.FALSE;

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.dependency["engine-sys"][i].getChild("csd-oil-psi").getValue() <= me.LOWPSI ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

# oil temperature
ConstantSpeedDrive.schedule = func {
   var csd = constant.FALSE;
   var csdpressurepsi = 0.0;
   var oatdegc = 0.0;
   var egtdegc = 0.0;
   var egtdegf = 0.0;
   var inletdegc = 0.0;
   var diffdegc = 0.0;

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
       csd = me.dependency["engine-ctrl"][i].getChild("csd").getValue();
       if( csd ) {
           csdpressurepsi = me.dependency["engine"][i].getChild("oil-pressure-psi").getValue();
       }
       else {
           csdpressurepsi = 0.0;
       }

       # not real
       interpolate(me.dependency["engine-sys"][i].getChild("csd-oil-psi").getPath(),csdpressurepsi,me.ELECSEC);

       oatdegc = me.noinstrument["temperature"].getValue();

       # connected
       if( csd ) {
           egtdegf = me.dependency["engine"][i].getChild("egt-degf").getValue();
           egtdegc = constant.fahrenheit_to_celsius( egtdegf );
       }

       # not real
       inletdegc = me.dependency["engine-sys"][i].getChild("csd-inlet-degc").getValue();
       if( csd ) {
           inletdegc = egtdegc / 3.3;
       }
       # scale until 0 deg C
       else {
           inletdegc = inletdegc * 0.95;
       }
       if( inletdegc < oatdegc ) {
           inletdegc = oatdegc;
       }
       interpolate(me.dependency["engine-sys"][i].getChild("csd-inlet-degc").getPath(),inletdegc,me.ELECSEC);

       # not real
       diffdegc = me.dependency["engine-sys"][i].getChild("csd-diff-degc").getValue();
       if( csd ) {
           diffdegc = egtdegc / 17.0;
       }
       # scale until 0 deg C
       else {
           diffdegc = diffdegc * 0.95;
       }
       interpolate(me.dependency["engine-sys"][i].getChild("csd-diff-degc").getPath(),diffdegc,me.ELECSEC);
   }
}


# =================
# EMERGENCY RELIGHT
# =================

EmergencyRelight = {};

EmergencyRelight.new = func {
   var obj = { parents : [EmergencyRelight,System],

               switches : [ -1, 1, 3, 2, 0 ]                     # maps selector to relight (-1 is off)
         };

   obj.init();

   return obj;
};

EmergencyRelight.init = func {
   me.inherit_system("/systems/electrical");
}

EmergencyRelight.engineexport = func( engine ) {
   # switch off
   var selector = me.switches[0];

   for( var i = 1; i <= constantaero.NBENGINES; i = i+1 ) {
        # selector on engine
        if( me.switches[ i ] == engine ) {
            selector = i;
            break;
        }
   }

   return selector;
}

EmergencyRelight.selectorexport = func {
   var selector = me.itself["emergency"].getChild("relight-selector").getValue();
   var engine = me.switches[selector];

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {

        # only 1 emergency relight has voltage, if selector not at 0
        if( i == engine ) {
            me.itself["relight"][i].setValue( constant.FALSE );
            me.itself["relight-emergency"][i].setValue( constant.TRUE );
        }

        # all 4 relights have voltage, if selector at 0
        else {
            me.itself["relight-emergency"][i].setValue( constant.FALSE );
            me.itself["relight"][i].setValue( constant.TRUE );
        }
   }
}


# ============
# DC VOLTMETER
# ============

DCVoltmeter = {};

DCVoltmeter.new = func {
   var obj = { parents : [DCVoltmeter,System],

               ELECSEC : 1.0,                                 # refresh rate

               NOVOLT : 0.0,

               selector : 0
         };

   obj.init();

   return obj;
};

DCVoltmeter.init = func {
   me.inherit_system("/instrumentation/voltmeter-dc");
}

DCVoltmeter.set_rate = func( rates ) {
   me.ELECSEC = rates;
}

DCVoltmeter.schedule = func {
   var result = me.NOVOLT;

   if( me.selector == -2 ) {
       result = me.dependency["suppliers"].getChild("battery",0).getValue();
   }
   elsif( me.selector == -1 ) {
       result = me.dependency["probe"].getChild("dc-essential-a").getValue();
   }
   elsif( me.selector == 0 ) {
       result = me.dependency["probe"].getChild("dc-main-a").getValue();
   }
   elsif( me.selector == 1 ) {
       result = me.dependency["probe"].getChild("dc-main-b").getValue();
   }
   elsif( me.selector == 2 ) {
       result = me.dependency["probe"].getChild("dc-essential-b").getValue();
   }
   elsif( me.selector == 3 ) {
       result = me.dependency["suppliers"].getChild("battery",1).getValue();
   }

   interpolate(me.itself["root"].getChild("indicated-volt").getPath(), result, me.ELECSEC);
}

DCVoltmeter.selectorexport = func {
   me.selector = me.dependency["dc"].getChild("voltmeter").getValue();

   me.schedule();
}


# ============
# AC VOLTMETER
# ============

ACVoltmeter = {};

ACVoltmeter.new = func {
   var obj = { parents : [ACVoltmeter,System],

               ELECSEC : 1.0,                                 # refresh rate

               NOVOLT : 0.0,

               NORMALHZ : 400,
               NOHZ : 0,

               selector : 0
         };

   obj.init();

   return obj;
};

ACVoltmeter.init = func {
   me.inherit_system("/instrumentation/voltmeter-ac");
}

ACVoltmeter.set_rate = func( rates ) {
   me.ELECSEC = rates;
}

ACVoltmeter.schedule = func {
   var frequencyhz = me.NOHZ;
   var result = me.NOVOLT;

   if( me.selector == -3 ) {
       result = me.dependency["probe"].getChild("ac-gpb").getValue();
   }
   elsif( me.selector == -2 ) {
       result = me.dependency["probe"].getChild("ac-emergency-a").getValue();
   }
   elsif( me.selector == -1 ) {
       result = me.dependency["probe"].getChild("ac-generator",0).getValue();
   }
   elsif( me.selector == 0 ) {
       result = me.dependency["probe"].getChild("ac-generator",1).getValue();
   }
   elsif( me.selector == 1 ) {
       result = me.dependency["probe"].getChild("ac-generator",2).getValue();
   }
   elsif( me.selector == 2 ) {
       result = me.dependency["probe"].getChild("ac-generator",3).getValue();
   }

   if( result > me.NOVOLT ) {
       frequencyhz = me.NORMALHZ;
   }

   interpolate(me.itself["root"].getChild("indicated-volt").getPath(), result, me.ELECSEC);
   interpolate(me.dependency["frequency-meter"].getChild("indicated-hz").getPath(), frequencyhz, me.ELECSEC);
}

ACVoltmeter.selectorexport = func {
   me.selector = me.dependency["ac"].getChild("voltmeter").getValue();

   me.schedule();
}


# =====
# WIPER
# =====

Wiper = {};

Wiper.new = func {
   var obj = { parents : [Wiper, System],

               noseinstrument : nil,

               RAINSEC : 1.0,

               MOVEMENTSEC : [ 1.8, 0.8 ],

               ratesec : [ 0.0, 0.0 ],

               WIPERUP : 1.0,
               WIPERDELTA : 0.1,                            # interpolate may not completely reach its target
               WIPERDOWN : 0.0,

               WIPEROFF : 0
         };

   obj.init();

   return obj;
};

Wiper.init = func {
   me.inherit_system("/instrumentation/wiper");
}

Wiper.set_relation = func( nose ) {
   me.noseinstrument = nose;
}

Wiper.schedule = func {
   if( me.dependency["electric"].getChild("specific").getValue() ) {
       # disables wiper with visor up, since one cannot raise the visor with the wiper running.
       if( me.noseinstrument.is_visor_down() ) {
           me.motor();
       }
   }
}

Wiper.motor = func {
   var power = constant.FALSE;
   var stopped = constant.TRUE;
   var selector = 0;
   var pos = 0.0;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        selector =  me.itself["motor"][i].getChild("selector").getValue();

        if( selector > me.WIPEROFF ) {
            stopped = constant.FALSE;
            power = constant.TRUE;

            # returns to rest at the same speed.
            me.ratesec[i] = me.MOVEMENTSEC[selector-1]; 
        }
        else {
            stopped = constant.TRUE;
        }

        pos = me.itself["motor"][i].getChild("position-norm").getValue();

        # starts a new sweep.
        if( pos <= ( me.WIPERDOWN + me.WIPERDELTA ) ) {
            if( !stopped ) {
               interpolate(me.itself["motor"][i].getChild("position-norm").getPath(),me.WIPERUP,me.ratesec[i]);
            }
        }

        # ends its sweep, even if off.
        elsif( pos >= ( me.WIPERUP - me.WIPERDELTA ) ) {
            power = constant.TRUE;
            interpolate(me.itself["motor"][i].getChild("position-norm").getPath(),me.WIPERDOWN,me.ratesec[i]);
        }
   }

   me.itself["root"].getChild("power").setValue( power );
}


# ========
# LIGHTING
# ========

Lighting = {};

Lighting.new = func {
   var obj = { parents : [Lighting,System],

               compass : CompassLight.new(),
               internal : LightLevel.new(),
               landing : LandingLight.new()
         };

   obj.init();

   return obj;
};

Lighting.init = func {
   me.inherit_system("/systems/lighting");

   var strobe_switch = me.itself["root-ctrl"].getNode("strobe");

   aircraft.light.new(me.itself["root-ctrl"].getNode("external/strobe").getPath(), [ 0.03, 1.20 ], strobe_switch);
}

Lighting.schedule = func {
   me.compass.schedule();
   me.landing.schedule();
   me.internal.schedule();
}

Lighting.compassexport = func( level ) {
   me.compass.illuminateexport( level );
}

Lighting.extendexport = func {
   me.landing.extendexport();
}

Lighting.floodexport = func {
   me.internal.floodexport();
}

Lighting.roofexport = func {
   me.internal.roofexport();
}


# =====================
# STANDBY COMPASS LIGHT
# =====================

CompassLight = {};

CompassLight.new = func {
   var obj = { parents : [CompassLight, System],

               BRIGHTNORM : 1.0,
               DIMNORM : 0.5,
               OFFNORM : 0.0,

               norm : 0.0
         };

   obj.init();

   return obj;
}

CompassLight.init = func {
   me.inherit_system("/systems/lighting");

   me.norm = me.itself["overhead"].getChild("compass-norm").getValue();
}

CompassLight.schedule = func {
   var level = me.norm;

   if( !me.dependency["electric"].getChild("specific").getValue() ) {
       level = me.OFFNORM;
   }

   me.itself["overhead"].getChild("compass-light").setValue( level );
}

CompassLight.illuminateexport = func( level ) {
   if( level == me.norm ) {
       me.norm = me.OFFNORM;
   }
   else {
       me.norm = level;
   }

   me.itself["overhead"].getChild("compass-norm").setValue( me.norm );

   me.schedule();
}


# =============
# LANDING LIGHT
# =============

LandingLight = {};

LandingLight.new = func {
   var obj = { parents : [LandingLight,System],

               EXTENDSEC : 8.0,                                # time to extend a landing light
               ROTATIONSEC : 2.0,                              # time to rotate a landing light
 
               ROTATIONNORM : 1.2,
               EXTENDNORM : 1.0,
               ERRORNORM : 0.1,                                # Nasal interpolate may not reach 1.0
               RETRACTNORM : 0.0,

               MAXKT : 365.0                                   # speed of automatic blowback
         };

   obj.init();

   return obj;
};

LandingLight.init = func {
   me.inherit_system("/systems/lighting");
}

LandingLight.schedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       if( me.landingextended() ) {
           me.extendexport();
       }
   }
}

LandingLight.landingextended = func {
   var extension = constant.FALSE;

   # because of motor failure, may be extended with switch off, or switch on and not yet extended
   for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1) {
        if( me.itself["main-landing"][i].getChild("norm").getValue() > 0 or
            me.itself["main-landing"][i].getChild("extend").getValue() ) {
            extension = constant.TRUE;
            break;
        }
        if( me.itself["landing-taxi"][i].getChild("norm").getValue() > 0 or
            me.itself["landing-taxi"][i].getChild("extend").getValue() ) {
            extension = constant.TRUE;
            break;
        }
   }

   return extension;
}

# automatic blowback
LandingLight.landingblowback = func {
   if( me.dependency["asi"].getChild("indicated-speed-kt").getValue() > me.MAXKT ) {
       for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1) {
            if( me.itself["main-landing"][i].getChild("extend").getValue() ) {
                me.itself["main-landing"][i].getChild("extend").setValue(constant.FALSE);
            }
            if( me.itself["landing-taxi"][i].getChild("extend").getValue() ) {
                me.itself["landing-taxi"][i].getChild("extend").setValue(constant.FALSE);
            }
       }
   }
}

# compensate approach attitude
LandingLight.landingrotate = func {
   # ground taxi
   var target = me.EXTENDNORM;

   # pitch at approach
   if( me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue() > constantaero.AGLTOUCHFT ) {
       target = me.ROTATIONNORM;
   }

   return target;
}

LandingLight.landingmotor = func( light, present, target ) {
   var durationsec = 0.0;

   if( present < me.RETRACTNORM + me.ERRORNORM ) {
       if( target == me.EXTENDNORM ) {
           durationsec = me.EXTENDSEC;
       }
       elsif( target == me.ROTATIONNORM ) {
           durationsec = me.EXTENDSEC + me.ROTATIONSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   elsif( present > me.EXTENDNORM - me.ERRORNORM and present < me.EXTENDNORM + me.ERRORNORM ) {
       if( target == me.RETRACTNORM ) {
           durationsec = me.EXTENDSEC;
       }
       elsif( target == me.ROTATIONNORM ) {
           durationsec = me.ROTATIONSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   elsif( present > me.ROTATIONNORM - me.ERRORNORM ) {
       if( target == me.RETRACTNORM ) {
           durationsec = me.ROTATIONSEC + me.EXTENDSEC;
       }
       elsif( target == me.EXTENDNORM ) {
           durationsec = me.EXTENDSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   # motor in movement
   else {
       durationsec = 0.0;
   }

   if( durationsec > 0.0 ) {
       interpolate(light,target,durationsec);
   }
}

LandingLight.extendexport = func {
   var target = 0.0;
   var value = 0.0;
   var result = 0.0;
   var light = "";

   if( me.dependency["electric"].getChild("specific").getValue() ) {

       # automatic blowback
       me.landingblowback();

       # activate electric motors
       target = me.landingrotate();

       for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
            if( me.itself["main-landing"][i].getChild("extend").getValue() ) {
                value = target;
            }
            else {
                value = me.RETRACTNORM;
            }

            result = me.itself["main-landing"][i].getChild("norm").getValue();
            if( result != value ) {
                light = me.itself["main-landing"][i].getChild("norm").getPath();
                me.landingmotor( light, result, value );
            }

            if( me.itself["landing-taxi"][i].getChild("extend").getValue() ) {
                value = target;
            }
            else {
                value = me.RETRACTNORM;
            }
 
            result = me.itself["landing-taxi"][i].getChild("norm").getValue();
            if( result != value ) {
                light = me.itself["landing-taxi"][i].getChild("norm").getPath();
                me.landingmotor( light, result, value );
            }
       }
   }
}


# ===========
# LIGHT LEVEL
# ===========

# the material animation is for instruments :
# - no blend of fluorescent and flood.
# - all object is illuminated, instead of only a surface.
LightLevel = {};

LightLevel.new = func {
   var obj = { parents : [LightLevel,System],

# internal lights
               LIGHTFULL : 1.0,
               LIGHTINVISIBLE : 0.00001,                      # invisible offset
               LIGHTAMBIENT : 0.3,                            # 3D warning light by night
               LIGHTNO : 0.0,

               invisible : constant.TRUE,                     # force a change on 1st recover, then alternate

# norm is user setting, light is animation
               fluorescent : "roof-light",
               fluorescentnorm : "roof-norm",

               floods : [ "captain/flood-light", "copilot/flood-light",
                          "center/flood-light", "engineer/flood-light",
                          "engineer/spot-light" ],
               floodnorms : [ "captain/flood-norm", "copilot/flood-norm",
                              "center/flood-norm", "engineer/flood-norm",
                              "engineer/spot-norm" ],
               nbfloods : 5,

               powerfailure : constant.FALSE,

               lights : {},
               FLOODCAPTAIN : 0,
               FLOODCOPILOT : 1,
               FLOODCENTER : 2,
               FLOODENGINEER : 3,
               FLOODENGINEERSPOT : 4,
               FLUOROOF : 5
         };

   obj.init();

   return obj;
};

LightLevel.init = func {
   me.inherit_system("/systems/lighting");
}

LightLevel.floodexport = func {
   me.floodrecover();
}

LightLevel.roofexport = func {
   var value = 0.0;

   if( me.itself["crew"].getChild("roof").getValue() ) {
       value = me.LIGHTFULL;

       # no blend with flood
       me.floodfailure();
   }
   else {
       value = me.LIGHTNO;

       me.invisible = !me.invisible;

       me.floodrecover();
   }

   me.itself["crew"].getNode(me.fluorescentnorm).setValue(value);
   me.fluorecover();
}

LightLevel.schedule = func {
   # clear all lights
   if( !me.dependency["electric"].getChild("specific").getValue() or
       !me.itself["root"].getChild("serviceable").getValue() ) {
       me.powerfailure = constant.TRUE;
       me.failure();
   }

   # recover from failure
   elsif( me.powerfailure ) {
       me.powerfailure = constant.FALSE;
       me.recover();
   }

   me.mixing();
}

# OSG doesn't accept many material on the same object :
# - one must compute light level.
# - a lighted object cannot belong to a group, if its father is also lighted.
LightLevel.mixing = func {
   var level = 0.0;


   # current light levels
   for( var i=0; i < me.nbfloods; i=i+1 ) {
        me.lights[i] = me.itself["crew"].getNode(me.floods[i]).getValue();
   }
   me.lights[me.FLUOROOF] = me.itself["crew"].getNode(me.fluorescent).getValue();


   # computes the highest light
   level = me.lights[me.FLUOROOF];
   me.itself["level"].getNode("roof").setValue( level );

   # makes visible 3D warning lights by night
   if( me.is_night() ) {
       level = level * me.LIGHTAMBIENT;
   }
   else {
       level = me.LIGHTNO;
   }
   me.itself["level"].getNode("roof-ambient").setValue( level );

   level = me.lights[me.FLOODCAPTAIN];
   level = constant.intensity( level, me.lights[me.FLOODCENTER] );
   level = constant.intensity( level, me.lights[me.FLOODCOPILOT] );
   level = constant.intensity( level, me.lights[me.FLUOROOF] );
   me.itself["level"].getNode("human/copilot").setValue( level );
   me.itself["level"].getNode("panel/main").setValue( level );

   level = me.lights[me.FLOODCAPTAIN];
   level = constant.intensity( level, me.lights[me.FLUOROOF] );
   me.itself["level"].getNode("flood/captain").setValue( level );

   level = me.lights[me.FLOODCOPILOT];
   level = constant.intensity( level, me.lights[me.FLUOROOF] );
   me.itself["level"].getNode("flood/copilot").setValue( level );

   level = me.lights[me.FLOODCENTER];
   level = constant.intensity( level, me.lights[me.FLUOROOF] );
   me.itself["level"].getNode("flood/center").setValue( level );
   me.itself["level"].getNode("panel/center").setValue( level );
   me.itself["level"].getNode("panel/console").setValue( level );

   level = me.lights[me.FLOODENGINEER];
   level = constant.intensity( level, me.lights[me.FLUOROOF] );
   me.itself["level"].getNode("human/engineer").setValue( level );
   me.itself["level"].getNode("engineer/panel").setValue( level );

   level = me.lights[me.FLOODENGINEERSPOT];
   level = constant.intensity( level, me.lights[me.FLUOROOF] );
   me.itself["level"].getNode("engineer/deck").setValue( level );
}

LightLevel.failure = func {
   me.fluofailure();
   me.floodfailure();
}

LightLevel.fluofailure = func {
   me.itself["crew"].getNode(me.fluorescent).setValue(me.LIGHTNO);
}

LightLevel.floodfailure = func {
   for( var i=0; i < me.nbfloods; i=i+1 ) {
        me.itself["crew"].getNode(me.floods[i]).setValue(me.LIGHTNO);
   }
}

LightLevel.recover = func {
   me.fluorecover();
   me.floodrecover();
}

LightLevel.fluorecover = func {
   if( !me.powerfailure ) {
       me.failurerecover(me.fluorescentnorm,me.fluorescent,constant.FALSE);
   }
}

LightLevel.floodrecover = func {
   if( !me.itself["crew"].getChild("roof").getValue() and !me.powerfailure ) {
       for( var i=0; i < me.nbfloods; i=i+1 ) {
            # may change a flood light, during a fluo lighting
            me.failurerecover(me.floodnorms[i],me.floods[i],me.invisible);
       }
   }
}

# was no light, because of failure, or the knob has changed
LightLevel.failurerecover = func( propnorm, proplight, offset ) {
   var norm = me.itself["crew"].getNode(propnorm).getValue();

   if( norm != me.itself["crew"].getNode(proplight).getValue() ) {

       # flood cannot recover from fluorescent light without a change
       if( offset ) {
           if( norm > me.LIGHTNO and me.invisible ) {
               norm = norm - me.LIGHTINVISIBLE;
           }
       }

       me.itself["crew"].getNode(proplight).setValue(norm);
   }
}

LightLevel.is_night = func {
   var result = constant.FALSE;

   if( me.noinstrument["sun"].getValue() > constant.NIGHTRAD ) {
       result = constant.TRUE;
   }

   return result;
}


# ==========
# ANTI-ICING
# ==========

# reference :
# ---------
#  - http://fr.wikipedia.org/wiki/Concorde :
#  electric anti-icing (no air piping).

Antiicing = {};

Antiicing.new = func {
   var obj = { parents : [Antiicing,System],

               detector : Icedetection.new()
         };

   obj.init();

   return obj;
};

Antiicing.init = func {
    me.inherit_system("/systems/anti-icing");
}

Antiicing.red_ice = func {
    var result = constant.FALSE;

    if( me.itself["root"].getChild("warning").getValue() ) {
        if( !me.itself["power"].getChild("wing").getValue() ) {
            result = constant.TRUE;
        }
       
        else {
            for( i = 0; i < constantaero.NBENGINES; i=i+1 ) {
                 if( !me.itself["power"].getChild("engine",i).getValue() ) {
                     result = constant.TRUE;
                     break;
                 }
            }
        }
    }

    return result;
}

Antiicing.schedule = func {
    var serviceable = me.itself["root"].getChild("serviceable").getValue();
    var power = me.dependency["electric"].getChild("specific").getValue();
    var value = constant.FALSE;

    if( ( me.itself["wing"].getChild("main-selector").getValue() > 0 or
          me.itself["wing"].getChild("alternate-selector").getValue() > 0 ) and
          power and serviceable ) {
        value = constant.TRUE;
    }

    me.itself["power"].getChild("wing").setValue( value );

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.itself["engine"][i].getChild("inlet-vane").getValue() and
             power and serviceable ) {
             value = constant.TRUE;
         }
         else {
             value = constant.FALSE;
         }

         me.itself["power"].getChild("engine", i).setValue( value );
    }
}

Antiicing.slowschedule = func {
    me.detector.schedule();
}

setprop("/controls/lighting/instruments-norm",0.0);
setprop("/controls/lighting/crew/captain/flood-norm",0.2);

var _instrlight = setlistener("sim/signals/fdm-initialized", func() {
	sun=getprop("/sim/time/sun-angle-rad");
	if (sun<1.53){
	  setprop("/controls/lighting/instrument-lights",0);
	  } else{
	  setprop("/controls/lighting/instrument-lights",1);
	  setprop("/controls/lighting/instruments-norm",0.4);
	};
	
	removelistener(_instrlight); # run ONCE
});

var _clight = setlistener("sim/multiplay/generic/int[19]", func() {
	  setprop("/sim/multiplay/generic/int[19]",0);
});

