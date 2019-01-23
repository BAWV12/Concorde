# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by sched are called from cron
# HUMAN : functions ending by human are called by artificial intelligence


# Like the real Concorde : see http://www.concordesst.com.



# =========
# AUTOPILOT
# =========

Autopilot = {};

Autopilot.new = func {
   var obj = { parents : [Autopilot,System],

               autothrottlesystem : nil,

               PREDICTIONSEC : 6.0,
               STABLESEC : 3.0,
               AUTOPILOTSEC : 3.0,                            # refresh rate
               ALTACQUIRESEC : 2.0,
               MAXCLIMBSEC : 1.0,
               SAFESEC : 1.0,                                 # autoland
               GOAROUNDSEC : 1.0,
               TOUCHSEC : 0.2,
               FLARESEC : 0.1,

               CLIMBFPM : 2000.0,
               ACQUIREFPM : 800.0,
               TOUCHFPM : -750.0,                             # autoland
               DESCENTFPM : -1000.0,

               MACHFT : 25000.0,                              # altitude for Mach speed
               AUTOLANDFT : 1500.0,
               ALTIMETERFT : 1200.0,
               LANDINGFT : 500.0,                             # adjusts to the landing pitch
               PITCHFT : 100.0,                               # reaches the landing pitch
               FLAREFT : 100.0,                               # leaves glide slope
               LIGHTFT : 50.0,

               PITCHDEG : 20.0,                               # max pitch
               ALPHADEG : 17.5,                               # max alpha
               ROLLDEG : 1.0,                                 # roll to swap to next waypoint
               OSCTRACKDEG : 0.5,                             # gap between track heading and prediction filter, before oscillations
               OSCNAVDEG : 0.5,                               # gap between nav hold and prediction filter, before oscillations

               WPTNM : 0.5,                                   # distance to swap to next waypoint original 4.0
               VORNM : 3.0,                                   # distance to inhibate VOR

               GOAROUNDDEG : 15.0,


# If no pitch control, sudden swap to 10 deg causes a rebound, worsened by the ground effect.
# Ignoring the glide slope at 200-300 ft, with a pitch of 10 degrees, would be simpler;
# but the glide slope following is implicit until 100 ft (red autoland light).
               FLAREDEG : 10.0,

# If 10 degrees, vertical speed, too high to catch the glide slope,
# cannot be recovered during the last 100 ft.
               LANDINGDEG : 8.5,                              # landing pitch

               PIDSUPERSONIC : 1,
               PIDSUBSONIC : 0,

               landheadingdeg : 0.0,

               routeactive : constant.FALSE,

               engaged_channel : constantaero.APNONE
         };

# autopilot initialization
   obj.init();

   return obj;
};

Autopilot.init = func {
   me.inherit_system("/systems/autopilot");

   me.reinitexport();
   me.apdiscexport();

   setprop("/sim/messages/copilot", "");

}

Autopilot.reinitexport = func {
   # - NAV 0 is reserved for autopilot.
   # - copy NAV 0-1 from preferences.xml to 1-2.
   me.sendnav( 1, 2 );
   me.sendnav( 0, 1 );
}

Autopilot.set_relation = func( autothrottle ) {
   me.autothrottlesystem = autothrottle;
}

Autopilot.red_autopilot = func {
   var failure = [ constant.FALSE, constant.FALSE ];

   if( me.has_engaged() ) {
       var result = constant.FALSE;

       # altimeter or IVSI failure, on altitude hold.
       if( me.has_lock_altitude() ) {
           if( !me.get_altimeter().getChild("serviceable").getValue() or
               !me.get_ivsi().getChild("serviceable").getValue() ) {
               result = constant.TRUE;
           }
       }

       # heading indicator failure, on heading/track hold.
       if( me.has_lock_altitude() ) {
           if( !me.get_hsi().getChild("serviceable").getValue() ) {
               result = constant.TRUE;
           }
       }

       # radio altimeter failure, on autoland.
       if( me.is_landing() ) {
           if( !me.get_radioaltimeter().getChild("serviceable").getValue() ) {
               result = constant.TRUE;
           }
       }

       # alpha greater than 17.5 deg, without autoland.
       else {
           if( me.get_component("aoa").getChild("alpha-deg").getValue() > me.ALPHADEG ) {
               result = constant.TRUE;
           }
 
       # attitude greater than 20 deg, without autoland.
           elsif( me.get_attitude().getChild("indicated-pitch-deg").getValue() > me.PITCHDEG ) {
               result = constant.TRUE;
           }
       }

       failure[me.engaged_channel] = result;
   }

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        # here, because disables the engaged_channel.
        if( !me.itself["autopilot"][i].getChild("serviceable").getValue() ) {
            failure[i] = constant.TRUE;
        }

        me.itself["state"].getChild("failure",i).setValue(failure[i]);
   }
}

Autopilot.schedule = func {
   me.supervisor( constant.FALSE );

   me.red_autopilot();
}

Autopilot.slowschedule = func {
   me.releasedatum();
}

Autopilot.supervisor = func( recursive = 1 ) {
   # avoid recursive calls
   if( !recursive ) {
       # disconnect autopilot if no voltage (TO DO by FG)
       me.voltage();

       me.inslight();
   }

   me.lockroll();

   # more sensitive at supersonic speed
   me.sonicheadingmode();
   me.sonicaltitudemode();
   me.sonicspeedmode();

   me.landlight();

   # TEMPORARY work around for heading modes PID :
   # heading modes banks into the direction, before engagement.
   if( !me.is_lock_magnetic() ) {
       # sets the value early.
       me.magneticheading();
   }
}

Autopilot.no_voltage = func {
   var result = constant.FALSE;

   if( ( !me.dependency["electric"].getChild("autopilot", constantaero.AP1).getValue() and
         !me.dependency["electric"].getChild("autopilot", constantaero.AP2).getValue() ) or
       ( !me.itself["autopilot"][constantaero.AP1].getChild("serviceable").getValue() and
         !me.itself["autopilot"][constantaero.AP2].getChild("serviceable").getValue() ) ) {
       result = constant.TRUE;
   }

   return result;
}

# disconnect if no voltage (cannot disable the autopilot !)
Autopilot.voltage = func {
   var channel = constant.FALSE;
   var voltage1 = me.dependency["electric"].getChild("autopilot", constantaero.AP1).getValue();
   var voltage2 = me.dependency["electric"].getChild("autopilot", constantaero.AP2).getValue();

   if( voltage1 ) {
       voltage1 = me.itself["autopilot"][constantaero.AP1].getChild("serviceable").getValue();
   }
   if( voltage2 ) {
       voltage2 = me.itself["autopilot"][constantaero.AP2].getChild("serviceable").getValue();
   }

   if( !voltage1 or !voltage2 ) {
       # not yet in hand of copilot
       if( !me.itself["state"].getChild("virtual").getValue() ) {

           # disconnect autopilot 1
           if( !voltage1 ) {
               channel = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
               if( channel ) {
                   me.engagechannel(constantaero.AP1, constant.FALSE);
                   channel = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();
                   if( !channel ) {
                       me.apdiscexport();
                   }
               }
           }

           # disconnect autopilot 2
           if( !voltage2 ) {
               channel = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();
               if( channel ) {
                   me.engagechannel(constantaero.AP2, constant.FALSE);
                   channel = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
                   if( !channel ) {
                       me.apdiscexport();
                   }
               }
           }
       }
   }
}

# emulates a human pilot
Autopilot.virtualhuman = func {
    # cut autopilot before, if no voltage
    me.voltage();
    me.autothrottlesystem.voltage();

    me.itself["state"].getChild("virtual").setValue(constant.TRUE);

    me.apenable();
}

# real autopilot
Autopilot.realhuman = func {
    if( me.itself["state"].getChild("virtual").getValue() ) {
        me.itself["state"].getChild("virtual").setValue(constant.FALSE);

        # clear autopilot after (as sets by human pilot), if no voltage
        me.voltage();
        me.autothrottlesystem.voltage();
    }
}

