# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ================
# HYDRAULIC SYSTEM
# ================

Hydraulic = {};

Hydraulic.new = func {
   var obj = { parents : [Hydraulic,System], 

               parser : HydraulicXML.new(),
               ground : HydGround.new(),
               rat : Rat.new(),
               brakes : Brakes.new(),

               HYDSEC : 1.0,                                  # refresh rate

               HYDFAILUREPSI : 3400
         };

    obj.init();

    return obj;
}

Hydraulic.init = func() {
    me.inherit_system("/systems/hydraulic");

    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.set_rate = func( rates ) {
    me.HYDSEC = rates;

    me.parser.set_rate( me.HYDSEC );
    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.groundexport = func {
    me.ground.selectorexport();
}

Hydraulic.brakesparkingexport = func {
    me.brakes.parkingexport();
}

Hydraulic.brakesemergencyexport = func {
    me.brakes.emergencyexport();
}

Hydraulic.rattestexport = func {
    me.rat.testexport();
}

Hydraulic.ratdeployexport = func {
    me.rat.deployexport();
}

Hydraulic.amber_hydraulics = func {
    var result = constant.FALSE;

    if( me.itself["sensors"].getChild("green-left").getValue() < me.HYDFAILUREPSI or
        me.itself["sensors"].getChild("green-right").getValue() < me.HYDFAILUREPSI or
        me.itself["sensors"].getChild("yellow-left").getValue() < me.HYDFAILUREPSI or
        me.itself["sensors"].getChild("yellow-right").getValue() < me.HYDFAILUREPSI or
        me.itself["sensors"].getChild("blue-left").getValue() < me.HYDFAILUREPSI or
        me.itself["sensors"].getChild("blue-right").getValue() < me.HYDFAILUREPSI ) {
        result = constant.TRUE;
    }

    return result;
}

Hydraulic.red_intake = func( index ) {
    var result = constant.FALSE;

    if( me.itself["sensors"].getChild("intake", index).getValue() < me.HYDFAILUREPSI ) {
        result = constant.TRUE;
    }

    return result;
}

Hydraulic.red_feel = func {
    var result = constant.TRUE;

    if( me.has_green() or me.has_blue() ) {
        result = constant.FALSE;
    }

    return result;
}

Hydraulic.has_green = func {
   var result = constant.FALSE;
   var greenpsi = me.itself["sensors"].getChild("green").getValue();
   if( greenpsi == nil ) greenpsi = 0;
   if( greenpsi >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.has_yellow = func {
   var result = constant.FALSE;
   var yellowpsi = me.itself["sensors"].getChild("yellow").getValue();
   if( yellowpsi == nil ) yellowpsi = 0;
   if( yellowpsi >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.has_blue = func {
   var result = constant.FALSE;
   var bluepsi = me.itself["sensors"].getChild("blue").getValue();
   if( bluepsi == nil ) bluepsi = 0;
   if( bluepsi  >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.has_gear = func {
   var result = constant.FALSE;
   var gearpsi = me.itself["sensors"].getChild("gear").getValue();
   if( gearpsi == nil ) gearpsi = 0;
   if( gearpsi >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.has_no_steering = func {
   var result = 1.0;
   var steeringpsi = me.itself["sensors"].getChild("steering").getValue();
   if( steeringpsi == nil ) steeringpsi = 0;
   if( steeringpsi >= me.HYDFAILUREPSI ) {
       result = 0.0;
   }

   return result;
}

Hydraulic.has_flight = func {
   var result = constant.FALSE;
   var steeringpsi = me.itself["sensors"].getChild("flight").getValue();
   if( steeringpsi == nil ) steeringpsi = 0;
   if( steeringpsi >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.brakes_pedals = func( pressure ) {
   return me.brakes.pedals( pressure );
}

Hydraulic.schedule = func {
   me.ground.schedule();
   me.parser.schedule();

   var greenpsi = me.itself["sensors"].getChild("green").getValue();
   if( greenpsi == nil ) greenpsi = 0;
   var yellowpsi = me.itself["sensors"].getChild("yellow").getValue();
   if( yellowpsi == nil ) yellowpsi = 0;

   me.brakes.schedule( greenpsi, yellowpsi );

   me.itself["power"].getChild("blue").setValue( me.has_blue() );
   me.itself["power"].getChild("green").setValue( me.has_green() );
   me.itself["power"].getChild("yellow").setValue( me.has_yellow() );

   me.itself["power"].getChild("gear").setValue( me.has_gear() );
   me.itself["power"].getChild("steering-off").setValue( me.has_no_steering() );
   me.itself["power"].getChild("flight").setValue( me.has_flight() );
}


# =============
# GROUND SUPPLY
# =============
HydGround = {};

HydGround.new = func {
   var obj = { parents : [HydGround,System], 

               pumps : [ [ constant.FALSE, constant.TRUE , constant.TRUE , constant.FALSE ],     # Y-Y
                         [ constant.TRUE , constant.FALSE, constant.FALSE, constant.TRUE  ],     # G-B
                         [ constant.FALSE, constant.TRUE , constant.FALSE, constant.TRUE  ],     # B-Y
                         [ constant.FALSE, constant.TRUE , constant.TRUE , constant.FALSE ],     # Y-Y
                         [ constant.TRUE , constant.FALSE, constant.TRUE , constant.FALSE ],     # G-Y
                         [ constant.FALSE, constant.TRUE , constant.TRUE , constant.FALSE ] ]    # Y-Y
         };

    obj.init();

    return obj;
}

HydGround.init = func() {
    me.inherit_system("/systems/hydraulic");
}

HydGround.schedule = func {
   var selector = me.itself["ground"].getChild("selector").getValue();

   # magnetic release of the switch
   if( !me.dependency["electric"].getChild("ground-service").getValue() ) {
       for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
            me.itself["pump"][i].getChild("switch").setValue(constant.FALSE);
       }

       me.itself["circuit"][0].getChild("ground").setValue( constant.FALSE );
       me.itself["circuit"][1].getChild("ground", 0).setValue( constant.FALSE );
       me.itself["circuit"][1].getChild("ground", 1).setValue( constant.FALSE );
       me.itself["circuit"][2].getChild("ground").setValue( constant.FALSE );
   }

   if( me.itself["pump"][0].getChild("switch").getValue() ) {
       me.itself["circuit"][0].getChild("ground").setValue( me.pumps[selector][0] );
       me.itself["circuit"][1].getChild("ground", 0).setValue( me.pumps[selector][1] );
   }
   else {
       me.itself["circuit"][0].getChild("ground").setValue( constant.FALSE );
       me.itself["circuit"][1].getChild("ground", 0).setValue( constant.FALSE );
   }

   if( me.itself["pump"][1].getChild("switch").getValue() ) {
       me.itself["circuit"][1].getChild("ground", 1).setValue( me.pumps[selector][2] );
       me.itself["circuit"][2].getChild("ground").setValue( me.pumps[selector][3] );
   }
   else {
       me.itself["circuit"][1].getChild("ground", 1).setValue( constant.FALSE );
       me.itself["circuit"][2].getChild("ground").setValue( constant.FALSE );
   }
}


# ============
# WHEEL CHOCKS
# ============

WheelChocks = {};

WheelChocks.new = func {
   var obj = { parents : [WheelChocks,System] 
         };

   obj.init();

   return obj;
}

WheelChocks.init = func {
    me.inherit_system("/systems/brakes");
}

WheelChocks.toggle = func {
   if( me.dependency["gear-ctrl"].getChild("wheel-chocks").getValue() ) {
       me.dependency["gear-ctrl"].getChild("brake-parking").setValue(constantaero.BRAKEPARKING);
   }

   else {
       me.dependency["gear-ctrl"].getChild("brake-parking").setValue(constantaero.BRAKENORMAL);
   }
}

WheelChocks.schedule = func {
   var offsetmeter = 0.0;

   # adjust wheel chocks over ground
   if( me.dependency["gear-ctrl"].getChild("wheel-chocks").getValue() ) {
       for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
            offsetmeter = me.meter( i );
            me.dependency["gear-sys"][i].getChild("chock-z-m").setValue( offsetmeter );
       }
   }
}

WheelChocks.meter = func( index ) {
   var compressionnorm = me.dependency["gear"][index].getChild("compression-norm").getValue();

   var compressionminnorm = me.dependency["chocks-ctrl"][index].getChild("compression-min-norm").getValue();
   var compressionmaxnorm = me.dependency["chocks-ctrl"][index].getChild("compression-max-norm").getValue();
   var offsetminmeter  = me.dependency["chocks-ctrl"][index].getChild("offset-min-m").getValue();
   var offsetmaxmeter  = me.dependency["chocks-ctrl"][index].getChild("offset-max-m").getValue();

   var ratio = ( compressionmaxnorm - compressionnorm ) / ( compressionmaxnorm - compressionminnorm);
   var offsetmeter = ( offsetminmeter - offsetmaxmeter );

   var result = offsetmaxmeter + offsetmeter * ratio;

   return result;
}


# ======
# BRAKES
# ======

Brakes = {};

Brakes.new = func {
   var obj = { parents : [Brakes,System], 

               heat : BrakesHeat.new(),
               wheelchock : WheelChocks.new(),

               HYDSEC : 1.0,                               # refresh rate

               BRAKEACCUPSI : 3000.0,                      # yellow emergency/parking brakes accumulator
               BRAKEMAXPSI : 1200.0,                       # max brake pressure
               BRAKEYELLOWPSI : 900.0,                     # max abnormal pressure (yellow)
               BRAKEGREENPSI : 400.0,                      # max normal pressure (green)
               BRAKERESIDUALPSI : 15.0,                    # residual pressure of emergency brakes (1 atmosphere)
               HYDNOPSI : 0.0,

               BRAKEPSIPSEC : 400.0,                       # reaction time, when one applies brakes

               BRAKERATEPSI : 0.0,

               normalaccupsi : 0.0,
               leftbrakepsi : 0.0,
               rightbrakepsi : 0.0,
               emergaccupsi : 0.0,
               leftemergpsi : 0.0,
               rightemergpsi : 0.0
         };

   obj.init();

   return obj;
}

Brakes.init = func {
    me.inherit_system("/systems/brakes");

    me.set_rate( me.HYDSEC );

    # sets 3D lever from brake-parking-lever flag in Concorde-set.xml file
    me.lever();
}

Brakes.set_rate = func( rates ) {
    me.HYDSEC = rates;
    me.BRAKERATEPSI = me.BRAKEPSIPSEC * me.HYDSEC;

    me.heat.set_rate( rates );
}

Brakes.lever = func {
    # normal
    var pos = constantaero.BRAKENORMAL;

    # parking brake
    if( me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
        pos = constantaero.BRAKEPARKING;
    }

    # emergency (must be set by Captain)
    elsif( me.dependency["gear-ctrl"].getChild("brake-emergency").getValue() ) {
        pos = constantaero.BRAKEEMERGENCY;
    }

    # for 3D lever
    me.dependency["gear-ctrl"].getChild("brake-pos-norm").setValue(pos);
}

Brakes.emergencyexport = func {
    var value = constant.TRUE;
    var value2 = constant.FALSE;

    if( me.dependency["gear-ctrl"].getChild("brake-emergency").getValue() ) {
        value = constant.FALSE;
        value2 = constant.TRUE;
    }

    # toggles between parking and emergency
    me.dependency["gear-ctrl"].getChild("brake-emergency").setValue(value);
    me.dependency["gear-ctrl"].getChild("brake-parking-lever").setValue(value2);

    me.lever();
}

Brakes.parkingexport = func {
    var value = constant.TRUE;

    if( me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
        value = constant.FALSE;
    }

    # toggles between parking and normal
    me.dependency["gear-ctrl"].getChild("brake-emergency").setValue(constant.FALSE);
    me.dependency["gear-ctrl"].getChild("brake-parking-lever").setValue(value);

    me.lever();
}

Brakes.pedals = func( pressure ) {
    var action = constant.TRUE;
    var depress = me.has();

    # releases the pedals
    if( pressure == 0 ) {
        action = constant.FALSE;
    }

    me.itself["root"].getChild("pedals").setValue(action);

    return depress;
}

Brakes.has_emergency = func {
    var result = constant.TRUE;

    # TO DO : failure only on left or right
    if( me.itself["root"].getChild("yellow-accu-psi").getValue() < me.BRAKEACCUPSI ) {
        result = constant.FALSE;
    }

    return result;
}

Brakes.has_normal = func {
    var result = constant.TRUE;

    # TO DO : failure only on left or right
    if( me.itself["root"].getChild("green-accu-psi").getValue() < me.BRAKEACCUPSI ) {
        result = constant.FALSE;
    }

    return result;
}

Brakes.has = func {
    var result = constant.TRUE;
    var emergency = me.dependency["gear-ctrl"].getChild("brake-emergency").getValue();

    # TO DO : failure only on left or right
    if( ( !me.has_normal() and !emergency ) or
        ( !me.has_emergency() and emergency ) ) {
        result = constant.FALSE;
    }

    return result;
}

Brakes.schedule = func( greenpsi, yellowpsi ) {
   me.normal( greenpsi, yellowpsi );
   me.emergency( yellowpsi );
   me.accumulator();

   me.heat.schedule();
}

Brakes.accumulator = func {
   interpolate(me.itself["root"].getChild("green-accu-psi").getPath(),me.normalaccupsi,me.HYDSEC);
   interpolate(me.itself["root"].getChild("left-psi").getPath(),me.leftbrakepsi,me.HYDSEC);
   interpolate(me.itself["root"].getChild("right-psi").getPath(),me.rightbrakepsi,me.HYDSEC);

   interpolate(me.itself["root"].getChild("yellow-accu-psi").getPath(),me.emergaccupsi,me.HYDSEC);
   interpolate(me.itself["root"].getChild("emerg-left-psi").getPath(),me.leftemergpsi,me.HYDSEC);
   interpolate(me.itself["root"].getChild("emerg-right-psi").getPath(),me.rightemergpsi,me.HYDSEC);
}

Brakes.normal = func( greenpsi, yellowpsi ) {
   var targetbrakepsi = 0.0;

   # brake failure
   if( !me.dependency["gear-ctrl"].getChild("brake-emergency").getValue() ) {
       targetbrakepsi = me.normalpsi( greenpsi );

       # disable normal brake (joystick)
       if( me.normalfailure( targetbrakepsi ) ) {
       }

       # visualize apply of brake
       else {
           me.brakeapply( me.leftbrakepsi, me.rightbrakepsi, targetbrakepsi );
       }
   }

   # ermergency brake failure
   else {
       targetbrakepsi = me.emergencypsi( yellowpsi );

       # above the yellow area exceptionally allowed
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEMAXPSI );

       if( me.emergfailure( targetbrakepsi ) ) {
           # disable emergency brake (joystick)
       }

       # visualize apply of emergency brake
       else {
           me.brakeapply( me.leftemergpsi, me.rightemergpsi, targetbrakepsi );
       }
   }
}

Brakes.emergency = func( yellowpsi ) {
   var targetbrakepsi = me.emergencypsi( yellowpsi );

   # brake parking failure
   if( me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
       # stays in the green area
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );
       if( me.emergfailure( targetbrakepsi ) ) {
           # disable brake parking (keyboard)
           me.wheelchock.toggle();
       }

       # visualize apply of parking brake
       else {
           me.dependency["gear-ctrl"].getChild("brake-parking").setValue(constantaero.BRAKEPARKING);

           me.parkingapply( targetbrakepsi );
       }
   }

   # unused emergency/parking brakes have a weaker pressure
   else {
       me.wheelchock.toggle();

       if( me.normalaccupsi >= me.BRAKEACCUPSI ) {
           targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEMAXPSI );

           # yellow failure
           if( me.emergfailure( targetbrakepsi ) ) {
           }
           else {
               me.parkingapply( targetbrakepsi );
           }
       }
   }

   # adjust wheel chocks over ground
   me.wheelchock.schedule();
}

Brakes.normalpsi = func( pressurepsi ) {
   # normal brakes are on green circuit
   me.normalaccupsi = me.truncate( pressurepsi, me.BRAKEACCUPSI );

   # divide by 2 : left and right
   var targetbrakepsi = me.normalaccupsi / 2.0;

   # green has same action than yellow
   var targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );

   me.leftbrakepsi = me.itself["root"].getChild("left-psi").getValue();
   me.rightbrakepsi = me.itself["root"].getChild("right-psi").getValue();

   return targetbrakepsi;
}

Brakes.emergencypsi = func( pressurepsi ) {
   # emergency brakes accumulator
   me.emergaccupsi = me.truncate( pressurepsi, me.BRAKEACCUPSI );

   # divide by 2 : left and right
   var targetbrakepsi = me.emergaccupsi / 2.0;

   me.leftemergpsi = me.itself["root"].getChild("emerg-left-psi").getValue();
   me.rightemergpsi = me.itself["root"].getChild("emerg-right-psi").getValue();

   return targetbrakepsi;
}

Brakes.brakeapply = func( leftnormalpsi, rightnormalpsi, targetbrakepsi ) {
   var leftpsi = me.apply( me.dependency["gear-ctrl"].getChild("brake-left").getPath(), leftnormalpsi, targetbrakepsi );
   var rightpsi = me.apply( me.dependency["gear-ctrl"].getChild("brake-right").getPath(), rightnormalpsi, targetbrakepsi );

   me.leftbrakepsi = leftpsi;       # BUG ?
   me.rightbrakepsi = rightpsi;       # BUG ?
}

Brakes.parkingapply = func( targetbrakepsi ) {
   var leftpsi = me.apply( me.dependency["gear-ctrl"].getChild("brake-parking").getPath(), me.leftemergpsi, targetbrakepsi );
   var rightpsi = me.apply( me.dependency["gear-ctrl"].getChild("brake-parking").getPath(), me.rightemergpsi, targetbrakepsi );

   me.leftemergpsi = leftpsi;       # BUG ?
   me.rightemergpsi = rightpsi;       # BUG ?
}

Brakes.apply = func( pedal, brakepsi, targetpsi ) {
   var maxpsi = 0.0;
   var pedalpsi = 0.0;
   var pedalpos = getprop(pedal);

   # target is not greatest than the yellow pressure
   if( pedalpos > 0.0 ) {
       maxpsi = me.BRAKERESIDUALPSI + ( targetpsi - me.BRAKERESIDUALPSI ) * pedalpos; 
       pedalpsi = me.increase( brakepsi, maxpsi );
   }
   # visualize release of brake
   else {
       pedalpsi = me.decrease( brakepsi, me.BRAKERESIDUALPSI );
   }

   return pedalpsi;
}

Brakes.normalfailure = func( targetbrakepsi ) {
   var leftpsi = 0.0;
   var rightpsi = 0.0;
   var result = constant.FALSE;

   if( targetbrakepsi < me.BRAKEGREENPSI ) {
       leftpsi = me.decrease( me.leftbrakepsi, targetbrakepsi );
       rightpsi = me.decrease( me.rightbrakepsi, targetbrakepsi );

       me.leftbrakepsi = leftpsi;       # BUG ?
       me.rightbrakepsi = rightpsi;       # BUG ?

       result = constant.TRUE;
   }

   return result;
}

Brakes.emergfailure = func( targetbrakepsi ) {
   var leftpsi = 0.0;
   var rightpsi = 0.0;
   var result = constant.FALSE;

   if( targetbrakepsi < me.BRAKEGREENPSI ) {
       leftpsi = me.decrease( me.leftemergpsi, targetbrakepsi );
       rightpsi = me.decrease( me.rightemergpsi, targetbrakepsi );

       me.leftemergpsi = leftpsi;       # BUG ?
       me.rightemergpsi = rightpsi;       # BUG ?

       result = constant.TRUE;
   }

   return result;
}

Brakes.increase = func( pressurepsi, maxpsi ) {
    var resultpsi = pressurepsi + me.BRAKERATEPSI;

    if( resultpsi > maxpsi ) {
        resultpsi = maxpsi;
    }

    return resultpsi;
}

Brakes.decrease = func( pressurepsi, minpsi ) {
    var resultpsi = pressurepsi - me.BRAKERATEPSI;

    if( resultpsi < minpsi ) {
        resultpsi = minpsi;
    }

    return resultpsi;
}

Brakes.truncate = func( pressurepsi, maxpsi ) {
    var resultpsi = pressurepsi;

    if( pressurepsi > maxpsi ) {
        resultpsi = maxpsi;
    }

    return resultpsi;
}


# ===========
# BRAKES HEAT
# ===========

# reference :
# ---------
#  - http://en.wikipedia.org/wiki/Concorde :
#  several hours of cooling (300-500 degC) after an aborted takeoff (before V1).
#  - http://en.wikipedia.org/wiki/Heat_conduction :
#  Newton's law of cooling, T = Tenv + ( To - Tenv ) exp( - t / t0 ).

BrakesHeat = {};

BrakesHeat.new = func {
   var obj = { parents : [BrakesHeat,System], 

               COOLSEC : 1000,                             # ( 500 - 15 ) degc / 2 hours
               HYDSEC : 1.0,

               timesec : 0.0,

               WARMKT2TODEGCPSEC : 0.0184,                 # (500 - 15 ) degc / ( 160 kt x 160 kt )

               lastspeedkt : 0.0,

               ABRUPTDEGC : 1.0,

               lastoatdegc : 0.0,
               tempdegc : 0.0,
               tempmaxdegc : 0.0,
               temppeakdegc : 0.0
         };

   obj.init();

   return obj;
}

BrakesHeat.init = func {
    me.inherit_system("/systems/brakes");

    me.set_rate( me.HYDSEC );

    me.tempdegc = me.itself["root"].getChild("temperature-degc").getValue();
    me.tempmaxdegc = me.itself["root"].getChild("temp-max-degc").getValue();
    me.lastoatdegc = me.tempdegc;
    me.peak();
}

BrakesHeat.set_rate = func( rates ) {
    me.HYDSEC = rates;

    me.set_rate_ancestor( me.HYDSEC );

    me.WARMKT2TODEGCPSEC = me.WARMKT2TODEGCPSEC * me.HYDSEC;
}

BrakesHeat.schedule = func {
   if( !me.warming() ) {
       me.cooling();
   }

   me.itself["root"].getChild("temperature-degc").setValue(me.tempdegc);

   if( me.tempdegc > me.tempmaxdegc ) {
       me.tempmaxdegc = me.tempdegc;
       me.itself["root"].getChild("temp-max-degc").setValue(me.tempmaxdegc);

       # gauge
       if( !me.itself["root"].getChild("test").getValue() ) {
           me.itself["root"].getChild("test-degc").setValue(me.tempmaxdegc);
       }
   }
}

BrakesHeat.warming = func {
   var result = constant.FALSE;
   var speedkt = me.noinstrument["airspeed"].getValue();

   if( me.noinstrument["agl"].getValue() < constantaero.AGLTOUCHFT ) {
       if( me.noinstrument["gear"].getValue() ) {
           var left = 0.0;
           var right = 0.0;
           var allbrakes = 0.0;
           var stepkt2 = 0.0;
           var stepdegc = 0.0;

           left = me.dependency["gear-ctrl"].getChild("brake-left").getValue();
           right = me.dependency["gear-ctrl"].getChild("brake-right").getValue();
           allbrakes = left + right;

           if( allbrakes > 0.0 ) {
               # aborted takeoff at V1 (160 kt) heats until 300-500 degc
               if( speedkt < me.lastspeedkt ) {
                   # conversion of kinetic energy to heat
                   stepkt2 = ( me.lastspeedkt * me.lastspeedkt - speedkt * speedkt );
                   stepdegc = stepkt2 * me.WARMKT2TODEGCPSEC;
                   stepdegc = allbrakes * stepdegc;

                   result = constant.TRUE;

                   me.tempdegc = me.tempdegc + stepdegc;
                   me.peak();
               }
           }
       }
   }

   me.lastspeedkt = speedkt;

   return result;
}

BrakesHeat.cooling = func {
   var ratio = 0.0;
   var diffdegc = 0.0;
   var oatdegc = me.noinstrument["temperature"].getValue();

   me.curvestep( oatdegc );

   # exponential cooling
   if( !me.is_relocating() ) {
       ratio = - me.timesec / me.COOLSEC;
       diffdegc = ( me.temppeakdegc - oatdegc ) * math.exp( ratio );
       me.tempdegc = oatdegc + diffdegc;
   }

   me.lastoatdegc = oatdegc;
}

BrakesHeat.peak = func {
   me.temppeakdegc = me.tempdegc;

   me.curvereset();
}

BrakesHeat.curvestep = func( oatdegc ) {
   # cooling curve within a stable environment.
   if( constant.within( oatdegc, me.lastoatdegc, me.ABRUPTDEGC ) ) {  
       me.timesec = me.timesec + me.speed_timesec( me.HYDSEC );
   }

   # new cooling curve, with new boundary conditions, imposed by external air mass.
   else {
       me.curvereset();
   }
}

BrakesHeat.curvereset = func {
   me.timesec = 0.0;
}


# ===============
# RAM AIR TURBINE
# ===============
Rat = {};

Rat.new = func {
   var obj = { parents : [Rat, System],

               TESTSEC : 2.5,
               DEPLOYSEC : 1.5
         };

   obj.init();

   return obj;
}

Rat.init = func() {
    me.inherit_system("/systems/hydraulic");
}

Rat.testexport = func {
   me.test();
}

Rat.test = func {
    if( me.itself["rat"].getChild("test").getValue() ) {
        me.itself["rat-ctrl"][0].getChild("test").setValue(constant.FALSE);
        me.itself["rat-ctrl"][1].getChild("test").setValue(constant.FALSE);
        me.itself["rat"].getChild("test").setValue( constant.FALSE );
    }

    elsif( me.itself["rat-ctrl"][0].getChild("test").getValue() or
           me.itself["rat-ctrl"][1].getChild("test").getValue() ) {
        me.itself["rat"].getChild("test").setValue( constant.TRUE );

        # shows the light
        settimer(func { me.test(); }, me.TESTSEC);
    }
}

Rat.deployexport = func {
    me.dependency["emergency"].getChild("standby").setValue( constant.TRUE );

    me.deploy();
}

Rat.deploy = func {
    if( me.itself["rat"].getChild("deploying").getValue() ) {
        me.itself["rat"].getChild("deploying").setValue( constant.FALSE );
        me.itself["rat"].getChild("deployed").setValue( constant.TRUE );
    }

    elsif( me.itself["rat-ctrl"][0].getChild("on").getValue() or
           me.itself["rat-ctrl"][1].getChild("on").getValue() ) {

        if( !me.itself["rat"].getChild("deployed").getValue() and
            !me.itself["rat"].getChild("deploying").getValue() ) {
            me.itself["rat"].getChild("deploying").setValue( constant.TRUE );

            # delay of deployment
            settimer(func { me.deploy(); }, me.DEPLOYSEC);
        }
    }
}


# ===========
# GEAR SYSTEM
# ===========

Gear = {};

Gear.new = func {
   var obj = { parents : [Gear, System],

               damper : PitchDamper.new(),

               STEERINGKT : 25,

               GEARSEC : 5.0
         };

   obj.init();

   return obj;
}

Gear.init = func {
    me.inherit_system("/systems/gear");

    settimer( func { me.schedule(); }, me.GEARSEC );
}

Gear.steeringexport = func {
   var result = constant.FALSE;

   # taxi with steering wheel, rudder pedal at takeoff
   if( me.noinstrument["airspeed"].getValue() < me.STEERINGKT ) {

       # except forced by menu
       if( !me.dependency["steering"].getChild("pedal").getValue() ) {
           result = constant.TRUE;
       }
   }

   me.dependency["steering"].getChild("wheel").setValue(result);
}

Gear.schedule = func {
    var rates = me.damper.schedule();

    me.steeringexport();
    me.steering();

    settimer( func { me.schedule(); }, rates );
}

Gear.steering = func {
    # on ground, inhibit if no hydraulics
    if( !me.dependency["hydraulic"].getChild("green").getValue() and !me.dependency["hydraulic"].getChild("yellow").getValue() and me.dependency["weight"].getChild("wow").getValue() ) 
    {
        me.itself["steering"].getChild("hydraulic").setValue( constant.FALSE );
    }

    if((me.dependency["hydraulic"].getChild("green").getValue() or me.dependency["hydraulic"].getChild("yellow").getValue()) and me.dependency["weight"].getChild("wow").getValue() ) 
    {
        me.itself["steering"].getChild("hydraulic").setValue( constant.TRUE );
    }
}

Gear.can_up = func {
   var result = constant.FALSE;

   if( me.dependency["electric"].getValue() ) {
       if( me.dependency["hydraulic"].getChild("gear").getValue() ) {
           # prevents retract on ground
           if( me.noinstrument["agl"].getValue() > constantaero.GEARFT ) {
               if( me.itself["root-ctrl"].getChild("gear-down").getValue() ) {
                   result = constant.TRUE;
               }
           }
       }
   }

   return result;
}

Gear.can_down = func {
   var result = constant.FALSE;

   if( me.dependency["electric"].getValue() ) {
       if( me.dependency["hydraulic"].getChild("gear").getValue() ) {
           if( !me.itself["root-ctrl"].getChild("gear-down").getValue() ) {
               result = constant.TRUE;
           }
       }
   }

   return result;
}

Gear.can_standby = func {
   var result = constant.FALSE;

   if( me.dependency["electric"].getValue() ) {
       if( me.dependency["hydraulic"].getChild("yellow").getValue() ) {
           if( !me.itself["root-ctrl"].getChild("gear-down").getValue() ) {
               result = constant.TRUE;
           }
       }
   }

   return result;
}

Gear.standbyexport = func {
   if( me.can_standby() ) {
       if( !me.itself["root-ctrl"].getChild("gear-down").getValue() ) {
           me.itself["root-ctrl"].getChild("gear-down").setValue( constant.TRUE );
       }
   }
}


# ============
# PITCH DAMPER
# ============

PitchDamper = {};

PitchDamper.new = func {
   var obj = { parents : [PitchDamper,System],

               wow : WeightSwitch.new(),

               DAMPERSEC : 1.0,
               TOUCHSEC : 0.2,                                      # to detect touch down

               rates : 0.0,

               TOUCHDEG : 5.0,

               rebound : constant.FALSE,

               DAMPERDEGPS : 1.0,

               field : { "left" : "bogie-left-deg", "right" : "bogie-right-deg" }
         };

   obj.init();

   return obj;
}

PitchDamper.init = func {
    me.inherit_system("/systems/gear");
}

PitchDamper.schedule = func {
    me.rates = me.wow.schedule();

    me.damper( "left" );
    me.damper( "right" );

    return me.rates;
}

PitchDamper.set_rate = func( rates ) {
    if( rates < me.rates ) {
        me.rates = rates;
    }
}

PitchDamper.damper = func( name ) {
    var target = 0.0;
    var path = "";
    var result = me.itself["root"].getChild(me.field[name]).getValue();

    # shock at touch down
    if( me.wow.bogie(name) ) {
        target = me.noinstrument["pitch"].getValue();

        # aft tyre rebounds over runway
        if( result == 0.0 ) {
            target = target + me.TOUCHDEG;
            me.itself["root"].getChild(me.field[name]).setValue(target);
            me.rebound = constant.TRUE;
            me.set_rate( me.TOUCHSEC );
        }

        # end of rebound
        elsif( me.rebound ) {
            me.itself["root"].getChild(me.field[name]).setValue(target);
            me.rebound = constant.FALSE;
            me.set_rate( me.TOUCHSEC );
        }

        # rolling
        else {
            path = me.itself["root"].getChild(me.field[name]).getPath();
            me.rebound = constant.FALSE;
            me.set_rate( me.DAMPERSEC );
            interpolate(path,target,me.rates);
        }
    }

    # pitch damper
    elsif( result != 0.0 ) {
        target = result - me.DAMPERDEGPS * me.rates;
        if( target < 0.0 ) {
            target = 0.0;
        }

        path = me.itself["root"].getChild(me.field[name]).getPath();
        interpolate(path,target,me.rates);
        me.rebound = constant.FALSE;
    }
}


# =============
# WEIGHT SWITCH
# =============

WeightSwitch = {};

WeightSwitch.new = func {
  var  obj = { parents : [WeightSwitch,System],

               AIRSEC : 15.0,
               TOUCHSEC : 0.2,                                      # to detect touch down

               rates : 0.0,

               LANDFT : 500.0,
               AIRFT : 50.0,
  
               tyre : { "left" : 2, "right" : 4 },
               ground : { "left" : constant.TRUE, "right" : constant.TRUE }
         };

   obj.init();

   return obj;
}

WeightSwitch.init = func {
    me.inherit_system("/instrumentation/weight-switch");
}

WeightSwitch.schedule = func {
    var result = constant.FALSE;
    var aglft = me.noinstrument["agl"].getValue();

    me.rates = me.AIRSEC;

    me.gear( "left", aglft );
    me.gear( "right", aglft );

    if( me.ground["left"] or me.ground["right"] ) {
        result = constant.TRUE;
    }

    me.itself["root"].getChild("wow").setValue(result);

    return me.rates;
}

WeightSwitch.gear = func( name, aglft ) {
    # touch down
    if( me.dependency["gear"][me.tyre[name]].getChild("wow").getValue() ) {
        if( aglft < me.AIRFT ) {
            me.ground[name] = constant.TRUE;
        }

        # wow not reset in air (bug)
        else {
            if( aglft < me.LANDFT ) {
                me.rates = me.TOUCHSEC;
            }

            me.ground[name] = constant.FALSE;
        }
    }

    # lift off
    else {
        if( aglft < me.LANDFT ) {
            me.rates = me.TOUCHSEC;
        }

        me.ground[name] = constant.FALSE;
    }
}

WeightSwitch.bogie = func( name ) {
    return me.ground[name];
}


# ==========
# NOSE VISOR
# ==========

NoseVisor = {};

NoseVisor.new = func {
   var obj = { parents : [NoseVisor, System],

               VISORDOWN : 0.0
         };

   obj.init();

   return obj;
};

NoseVisor.init = func() {
    me.inherit_system("/instrumentation/nose-visor");

    me.VISORDOWN = me.noinstrument["setting"][1].getValue();
}

NoseVisor.has_nose_down = func {
   var result = constant.FALSE;

   if( me.itself["root-ctrl"].getChild("pos-norm").getValue() > me.VISORDOWN ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.is_visor_down = func {
   var result = constant.FALSE;

   if( me.itself["root"].getChild("pos-norm").getValue() >= me.VISORDOWN ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.can_up = func {
   var result = constant.FALSE;

   if( me.dependency["hydraulic"].getChild("green").getValue() ) {
       # raising of visor is not allowed, if wiper is not parked
       if( me.dependency["wiper"].getValue() ) {
           if( me.has_nose_down() ) {
               result = constant.TRUE;
           }
           elsif( me.itself["root-ctrl"].getChild("wiper-override").getValue() ) {
               result = constant.TRUE;
           }
       }
       else {
           result = constant.TRUE;
       }
   }

   return result;
}

NoseVisor.can_down = func {
   var result = constant.FALSE;

   if( me.dependency["hydraulic"].getChild("green").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.can_standby = func {
   var result = constant.FALSE;

   if( me.dependency["hydraulic"].getChild("yellow").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.standbyexport = func {
   if( me.can_standby() ) {
       override_flapsDown(1);
   }
}



# ======================
# FLIGHT CONTROLS SYSTEM
# ======================

Flight = {};

Flight.new = func {
   var obj = { parents : [Flight,System], 

               elevondown : 0.0,                             # by gravity
               
               POSNEUTRAL : 0.0,
               POSDOWN : 1.0,
               
               FLIGHTSEC : 3.0,                              # refresh rate

               WINDKT : 40
         };

    obj.init();

    return obj;
}

Flight.init = func() {
    me.inherit_system("/systems/flight");
    
    # bind jsbsim property
    me.itself["root"].getChild("gravity").setValue( me.elevondown );
}

Flight.resetexport = func {
   var result = constant.FALSE;

   # at least an inverter
   if( me.dependency["electric"].getChild("flight-control-monitoring").getValue() ) {
       var blue = constant.FALSE;
       var green = constant.FALSE;

       blue = me.dependency["electric"].getChild("channel-blue").getValue();
       if( blue ) {
           blue = me.dependency["hydraulic"].getChild("blue").getValue();
       }

       if( !blue ) {
           green = me.dependency["electric"].getChild("channel-green").getValue();
           if( green ) {
               green = me.dependency["hydraulic"].getChild("green").getValue();
           }

           if( !me.itself["channel"].getChild("inner-mechanical").getValue() ) {
               if( !green ) {
                   me.itself["channel"].getChild("inner-mechanical").setValue( constant.TRUE );
               }
               elsif( me.itself["channel"].getChild("inner-blue").getValue() ) {
                   me.itself["channel"].getChild("inner-blue").setValue( constant.FALSE );
               }
           }

           if( !me.itself["channel"].getChild("outer-mechanical").getValue() ) {
               if( !green ) {
                   me.itself["channel"].getChild("outer-mechanical").setValue( constant.TRUE );
               }
               elsif( me.itself["channel"].getChild("outer-blue").getValue() ) {
                   me.itself["channel"].getChild("outer-blue").setValue( constant.FALSE );
               }
           }

           if( !me.itself["channel"].getChild("rudder-mechanical").getValue() ) {
               if( !green ) {
                   me.itself["channel"].getChild("rudder-mechanical").setValue( constant.TRUE );
               }
               elsif( me.itself["channel"].getChild("rudder-blue").getValue() ) {
                   me.itself["channel"].getChild("rudder-blue").setValue( constant.FALSE );
               }
           }
       }

       result = constant.TRUE;
   } 

   return result;
}

Flight.red_pfc = func {
   var result = constant.FALSE;

   if( !me.dependency["electric"].getChild("inverter-blue").getValue() or
       !me.dependency["hydraulic"].getChild("blue").getValue() or
       !me.dependency["hydraulic"].getChild("green").getValue() or
       !me.dependency["electric"].getChild("inverter-green").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Flight.schedule = func {
   # avoid reset by FDM or system initialization
   if( me.is_ready() ) {
       me.monitoring();
   }
}

Flight.monitoring = func {
   var gravity = me.POSNEUTRAL;
   var pfcu_inner = constant.FALSE;
   var pfcu_outer = constant.FALSE;
   var pfcu_rudder = constant.FALSE;

   # automatic swap to mechanical channel, only with flight control monitoring;
   # otherwise surfaces freely floats into the wind, until crew swap manually to mechanical channel.
   if( !me.resetexport() ) {
       if( !me.itself["channel"].getChild("inner-mechanical").getValue() ) {
           pfcu_inner = constant.TRUE;
       }

       if( !me.itself["channel"].getChild("outer-mechanical").getValue() ) {
           pfcu_outer = constant.TRUE;
       }

       if( !me.itself["channel"].getChild("rudder-mechanical").getValue() ) {
           pfcu_rudder = constant.TRUE;
       }
   }

   # surfaces float into the wind
   if( me.noinstrument["airspeed"].getValue() > me.WINDKT ) {
       me.itself["pfcu"].getChild("inner-zero").setValue( pfcu_inner );
       me.itself["pfcu"].getChild("outer-zero").setValue( pfcu_outer );
       me.itself["pfcu"].getChild("rudder-zero").setValue( pfcu_rudder );

       me.itself["pfcu"].getChild("inner-stuck").setValue( constant.FALSE );
       me.itself["pfcu"].getChild("outer-stuck").setValue( constant.FALSE );
       me.itself["pfcu"].getChild("rudder-stuck").setValue( constant.FALSE );
   }

   # without wind and hydraulics, surfaces fall down
   # http://www.concordesst.com/flightsys.html
   else {
       if( !me.dependency["hydraulic"].getChild("flight").getValue() ) {
           gravity = me.POSDOWN;
       }
       
       me.itself["pfcu"].getChild("inner-zero").setValue( constant.FALSE );
       me.itself["pfcu"].getChild("outer-zero").setValue( constant.FALSE );
       me.itself["pfcu"].getChild("rudder-zero").setValue( constant.FALSE );

       me.itself["pfcu"].getChild("inner-stuck").setValue( constant.FALSE );
       me.itself["pfcu"].getChild("outer-stuck").setValue( constant.FALSE );
       me.itself["pfcu"].getChild("rudder-stuck").setValue( constant.FALSE );
   }
   
   if( me.elevondown != gravity ) {
       me.elevondown = gravity;
       interpolate(me.itself["root"].getChild("gravity").getPath(),me.elevondown,me.FLIGHTSEC);
   }
}


# =====
# DOORS
# =====

Doors = {};

Doors.new = func {
   var obj = { parents : [Doors,System],

               INSIDEDECKZM : 10.60,

               DOORCLOSED : 0.0,

               flightdeck : nil,
               engineerdeck : nil
         };

# user customization
   obj.init();

   return obj;
};

Doors.init = func {
   me.inherit_system( "/systems/doors" );

   # 10 s, door closed
   me.flightdeck = aircraft.door.new(me.itself["root-ctrl"].getNode("flight-deck").getPath(), 10.0);

   # 4 s, deck out
   me.engineerdeck = aircraft.door.new(me.itself["root-ctrl"].getNode("engineer-deck").getPath(), 4.0);

   if( me.itself["root-ctrl"].getNode("flight-deck").getChild("opened").getValue() ) {
       me.flightdeck.toggle();
   }
   if( !me.itself["root-ctrl"].getNode("engineer-deck").getChild("out").getValue() ) {
       me.engineerdeck.toggle();
   }
}

Doors.flightdeckexport = func {
   var allowed = constant.TRUE;

   if( me.itself["root-ctrl"].getNode("flight-deck").getChild("position-norm").getValue() == me.DOORCLOSED ) {
       # locked in flight
       if( me.itself["root-ctrl"].getNode("flight-deck").getChild("normal").getValue() ) {
           # can open only from inside
           if( me.noinstrument["view"].getValue() > me.INSIDEDECKZM ) {
               allowed = constant.FALSE;
           }
       }
   }

   if( allowed ) {
       me.flightdeck.toggle();
   }
}

Doors.engineerdeckexport = func {
   var state = constant.TRUE;

   me.engineerdeck.toggle();

   if( me.itself["root-ctrl"].getNode("engineer-deck").getChild("out").getValue() ) {
       state = constant.FALSE;
   }

   me.itself["root-ctrl"].getNode("engineer-deck").getChild("out").setValue(state);
}


# =======
# TRACTOR
# =======

Tractor = {};

Tractor.new = func {
   var obj = { parents : [Tractor,System],

               TRACTORSEC : 10.0,

               SPEEDFPS : 5.0,
               STOPFPS : 0.0,

               CONNECTED : 1.0,
               DISCONNECTED : 0.0,

               disconnecting : constant.FALSE,

               initial : nil
             };

# user customization
   obj.init();

   return obj;
};

Tractor.init = func {
   me.inherit_system( "/systems/tractor" );
}

Tractor.schedule = func {
   if( me.itself["root-ctrl"].getChild("pushback").getValue() ) {
       me.start();
   }

   me.move();
}

Tractor.move = func {
   if( me.itself["root"].getChild("pushback").getValue() and !me.disconnecting ) {
       var status = "";
       var latlon = geo.aircraft_position();
       var rollingmeter = latlon.distance_to( me.initial );

       status = sprintf(rollingmeter, "1f.0");

       # wait for tractor connect
       if( me.dependency["pushback"].getChild("position-norm").getValue() == me.CONNECTED ) {
           var ratefps = math.sgn( me.itself["root-ctrl"].getChild("distance-m").getValue() ) * me.SPEEDFPS;

           me.dependency["pushback"].getChild("target-speed-fps").setValue( ratefps );
       }

       if( rollingmeter >= math.abs( me.itself["root-ctrl"].getChild("distance-m").getValue() ) ) {
           # wait for tractor disconnect
           me.disconnecting = constant.TRUE;

           me.dependency["pushback"].getChild("target-speed-fps").setValue( me.STOPFPS );
           interpolate(me.dependency["pushback"].getChild("position-norm").getPath(), me.DISCONNECTED, me.TRACTORSEC);

           status = "";
       }

       me.itself["root"].getChild("distance-m").setValue( status );
   }

   # tractor disconnect
   elsif( me.disconnecting ) {
       if( me.dependency["pushback"].getChild("position-norm").getValue() == me.DISCONNECTED ) {
           me.disconnecting = constant.FALSE;

           me.dependency["pushback"].getChild("enabled").setValue( constant.FALSE );

           # interphone to copilot
           me.itself["root"].getChild("clear").setValue( constant.TRUE );
           me.itself["root"].getChild("pushback").setValue( constant.FALSE );
       }
   }
}

Tractor.start = func {
   # must wait for end of current movement
   if( !me.itself["root"].getChild("pushback").getValue() ) {
       me.disconnecting = constant.FALSE;

       me.initial = geo.aircraft_position();

       me.itself["root-ctrl"].getChild("pushback").setValue( constant.FALSE );
       me.itself["root"].getChild("pushback").setValue( constant.TRUE );
       me.itself["root"].getChild("clear").setValue( constant.FALSE );
       me.itself["root"].getChild("engine14").setValue( constant.FALSE );

       me.dependency["pushback"].getChild("enabled").setValue( constant.TRUE );
       interpolate(me.dependency["pushback"].getChild("position-norm").getPath(), me.CONNECTED, me.TRACTORSEC);
   }
}
