# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ===============
# VIRTUAL COPILOT
# ===============

Virtualcopilot = {};

Virtualcopilot.new = func {
   var obj = { parents : [Virtualcopilot,CommonCheck,Virtualcrew,Checklist,Emergency,System],

               airbleedsystem : nil,
               autopilotsystem : nil,
               electricalsystem : nil,
               flightsystem : nil,
               hydraulicsystem : nil,
               mwssystem : nil,
               voicecrew : nil,
 
               nightlighting : Nightlighting.new(),
               radiomanagement : RadioManagement.new(),

               FUELSEC : 30.0,
               CRUISESEC : 10.0,
               TAKEOFFSEC : 5.0,

               rates : 0.0,

               VLA41KT : 300.0,
               VLA15KT : 250.0,
               MARGINKT : 25.0,

               FL41FT : 41000.0,
               FL15FT : 15000.0,

               aglft : 0.0,

               STEPFTPM : 100.0,
               GLIDEFTPM : -1500.0,                           # best glide (guess)

               descentftpm : 0.0,

               VISORUP : 0,
               VISORDOWN : 1,
               NOSE5DEG : 2,
               NOSEDOWN : 3,

               pilotincommand : constant.FALSE
         };

   obj.init();

   return obj;
};

Virtualcopilot.init = func {
   var path = "/systems/copilot";

   me.inherit_system(path);
   me.inherit_checklist(path);
   me.inherit_emergency(path);
   me.inherit_virtualcrew(path);
   me.inherit_commoncheck(path);

   me.rates = me.TAKEOFFSEC;
   me.run();
}

Virtualcopilot.set_relation = func( airbleed, autopilot, electrical, flight, hydraulic, lighting, mws, voice ) {
   me.airbleedsystem = airbleed;
   me.autopilotsystem = autopilot;
   me.electricalsystem = electrical;
   me.flightsystem = flight;
   me.hydraulicsystem = hydraulic;
   me.mwssystem = mws;
   me.voicecrew = voice;

   me.nightlighting.set_relation( lighting );

   me.radiomanagement.set_relation( autopilot );
}


Virtualcopilot.toggleexport = func {
   var launch = constant.FALSE;

   if( !me.itself["root-ctrl"].getChild("activ").getValue() ) {
       launch = constant.TRUE;
   }

   me.itself["root-ctrl"].getChild("activ").setValue(launch);
       
   if( launch and !me.is_running() ) {
       # must switch again lights
       me.nightlighting.set_task();

       me.radiomanagement.set_task();

       me.schedule();
       me.slowschedule();
   }
}

Virtualcopilot.slowschedule = func {
   me.reset();

   me.rates = me.FUELSEC;

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.timestamp();
   }

   me.runslow();
}

Virtualcopilot.schedule = func {
   me.reset();

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.routine();
   }
   else {
       me.rates = me.CRUISESEC;
       me.itself["root"].getChild("activ").setValue(constant.FALSE);
   }

   me.run();
}

Virtualcopilot.fastschedule = func {
   me.reset();

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.unexpected();
   }
}

Virtualcopilot.runslow = func {
   if( me.itself["root-ctrl"].getChild("activ").getValue() ) {
       me.rates = me.speed_ratesec( me.rates );
       settimer( func { me.slowschedule(); }, me.rates );
   }
}

Virtualcopilot.run = func {
   if( me.itself["root-ctrl"].getChild("activ").getValue() ) {
       me.set_running();

       me.rates = me.speed_ratesec( me.rates );
       settimer( func { me.schedule(); }, me.rates );
   }
}

Virtualcopilot.unexpected = func {
   me.pilotincommand = constant.FALSE;

   if( me.itself["root-ctrl"].getChild("activ").getValue() ) {
       me.set_checklist();

       me.airspeedperception( constant.TRUE );
       me.altitudeperception( constant.TRUE );

       # 4 engines flame out
       me.engine4flameout();

       me.timestamp();
   }

   if( !me.pilotincommand ) {
       me.autopilotsystem.realhuman();
   }

   me.dependency["crew"].getChild("unexpected").setValue(me.pilotincommand);
}