# waypoint transition
Autopilot.lockroll = func {
   if( me.is_engaged() ) {
       if( me.is_ins() ) {
           me.lockwaypointroll();
       }

       # VOR transition
       elsif( me.is_vor() ) {
           me.lockvorroll();
       }
   }
}

# avoid strong roll near a waypoint
Autopilot.lockwaypointroll = func {
    var distancenm = me.itself["waypoint"][0].getChild("dist").getValue();

  dist=getprop("/instrumentation/ins[0]/computed/ground-speed-fps")/1.687/100-1.5;
  if (dist<1){
    dist=1;
  };

  me.WPTNM=dist;



    # next waypoint
    if( distancenm != nil ) {
        var lastnm = me.itself["state"].getChild("waypoint-nm").getValue();

        # avoids strong roll
        if( distancenm < me.WPTNM ) {

		wptn=getprop("/autopilot/route-manager/wp/id");
		nwptn=getprop("/autopilot/route-manager/wp[1]/id");
		nwptd=math.round(getprop("/autopilot/route-manager/wp[1]/dist"));
		etan=getprop("/autopilot/route-manager/wp[1]/eta");
		lwptd=math.round(getprop("/autopilot/route-manager/wp-last/dist"));




            # pop waypoint, enough soon to avoid banking on release
            # into the opposite direction of the next waypoint
            var rolldeg =  me.noinstrument["roll"].getValue();
            if( distancenm > lastnm or math.abs(rolldeg) > me.ROLLDEG ) {
                if( me.is_lock_true() ) {
                    me.itself["route-manager"].getChild("input").setValue("@DELETE0");
                    me.resetprediction( "true-heading-hold1" );

		    for( var i = 0; i < 3; i = i+1 ) {
                    	cwpt=getprop("/instrumentation/ins[" ~ i ~ "]/control/waypoint");
			if (cwpt>1){
				setprop("/instrumentation/ins[" ~ i ~ "]/control/waypoint",cwpt-1);
			};
		    };

		    msg="Over "~wptn~", next waypoint "~nwptn~", distance "~nwptd~", ETA "~etan~", "~lwptd~" nm to destination.";
		    oldmsg=getprop("/sim/messages/copilot");
		    if (substr(msg,1,20)!=substr(oldmsg,1,20) and nwptd>9){
		    	setprop("/sim/messages/copilot", msg);
		    };


                }
            }
        }

        # new waypoint
        elsif( distancenm > lastnm ) {
            me.resetprediction( "true-heading-hold1" );
        }

        me.itself["state"].getChild("waypoint-nm").setValue(distancenm);
    }
}

Autopilot.get_nav = func {
    # NAV 0, if not engaged
    var index = me.engaged_channel + 1;

    # once frenquecy is sended, NAV 0 reflects NAV 1/2 only at the next loop !!
    return me.dependency["nav"][index];
}

Autopilot.get_component = func( name ) {
    return me.dependency[name][me.engaged_channel];
}

Autopilot.get_altimeter = func {
    return me.get_component("altimeter");
}

Autopilot.get_attitude = func {
    return me.get_component("attitude");
}

Autopilot.get_hsi = func {
    return me.get_component("hsi");
}

Autopilot.get_ivsi = func {
    return me.get_component("ivsi");
}

Autopilot.get_mach = func {
    return me.get_component("mach");
}

Autopilot.get_radioaltimeter = func {
    return me.get_component("radio-altimeter");
}

