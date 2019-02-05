# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by sched are called from cron
# HUMAN : functions ending by human are called by artificial intelligence


# Like the real Concorde : see http://www.concordesst.com.



# ============
# AUTOTHROTTLE
# ============

Autothrottle = {};

Autothrottle.new = func {
   var obj = { parents : [Autothrottle,System],

               SPEEDACQUIRESEC : 2.0,

               MAXMACH : 2.02,
               CRUISEMACH : 2.0,

               LIGHTKT : 10.0,

               engaged_channel : constantaero.APNONE
         };

# autopilot initialization
   obj.init();

   return obj;
}

Autothrottle.init = func {
   me.inherit_system("/systems/autothrottle");

   me.atdiscexport();
}

Autothrottle.schedule = func {
   # disconnect autothrottle if no voltage (TO DO by FG)
   me.voltage();

   me.autothrottleswitch();
}

Autothrottle.autothrottleswitch = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();
   var mode = "";

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.dependency["engine"][i].getChild("autothrottle").getValue() and
            me.dependency["throttle"][i].getChild("available").getValue() ) {
            mode = speedmode;
        }
        else {
            mode = "";
        }
        me.itself["engine"][i].setValue( mode );
   }
}

Autothrottle.slowschedule = func {
   me.iaslight();
   me.releasedatum();
}

Autothrottle.get_component = func( name ) {
    return me.dependency[name][me.engaged_channel];
}

Autothrottle.get_asi = func {
    return me.get_component("asi");
}

Autothrottle.get_mach = func {
    return me.get_component("mach");
}

Autothrottle.engagechannel = func( index, value ) {
    me.itself["channel"][index].getChild("engage").setValue(value);

    me.whichchannel();
}

Autothrottle.whichchannel = func {
    # records the 1st channel of autoland; otherwise must disengage to swap.
    if( me.itself["channel"][constantaero.AP1].getChild("engage").getValue() ) {
        if( !me.itself["channel"][constantaero.AP2].getChild("engage").getValue() ) {
            me.engaged_channel = constantaero.AP1;
        }
    }
    elsif( me.itself["channel"][constantaero.AP2].getChild("engage").getValue() ) {
        if( !me.itself["channel"][constantaero.AP1].getChild("engage").getValue() ) {
            me.engaged_channel = constantaero.AP2;
        }
    }

    # crash if channel access !
    else {
        me.engaged_channel = constantaero.APNONE;
    }
}

# ias light, when discrepancy with the autothrottle
Autothrottle.iaslight = func {
   var speedkt = 0.0;
   var minkt = 0.0;
   var maxkt = 0.0;

   if( me.is_engaged() ) {
       if( me.is_speed_throttle() ) {
           speedkt = me.itself["settings"].getChild("target-speed-kt").getValue();

           # ias light within 10 kt
           minkt = speedkt - me.LIGHTKT;
           me.itself["airspeed"].getChild("light-min-kt").setValue(minkt);
           maxkt = speedkt + me.LIGHTKT;
           me.itself["airspeed"].getChild("light-max-kt").setValue(maxkt);
       }
   }
}

Autothrottle.is_maxcruise = func {
    var speed2 = me.itself["autoflight"].getChild("speed2").getValue();
    var result = constant.FALSE;

    if( speed2 == "maxcruise" ) {
        result = constant.TRUE;
    }

    return result;
}

Autothrottle.is_maxclimb = func {
    var speed2 = me.itself["autoflight"].getChild("speed2").getValue();
    var result = constant.FALSE;

    if( speed2 == "maxclimb" or speed2 == "maxcruise" ) {
        result = constant.TRUE;
    }

    return result;
}

Autothrottle.discmaxclimb = func {
    if( me.is_maxclimb() ) {
        # switch to speed hold
        me.atdiscspeed2();
    }
}