Virtualcopilot.routine = func {
   me.rates = me.CRUISESEC;

   if( me.itself["root-ctrl"].getChild("activ").getValue() ) {
       me.set_checklist();
       me.set_emergency();

       # normal procedures
       if ( me.normal() ) {
            me.rates = me.randoms( me.rates );
       }

       me.timestamp();
   }

   me.itself["root"].getChild("activ").setValue(me.is_activ());
}

Virtualcopilot.engine4flameout = func {
   # hold heading and speed, during engine start
   if( me.altitudeft > constantaero.APPROACHFT ) {
       if( me.autopilotsystem.no_voltage() ) {
           me.pilotincommand = constant.TRUE;

           me.log("no-autopilot");

           me.autopilotsystem.virtualhuman();

           me.keepheading();

           me.keepspeed();
       }
   }
}

# instrument failures ignored
Virtualcopilot.normal = func {
    me.rates = me.TAKEOFFSEC;

    me.airspeedperception( constant.FALSE );
    me.altitudeperception( constant.FALSE );
    me.aglft = me.noinstrument["agl"].getValue();


    # normal
    if( me.is_beforetakeoff() ) {
        me.set_activ();
        me.beforetakeoff();
        me.rates = me.TAKEOFFSEC;
    }

    elsif( me.is_taxi() ) {
        me.set_activ();
        me.taxi();
    }

    elsif( me.is_afterstart() ) {
        me.set_activ();
        me.afterstart();
    }

    elsif( me.is_pushback() ) {
        me.set_activ();
        me.pushback();
    }

    elsif( me.is_enginestart() ) {
        me.set_activ();
        me.completed();
    }

    elsif( me.is_beforestart() ) {
        me.set_activ();
        me.beforestart();
    }

    elsif( me.is_cockpit() ) {
        me.set_activ();
        me.cockpit();
    }

    elsif( me.is_preliminary() ) {
        me.completed();
    }

    elsif( me.is_external() ) {
        me.completed();
    }

    elsif( me.is_stopover() ) {
        me.set_activ();
        me.stopover();
    }

    elsif( me.is_parking() ) {
        me.set_activ();
        me.parking();
    }

    elsif( me.is_afterlanding() ) {
        me.set_activ();
        me.afterlanding();
    }

    elsif( me.is_beforelanding() ) {
        me.set_activ();
        me.beforelanding();
        me.rates = me.TAKEOFFSEC;
    }

    elsif( me.is_approach() ) {
        me.set_activ();
        me.approach();
        me.rates = me.TAKEOFFSEC;
    }

    elsif( me.is_descent() ) {
        me.set_activ();
        me.descent();
    }

    elsif( me.is_transsonic() ) {
        me.set_activ();
        me.transsonic();
    }

    elsif( me.is_climb() ) {
        me.set_activ();
        me.climb();
    }

    elsif( me.is_aftertakeoff() ) {
        me.set_activ();
        me.aftertakeoff();
        me.rates = me.TAKEOFFSEC;
    }


    # emergency
    elsif( me.is_fourengineflameout() ) {
        me.set_activ();
        me.fourengineflameout();
    }

    elsif( me.is_fourengineflameoutmach1() ) {
        me.set_activ();
        me.fourengineflameoutmach1();
    }


    me.allways();

    return me.is_activ();
}


# ------
# FLIGHT
# ------
Virtualcopilot.allways = func {
    if( me.altitudeft > constantaero.APPROACHFT ) {
        me.nosevisor( me.VISORUP );
    }

    if( me.altitudeft > constantaero.TRANSITIONFT ) {
        me.altimeter();
    }

    me.nightlighting.copilot( me );
    me.radiomanagement.copilot( me );
}

Virtualcopilot.aftertakeoff = func {
    me.landinggear( constant.FALSE );
    
    if( me.aglft > constantaero.CLIMBFT ) {
        me.mainlanding( constant.FALSE );
        me.landingtaxi( constant.FALSE );

        me.mwsrecallcaptain();

        me.nosevisor( me.VISORDOWN );

        # otherwise disturbing
        me.takeoffmonitor( constant.FALSE );

        me.completed();
    }
}

Virtualcopilot.climb = func {
    me.taxiturn( constant.FALSE );

    me.completed();
}

Virtualcopilot.transsonic = func {
    me.completed();
}

Virtualcopilot.descent = func {
    me.completed();
}