Autopilot.is_subsonic = func {
   var result = constant.FALSE;
   var speedmach = me.get_mach().getChild("indicated-mach").getValue();

   if( speedmach <= constantaero.SOUNDMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.sonicpid = func {
   var mode = me.PIDSUPERSONIC;

   if( me.is_subsonic() ) {
       mode = me.PIDSUBSONIC;
   }

   return mode;
}

Autopilot.is_supersonicpid = func( mode ) {
   var result = constant.FALSE;

   if( mode == me.PIDSUPERSONIC ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_subsonicpid = func( mode ) {
   var result = constant.FALSE;

   if( mode == me.PIDSUBSONIC ) {
       result = constant.TRUE;
   }

   return result;
}

# avoid strong roll near a VOR
Autopilot.lockvorroll = func {
    var distancenm = 0.0;

    # near VOR
    if( me.dependency["dme"].getChild("in-range").getValue() ) {
        # restores after VOR
        distancenm = me.dependency["dme"].getChild("indicated-distance-nm").getValue();
        if( distancenm > me.VORNM ) {
            if( me.is_lock_magnetic() ) {
                me.locknav1();
            }
        }

        # avoids strong roll
        else {
            # switches to heading hold
            if( me.is_lock_nav() ) {
                # except if mode has just been engaged, leaving a VOR :
                # EGLL 27R, then leaving LONDON VOR 113.60 on its 260 deg radial (SID COMPTON 3).
                if( !me.get_nav().getChild("from-flag").getValue() ) { 
                    me.magneticheading();
                    me.lockmagnetic();
                }
            }
        }
    }
}


# ---------------
# AUTOPILOT MODES
# ---------------

# To avoid bugs, swaping from an horizontal / vertical mode (composed of 2 or more submodes)
# may keep submodes, if that is coherent.
# Example : swaping from turbulence mode (= pitch + heading hold) to pitch hold, keeps heading hold.

# disconnect autopilot
Autopilot.apdiscexport = func {
   me.apdischeading();
   me.apdiscvertical();
   me.apdischorizontal();
   me.apdiscaltitude();

   me.engagechannel(0, constant.FALSE);
   me.engagechannel(1, constant.FALSE);

   me.itself["locks"].getChild("altitude").setValue("");
   me.itself["locks"].getChild("heading").setValue("");
}

Autopilot.is_disc = func {
   var result = constant.FALSE;
   var altitude = me.itself["autoflight"].getChild("altitude").getValue();
   var heading = me.itself["autoflight"].getChild("heading").getValue();
   var vertical = me.itself["autoflight"].getChild("vertical").getValue();
   var horizontal = me.itself["autoflight"].getChild("horizontal").getValue();

   if( altitude == "" and heading == "" and vertical == "" and horizontal == "" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.sonicmode = func( mode ) {
   if( me.engaged_channel == constantaero.AP2 ) {
       if( mode != "" ) {
           mode = mode ~ "-2";
       }
   }

   return mode;
}

Autopilot.sonicspeedmode = func {
   var mode = me.autothrottlesystem.sonicspeedmode();

   mode = me.sonicmode( mode );

   me.itself["sonic"].getChild("speed").setValue(mode);
}

# activate a mode, and engage a channel
Autopilot.apactivatemode2 = func( property, value, value2 ) {
   if( property == "altitude" ) {
       if( value2 != "" ) {
           me.apactivatemode("vertical",value2);
       }
       else {
           me.apdiscvertical();
       }
   }
   elsif( property == "heading" ) {
       if( value2 != "" ) {
           me.apactivatemode("horizontal",value2);
       }
       else {
           me.apdischorizontal();
       }
   }

   me.apactivatemode( property, value );
}

# activate a mode, and engage a channel
Autopilot.apactivatemode = func( property, value ) {
   var channel1 = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
   var channel2 = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();

   if( property == "altitude" ) {
       me.apdiscaltitude();
   }
   elsif( property == "vertical" ) {
       me.apdiscvertical();
   }
   elsif( property == "heading" ) {
       me.apdischeading();
   }
   elsif( property == "horizontal" ) {
       me.apdischorizontal();
   }

   me.itself["autoflight"].getChild(property).setValue(value);

   # remove 2nd channel of autoland after a goaround
   if( channel1 and channel2 ) {
       if( !me.is_autoland() ) {
           channel2 = constant.FALSE;
           me.engagechannel(1, channel2);
       }
   }

   me.autothrottlesystem.atdiscincompatible( channel1, channel2 );
}

Autopilot.apenable = func {
   if( !me.is_engaged() ) {
       me.engagechannel(0, constant.TRUE);
   }
}

Autopilot.has_engaged = func {
   var result = constant.FALSE;

   if( me.engaged_channel > constantaero.APNONE ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_engaged = func {
   var result = constant.FALSE;

   if( me.itself["channel"][constantaero.AP1].getChild("engage").getValue() or
       me.itself["channel"][constantaero.AP2].getChild("engage").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.apengage = func {
   var altitudemode = "";
   var headingmode = "";

   if( me.is_engaged() ) {
       altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
       headingmode = me.itself["autoflight"].getChild("heading").getValue();
   }

   me.itself["locks"].getChild("altitude").setValue(altitudemode);
   me.itself["locks"].getChild("heading").setValue(headingmode);

   me.supervisor();
}

Autopilot.apengagealtitude = func {
   var altitudemode = "";

   if( me.is_engaged() ) {
       altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   }

   me.itself["locks"].getChild("altitude").setValue(altitudemode);

   me.supervisor();
}

# activate autopilot
Autopilot.apexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   var channel1 = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
   var channel2 = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();

   # channel engaged by XML
   me.whichchannel();

   me.apsendheadingexport();
   me.apsendnavexport();

   # 2 channels only in land mode
   if( channel1 and channel2 ) {
       if( !me.is_autoland() ) {
           me.engagechannel(1, constant.FALSE);
       }
   }

   # pitch hold and heading hold is default on activation
   elsif( channel1 or channel2 ) {
       if( me.is_disc() ) {
           me.appitchexport();
           me.apheadingholdexport();
       }
       else {
           me.apengage();
       }

       # disconnect autothrottle, if not compatible
       me.autothrottlesystem.atdiscincompatible( channel1, channel2 );
   }

   # disconnect if no channel
   else {
       me.apengage();
   }
}
}

Autopilot.engagechannel = func( index, value ) {
    me.itself["channel"][index].getChild("engage").setValue(value);

    me.whichchannel();
}

Autopilot.whichchannel = func {
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

# spring returns to center, once released by hand
Autopilot.releasedatum = func {
   if( me.itself["autoflight"].getNode("datum/altitude").getValue() != 0.0 ) {
       # no mouse left click
       if( !me.itself["mouse"][constantaero.AP1].getValue() ) {
           me.itself["autoflight"].getNode("datum/altitude").setValue(0.0);
       }
   }
}

# datum adjust of autopilot, arguments
# - step plus/minus 1 (fast) or 0.1 (slow)
Autopilot.datumapexport = func( sign ) {
   var maxcruise = constant.FALSE;
   var value = 0.0;
   var step = 0.0;
   var datum = 0.0;
   var datumold = 0.0;
   var maxstep = 0.0;
   var ratio = 0.0;
   var targetfpm = 0.0;
   var targerdeg = 0.0;
   var targetkt = 0.0;
   var targetft = 0.0;
   var targetmach = 0.0;
   var result = constant.FALSE;


   if( me.has_lock_altitude() ) {
       result = constant.TRUE;

       maxcruise = me.autothrottlesystem.is_maxcruise();
# TO DO : slaving to TMO not implemented
       maxcruise = constant.FALSE;

       # plus/minus 6000 ft/min (real)
       # plus/minus 17 kt (real) : maxclimb

#       if(maxcruise){
#	   setprop("/autopilot/settings/vertical-speed-fpm",50);
#       };

       if( me.is_lock_vertical() and !maxcruise ) {
           # 80 or 800 ft/min per second (real) : 10 or 100 ft/min per key
           # 0.7 or 2 kt per second (real) : 10 or 100 ft/min per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
               step = 0.16667 * sign;
           }
           else {
               value = 100.0 * sign;
               step = 0.16667 * sign;
           }
       }
       # plus/minus 11 deg
       elsif( me.is_lock_pitch() ) {
           # 0.1 or 0.5 deg per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 1.0 * sign;
               step = 0.90909 * sign;
           }
           else {
               value = 0.5 * sign;
               step = 0.454545 * sign;
           }
       }
       # plus/minus 600 ft (real)
       elsif( me.is_lock_altitude() ) {
           # 20 or 60 ft per second (real) : 10 or 50 ft per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
               step = 1.66667 * sign;
           }
           else {
               value = 50.0 * sign;
               step = 0.83333 * sign;
           }
       }
       # plus/minus 20 kt (real)
       elsif( me.is_lock_speed_pitch() ) {
           # 0.7 or 2 kt per second (real) : 0.5 or 1 kt per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 5.0 * sign;
               step = 0.25 * sign;
           }
           else {
               value = 1.0 * sign;
               step = 0.5 * sign;
           }
       }
       # plus/minus 0.06 Mach (real)
       elsif( me.is_lock_mach_pitch() ) {
           # 0.002 or 0.007 Mach per second (real)
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 0.02 * sign;
               step = 3.33333 * sign;
           }
           else {
               value = 0.007 * sign;
               step = 1.166667 * sign;
           }
       }
       # default (touches cursor)
       else {
           value = 0.0;
           step = 1.0 * sign;
       }

       # limited to plus/minus 10 steps
       datum = me.itself["autoflight"].getNode("datum/altitude").getValue();
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
           if( me.is_lock_vertical() and !maxcruise ) {
               targetfpm = me.itself["settings"].getChild("vertical-speed-fpm").getValue();
               if( targetfpm == nil ) {
                   targetfpm = 0.0;
               }
               targetfpm = targetfpm + value;
               me.verticalspeed(targetfpm);
           }
           elsif( me.is_lock_pitch() ) {
               targetdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();
               targetdeg = targetdeg + value;
               me.pitch( targetdeg );
           }
           elsif( me.is_lock_altitude() ) {
               targetft = me.itself["settings"].getChild("target-altitude-ft").getValue();
               targetft = targetft + value;
               me.apaltitude(targetft);
           }
           elsif( me.is_lock_speed_pitch() ) {
               targetkt = me.itself["settings"].getChild("target-speed-kt").getValue();
               targetkt = targetkt + value;

	       # safety minimum speed
   	       if (targetkt<170) {
                 targetkt=170
               };

               me.autothrottlesystem.speed(targetkt);
           }
           elsif( me.is_lock_mach_pitch() ) {
               targetmach = me.itself["settings"].getChild("target-mach").getValue();
               targetmach = targetmach + value;
               me.autothrottlesystem.mach(targetmach);
           }

           me.itself["autoflight"].getNode("datum/altitude").setValue(datum);
       }
   }


   return result;
}

# manual setting of heading with knob
Autopilot.headingknobexport = func( sign ) {
   var headingdeg = 0.0;

   if( me.has_lock_heading() ) {
       result = constant.TRUE;
       
       if( me.istrackheading() ) {
           if( me.is_lock_magnetic() ) {
               headingdeg = me.itself["channel"][me.engaged_channel].getChild("heading-select").getValue();
               
               headingdeg = headingdeg + 1 * sign;
               headingdeg = constant.truncatenorth( headingdeg );
               
               me.itself["channel"][me.engaged_channel].getChild("heading-select").setValue(headingdeg);
               
               me.heading(headingdeg);
           }
           elsif( me.is_lock_true() ) {
               headingdeg = me.itself["channel"][me.engaged_channel].getChild("heading-true-select").getValue();
               
               headingdeg = headingdeg + 1* sign;
               headingdeg = constant.truncatenorth( headingdeg );
               
               me.itself["channel"][me.engaged_channel].getChild("heading-true-select").setValue(headingdeg);
               
               me.trueheading(headingdeg);
           }
       }
   }
}


# ---------------
# FLIGHT DIRECTOR
# ---------------

# activate autopilot
Autopilot.fdexport = func {
   var altitude = "";
   var heading = "";
   var vertical = "";
   var horizontal = "";
   var fd1 = me.itself["flight-director"][constantaero.AP1].getChild("engage").getValue();
   var fd2 = me.itself["flight-director"][constantaero.AP2].getChild("engage").getValue();

   if( fd1 or fd2 ) {
       altitude = me.itself["autoflight"].getChild("altitude").getValue();
       heading = me.itself["autoflight"].getChild("heading").getValue();
       vertical = me.itself["autoflight"].getChild("vertical").getValue();
       horizontal = me.itself["autoflight"].getChild("horizontal").getValue();

       # pitch hold is default on activation
       if( ( altitude == "" or altitude == nil ) and ( vertical == "" or vertical == nil ) and
           ( heading == "" or heading == nil ) and ( horizontal == "" or horizontal == nil ) ) {
           me.appitchexport();
       }
   }
}


# -------------
# VERTICAL MODE
# -------------

Autopilot.apdiscverticalmode2 = func {
   me.apdiscvertical();
   me.apdiscaltitude();
}

# disconnect vertical mode
Autopilot.apdiscvertical = func {
   me.itself["autoflight"].getChild("vertical").setValue("");
}

# go around mode
Autopilot.goaround = func {
   # cron runs without autopilot engagement
   if( me.is_engaged() ) {

       # 2 throttles full foward during an autoland or glide slope
       if( me.is_glide() or me.is_landing() ) {
           if( me.autothrottlesystem.goaround() ) {
               me.apactivatemode("heading","wing-leveler","");

               # pitch at 15 deg and hold the wing level, until the next command of crew
               me.modepitch( me.GOAROUNDDEG );

               # crew control
               me.autothrottlesystem.atdiscexport();

               # throttle is being changed by autothrottle
               me.autothrottlesystem.full();

               # light on
               me.apactivatemode("vertical","goaround");

               me.apengage();
           }
       }

       # light off
       elsif( me.is_going_around() ) {
           if( !me.is_pitch() or
               me.itself["autoflight"].getChild("heading").getValue() != "wing-leveler" ) {
               me.apdiscvertical();
           }
       }
   }
}

Autopilot.is_going_around = func {
   var result = constant.FALSE;

   if( me.itself["autoflight"].getChild("vertical").getValue() == "goaround" ) {
       result = constant.TRUE;
   }

   return result;
}

# CAUTION, avoids concurrent crons (stack overflow Nasal error) :
# one may activate glide slope, then arm autoland = 2 calls.
Autopilot.is_goaround = func {
   var result = constant.FALSE;

   if( me.itself["autoflight"].getChild("vertical2").getValue() == "goaround-armed" or me.is_going_around() ) {
       result = constant.TRUE;
   }

   return result;
}

# adjust target speed with wind
# - target speed (kt)
Autopilot.targetwind = func {
   # VREF 152-162 kt
   var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
   var targetkt = constantaero.Vrefkt( weightlb );
   var windkt = me.dependency["ins"][constantaero.AP1].getNode("computed/wind-speed-kt").getValue();

   # wind increases lift
   if( windkt > 0 ) {
       var winddeg = me.dependency["ins"][constantaero.AP1].getNode("computed/wind-from-heading-deg").getValue();
       var vordeg = me.get_nav().getNode("radials").getChild("target-radial-deg").getValue();
       var offsetdeg = vordeg - winddeg;

       offsetdeg = constant.crossnorth( offsetdeg );

       # add head wind component;
       # except tail wind (too much glide)
       if( offsetdeg > -constant.DEG90 and offsetdeg < constant.DEG90 ) {
           var offsetrad = offsetdeg * constant.DEGTORAD;
           var offsetkt = windkt * math.cos( offsetrad );

           targetkt = targetkt + offsetkt;
       }
   }

   # safety minimum speed
   if (targetkt<170) {
     targetkt=170
   };

   # avoid infinite gliding (too much ground effect ?)
   me.autothrottlesystem.speed(targetkt);
}

# smooth the rebound of pitch hold during the flare
Autopilot.targetpitch = func( targetdeg, aglft, rates ) {
   var pitchdeg = 0.0;
   var speedfps = 0.0;
   var deltaft = 0.0;
   var timesec = 0.0;
   var deltadeg = 0.0;
   var ratedegps = 0.0;
   var stepdeg = 0.0;

   # start from attitude
   if( !me.is_pitch() ) {
       pitchdeg = me.noinstrument["pitch"].getValue();
   }
   else {
       pitchdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();
   }

   if( pitchdeg != targetdeg ) {
       if( targetdeg > pitchdeg ) {
           speedfps = - me.get_ivsi().getChild("indicated-speed-fps").getValue();
           deltaft = aglft - me.PITCHFT;
           timesec = deltaft / speedfps;

           deltadeg = targetdeg - pitchdeg;
           ratedegps = deltadeg / timesec;

           stepdeg = ratedegps * rates;
           pitchdeg = pitchdeg + stepdeg;
       }

       # maximum
       else {
           pitchdeg = targetdeg;
       }
   }

   me.modepitch( pitchdeg );
}

# autoland mode
Autopilot.autoland = func {
   var aglft = 0.0;
   var pitchdeg = 0.0;
   var verticalmode2 = "";      

   # to catch the go around
   var rates = me.GOAROUNDSEC;

   me.goaround();

   if( me.is_autoland() ) {
       verticalmode2 = "goaround-armed";

       # cron runs without autopilot engagement
       if( me.is_engaged() ) {
           aglft = me.get_radioaltimeter().getChild("indicated-altitude-ft").getValue();

           # armed
           if( me.is_land_armed() ) {
               if( aglft <= me.AUTOLANDFT ) {
                   me.itself["autoflight"].getChild("vertical").setValue("autoland");
               }
           }

           # engaged
           if( me.is_landing() ) {
               # touch down
               if( aglft < constantaero.AGLTOUCHFT ) {

                   # gently reduce pitch
                   if( me.noinstrument["pitch"].getValue() > 1.0 ) {
                       rates = me.TOUCHSEC;

                       # 1 deg / s
                       pitchdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();
                       pitchdeg = pitchdeg - 0.2;
                       me.modepitch( pitchdeg );
                       me.autothrottlesystem.atdiscspeedmode2();
                   }

                   # safe on ground
                   else {
                       rates = me.SAFESEC;

                       # disable autopilot
                       verticalmode2 = "";
                       me.apdiscexport();
                       me.autothrottlesystem.atdiscexport();

                       # reset trims
                       me.dependency["flight"].getChild("elevator-trim").setValue(0.0);
                       me.dependency["flight"].getChild("rudder-trim").setValue(0.0);
                       me.dependency["flight"].getChild("aileron-trim").setValue(0.0);
                   }

                   # pilot must activate autothrottle
                   me.autothrottlesystem.idle();
               }
 
               # triggers below 1500 ft
               elsif( aglft > me.AUTOLANDFT ) {
                   me.itself["autoflight"].getChild("vertical").setValue("autoland-armed");
               }

               # approach
               else {
                   # if activated below 1500 ft
                   me.apdischorizontal();

                   if( aglft < me.LANDINGFT ) {
                       rates = me.FLARESEC;

                       # landing pitch (flare) :
                       # - not above 100 ft, because outside of glide slope (autoland red light).
                       # - vertical-speed-with-throttle removes the rebound at touch down of
                       # vertical-speed-hold.
                       if( aglft < me.FLAREFT ) {
                           # possible nav errors below 100 ft (example KJFK 22L, EGLL 27R) :
                           # heading hold avoids roll outside the runway.
                           if( !me.itself["autoflight"].getChild("real-nav").getValue() ) {
                               if( !me.is_magnetic() ) {
                                   me.landheadingdeg = me.noinstrument["magnetic"].getValue();
                               }
                               me.heading(me.landheadingdeg);
                               me.apactivatemode("heading","dg-heading-hold");
                           }
                           me.modepitch( me.FLAREDEG );
                           me.verticalspeed(me.TOUCHFPM);
                           me.autothrottlesystem.atactivatemode("speed","vertical-speed-with-throttle");
                       }

                       # tip to landing pitch :
                       # - sooner at 10 deg reduces the rebound.
                       # - cannot go back, when rebound.
                       # - glide slope with throttle is less prone to lose pitch
                       # to catch the glide slope below.
                       elsif( !me.autothrottlesystem.is_lock_vertical() ) {
                           me.apactivatemode("heading","nav1-hold");
                           me.targetpitch( me.LANDINGDEG, aglft, rates );
                           me.autothrottlesystem.atactivatemode("speed","gs1-with-throttle");
                       } 
                   }

                   # glide slope : cannot go back when then aircraft climbs again
                   # (rebound caused by landing pitch), otherwise will crash to catch the glide slope.
                   elsif( !me.autothrottlesystem.is_lock_glide() ) {
                       me.apactivatemode("heading","nav1-hold");
                       me.modeglide();

                       # near VREF (no wind)
                       me.targetwind();
                       me.autothrottlesystem.atactivatemode("speed","speed-with-throttle");
                   }

                   # pilot must activate autothrottle
                   me.autothrottlesystem.atengage();
               }
           }

           me.apengage();
       }
   }
   else {
       if( me.is_glide() ) {
           verticalmode2 = "goaround-armed";      
       }
   }

   me.itself["autoflight"].getChild("vertical2").setValue(verticalmode2);

   # re-schedule the next call
   if( me.is_goaround() ) {
       settimer(func { me.autoland(); }, rates);
   }
}

Autopilot.landlight = func {
   var land2 = constant.FALSE;
   var land3 = constant.FALSE;
   var channel1 = constant.FALSE;
   var channel2 = constant.FALSE;

   if( me.is_landing() ) {
       channel1 = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
       channel2 = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();

       if( channel1 or channel2 ) {
           land2 = constant.TRUE;
       }
       if( channel1 and channel2 ) {
           land3 = constant.TRUE;
       }
   }

   me.itself["state"].getChild("land2").setValue(land2);
   me.itself["state"].getChild("land3").setValue(land3);
}

Autopilot.is_landing = func {
   var result = constant.FALSE;
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();

   if( verticalmode == "autoland" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_land_armed = func {
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();
   var result = constant.FALSE;

   if( verticalmode == "autoland-armed" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_autoland = func {
   var result = constant.FALSE;

   if( me.is_landing() or me.is_land_armed() ) {
       result = constant.TRUE;
   }

   return result;
}

# autopilot autoland
Autopilot.aplandexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_autoland() ) {
       me.apactivatemode("vertical","autoland-armed");
   }
   else {
       me.apdiscvertical();
   }

   me.apengage();

   if( !me.is_goaround() ) {
       me.autoland();
   }
}
}

Autopilot.is_turbulence = func {
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();
   var result = constant.FALSE;

   if( verticalmode == "turbulence" ) {
       result = constant.TRUE;
   }

   return result;
}

# autopilot turbulence mode
Autopilot.apturbulenceexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_turbulence() ) {
       me.magneticheading();
       me.apactivatemode2("heading","dg-heading-hold","");
       me.attitudepitch();
       me.apactivatemode2("altitude","pitch-hold","turbulence");
   }
   else {
       me.apdiscverticalmode2();
       me.apdischeading(); 
   }

   me.apengage();
}
}

# -------------
# ALTITUDE MODE
# -------------

# disconnect autopilot altitude
Autopilot.apdiscaltitude = func {
   me.itself["autoflight"].getChild("altitude").setValue("");

   # switch to speed hold
   if( me.autothrottlesystem != nil ) {
       me.autothrottlesystem.discmaxclimb();
   }
}

# altitude button lights, when the dialed altitude is reached.
# altimeter light, when the dialed altitude is reached.
Autopilot.altitudelight = func {
   var altft = 0.0;
   var minft = 0.0;
   var maxft = 0.0;

   if( me.is_engaged() ) {
       if( me.is_altitude_hold() or me.is_altitude_acquire() ) {
           altft = me.itself["autoflight"].getChild("altitude-select").getValue();

           # altimeter light within 1200 ft
           minft = altft - me.ALTIMETERFT;
           me.itself["altimeter"].getChild("target-min-ft").setValue(minft);
           maxft = altft + me.ALTIMETERFT;
           me.itself["altimeter"].getChild("target-max-ft").setValue(maxft);

           # no altimeter light within 50 ft
           minft = altft - me.LIGHTFT;
           me.itself["altimeter"].getChild("light-min-ft").setValue(minft);
           maxft = altft + me.LIGHTFT;
           me.itself["altimeter"].getChild("light-max-ft").setValue(maxft);
       }
   }
}

Autopilot.altitudelight_on = func ( altitudeft, targetft ) {
   var result = constant.TRUE;

   if( altitudeft < targetft - me.ALTIMETERFT or
       altitudeft > targetft + me.ALTIMETERFT ) {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.altitudeacquire = func {
   var altitudeft = 0.0;
   var speedfpm = 0.0;
   var mode = "";

   if( me.is_engaged() ) {
       if( me.is_altitude_acquire() ) {
           me.altitudelight();

           altitudeft = me.get_altimeter().getChild("indicated-altitude-ft").getValue();
           if( altitudeft > me.itself["altimeter"].getChild("target-max-ft").getValue() ) {
               speedfpm = -me.ACQUIREFPM;
               mode = "vertical";
           }
           elsif( altitudeft < me.itself["altimeter"].getChild("target-min-ft").getValue() ) {
               speedfpm = me.ACQUIREFPM;
               mode = "vertical";
           }

           # capture
           elsif( altitudeft > me.itself["altimeter"].getChild("light-max-ft").getValue() or
                  altitudeft < me.itself["altimeter"].getChild("light-min-ft").getValue() ) {
               if( !me.is_altitude_hold() ) {
                   me.apactivatemode("altitude","altitude-hold");
               }
               mode = "capture";
           }

           # at level
           else {
               me.apactivatemode2("altitude","altitude-hold","");
               mode = "";
           }

           # default to vertical speed hold 800 ft/min, if comes from altitude hold;
           if( mode == "vertical" ) {
               if( me.is_altitude_hold() ) {
                   # pilot can change
                   me.modeverticalspeed( speedfpm );
               }
           }

           # nav1 can switch to magnetic
           me.apengagealtitude();

           # otherwise keep the previous vertical mode (if any),
           # which is supposed to reach the capture level, by pilot action

           # re-schedule the next call
           if( mode != "" ) {
               settimer(func { me.altitudeacquire(); }, me.ALTACQUIRESEC);
           }
       }
   }
}

Autopilot.selectfpm = func( altitudeft, targetft ) {
   var speedfpm = me.CLIMBFPM;

   if( altitudeft > targetft ) {
       speedfpm = me.DESCENTFPM;
   }

   me.verticalspeed(speedfpm);
}

Autopilot.has_lock_altitude = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode != "" and altitudemode != nil ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_altitude = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle altitude hold (ctrl-A)
Autopilot.aptogglealtitudeexport = func {
   var altitudeft = 0.0;
   var targetft = 0.0;

   if( !me.no_voltage() ) {
       if( !me.is_vertical_speed() or me.is_altitude_acquire() ) {
           me.apenable();
           me.apverticalexport();
       }
       me.apaltitudeexport();

       # avoid many manual operations
       if( me.is_vertical_speed() ) {
           altitudeft = me.get_altimeter().getChild("indicated-altitude-ft").getValue();
           targetft = me.itself["autoflight"].getChild("altitude-select").getValue();
           me.selectfpm( altitudeft, targetft );
       }
   }
}

Autopilot.apaltitudeselectexport = func {
   var altitudeft = 0.0;

   if( me.is_altitude_acquire() ) {
       altitudeft = me.itself["autoflight"].getChild("altitude-select").getValue();
       me.apaltitude(altitudeft);
   }
}

Autopilot.is_altitude_hold = func {
   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_altitude_acquire = func {
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();
   var result = constant.FALSE;

   if( verticalmode == "altitude-acquire" ) {
       result = constant.TRUE;
   }

   return result;
}

# autopilot altitude acquire
Autopilot.apaltitudeexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_altitude_acquire() ) {
       me.apactivatemode("vertical","altitude-acquire");
       me.apaltitudeselectexport();

       me.apengage();

       me.altitudeacquire();
   }
   else {
       me.apdiscvertical();

       me.apengage();
   }
}
}

Autopilot.apaltitude = func( altitudeft ) {
   me.itself["settings"].getChild("target-altitude-ft").setValue(altitudeft);
}

# toggle altitude hold (ctrl-T)
Autopilot.aptogglealtitudeholdexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_altitude() ) {
           me.apdiscaltitude();
           me.apengage();
       }
       else {
           me.apenable();
           me.apaltitudeholdexport();
       }
   }
}