# max climb mode
Autothrottle.maxclimb = func {
   if( me.is_engaged() ) {
       var speedmach = me.get_mach().getChild("indicated-mach").getValue();

       # climb
       if( speedmach < constantaero.REHEATMACH ) {
           var vmokt = me.get_asi().getChild("vmo-kt").getValue();

           # catches the VMO with autothrottle
           me.speed(vmokt);
           me.atactivatemode("speed","speed-with-throttle");

           if( me.is_maxcruise() ) {
               me.atactivatemode("speed2","maxclimb");
           }
       }

       # cruise
       else {
           var altft = me.dependency["altimeter"].getChild("indicated-altitude-ft").getValue();
           var mmomach = me.get_mach().getChild("mmo-mach").getValue();

           # cruise at Mach 2.0-2.02 (reduce fuel consumption)          
           if( mmomach > me.MAXMACH ) {
               mmomach = me.MAXMACH;
           }

           # TO DO : control TMO over 128C
           # catches the MMO with autothrottle
           me.mach(mmomach);

           if( speedmach > me.CRUISEMACH or altft > constantaero.MAXCRUISEFT ) {
               me.atactivatemode2("speed","mach-with-throttle","maxcruise");
           }
           else {
               me.atactivatemode2("speed","mach-with-throttle","maxclimb");
           }
       }
   }

   me.atengage();
}

Autothrottle.no_voltage = func {
   var result = constant.FALSE;

   if( ( !me.dependency["electric"].getChild("autopilot", constantaero.AP1).getValue() and
         !me.dependency["electric"].getChild("autopilot", constantaero.AP2).getValue() ) or
       ( !me.itself["autothrottle"][constantaero.AP1].getChild("serviceable").getValue() and
         !me.itself["autothrottle"][constantaero.AP2].getChild("serviceable").getValue() ) ) {
       result = constant.TRUE;
   }

   return result;
}

# disconnect if no voltage (cannot disable the autopilot !)
Autothrottle.voltage = func() {
   var voltage1 = me.dependency["electric"].getChild("autopilot", constantaero.AP1).getValue();
   var voltage2 = me.dependency["electric"].getChild("autopilot", constantaero.AP2).getValue();
   var channel = constant.FALSE;

   if( voltage1 ) {
       voltage1 = me.itself["autothrottle"][constantaero.AP1].getChild("serviceable").getValue();
   }
   if( voltage2 ) {
       voltage2 = me.itself["autothrottle"][constantaero.AP2].getChild("serviceable").getValue();
   }

   if( !voltage1 or !voltage2 ) {
       # disconnect autothrottle 1
       if( !voltage1 ) {
           channel = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
           if( channel ) {
               me.engagechannel(constantaero.AP1, constant.FALSE);
               channel = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();
               if( !channel ) {
                   me.atdiscexport();
               }
           }
       }

       # disconnect autothrottle 2
       if( !voltage2 ) {
           channel = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();
           if( channel ) {
               me.engagechannel(constantaero.AP2, constant.FALSE);
               channel = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
               if( !channel ) {
                   me.atdiscexport();
               }
           }
       }
   }
}

# idle throttle
Autothrottle.idle = func {
   if( me.is_engaged() ) {
       for(var i=0; i<constantaero.NBENGINES; i=i+1) {
           me.dependency["engine"][i].getChild("throttle").setValue(constantaero.THROTTLEIDLE);
       }
   }
}

# full foward throttle
Autothrottle.full = func {
  for(var i=0; i<constantaero.NBENGINES; i=i+1) {
      me.dependency["engine"][i].getChild("throttle").setValue(constantaero.THROTTLEMAX);
   }
}

Autothrottle.goaround = func {
   var count = 0;
   var result = constant.FALSE;

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( me.dependency["engine"][i].getChild("throttle-manual").getValue() == constantaero.THROTTLEMAX ) {
            count = count + 1;
        }
   }

   # 2 throttles full foward during an autoland or glide slope
   if( count >= 2 ) {
       result = constant.TRUE;
   }

   return result;
}

# check compatibility
# - autopilot channel 1
# - autopilot channel 2
Autothrottle.atdiscincompatible = func( apchannel1, apchannel2 ) {
    var channel1 = constant.FALSE;
    var channel2 = constant.FALSE;

    # disconnect autothrottle, if not compatible
    if( me.is_maxclimb() ) {
        channel1 = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
        channel2 = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();

        # same channel if maxclimb or maxcruise mode
        if( ( apchannel1 and apchannel2 ) or ( apchannel1 and channel2 ) or ( apchannel2 and channel1 ) ) {
            me.atdiscexport();
        }
    }
}

# disconnect speed 2 mode
Autothrottle.atdiscspeed2 = func {
   me.itself["autoflight"].getChild("speed2").setValue("");
}

# disconnect speed mode
Autothrottle.atdiscspeed = func {
   me.itself["autoflight"].getChild("speed").setValue("");
}

# disconnect autothrottle
Autothrottle.atdiscspeedmode2 = func {
   me.atdiscspeed();
   me.atdiscspeed2();
}