Virtualcopilot.approach = func {
    me.taxiturn( constant.TRUE );

    me.nosevisor( me.VISORDOWN );

    # relocation in flight
    me.takeoffmonitor( constant.FALSE );

    me.completed();
}

Virtualcopilot.beforelanding = func {
    me.landinggear( constant.TRUE );
    me.nosevisor( me.NOSEDOWN );
    me.brakelever( constant.FALSE );

    me.mainlanding( constant.TRUE );

    # relocation in flight
    me.takeoffmonitor( constant.FALSE );

    me.completed();
}


# ------
# GROUND
# ------
Virtualcopilot.afterlanding = func {
    me.mwsinhibitcaptain();

    me.nosevisor( me.NOSE5DEG );

    me.landingtaxi( constant.TRUE );
    me.mainlanding( constant.FALSE );

    me.completed();
}

Virtualcopilot.parking = func {
    me.mainlanding( constant.FALSE );
    me.landingtaxi( constant.FALSE );
    me.taxiturn( constant.FALSE );

    me.nosevisor( me.VISORUP );

    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         me.ins( i, constantaero.INSALIGN );
    }

    me.completed();
}

Virtualcopilot.stopover = func {
    me.allinverter( constant.FALSE );

    me.completed();
}

Virtualcopilot.cockpit = func {
    me.allinverter( constant.TRUE );

    me.completed();
}

Virtualcopilot.beforestart = func {
    me.brakelever( constant.TRUE );

    if( me.can() ) {
        if( !me.is_completed() ) {
            if( !me.wait_ground() ) {
                var callsign = me.noinstrument["user"].getValue();

                me.voicecrew.pilotcheck( "clearance", callsign );

                # must wait for ATC answer
                me.done_ground();
            }

            else {
                me.reset_ground();

                me.voicecrew.pilotcheck( "clear" );

                me.completed();
            }
        }
    }
}

Virtualcopilot.pushback = func {
    if( me.inboardenginesrunning() ) {
        me.grounddisconnect();
        me.tractor();

        me.completed();
    }
}

Virtualcopilot.afterstart = func {
    me.steering();
    me.grounddisconnect();

    me.flightchannelcaptain();

    if( me.has_completed() ) {
        me.voicecrew.pilotcheck( "completed" );
        me.voicecrew.startedinit();
    }
}

Virtualcopilot.taxi = func {
    me.nosevisor( me.NOSE5DEG );

    me.taxiturncaptain( constant.TRUE );
    me.landingtaxicaptain( constant.TRUE );
    me.mainlanding( constant.FALSE );

    me.completed();
}

Virtualcopilot.beforetakeoff = func {
    if( me.is_startup() ) {
        me.nosevisor( me.NOSE5DEG );
        me.not_startup();
    }

    me.taxiturn( constant.TRUE );
    me.mainlanding( constant.TRUE );
    me.landingtaxi( constant.FALSE );

    me.mwsrecallcaptain();
    me.mwsinhibitcaptain();

    me.takeoffmonitor( constant.TRUE );

    me.completed();
}


# ---------
# EMERGENCY
# ---------
Virtualcopilot.fourengineflameout = func {
    me.completed();
}

Virtualcopilot.fourengineflameoutmach1 = func {
    me.completed();
}


# ---------------------
# MASTER WARNING SYSTEM
# ---------------------
Virtualcopilot.mwsinhibitcaptain = func {
    if( me.can() ) {
        if( !me.dependency["mws"].getChild("inhibit").getValue() ) {
            if( me.is_busy() ) {
                me.dependency["mws"].getChild("inhibit").setValue(constant.TRUE);
                me.toggleclick("inhibit");
                me.voicecrew.captaincheck( "inhibit" );
            }

            else {
                me.done_crew("not-inhibit");
                me.voicecrew.engineercheck( "inhibit" );
            }
        }
    }
}

Virtualcopilot.mwsrecallcaptain = func {
    if( me.can() ) {
        if( !me.is_recall() ) {
            if( me.is_busy() ) {
                me.mwssystem.recallexport();
                me.toggleclick("recall");
                me.voicecrew.captaincheck( "recall" );
            }

            else {
                me.done_crew("not-recall");
                me.voicecrew.engineercheck( "recall" );
            }
        }
    }
}


# ---------------
# FLIGHT CONTROLS
# ---------------
Virtualcopilot.allinverter = func( value ) {
    me.inverter( "blue", value );
    me.inverter( "green", value );
}