# autopilot altitude hold
Autopilot.apaltitudeholdexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   var altitudeft = 0.0;

   if( !me.is_altitude_hold() ) {
       altitudeft = me.get_altimeter().getChild("indicated-altitude-ft").getValue();
       me.apaltitude(altitudeft);
       me.apactivatemode2("altitude","altitude-hold","");
   }
   else {
       me.apdiscverticalmode2();
   }

   me.apengage();

   me.altitudelight();
}
}

Autopilot.has_altitude_hold = func {
   var result = me.is_engaged();

   if( result ) {
       if( !me.is_altitude_hold() or me.is_altitude_acquire() ) {
           result = constant.FALSE;
       }
       else {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.modeglide = func {
    me.itself["autoflight"].getChild("altitude").setValue("gs1-hold");
}

Autopilot.is_lock_glide = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;
   var ndefl = getprop("instrumentation/nav[0]/gs-needle-deflection-norm");

#   if( altitudemode == "gs1-hold" and (ndefl<-0.2 or ndefl>0.2 ) ) {
#       me.verticalspeed(0);
#   }


   if( altitudemode == "gs1-hold" and ndefl>-0.05 and ndefl<0.2  ) {
       result = constant.TRUE;
   }

#   if( altitudemode == "gs1-hold") {
#       result = constant.TRUE;
#   }


   return result;
}

# toggle glide slope (ctrl-G)
Autopilot.aptoggleglideexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_glide() ) {
           me.apdiscverticalmode2();
           me.apengage();
       }
       else {
           me.apenable();
           me.apglideexport();
       }
   }
}