# disconnect autothrottle
Autothrottle.atdiscexport = func {
   me.atdiscspeedmode2();

   me.engagechannel(0, constant.FALSE);
   me.engagechannel(1, constant.FALSE);

   me.atengage();
}

Autothrottle.is_disc = func {
   var speedmode = me.itself["autoflight"].getChild("speed").getValue();
   var speedmode2 = me.itself["autoflight"].getChild("speed2").getValue();
   var result = constant.FALSE;

   if( speedmode == "" and speedmode2 == "" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.atactivatemode2 = func( property, value, value2 ) {
   if( property == "speed" ) {
       me.itself["autoflight"].getChild("speed2").setValue(value2);
   }

   me.itself["autoflight"].getChild(property).setValue(value);
}

Autothrottle.atactivatemode = func( property, value ) {
   me.itself["autoflight"].getChild(property).setValue(value);
}

Autothrottle.is_engaged = func {
   var result = constant.FALSE;

   if( me.itself["channel"][constantaero.AP1].getChild("engage").getValue() or
       me.itself["channel"][constantaero.AP2].getChild("engage").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.atengage = func {
   var mode = "";

   if( me.is_engaged() ) {
       mode = me.itself["autoflight"].getChild("speed").getValue();
   }

   me.itself["locks"].getChild("speed").setValue(mode);

   me.iaslight();
}

Autothrottle.atenable = func {
   if( !me.is_engaged() ) {
        me.engagechannel(0, constant.TRUE);
   }
}

# activate autothrottle
Autothrottle.atexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   var channel1 = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
   var channel2 = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();

   # channel engaged by XML
   me.whichchannel();

   # only 1 channel in max climb or max cruise mode
   if( channel1 and channel2 ) {
       if( me.is_maxclimb() ) {
           me.engagechannel(1, constant.FALSE);
       }
   }

   # IAS hold is default on activation
   elsif( channel1 or channel2 ) {
       if( me.is_disc() ) {
           me.atspeedholdexport();
       }
       else {
           me.atengage();
       }
   }

   else {
       me.atengage();
   }
}
}

Autothrottle.speedacquire = func {
   var minkt = 0.0;
   var maxkt = 0.0;

   if( me.is_engaged() ) {
       if( me.is_speed_acquire() ) {
           minkt = me.itself["airspeed"].getChild("light-min-kt").getValue();
           maxkt = me.itself["airspeed"].getChild("light-max-kt").getValue();
           speedkt = me.get_asi().getChild("indicated-speed-kt").getValue();

           # swaps to speed hold
           if( speedkt > minkt and speedkt < maxkt ) {
               me.atdiscspeed2();
           }
           else {
               settimer(func { me.speedacquire(); },me.SPEEDACQUIRESEC);
           }
       }
   }
}

Autothrottle.speed = func( speedkt ) {
   me.itself["settings"].getChild("target-speed-kt").setValue(speedkt);
}

Autothrottle.atspeedselectexport = func {
   var speedkt = 0.0;

   if( me.is_speed_acquire() ) {
       speedkt = me.itself["autoflight"].getChild("speed-select").getValue();
       me.speed(speedkt);
   }
}

Autothrottle.sonicspeedmode = func {
   var mode = "";

   if( me.is_lock_glide() ) {
       mode = "gs1-with-throttle";
   }
   elsif( me.is_lock_vertical() ) {
       mode = "vertical-speed-with-throttle";
   }

   return mode;
}

Autothrottle.is_speed_acquire = func {
   var speed2mode = me.itself["autoflight"].getChild("speed2").getValue();
   var result = constant.FALSE;

   if( speed2mode == "speed-acquire" ) {
       result = constant.TRUE;
   }

   return result;
}

# autothrottle
Autothrottle.atspeedexport = func {
 if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_speed_acquire() ) {
       me.atactivatemode2("speed","speed-with-throttle","speed-acquire");
       me.atspeedselectexport();
   }
   else{
       me.atdiscspeedmode2();
   }

   me.atengage();

   me.speedacquire();
 }
}