Virtualcopilot.inverter = func( color, value ) {
    if( me.can() ) {
        var path = "inverter-" ~ color;

        if( me.dependency["electric-dc"].getChild(path).getValue() != value ) {
            me.dependency["electric-dc"].getChild(path).setValue(value);
            me.toggleclick(path);
        }
    }
}

Virtualcopilot.is_flightchannel = func {
    var result = constant.TRUE;

    if( me.can() ) {
        if( !me.dependency["channel"].getChild("rudder-blue").getValue() or
            me.dependency["channel"].getChild("rudder-mechanical").getValue() or
            !me.dependency["channel"].getChild("inner-blue").getValue() or
            me.dependency["channel"].getChild("inner-mechanical").getValue() or
            !me.dependency["channel"].getChild("outer-blue").getValue() or
            me.dependency["channel"].getChild("outer-mechanical").getValue() ) {
            result = constant.FALSE;

            me.done_crew("channel-not-blue");
        }

        if( result ) {
            me.reset_crew();
        }
    }

    # captain must reset channels
    return result;
}

Virtualcopilot.flightchannel = func {
    if( me.can() ) {
        if( !me.dependency["channel"].getChild("rudder-blue").getValue() or
            me.dependency["channel"].getChild("rudder-mechanical").getValue() ) {
            me.dependency["channel"].getChild("rudder-blue").setValue(constant.TRUE);
            me.dependency["channel"].getChild("rudder-mechanical").setValue(constant.FALSE);

            me.flightsystem.resetexport();
            me.toggleclick("rudder-channel");
        }

        elsif( !me.dependency["channel"].getChild("inner-blue").getValue() or
            me.dependency["channel"].getChild("inner-mechanical").getValue() ) {
            me.dependency["channel"].getChild("inner-blue").setValue(constant.TRUE);
            me.dependency["channel"].getChild("inner-mechanical").setValue(constant.FALSE);

            me.flightsystem.resetexport();
            me.toggleclick("inner-channel");
        }

        elsif( !me.dependency["channel"].getChild("outer-blue").getValue() or
            me.dependency["channel"].getChild("outer-mechanical").getValue() ) {
            me.dependency["channel"].getChild("outer-blue").setValue(constant.TRUE);
            me.dependency["channel"].getChild("outer-mechanical").setValue(constant.FALSE);

            me.flightsystem.resetexport();
            me.toggleclick("outer-channel");
        }
    }
}

Virtualcopilot.flightchannelcaptain = func {
    if( me.is_busy() ) {
        var available = me.can();

        me.flightchannel();

        if( available and me.is_flightchannel() ) {
            me.voicecrew.captaincheck( "channel" );
        }
    }

    elsif( !me.is_flightchannel() ) {
        me.voicecrew.pilotcheck( "channel" );
    }
}


# -------
# ENGINES
# -------
Virtualcopilot.takeoffmonitor = func( set ) {
    if( me.can() ) {
        var path = "armed";

        if( me.dependency["to-monitor"].getChild(path).getValue() != set ) {
            me.dependency["to-monitor"].getChild(path).setValue( set );
            me.toggleclick("to-monitor");
        }
    }
}