Autopilot.is_glide = func {
   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "gs1-hold") {
       result = constant.TRUE;
   }

   return result;
}

# autopilot glide slope
Autopilot.apglideexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_glide() ) {
       me.apactivatemode("altitude","gs1-hold");
       me.apactivatemode2("heading","nav1-hold","");
       me.apsendnavexport();
   }
   else {
       me.apdiscverticalmode2();
       me.modevorloc();
   }

   me.apengage();

   if( !me.is_goaround() ) {
       me.autoland();
   }
}
}

Autopilot.attitudepitch = func {
   var pitchdeg = me.noinstrument["pitch"].getValue();

   me.pitch( pitchdeg );
}

Autopilot.pitch = func( pitchdeg ) {
   me.itself["settings"].getChild("target-pitch-deg").setValue(pitchdeg);
}

Autopilot.modepitch = func( pitchdeg ) {
   me.pitch( pitchdeg );
   me.itself["autoflight"].getChild("altitude").setValue("pitch-hold");
}

Autopilot.is_lock_pitch = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "pitch-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle pitch hold (ctrl-P)
Autopilot.aptogglepitchexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_pitch() ) {
           me.apdiscaltitude();
           me.apengage();
       }
       else {
           me.apenable();
           me.appitchexport();
       }
   }
}