Autothrottle.has_lock = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();
   var result = constant.FALSE;

   if( speedmode != "" and speedmode != nil ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_lock_vertical = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();
   var result = constant.FALSE;

   if( speedmode == "vertical-speed-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_lock_glide = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();
   var result = constant.FALSE;

   if( speedmode == "gs1-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_lock_speed = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();
   var result = constant.FALSE;

   if( speedmode == "speed-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle autothrottle (ctrl-S)
Autothrottle.attogglespeedexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_speed() ) {
           me.atdiscexport();
       }
       else {
           me.atenable();
           me.atspeedexport();
       }
   }
}

Autothrottle.mach = func( speedmach ) {
   me.itself["settings"].getChild("target-mach").setValue(speedmach);
}

# hold mach
Autothrottle.holdmach = func {
   var speedmach = me.get_mach().getChild("indicated-mach").getValue();

   me.mach(speedmach);
}

Autothrottle.is_lock_mach = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();
   var result = constant.FALSE;

   if( speedmode == "mach-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_mach_throttle = func {
   var speedmode = me.itself["autoflight"].getChild("speed").getValue();
   var result = constant.FALSE;

   if( speedmode == "mach-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

# mach hold
Autothrottle.atmachexport = func {
 if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_mach_throttle() ) {
       me.holdmach();
       me.atactivatemode("speed","mach-with-throttle","");
   }
   else{
       me.atdiscspeedmode2();
   }

   me.atengage();
 }
}

# hold speed
Autothrottle.holdspeed = func {
   var speedkt = me.get_asi().getChild("indicated-speed-kt").getValue();

   me.speed(speedkt-1);
}

Autothrottle.is_speed_throttle = func {
   var speedmode = me.itself["autoflight"].getChild("speed").getValue();
   var result = constant.FALSE;

   if( speedmode == "speed-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_speed_hold = func {
   var speed2mode = me.itself["autoflight"].getChild("speed2").getValue();
   var result = constant.FALSE;

   if( speed2mode == "" and me.is_speed_throttle() and getprop("/systems/electrical/outputs/specific")>20) {
       result = constant.TRUE;
   }

   return result;
}

# speed hold
Autothrottle.atspeedholdexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_speed_hold() ) {
       me.holdspeed();
       me.atactivatemode2("speed","speed-with-throttle","");
   }
   else{
       me.atdiscspeedmode2();
   }

   me.atengage();
}
}

# spring returns to center, once released by hand
Autothrottle.releasedatum = func {
   if( me.itself["autoflight"].getNode("datum/speed").getValue() != 0.0 ) {
       # no mouse left click
       if( !me.itself["mouse"][0].getValue() ) {
           me.itself["autoflight"].getNode("datum/speed").setValue(0.0);
       }
   }
}

# datum adjust of autothrottle, argument :
# - step : plus/minus 1
Autothrottle.datumatexport = func( sign ) {
   var result = constant.FALSE;
   var value = 0.0;
   var step = 0.0;
   var datum = 0.0;
   var datumold = 0.0;
   var maxstep = 0.0;
   var ratio = 0.0;
   var targetmach = 0.0;
   var targetkt = 0.0;

   if( me.has_lock() ) {
       result = constant.TRUE;

       # plus/minus 0.06 Mach (real)
       if( me.is_lock_mach() ) {
           # 0.006 Mach per second (real)
           value = 0.006 * sign;
           step = 1.0 * sign;
       }
       # plus/minus 22 kt (real)
       elsif( me.is_lock_speed() ) {
           # 2 kt per second (real) : 1 kt per key
           value = 1.0 * sign;
           step = 0.454545 * sign;
       }
       # default (touches cursor)
       else {
           step = 1.0 * sign;
       }

       # limited to plus/minus 10 steps
       datum = me.itself["autoflight"].getNode("datum/speed").getValue();
       if( datum == nil ) {
           datum = step;
       }
       else {
           datumold = datum;
           datum = datum + step;

           # maximum value of cursor
           if( datum > 10.0 and datumold < 10.0 ) {
               maxstep = 10.0 - datumold;
               ratio = maxstep / step;
               value = ratio * value;
               datum = 10.0;
           }
           # minimum value of cursor
           elsif( datum < -10.0 and datumold > -10.0 ) {
               maxstep = -10.0 - datumold;
               ratio = maxstep / step;
               value = ratio * value;
               datum = -10.0;
           }
       }

       if( datum >= -10.0 and datum <= 10.0 ) {
           if( me.is_lock_mach() ) {
               targetmach = me.itself["settings"].getChild("target-mach").getValue();
               targetmach = targetmach + value;
               me.mach(targetmach);
           }
           elsif( me.is_lock_speed() ) {
               targetkt = me.itself["settings"].getChild("target-speed-kt").getValue();
               targetkt = targetkt + value;
               me.speed(targetkt);
           }

           me.itself["autoflight"].getNode("datum/speed").setValue(datum);
       }
   }


   return result;
}