Virtualcopilot.inboardenginesrunning = func {
    var result = constant.TRUE;

    for( var i = constantaero.ENGINE2; i <= constantaero.ENGINE3; i = i + 1 ) {
         if( !me.dependency["engine"][i].getChild("running").getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}


# ---------
# AUTOPILOT
# ---------
Virtualcopilot.keepspeed = func {
    if( !me.autopilotsystem.is_vertical_speed() ) {
        me.log("vertical-speed");
        me.autopilotsystem.apverticalexport();
        me.descentftpm = me.GLIDEFTPM;
    }

    # the copilot follows the best glide
    me.adjustglide();  
    me.autopilotsystem.verticalspeed( me.descentftpm );
}

Virtualcopilot.adjustglide = func {
    var minkt = 0;

    if( me.altitudeft > me.FL41FT ) {
        minkt = me.VLA41KT;
    }
    elsif( me.altitudeft > me.FL15FT and me.altitudeft <= me.FL41FT ) {
        minkt = me.VLA15KT;
    }
    else {
        minkt = constantaero.V2FULLKT;
    }

    # stay above VLA (lowest allowed speed)
    minkt = minkt + me.MARGINKT;

    if( me.speedkt < minkt ) {
        me.descentftpm = me.descentftpm - me.STEPFTPM;
    }
}

Virtualcopilot.keepheading = func {
    if( !me.autopilotsystem.is_lock_magnetic() ) {
        me.log("magnetic");
        me.autopilotsystem.apheadingholdexport();
    }
}


# ----
# GEAR
# ----
Virtualcopilot.steering = func {
    if( me.can() ) {
        if( !me.dependency["steering"].getChild("hydraulic").getValue() ) {
            me.dependency["steering"].getChild("hydraulic").setValue( constant.TRUE );
            me.toggleclick("steering");
        }
    }
}

Virtualcopilot.brakelever = func( set ) {
    if( me.can() ) {
        if( me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() != set ) {
            me.hydraulicsystem.brakesemergencyexport();
            me.toggleclick("brake-parking");
        }
    }
}

Virtualcopilot.landinggear = func( landing ) {
    if( me.can() ) {
        if( !landing ) {
            if( me.dependency["gear-ctrl"].getChild("gear-down").getValue() ) {
                if( me.aglft > constantaero.GEARFT and me.speedkt > constantaero.GEARKT ) {
                    controls.gearDown(-1);
                    me.toggleclick("gear-up");
                }

                # waits
                else {
                    me.done();
                }
            }

            elsif( me.dependency["gear-ctrl"].getChild("hydraulic").getValue() ) {
                if( me.dependency["gear"].getValue() == globals.Concorde.constantaero.GEARUP ) {
                    controls.gearDown(-1);
                    me.toggleclick("gear-neutral");
                }

                # waits
                else {
                    me.done();
                }
            }
        }

        elsif( !me.dependency["gear-ctrl"].getChild("gear-down").getValue() ) {
            if( me.aglft < constantaero.LANDINGFT and me.speedkt < constantaero.GEARKT ) {
                controls.gearDown(1);
                me.toggleclick("gear-down");
            }

            # waits
            else {
                me.done();
            }
        }
    }
}


# ----
# NOSE
# ----
Virtualcopilot.nosevisor = func( targetpos ) {
    if( me.can() ) {
        var currentpos = 0;
        var child = nil;


        # not to us to create the property
        child = me.dependency["flaps"].getChild("current-setting");
        if( child == nil ) {
            currentpos = me.VISORUP;
        }
        else {
            currentpos = child.getValue();
        }

        pos = targetpos - currentpos;
        if( pos != 0 ) {
            # - must be up above 270 kt.
            # - down only below 220 kt.
            if( ( targetpos <= me.VISORDOWN and me.speedkt < constantaero.NOSEKT ) or
                ( targetpos > me.VISORDOWN and me.speedkt < constantaero.GEARKT ) ) {
                controls.flapsDown( pos );
                me.toggleclick("nose");
            }

            # waits
            else {
                me.done();
            }
        }
    }
}


# ----------
# NAVIGATION
# ----------
Virtualcopilot.altimeter = func {
    if( me.can() ) {
        if( me.dependency["altimeter"].getChild("setting-inhg").getValue() != constantISA.SEA_inhg ) {
            me.dependency["altimeter"].getChild("setting-inhg").setValue(constantISA.SEA_inhg);
            me.toggleclick("altimeter");
        }
    }
}


# --------
# LIGHTING
# --------
Virtualcopilot.mainlanding = func( set ) {
    var path = "";

    # optional in checklist
    if( !me.dependency["crew-ctrl"].getChild("landing-lights").getValue() ) {
        set = constant.FALSE;
    }

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "main-landing[" ~ i ~ "]/extend";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("landing-extend-" ~ i);
             }
         }

         path = "main-landing[" ~ i ~ "]/on";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("landing-on-" ~ i);
             }
         }
    }
}

Virtualcopilot.landingtaxi = func( set ) {
    var path = "";

    # optional in checklist
    if( !me.dependency["crew-ctrl"].getChild("landing-lights").getValue() ) {
        set = constant.FALSE;
    }

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "landing-taxi[" ~ i ~ "]/extend";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-extend-" ~ i);
             }
         }

         path = "landing-taxi[" ~ i ~ "]/on";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-on-" ~ i);
             }
         }
    }
}