Autopilot.is_pitch = func {
   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "pitch-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# autopilot pitch hold
Autopilot.appitchexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_pitch() or me.is_turbulence() ) {
       me.attitudepitch();
       me.apactivatemode("altitude","pitch-hold");
       if( !me.is_altitude_acquire() ) {
           me.apdiscvertical();
       }
   }
   else {
       me.apdiscverticalmode2();
   }

   me.apengage();
}
}

Autopilot.sonicverticalspeed = func {
   var name = "vertical-speed-hold";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );
}

Autopilot.sonicaltitudemode = func {
   var mode = "";

   if( me.is_lock_vertical() ) {
       mode = "vertical-speed-hold";
   }
   elsif( me.is_lock_altitude() ) {
       mode = "altitude-hold";
   }
   elsif( me.is_lock_glide() ) {
       mode = "gs1-hold";
   }

   mode = me.sonicmode( mode );

   me.itself["sonic"].getChild("altitude").setValue(mode);

   me.sonicverticalspeed();
}

Autopilot.verticalspeed = func( speedfpm ) {
   me.itself["settings"].getChild("vertical-speed-fpm").setValue(speedfpm);
}

Autopilot.modeverticalspeed = func( speedfpm ) {
   me.verticalspeed(speedfpm);
   me.apactivatemode("altitude","vertical-speed-hold");
}

Autopilot.modeverticalspeedhold = func {
   var speedfps = me.get_ivsi().getChild("indicated-speed-fps").getValue();
   var speedfpm = speedfps * constant.MINUTETOSECOND;

   me.modeverticalspeed(speedfpm);
}

Autopilot.is_lock_vertical = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "vertical-speed-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_vertical_speed = func {
   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "vertical-speed-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# autopilot vertical speed hold
Autopilot.apverticalexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_vertical_speed() or me.autothrottlesystem.is_maxclimb() ) {
       if( !me.is_altitude_acquire() ) {
           me.apdiscverticalmode2();
       }
       me.modeverticalspeedhold();
   }

   else {
       me.apdiscaltitude();
   }

   me.apengage();
}
}

Autopilot.is_lock_speed_pitch = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "speed-with-pitch" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_speed_pitch = func {
   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "speed-with-pitch" ) {
       result = constant.TRUE;
   }

   return result;
}

# speed with pitch
Autopilot.apspeedpitchexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   # only if no autothrottle
   if( !me.is_speed_pitch() ) {
       if( !me.autothrottlesystem.is_engaged() ) {
           me.autothrottlesystem.holdspeed();
           me.apactivatemode2("altitude","speed-with-pitch","");
       }

       # default to pitch hold if autothrottle
       else {
           me.appitchexport();
       }
   }
   else {
       me.apdiscverticalmode2();
   }

   me.apengage();
}
}

Autopilot.is_lock_mach_pitch = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "mach-with-pitch" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_mach_pitch = func {
   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "mach-with-pitch" ) {
       result = constant.TRUE;
   }

   return result;
}

# mach with pitch
Autopilot.apmachpitchexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   # only if no autothrottle
   if( !me.is_mach_pitch() ) {
       if( !me.autothrottlesystem.is_engaged() ) {
           me.autothrottlesystem.holdmach();
           me.apactivatemode2("altitude","mach-with-pitch","");
       }

       # default to pitch hold if autothrottle
       else {
           me.appitchexport();
       }
   }

   else {
       me.apdiscverticalmode2();
   }

   me.apengage();
}
}

# max climb mode (includes max cruise mode)
Autopilot.maxclimb = func {
   altft = me.get_altimeter().getChild("indicated-altitude-ft").getValue();
   ceil=me.itself["autoflight"].getChild("altitude-select").getValue();
   olddelta=getprop("/instrumentation/adc/output/delta_spd");
   newdelta=getprop("/instrumentation/adc/output/vmo-kt")-getprop("/instrumentation/adc/output/airspeed-kt");
   mcvspd=getprop("/instrumentation/gps/indicated-vertical-speed");
   dd=abs(newdelta-olddelta);
   vspd=getprop("/autopilot/settings/vertical-speed-fpm");
   mode=getprop("/controls/autoflight/speed2");


   if( me.autothrottlesystem.is_maxclimb() ) {          
       if( me.is_engaged() ) {
           me.autothrottlesystem.maxclimb();
       }

       if(olddelta != 0){
	  if(newdelta>olddelta and newdelta>0 and mode=='maxclimb'){
 	    vspd=vspd-50;
	  };

	  if(newdelta<olddelta and newdelta<2){
 	    vspd=vspd+50;
	  };

          if(mode=='maxcruise'){
	  	if (mcvspd>60){
		  vspd=vspd-10;
	  	};

	  	if (mcvspd<40){
		  vspd=vspd+10;
	  	};
	  };

          if(mode=='maxcruise' and altft>ceil){
		setprop("/autopilot/settings/target-altitude-ft",60000);
		globals.Concorde.autopilotsystem.apaltitudeholdexport();
	  };


          setprop("/autopilot/settings/vertical-speed-fpm",vspd);
       };

       setprop("/instrumentation/adc/output/delta_spd",newdelta);
       setprop("/instrumentation/adc/output/olddelta_spd",olddelta);


       # re-schedule the next call
       settimer(func { me.maxclimb(); }, me.MAXCLIMBSEC);
   }
}