Virtualcopilot.landingtaxicaptain = func( set ) {
    if( me.can() ) {
        if( me.is_landingtaxi() != set ) {
            if( me.is_busy() ) {
                me.landingtaxi( set );

                if( me.is_landingtaxi() == set ) {
                    me.voicecrew.captaincheck( "landingtaxi" );
                }
            }

            else {
                me.done_crew("not-landingtaxi");
                me.voicecrew.engineercheck( "landingtaxi" );
            }
        }
    }
}

Virtualcopilot.is_landingtaxi = func {
    var result = constant.TRUE;
    var path = "";

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "landing-taxi[" ~ i ~ "]/extend";

         if( !me.dependency["lighting"].getNode(path).getValue() ) {
             result = constant.FALSE;
             break;
         }

         path = "landing-taxi[" ~ i ~ "]/on";

         if( !me.dependency["lighting"].getNode(path).getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}

Virtualcopilot.taxiturn = func( set ) {
    var path = "";

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "taxi-turn[" ~ i ~ "]/on";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-turn-" ~ i);
             }
         }
    }
}

Virtualcopilot.taxiturncaptain = func( set ) {
    if( me.can() ) {
        if( me.is_taxiturn() != set ) {
            if( me.is_busy() ) {
                me.taxiturn( set );

                if( me.is_taxiturn() == set ) {
                    me.voicecrew.captaincheck( "taxiturn" );
                }
            }

            else {
                me.done_crew("not-taxiturn");
                me.voicecrew.engineercheck( "taxiturn" );
            }
        }
    }
}

Virtualcopilot.is_taxiturn = func {
    var result = constant.TRUE;
    var path = "";

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "taxi-turn[" ~ i ~ "]/on";

         if( !me.dependency["lighting"].getNode(path).getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}


# ------
# GROUND
# ------
Virtualcopilot.grounddisconnect = func {
    if( me.can() ) {
        if( me.electricalsystem.has_ground() ) {
            if( !me.wait_ground() ) {
                me.voicecrew.pilotcheck( "disconnect" );

                # must wait for electrical system run (ground)
                me.done_ground();
            }

            else  {
                me.electricalsystem.groundserviceexport();

                me.reset_ground();
                me.done();
            }
        }

        elsif( me.airbleedsystem.has_groundservice() ) {
            if( !me.wait_ground() ) {
                # must wait for air bleed system run (ground)
                me.done_ground();
            }

            else  {
                me.airbleedsystem.groundserviceexport();

                me.reset_ground();
                me.done();
            }
        }

        elsif( me.airbleedsystem.has_reargroundservice() ) {
            if( !me.wait_ground() ) {
                # must wait for temperature system run (ground)
                me.done_ground();
            }

            else  {
                me.airbleedsystem.reargroundserviceexport();

                me.reset_ground();
                me.done();
            }
        }

        elsif( me.dependency["gear-ctrl"].getChild("wheel-chocks").getValue() ) {
            if( !me.wait_ground() ) {
                # must wait for removing of wheel chocks (ground)
                me.done_ground();
            }

            else  {
                me.dependency["gear-ctrl"].getChild("wheel-chocks").setValue( constant.FALSE );

                me.reset_ground();
                me.done();
            }
        }
    }
}

Virtualcopilot.tractor = func {
    if( me.can() ) {
        # waiting for start of outboard engines
        if( me.dependency["tractor"].getChild("engine14").getValue() ) {
        }

        # from ground interphone, pushback has ended
        elsif( me.dependency["tractor"].getChild("clear").getValue() ) {
            me.dependency["tractor"].getChild("clear").setValue( constant.FALSE );
            # engineer can start outboard engines
            me.dependency["tractor"].getChild("engine14").setValue( constant.TRUE );
            me.brakelever( constant.TRUE );
            me.voicecrew.pilotcheck( "clear" );
        }

        # from ground interphone, pushback has started
        elsif( !me.dependency["tractor"].getChild("pushback").getValue() ) {
            me.dependency["tractor-ctrl"].getChild("pushback").setValue( constant.TRUE );
            me.brakelever( constant.FALSE );
            me.voicecrew.pilotcheck( "pushback" );
        }

        # waiting for end of pushback
        else {
            me.done();
        }
    }
}