# max climb mode
Autopilot.apmaxclimbexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( me.autothrottlesystem.is_maxclimb() ) {          
       me.apdiscaltitude();
   }

   # holds pitch and VMO with throttle
   else {
       if( !me.is_altitude_acquire() ) {
           me.apdiscverticalmode2();
       }
       me.modeverticalspeedhold();
       me.autothrottlesystem.atactivatemode("speed2","maxclimb");
       me.maxclimb();
   }          

   me.apengage();
}
}

# ---------------
# HORIZONTAL MODE
# ---------------

Autopilot.apdischorizontalmode2 = func {
   me.apdischorizontal();
   me.apdischeading();
}

# disconnect horizontal mode
Autopilot.apdischorizontal = func {
   me.itself["autoflight"].getChild("horizontal").setValue("");
}

Autopilot.is_waypoint = func {
   var result = constant.FALSE;

   if( me.route_active() ) {
       var id = me.itself["waypoint"][0].getChild("id").getValue();

       if( id != nil and id != "" ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.route_active = func {
   var result = constant.FALSE;

   # autopilot/route-manager/wp is updated only once airborne
   if( me.itself["route-manager"].getChild("active").getValue() and
       me.itself["route-manager"].getChild("airborne").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.locktrue = func {
   me.itself["locks"].getChild("heading").setValue("true-heading-hold");
}

Autopilot.is_lock_true = func {
   var headingmode = me.itself["locks"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_true = func {
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.inslight = func {
   var activation = constant.FALSE;
   var id = ["", "", ""];

   # TEMPORARY work around for 2.0.0
   if( me.route_active() ) {
       activation = constant.TRUE;

       # each time, because the route can change
       var wp = me.itself["route"].getChildren("wp");
       var current_wp = me.itself["route-manager"].getChild("current-wp").getValue();
       var nb_wp = size(wp);

       # route manager doesn't update these fields
       if( nb_wp >= 1 ) {
           id[0] = wp[current_wp].getChild("id").getValue();

           # default
           id[1] = "";
           id[2] = id[0];
       }

       if( current_wp + 1 < nb_wp ) {
           id[1] = wp[current_wp + 1].getChild("id").getValue();
       }

       if( nb_wp > 0 ) {
           id[2] = wp[nb_wp-1].getChild("id").getValue();
       }
   }

   me.itself["waypoint"][0].getChild("id").setValue( id[0] );
   me.itself["waypoint"][1].getChild("id").setValue( id[1] );
   me.itself["route-manager"].getNode("wp-last").getNode("id",constant.DELAYEDNODE).setValue( id[2] );


   # no more waypoint
   if( me.is_ins() ) {

       # simulate an INS failure, by holding the magnetic heading
       # (cannot hold the true heading, when there are still waypoints).
       if( me.ins_failure() ) {
           me.apdischorizontal();
           me.magneticheading();
           me.lockmagnetic();
       }

       # keeps the current heading mode
       elsif( !me.is_waypoint() ) {
           me.apdischorizontal();
       }
   }

   # waypoint
   elsif( me.is_waypoint() ) {
       # real behaviour : INS input doesn't toggle autopilot
       if( !me.itself["autoflight"].getChild("fg-waypoint").getValue() ) {
           # keep current heading mode, if any
           if( !me.is_true() ) {
               me.apengage();
           }

           # already in true heading mode : keep display coherent
           elsif( !me.is_ins() ) {
               me.apinsexport();
           }
       }

       # Feedback requested by user : activation of route toggles autopilot
       elsif( !me.routeactive ) {
           # only when route is being activated (otherwise cannot leave INS mode)
           if( !me.is_ins() ) {
               me.apinsexport();
           }
       }
   }


   me.routeactive = activation;
}

Autopilot.ins_failure = func {
   var index = 0;
   var result = constant.FALSE;

   if( me.has_engaged() ) {
       # INS 2
       if( me.get_hsi().getChild("nav-ins2").getValue() ) {
           index = 1;
       }

       # INS 1
       else {
           index = 0;
       }

       if( me.dependency["ins"][index].getNode("light/warning").getValue() ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.is_ins = func {
   var horizontalmode = me.itself["autoflight"].getChild("horizontal").getValue();
   var result = constant.FALSE;

   if( horizontalmode == "ins" ) {
       result = constant.TRUE;
   }

   return result;
}

# ins mode
Autopilot.apinsexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_ins() ) {
       if( me.is_waypoint() ) {
           me.apactivatemode2("heading","true-heading-hold","ins");
       }
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}
}

# ------------
# HEADING MODE
# ------------

# disconnect heading mode
Autopilot.apdischeading = func {
   me.itself["autoflight"].getChild("heading").setValue("");

   if( me.is_turbulence() ) {
       me.apdiscvertical();
   }
}

# correction of prediction filter oscillations
Autopilot.predictioncorrection = func( name, node, mode, mindeg ) {
   # disabled, when it amplifies oscillations :
   # - speed up.
   # - supersonic cruise
   if( !me.itself["pid"].getChild("prediction-filter").getValue() or
       me.noinstrument["speed-up"].getValue() > 1.0 or
       me.is_supersonicpid( mode ) ) {
       me.resetprediction( name );
   }


   else {
       var erroraheaddeg = 0.0;
       var errordeg = 0.0;
       var offsetdeg = 0.0;
       var deltastablesec = 0.0;
       var deltalaunchsec = 0.0;
       var path = "";


       var filter = node.getChild("prediction-filter").getValue();

       var stablesec = node.getChild("stable-sec").getValue();
       var launchsec = node.getChild("launch-sec").getValue();
       var timesec = me.noinstrument["time"].getValue();

       if( stablesec > 0.0 ) {
           deltastablesec = timesec - stablesec;
       }
       if( launchsec > 0.0 ) {
           deltalaunchsec = timesec - launchsec;
       }


       path = me.itself["config"][me.PIDSUPERSONIC].getNode(name).getChild("input").getValue();
       erroraheaddeg = props.globals.getNode(path).getValue();

       path = me.itself["config"][me.PIDSUBSONIC].getNode(name).getChild("input").getValue();
       errordeg = props.globals.getNode(path).getValue();

       offsetdeg = errordeg - erroraheaddeg;
       offsetdeg = math.abs( offsetdeg );


       # would bank into the opposite direction, when engaged
       if( deltalaunchsec <= me.PREDICTIONSEC ) {
           deltastablesec = 0.0;

           # enable filter later on a plausible prediction
           mode = me.PIDSUPERSONIC;
       }

       # filter amplifies oscillations, once in cruise
       elsif( offsetdeg < mindeg and deltastablesec > me.STABLESEC ) {
           # disable filter in cruise
           mode = me.PIDSUPERSONIC;
       }

       # hysteresis, once stable
       elsif( !filter and offsetdeg < ( 2 * mindeg ) and deltastablesec > me.STABLESEC ) {
           # will enable filter on a higher offset
           mode = me.PIDSUPERSONIC;
       }

       # filter not yet stable
       else {
           deltastablesec = 0.0;
       }


       me.setprediction( name, node, mode );


       # reset timers
       if( deltastablesec <= 0.0 ) {
           me.setpredictionstability( node, timesec );
       }

       if( deltalaunchsec <= 0.0 ) {
           me.setpredictionlaunch( node, timesec );
       }
   }
}

Autopilot.setprediction = func( name, node, mode ) {
   var result = constant.FALSE;
   var child = node.getChild("input");
   var currentpath = child.getAliasTarget().getPath();
   var path = me.itself["config"][mode].getNode(name).getChild("input").getValue();

   # update only on change
   if( currentpath != path ) {
       child.unalias();
       child.alias( path );

       # feedback on filter activity
       node.getChild("prediction-filter").setValue( me.is_subsonicpid( mode ) );

       result = constant.TRUE;
   }

   return result;
}

Autopilot.resetprediction = func( name ) {
   var node = me.itself["pid"].getNode(name);

   if( me.setprediction( name, node, me.PIDSUPERSONIC ) ) {
       me.setpredictionstability( node, 0.0 );
       me.setpredictionlaunch( node, 0.0 );
   }
}

Autopilot.setpredictionstability = func( node, stablesec ) {
   node.getChild("stable-sec").setValue( stablesec );
}

Autopilot.setpredictionlaunch = func( node, launchsec ) {
   node.getChild("launch-sec").setValue( launchsec );
}

Autopilot.trueheading = func( headingdeg ) {
   me.itself["settings"].getChild("true-heading-deg").setValue(headingdeg);
}

# sonic true mode
Autopilot.sonictrueheading = func {
   var name = "true-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );
   node.getChild("u_min").setValue( me.itself["config"][mode].getNode(name).getChild("u_min").getValue() );
   node.getChild("u_max").setValue( me.itself["config"][mode].getNode(name).getChild("u_max").getValue() );

   # prediction filter may bank into the opposite direction, when engaged
   me.predictioncorrection( name, node, mode, me.OSCTRACKDEG );

   name = "true-heading-hold3";
   node = me.itself["pid"].getNode(name);
   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );

   # not real : FG default keyboard changes autopilot heading
   if( me.is_lock_true() and me.istrackheading() ) {
       headingdeg = me.itself["settings"].getChild("true-heading-deg").getValue();
       me.itself["channel"][me.engaged_channel].getChild("heading-true-select").setValue(headingdeg);
   }
}

# sonic magnetic mode
Autopilot.sonicmagneticheading = func {
   var name = "dg-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );
   node.getChild("u_min").setValue( me.itself["config"][mode].getNode(name).getChild("u_min").getValue() );
   node.getChild("u_max").setValue( me.itself["config"][mode].getNode(name).getChild("u_max").getValue() );

   # prediction filter amplifies oscillations
   if( me.is_autoland() or !me.istrackheading() ) {
       me.resetprediction( name );
   }

   else {
       me.predictioncorrection( name, node, mode, me.OSCTRACKDEG );
   }

   name = "dg-heading-hold3";
   node = me.itself["pid"].getNode(name);
   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );

   # not real : FG default keyboard changes autopilot heading
   if( me.is_lock_magnetic() and me.istrackheading() ) {
       headingdeg = me.itself["settings"].getChild("heading-bug-deg").getValue();
       me.itself["channel"][me.engaged_channel].getChild("heading-select").setValue(headingdeg);
   }
}

# sonic nav mode
Autopilot.sonicnavheading = func {
   var name = "nav-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   # prediction filter amplifies oscillations
   if( me.is_autoland() or me.is_glide() ) {
       me.resetprediction( name );
   }

   else {
       me.predictioncorrection( name, node, mode, me.OSCNAVDEG );
   }
}

Autopilot.sonicheadingmode = func {
   var magpid = constant.FALSE;
   var truepid = constant.FALSE;
   var navpid = constant.FALSE;

   if( me.is_lock_magnetic() ) {
       me.sonicmagneticheading();
       magpid = constant.TRUE;
   }

   elsif( me.is_lock_true() ) {
       me.sonictrueheading();
       truepid = constant.TRUE;
   }

   elsif( me.is_lock_nav() ) {
       me.sonicnavheading();
       navpid = constant.TRUE;
   }

   if( !magpid ) {
       me.resetprediction( "dg-heading-hold1" );
   }
   if( !truepid ) {
       me.resetprediction( "true-heading-hold1" );
   }
   if( !navpid ) {
       me.resetprediction( "nav-hold1" );
   }
}

Autopilot.heading = func( headingdeg ) {
   me.itself["settings"].getChild("heading-bug-deg").setValue(headingdeg);
}

# magnetic heading
Autopilot.magneticheading = func {
   var headingdeg = me.noinstrument["magnetic"].getValue();

   me.heading(headingdeg);
}

# heading hold
Autopilot.apheadingholdexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   var mode = me.itself["autoflight"].getChild("horizontal").getValue();

   if( mode != "magnetic" ) {
       me.magneticheading();
       me.apactivatemode2("heading","dg-heading-hold","magnetic");
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}
}

Autopilot.lockmagnetic = func {
   me.itself["locks"].getChild("heading").setValue("dg-heading-hold");
}

Autopilot.is_lock_magnetic = func {
   var headingmode = me.itself["locks"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_magnetic = func {
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.has_lock_heading = func {
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode != "" and headingmode != nil ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle heading hold (ctrl-H)
Autopilot.aptoggleheadingexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_magnetic() ) {
           me.apdischorizontalmode2();
           me.apengage();
       }
       else {
           me.apenable();
           me.apheadingholdexport();
       }
   }
}

Autopilot.istrackheading = func {
   var result = constant.FALSE;

   if( me.itself["autoflight"].getChild("horizontal").getValue() == "track-heading" ) {
       result = constant.TRUE;
   }

  return result;
}

Autopilot.apsendheadingexport = func {
   var headingdeg = 0.0;

   if( me.istrackheading() ) {
       if( me.is_engaged() ) {
           if( !me.itself["channel"][me.engaged_channel].getChild("track-push").getValue() ) {
               me.apactivatemode("heading","dg-heading-hold");
               headingdeg = me.itself["channel"][me.engaged_channel].getChild("heading-select").getValue();
               me.heading(headingdeg);
           }
           else {
               me.apactivatemode("heading","true-heading-hold");
               headingdeg = me.itself["channel"][me.engaged_channel].getChild("heading-true-select").getValue();
               me.trueheading(headingdeg);
           }
       }
   }
}

# autopilot heading
Autopilot.apheadingexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.istrackheading() ) {
       me.apactivatemode("horizontal","track-heading");
       me.apsendheadingexport();
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}
}

Autopilot.is_vor = func {
   var horizontalmode = me.itself["autoflight"].getChild("horizontal").getValue();
   var result = constant.FALSE;

   if( horizontalmode == "vor" ) {
       result = constant.TRUE;
   }

   return result;
}

# VOR loc
Autopilot.modevorloc = func {
   if( me.is_nav() and !me.is_glide() ) {
       me.itself["autoflight"].getChild("horizontal").setValue("vor");
   }
}

Autopilot.locknav1 = func {
   me.itself["locks"].getChild("heading").setValue("nav1-hold");
}

Autopilot.sendnav = func( index, target ) {
   var freqmhz = 0.0;
   var radialdeg = 0.0;

   freqmhz = me.dependency["nav"][index].getNode("frequencies/selected-mhz").getValue();
   me.dependency["nav"][target].getNode("frequencies/selected-mhz").setValue(freqmhz);
   freqmhz = me.dependency["nav"][index].getNode("frequencies/standby-mhz").getValue();
   me.dependency["nav"][target].getNode("frequencies/standby-mhz").setValue(freqmhz);
   radialdeg = me.dependency["nav"][index].getNode("radials/selected-deg").getValue();
   me.dependency["nav"][target].getNode("radials/selected-deg").setValue(radialdeg);
}

Autopilot.apsendnavexport = func {
   var index = 0;

   if( me.is_engaged() ) {
       index = me.engaged_channel + 1;
       me.sendnav( index, 0 );
   }
}

Autopilot.is_lock_nav = func {
   var headingmode = me.itself["locks"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle nav 1 hold (ctrl-N)
Autopilot.aptogglenav1export = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_nav() ) {
           me.apdischorizontalmode2();
           me.apengage();
       }
       else {
           me.apenable();
           me.apvorlocexport();
       }
   }
}

Autopilot.is_nav = func {
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# autopilot vor localizer
Autopilot.apvorlocexport = func {
if (getprop("/systems/electrical/outputs/specific")>20){
   if( !me.is_nav() ) {
       me.apactivatemode2("heading","nav1-hold","");
       me.modevorloc();
       me.apsendnavexport();
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}
};

setlistener("/controls/autoflight/altitude", func() {
  mode1=getprop("/controls/autoflight/altitude");
  if (mode1=="altitude-hold"){
    setprop("/autopilot/settings/vertical-speed-fpm",0);
  }
});




