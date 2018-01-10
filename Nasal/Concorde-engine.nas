# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ======
# ENGINE
# ======

Engine = {};

Engine.new = func {
   var obj = { parents : [Engine,System],

               enginecontrol : EngineControl.new(),
               airdoor : AirDoor.new(),
               bucket : Bucket.new(),
               intake : Intake.new(),
               rating : Rating.new(),
               throttles : EngineThrottle.new(),

               CUTOFFSEC : 1.0,

               OILPSI : 15.0
         };

   obj.init();

   return obj;
};

Engine.init = func {
    me.inherit_system("/systems/engines","engine");
}

Engine.amber_intake = func( index ) {
    return me.intake.amber_intake( index );
}

Engine.red_engine = func( index ) {
    var result = constant.TRUE;

    if( me.itself["engine"][index].getChild("oil-pressure-psi").getValue() > me.OILPSI ) {
        result = constant.FALSE;
    }

    return result;
}

Engine.red_throttle = func {
    return me.throttles.red_throttle();
}

Engine.set_rate = func( rates ) {
    me.bucket.set_rate( rates );
}

Engine.set_throttle = func( position ) {
    return me.rating.set_throttle( position );
}

Engine.starter = func( index ) {
    if( !me.itself["root"][index].getChild("relight").getValue() ) {
        if( me.dependency["electric"][index].getValue() ) {
            if( me.dependency["air"][index].getValue() ) {
                me.itself["root-ctrl"][index].getChild("starter").setValue(constant.TRUE);
            }
        }
    }
}

Engine.relight = func( index, set ) {
    if( set ) {
        if( !me.itself["root-ctrl"][index].getChild("starter").getValue() ) {
            me.itself["root"][index].getChild("relight").setValue(constant.TRUE);
        }
    }

    else {
        me.itself["root"][index].getChild("relight").setValue(constant.FALSE);
    }
}

# simplified engine start (2D panel)
Engine.cutoffexport = func {
   # delay for starter
   settimer(func { me.cutoffcron(); }, me.CUTOFFSEC);
}

Engine.laneexport = func {
    me.intake.laneexport();
}

Engine.reverseexport = func {
    me.bucket.reverseexport();
}

Engine.schedule = func {
    me.throttles.schedule();
    me.bucket.schedule();
    me.airdoor.schedule();
    me.rating.schedule();
    me.enginecontrol.schedule();
    me.failure();
    me.autoignition();
    me.start();
}

Engine.slowschedule = func {
    me.intake.schedule();
}

Engine.cutoffcron = func {
   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
       # engine start by user
       if( me.itself["engine"][i].getChild("starter").getValue() ) {
           if( !me.itself["root-ctrl"][i].getChild("hp-valve").getValue() ) {
               me.itself["root-ctrl"][i].getChild("hp-valve").setValue(constant.TRUE);
           }
       }
   }
}

Engine.failure = func {
   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( !me.itself["root"][i].getChild("serviceable").getValue() ) {
            if( !me.itself["root-ctrl"][i].getChild("cutoff").getValue() ) {
                me.itself["root-ctrl"][i].getChild("cutoff").setValue(constant.TRUE);
            }
        }
   }
}

Engine.autoignition = func {
   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( me.itself["root"][i].getChild("serviceable").getValue() ) {

            if( me.itself["root-ctrl"][i].getChild("autoignition").getValue() ) {
                if( !me.itself["engine"][i].getChild("running").getValue() and
                    me.itself["root-ctrl"][i].getChild("hp-valve").getValue() and
                    me.itself["root-ctrl"][i].getChild("cutoff").getValue() ) {
                    me.itself["root-ctrl"][i].getChild("cutoff").setValue(constant.FALSE);
                }
            }
        }
   }
}

Engine.start = func {
   # action by HP valve
   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( me.itself["root"][i].getChild("serviceable").getValue() ) {

            # start requires starter or relight
            if( me.itself["root-ctrl"][i].getChild("hp-valve").getValue() ) {
                if( ( me.itself["engine"][i].getChild("starter").getValue() or
                      me.itself["root"][i].getChild("relight").getValue() ) and
                    me.itself["engine"][i].getChild("cutoff").getValue() ) {
                    me.itself["root-ctrl"][i].getChild("cutoff").setValue(constant.FALSE);
                }
            }

            # shutdown
            else {
                if( !me.itself["engine"][i].getChild("cutoff").getValue() ) {
                    me.itself["root-ctrl"][i].getChild("cutoff").setValue(constant.TRUE);
                }
            }
        }
   }
}


# ===============
# ENGINE THROTTLE
# ===============

EngineThrottle = {};

EngineThrottle.new = func {
   var obj = { parents : [EngineThrottle,System]
             };

   obj.init();

   return obj;
}

EngineThrottle.init = func {
    me.inherit_system("/systems/engines","engine");
}

EngineThrottle.red_throttle = func {
    var result = constant.FALSE;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.dependency["throttle"][i].getChild("failure").getValue() or
             me.dependency["throttle-ctrl"][i].getChild("test").getValue() ) {
             result = constant.TRUE;
             break;
         }
    }

    return result;
}

EngineThrottle.schedule = func {
    var result = constant.FALSE;
    var factor = 0.0;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( !me.dependency["throttle"][i].getChild("serviceable").getValue() or
             me.dependency["throttle-ctrl"][i].getChild("off").getValue() ) {
             result = constant.FALSE;
         }
         else {
             result = constant.TRUE;
         }

         me.dependency["throttle"][i].getChild("available").setValue( result );

         if( !me.dependency["throttle"][i].getChild("serviceable").getValue() or
             me.dependency["throttle-ctrl"][i].getChild("test").getValue() ) {
             factor = 1.0;
         }
         else {
             factor = 0.0;
         }

         if( me.dependency["throttle"][i].getChild("failure").getValue() != factor ) {
             me.dependency["throttle"][i].getChild("failure").setValue( factor );
         }
    }
}


# =======================
# ENGINE CONTROL SCHEDULE
# =======================

EngineControl = {};

EngineControl.new = func {
   var obj = { parents : [EngineControl,System],

           rating : Rating.new(),

           LOWKT : 220,

           speekt : 0,

           HIGHMACH : 1.0,

           speedmach : 0,

           wow : constant.FALSE,
           takeoff : constant.FALSE,
           climb : constant.FALSE,
           reaheat : constant.FALSE,

           FLYOVER : "flyover",
           HIGH : "high",
           MID : "mid",
           LOW : "low",

           value : ""
         };

   obj.init();

   return obj;
}

EngineControl.init = func {
    me.inherit_system("/systems/engines","engine");
}

EngineControl.schedule = func {
    var selector = 0;

    me.speedkt = me.dependency["asi"].getChild("indicated-speed-kt").getValue();
    me.speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();
    me.wow = me.dependency["weight"].getChild("wow").getValue();

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         me.reheat = me.itself["root-ctrl"][i].getChild("reheat").getValue();
         me.takeoff = me.rating.is_takeoff( i );
         me.climb = me.rating.is_climb( i );

         # auto
         if( me.itself["engines-ctrl"].getChild("schedule-auto").getValue() ) {
             selector = me.itself["engines-ctrl"].getChild("schedule").getValue();

             # detects bugs
             me.value = "";

             # normal
             if( selector == constantaero.SCHEDULENORMAL ) {
                 if( me.setlow() ) {
                 }

                 elsif( !me.is_speedlow() and !me.reheat ) {
                     me.value = me.HIGH;
                 }

                 elsif( !me.is_speedlow() and me.climb ) {
                     me.value = me.MID;
                 }
             }

             # flyover
             elsif( selector < constantaero.SCHEDULENORMAL ) {
                 if( me.setlow() ) {
                 }

                 elsif( !me.is_speedlow() and !me.is_speedhigh() and !me.reheat ) {
                     me.value = me.FLYOVER;
                 }

                 elsif( me.is_speedhigh() and !me.reheat ) {
                     me.value = me.HIGH;
                 }
             }

             # approach
             else {
                 if( me.wow ) {
                     me.value = me.LOW;
                 }

                 else {
                     me.value = me.MID;
                 }
             }
         }

         else {
             # force low
             if( me.itself["engines-ctrl"].getChild("schedule-low").getValue() ) {
                 me.value = me.LOW;
             }

             else {
                 if( me.dependency["gear"][constantaero.GEARFRONT].getChild("position-norm").getValue() == constantaero.GEARDOWN ) {
                     me.value = me.LOW
                 }

                 else {
                     if( me.takeoff and me.reheat ) {
                         me.value = me.LOW;
                     }

                     elsif( !me.takeoff and me.reheat ) {
                         me.value = me.MID;
                     }

                     # force high
                     else {
                         me.value = me.HIGH;
                     }
                 }
             }
         }

         me.itself["root"][i].getChild("schedule").setValue( me.value );
    }
}

EngineControl.setlow = func {
    var result = constant.TRUE;

    if( me.wow ) {
        me.value = me.LOW;
    }

    elsif( me.is_speedlow() ) {
        me.value = me.LOW;
    }

    elsif( me.takeoff and me.reheat ) {
        me.value = me.LOW;
    }

    else {
        result = constant.FALSE;
    }
}

EngineControl.is_speedlow = func {
    var result = constant.FALSE;

    if( me.speedkt <= me.LOWKT ) {
        result = constant.TRUE;
    }

    return result;
}

EngineControl.is_speedhigh = func {
    var result = constant.FALSE;

    if( me.speedmach >= me.HIGHMACH ) {
        result = constant.TRUE;
    }

    return result;
}


# =========
# ENGINE N1
# =========

EngineN1 = {};

EngineN1.new = func {
   var obj = { parents : [EngineN1,System],

               TRANSITSEC : 2.5,                              # duration of transit sound

               TRANSITEND : 1.0,                           
               TRANSITOFF : 0.0,

               THROTTLE88N1 : 0.806,                          # doesn't depend of temperature
	       THROTTLETOM : 0.94, 			      # T/O monitor ARMED
               THROTTLEREHEAT : 0.10,
  
               N1REHEAT : 81,
               N1EXHAUST : 50,
               N1TRANSIT : 50,                                # like sound file

               reheat : [ constant.FALSE, constant.FALSE, constant.FALSE, constant.FALSE ],

               texpath : "Textures",
               exhaust : [ 0.0, 0.0, 0.0, 0.0 ],

               engine4limiter : constant.FALSE,

               ENGINE4KT : 60.0
         };

   obj.init();

   return obj;
};

EngineN1.init = func {
    me.inherit_system("/systems/engines","engine");
}

EngineN1.get_throttle = func( position ) {
    var maxthrottle = constantaero.THROTTLEMAX;

    if( me.engine4limiter ) {
        maxthrottle = me.THROTTLE88N1;
    }

    if( position > maxthrottle ) {
        position = maxthrottle;
    }

    return position;
}

EngineN1.schedule = func {
    var speedkt = me.dependency["asi"].getChild("indicated-speed-kt").getValue();

    me.groundidle( speedkt );
    me.engine4( speedkt );
    me.reheatcontrol();
    me.transitsound();
}

EngineN1.groundidle = func( speedkt ) {
    var idle = constant.FALSE;

    if( me.itself["engines-ctrl"].getChild("ground-idle14").getValue() or
        me.itself["engines-ctrl"].getChild("ground-idle23").getValue() ) {
        idle = constant.TRUE;

        # only below 60 kt
        if( speedkt > me.ENGINE4KT ) {
            me.itself["engines-ctrl"].getChild("ground-idle14").setValue( constant.FALSE );
            me.itself["engines-ctrl"].getChild("ground-idle23").setValue( constant.FALSE );
            idle = constant.FALSE;
        }
    }

   # JSBSim can idle only 4 engines at once
   me.itself["engines-sys"].getChild("ground-idle").setValue(idle);
}

# Engine 4 N1 takeoff limiter
EngineN1.engine4 = func( speedkt ) {
    var throttle = 0.0;

    # avoids engine 4 vibration because of turbulences
    if( speedkt != nil ) {

        # only below 60 kt
        if( speedkt < me.ENGINE4KT ) {
            me.engine4limiter = me.itself["root-ctrl"][3].getChild("n1-to-limiter").getValue();
        }

        # normal control
        else {
             if( me.engine4limiter ) {
                 me.engine4limiter = constant.FALSE;

                # align throttle
                throttle = me.itself["root-ctrl"][2].getChild("throttle").getValue();
                me.itself["root-ctrl"][3].getChild("throttle").setValue(throttle);
            }
        }
    }
}

EngineN1.reheatcontrol = func {
   var augmentation = constant.FALSE;

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.itself["root-ctrl"][i].getChild("reheat").getValue() and
            me.itself["root-ctrl"][i].getChild("throttle").getValue() > me.THROTTLEREHEAT and
            me.itself["engine"][i].getChild("n1").getValue() > me.N1REHEAT ) {
            augmentation = constant.TRUE;
        }
        else {
            augmentation = constant.FALSE;
        }

        if( me.reheat[i] != augmentation ) {
            me.reheat[i] = augmentation;
            me.itself["root-ctrl"][i].getChild("augmentation").setValue( me.reheat[i] );
        }
   }
}

EngineN1.transitsound = func {
   var value = 0.0;
   var found = constant.FALSE;

   var transit = me.itself["engines-sys"].getChild("transit").getValue();

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        value = me.itself["engine"][i].getChild("n1").getValue();

        if( value >= me.N1TRANSIT ) {
            if( transit == me.TRANSITOFF ) {
                # only once, above 70.
                interpolate( me.itself["engines-sys"].getChild("transit").getPath(), me.TRANSITEND, me.TRANSITSEC );
                break;
            }

            found = constant.TRUE;
        }
   }

   if( !found ) {
       me.itself["engines-sys"].getChild("transit").setValue(me.TRANSITOFF);
   }
}


# ======
# RATING
# ======

Rating = {};

Rating.new = func {
   var obj = { parents : [Rating,System],

               enginen1 : EngineN1.new(),

# contingency is not yet supported
               THROTTLETAKEOFF : 1.0,                         # N2 105.7 % (106.0 in Engines file)
               THROTTLECLIMB : 0.980,                         # N2 105.1 %
               THROTTLECRUISE : 0.967,                        # N2 104.5 % (guess)
               THROTTLEREVERSEGROUND : 0.933,                 # N2 98 %



               GEARLEFT : 1,
               GEARRIGHT : 3
         };

   obj.init();

   return obj;
};

Rating.init = func {
   me.inherit_system("/systems/engines","engine");
}

Rating.set_throttle = func( position ) {
   var maxthrottle = constantaero.THROTTLEIDLE;
   var position_new = constantaero.THROTTLEIDLE;
   var monitor = me.dependency["takeoff-monitor"].getValue();
   var speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();
   var n1gov = 2.0;
   var r1=me.itself["root-ctrl"][0].getChild("reverser").getValue();
   var r2=me.itself["root-ctrl"][1].getChild("reverser").getValue();
   var r3=me.itself["root-ctrl"][2].getChild("reverser").getValue();
   var r4=me.itself["root-ctrl"][3].getChild("reverser").getValue();
  
   # faster to process here
   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        position_new = position;

        if( monitor == 0 and speedmach<n1gov) {
          maxthrottle = 0.90;
        }
        else {
	  maxthrottle = me.level( i );        
        }

	if (((monitor==0 or (monitor==1 and !me.is_takeoff(i))) and speedmach>n1gov) and me.itself["root-ctrl"][i].getChild("throttle").getValue()>0.90) { 
            maxthrottle=( (100-60*(speedmach-n1gov))*0.0090 );
	}
        else {
	  maxthrottle = me.level( i );        
        }

        if( position_new > maxthrottle ) {
            position_new = maxthrottle;
        }

        if (r1==0 and r2==1 and r3==1 and r4==0 and (i==0 or i==3)) {
	    position_new = constantaero.THROTTLEIDLE;
        }

        # engine N1 limiter
        if( i == constantaero.ENGINE4 ) {
            position_new = me.enginen1.get_throttle( position_new );
        }

        # default, except autothrottle
        if( me.itself["engine-auto"][i].getValue() == "" ) {
            me.itself["root-ctrl"][i].getChild("throttle").setValue( position_new );
        }

        # last human operation (to detect goaround).
        me.itself["root-ctrl"][i].getChild("throttle-manual").setValue( position );
   }

}

Rating.schedule = func {
   me.enginen1.schedule();
   me.supervisor();
   me.autothrottle();
}

Rating.supervisor = func {
   var reheat = constant.FALSE;
   var monitor = me.dependency["takeoff-monitor"].getValue();
   speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();
   var j = 0;
   var rating = "";
   var dummy=0;
   n1gov = 2.0;
 
   # arm takeoff rating
   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( !me.is_takeoff(i) ) {
            # engines 2 and 3 by right gear
            if( i > constantaero.ENGINE1 and i < constantaero.ENGINE4 ) {
                j = me.GEARRIGHT;
            }

            # engines 1 and 4 armed by left gear
            else {
                j = me.GEARLEFT;
            }

            if( me.dependency["gear"][j].getChild("position-norm").getValue() == constantaero.GEARDOWN ) {
                me.itself["root-ctrl"][i].getChild("rating").setValue(constantaero.RATINGTAKEOFF);
            }
        }
   }

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
       reheat = me.itself["root-ctrl"][i].getChild("reheat").getValue();

       if( reheat and me.is_takeoff(i) ) {
           # automatic contigency, if takeoff monitor
           if( monitor ) {
               me.itself["root-ctrl"][i].getChild("contingency").setValue(constant.TRUE);
           }
       }
       elsif( !reheat and me.itself["root-ctrl"][i].getChild("contingency").getValue() ) {
           me.itself["root-ctrl"][i].getChild("contingency").setValue(constant.FALSE);
       }
   }

   # apply to engines
   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        rating = me.itself["root-ctrl"][i].getChild("rating").getValue();
        if( rating != constantaero.RATINGTAKEOFF ) {
            rating = me.itself["root-ctrl"][i].getChild("rating-flight").getValue();
        }
        me.itself["root"][i].getChild("rating").setValue(rating);

   	if (monitor==0 and me.itself["root-ctrl"][i].getChild("throttle").getValue()>0.90 and speedmach<n1gov) {
            me.itself["root-ctrl"][i].getChild("throttle").setValue( 0.90 );
	}

	if (((monitor==0 or (monitor==1 and !me.is_takeoff(i))) and speedmach>n1gov) and me.itself["root-ctrl"][i].getChild("throttle").getValue()>(100-60*(speedmach-n1gov))*0.0090) { 
            me.itself["root-ctrl"][i].getChild("throttle").setValue( (100-60*(speedmach-n1gov))*0.0090 );
	}

   }

}

Rating.autothrottle = func {
    var maxthrottle = constantaero.THROTTLEIDLE;
    var monitor = me.dependency["takeoff-monitor"].getValue();
    speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();
    n1gov = 2.0;

    for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {

        if( monitor == 0 and speedmach<n1gov) {
          maxthrottle = 0.90;
        }
        else {
	  maxthrottle = me.level( i );        
        }

	if (((monitor==0 or (monitor==1 and !me.is_takeoff(i))) and speedmach>n1gov) ) { 
            maxthrottle=( (100-60*(speedmach-n1gov))*0.0090 );
	}


         me.dependency["autothrottle"][i].getChild("u_max").setValue( maxthrottle );
         me.dependency["automach"][i].getChild("u_max").setValue( maxthrottle );
    }
}

Rating.level = func( index ) {
    var maxthrottle = constantaero.THROTTLEIDLE;

    # autoland first
    if( me.is_takeoff( index ) ) {
        if( me.itself["root-ctrl"][index].getChild("reverser").getValue() ) {
            maxthrottle = me.THROTTLEREVERSEGROUND;
        }
        else
        {
            maxthrottle = me.THROTTLETAKEOFF;
        }
    }

    # flight
    else {
        if( me.is_climb( index ) ) {
            maxthrottle = me.THROTTLECLIMB;
        }

        # cruise
        else {
            maxthrottle = me.THROTTLECRUISE;
        }
    }

    return maxthrottle;
}

Rating.is_takeoff = func( index ) {
    var result = constant.FALSE;

    if( me.itself["root-ctrl"][index].getChild("rating").getValue() == constantaero.RATINGTAKEOFF ) {
        result = constant.TRUE;
    }

    return result;
}

Rating.is_climb = func( index ) {
    var result = constant.FALSE;

    if( !me.is_takeoff( index ) and
        me.itself["root-ctrl"][index].getChild("rating-flight").getValue() == constantaero.RATINGCLIMB ) {
        result = constant.TRUE;
    }

    return result;
}


# =======================
# SECONDARY NOZZLE BUCKET
# =======================

Bucket = {};

Bucket.new = func {
   var obj = { parents : [Bucket,System],

               TRANSITSEC : 6.0,                                   # reverser transit in 6 s
               BUCKETSEC : 1.0,                                    # refresh rate

               AEROBRAKEDEG : 180.0,                               # guess of force (90 deg is no thrust)
               REVERSERDEG : 73.0,
               TAKEOFFDEG : 21.0,
               SUPERSONICDEG : 0.0,
               RATEDEG : 0.0,                                      # maximum rotation speed

               SUBSONICMACH : 0.55,
               SUPERSONICMACH : 1.1,

               COEF : 0.0
         };

   obj.init();

   return obj;
};

Bucket.set_rate = func( rates ) {
   var offsetdeg = me.REVERSERDEG - me.TAKEOFFDEG;

   me.BUCKETSEC = rates;

   me.RATEDEG = offsetdeg * ( me.BUCKETSEC / me.TRANSITSEC );
}

Bucket.init = func {
   me.inherit_system("/systems/engines","engine");

   var denom = me.SUPERSONICMACH - me.SUBSONICMACH;

   me.set_rate( me.BUCKETSEC );

   me.COEF = me.TAKEOFFDEG / denom;
}

Bucket.reverseexport = func {
   var reverse = constant.FALSE;
   var target = constant.FALSE;

   # determine current position of levers
   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( me.itself["root-ctrl"][i].getChild("reverser").getValue() ) {
            reverse = constant.TRUE;
            break;
        }
   }

   # 4 levers on ground
   if( me.dependency["weight"].getChild("wow").getValue() ) {
       target = constant.not( reverse );

       for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
            me.itself["root-ctrl"][i].getChild("reverser").setValue( target );
       }
   }

   # only levers 2 and 3 in flight
   else {
       target = constant.not( reverse );

       for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {

            if( i==1 or i==2 ) {
                me.itself["root-ctrl"][i].getChild("reverser").setValue( target );
		setprop("controls/engines/flight-reverse",1);
            }

       }
   }
}

Bucket.schedule = func {
    me.position();
}

Bucket.increase = func( angledeg, maxdeg ) {
    angledeg = angledeg + me.RATEDEG;
    if( angledeg > maxdeg ) {
        angledeg = maxdeg;
    }

    return angledeg;
}

Bucket.decrease = func( angledeg, mindeg ) {
    angledeg = angledeg - me.RATEDEG;
    if( angledeg < mindeg ) {
        angledeg = mindeg;
    }

    return angledeg;
}

Bucket.inertia = func( angledeg, targetdeg ) {
   var valuedeg = 0.0;
   var offsetdeg = targetdeg - angledeg;

   if( offsetdeg > 0 ) {
       valuedeg = me.increase( angledeg, targetdeg );
   }
   else {
       valuedeg = me.decrease( angledeg, targetdeg );
   }

   return valuedeg;
}

Bucket.apply = func( property, angledeg, targetdeg ) {
   if( angledeg != targetdeg ) {
       var valuedeg = me.inertia( angledeg, targetdeg );

       interpolate( property, valuedeg, me.BUCKETSEC );
   }
}

Bucket.applyrad = func( property, anglerad, targetdeg ) {
   var angledeg = anglerad * constant.RADTODEG;

   if( angledeg != targetdeg ) {
       var valuedeg = me.inertia( angledeg, targetdeg );

       interpolate( property, valuedeg * constant.DEGTORAD, me.BUCKETSEC );
   }
}

Bucket.reverse = func( index ) {
   var result = constant.FALSE;
   var flightrev = me.itself["engines-ctrl"].getChild("flight-reverse").getValue();

   # disarmed by throttle above 10 %.
   if( flightrev ) {
       if( me.itself["root-ctrl"][index].getChild("throttle").getValue() > 1.1 ) {
           flightrev = constant.FALSE;
           me.itself["engines-ctrl"].getChild("flight-reverse").setValue( flightrev );
       }
   }

   # CAUTION : use controls, because there is a delay by /engines/engine[0]/reversed !
   if( me.itself["root-ctrl"][index].getChild("reverser").getValue() ) {
       # on ground
       if( me.dependency["weight"].getChild("wow").getValue() ) {
           result = constant.TRUE;
       }

       # in flight, only if :
       # - armed.
       # - engines 2 and 3.
       # - idle throttle.
       elsif( flightrev ) {
           if( constantaero.inboardengine( index ) ) {
               result = constant.TRUE;
           }
       }
   }

   return result;
}

# bucket position
Bucket.position = func {
   var step = 0.0;
   var reverserdeg = 0.0;
   var valuedeg = 0.0;
   var result = 0.0;
   var speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();

   # supersonic : 0 deg
   var bucketdeg = me.SUPERSONICDEG;

   # takeoff : 21 deg
   if( speedmach < me.SUBSONICMACH ) {
       bucketdeg = me.TAKEOFFDEG;
   }
   # subsonic : 21 to 0 deg
   elsif( speedmach <= me.SUPERSONICMACH ) {
       step = speedmach - me.SUBSONICMACH;
       bucketdeg = me.TAKEOFFDEG - me.COEF * step;
   }

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
       if( me.reverse( i ) ) {
           # reversed : 73 deg
           valuedeg = me.REVERSERDEG;
           reverserdeg = me.AEROBRAKEDEG;
       }
       else {
           valuedeg = bucketdeg;
           reverserdeg = 0.0;
       }

       result = me.itself["root"][i].getChild("bucket-deg").getValue();
       valuedeg = me.apply( me.itself["root"][i].getChild("bucket-deg").getPath(), result, valuedeg );

       result = me.itself["root-ctrl"][i].getChild("reverser-angle-rad").getValue();
       me.applyrad( me.itself["root-ctrl"][i].getChild("reverser-angle-rad").getPath(), result, reverserdeg );
   }
}


# ===================
# SECONDARY AIR DOORS
# ===================

AirDoor = {};

AirDoor.new = func {
   var obj = { parents : [AirDoor,System],

               ENGINESMACH : 0.26,
               ENGINE4KT : 220.0
         };

   obj.init();

   return obj;
};

AirDoor.init = func {
   me.inherit_system("/systems/engines","engine");
}

# air door position
AirDoor.schedule = func {
   var value = constant.FALSE;
   var speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();
   var speedkt = me.dependency["asi"].getChild("indicated-speed-kt").getValue();
   var touchdown = me.dependency["weight"].getChild("wow").getValue();
   var gearpos = me.dependency["gear"][constantaero.GEARLEFT].getChild("position-norm").getValue();

   # engines 1 to 3 :
   for( var i=0; i <= constantaero.ENGINE3; i=i+1 ) {
       if( me.itself["root-ctrl"][i].getChild("secondary-air-door").getValue() ) {
           value = me.itself["root"][i].getChild("secondary-air-door").getValue();
           # opens above Mach 0.26
           if( !value ) {
               if( speedmach > me.ENGINESMACH ) {
                   value = constant.TRUE;
               }
           }
           # shuts below Mach 0.26, if touch down
           elsif( speedmach < me.ENGINESMACH and touchdown ) {
               value = constant.FALSE;
           }
           me.itself["root"][i].getChild("secondary-air-door").setValue(value);
       }
   }

   # engine 4
   if( me.itself["root-ctrl"][constantaero.ENGINE4].getChild("secondary-air-door").getValue() ) {
       value = me.itself["root"][constantaero.ENGINE4].getChild("secondary-air-door").getValue();
       # opens above 220 kt
       if( !value ) {
           if( speedkt > me.ENGINE4KT ) {
               value = constant.TRUE;
           }
       } 
       # shuts below Mach 0.26, gear down
       elsif( speedmach < me.ENGINESMACH and gearpos == constantaero.GEARDOWN ) {
           value = constant.FALSE;
       }
       me.itself["root"][constantaero.ENGINE4].getChild("secondary-air-door").setValue(value);
   }
}


# ===========
# INTAKE RAMP
# ===========

Intake = {};

Intake.new = func {
   var obj = { parents : [Intake,System],

           MAXRAMP : 50.0,
           MINRAMP : 0.0,
           MAXMACH : 2.02,
           MINMACH : 1.3,
           INLETMACH : 0.75,
           OFFSETMACH : 0.0,

           LANEA : 2,
           LANEAUTOA : 0,

           POSSUBSONIC : 1.0,
           POSSUPERSONIC : 0.0,

           hydmain : [ "green", "green", "blue", "blue" ],

           lane : [ constant.TRUE, constant.FALSE ]
         };

   obj.init();

   return obj;
};

Intake.init = func {
   me.inherit_system("/systems/engines","engine");

   me.OFFSETMACH = me.MAXMACH - me.MINMACH;
}

# main system failure
Intake.amber_intake = func( index ) {
    var result = constant.FALSE;

    # auto or green / blue selected
    if( !me.dependency["hydraulic"].getChild(me.hydmain[index]).getValue() and
        me.itself["root"][index].getChild("intake-main").getValue() ) {
        result = constant.TRUE;
    }

    # yellow selected
    elsif( !me.dependency["hydraulic"].getChild("yellow").getValue() and
           me.itself["root"][index].getChild("intake-standby").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}

Intake.laneexport = func {
   var selector = 0;

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        selector = me.itself["root-ctrl"][i].getChild("intake-selector").getValue();

        if( selector == me.LANEAUTOA or selector == me.LANEA ) {
            me.lane[0] = constant.TRUE;
            me.lane[1] = constant.FALSE;
        }
        else {
            me.lane[0] = constant.FALSE;
            me.lane[1] = constant.TRUE;
        }

        for( var j=0; j<constantaero.NBAUTOPILOTS; j=j+1 ) {
             me.itself["root"][i].getChild("intake-lane", j).setValue(me.lane[j]);
        }
   }
}

Intake.schedule = func {
   var speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();

   me.auxilliaryinlet( speedmach );
   me.ramphydraulic();
   me.rampposition( speedmach );
}

Intake.auxilliaryinlet = func( speedmach ) {
   var pos = constant.FALSE;

   if( speedmach < me.INLETMACH ) {
       pos = constant.TRUE;
   }

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        me.itself["root"][i].getChild("intake-aux-inlet").setValue(pos);
   }
}

Intake.ramphydraulic = func {
   var main = constant.FALSE;
   var standby  = constant.FALSE;

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( me.itself["root-ctrl"][i].getChild("intake-auto").getValue() ) {
            main = constant.TRUE;
            standby = !me.dependency["hydraulic"].getChild(me.hydmain[i]).getValue();
        }
        else {
            main = me.itself["root-ctrl"][i].getChild("intake-main").getValue();
            standby = !main;
        }

        me.itself["root"][i].getChild("intake-main").setValue(main);
        me.itself["root"][i].getChild("intake-standby").setValue(standby);
   }
}

Intake.rampposition = func( speedmach ) {
   var stepmach = 0.0;
   var coef = 0.0;
   var pospercent = 0.0;
   var ratio = 0.0;
   var ratiopercent = 0.0;
   var ramppercent = me.MAXRAMP;
   var rampsubsonic = me.POSSUPERSONIC;
   var hydfailure = constant.FALSE;

   if( speedmach <= me.MINMACH ) {
       ramppercent = me.MINRAMP;
       rampsubsonic = me.POSSUBSONIC;
   }
   elsif( speedmach > me.MINMACH and speedmach < me.MAXMACH ) {
       stepmach = speedmach - me.MINMACH;
       coef = stepmach / me.OFFSETMACH;
       ramppercent = me.MAXRAMP * coef;
       rampsubsonic = me.POSSUPERSONIC;
   }

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
        if( me.amber_intake(i) ) {
            hydfailure = constant.TRUE;
            break;
        }
   }

   # TO DO : effect of throttle on intake pressure ratio error

   # engineer moves ramp manually
   if( hydfailure ) {
       for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
            pospercent = me.itself["root"][i].getChild("ramp-percent").getValue();

            # to the left (negativ), if throttle lever must be retarded
            ratio = ( ramppercent - pospercent ) / me.MAXRAMP;

            ratiopercent = ratio * 100;
            me.itself["root"][i].getChild("intake-ratio-error").setValue(ratiopercent);
       }

       # ramp is too much closed (supercritical)
       if( ratio < 0.0 ) {
           if( rampsubsonic == me.POSSUBSONIC ) {
               rampsubsonic = me.superramp( ratio, me.POSSUPERSONIC, rampsubsonic );
           }
           else {
               rampsubsonic = me.superramp( ratio, me.POSSUBSONIC, rampsubsonic );
           }
       }

       # ramp is too much opened (subcritical)
       elsif( ratio > 0.0 ) {
           if( rampsubsonic == me.POSSUPERSONIC ) {
               rampsubsonic = me.subramp( ratio, me.POSSUBSONIC, rampsubsonic );
           }
           else {
               rampsubsonic = me.subramp( ratio, me.POSSUPERSONIC, rampsubsonic );
           }
       }
   }

   # hydraulics moves intake ramp
   else {
       for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
            me.itself["root"][i].getChild("ramp-percent").setValue(ramppercent);
            me.itself["root"][i].getChild("intake-ratio-error").setValue(0.0);
       }
   }

   # JSBSim can disable only 4 intakes at once
   me.itself["engines-sys"].getChild("intake-subsonic").setValue(rampsubsonic);
}

Intake.superramp = func( ratio, target, present ) {
   var result = present - ( target - present ) * ratio;

   return result;
}

Intake.subramp = func( ratio, target, present ) {
   var result = present + ( target - present ) * ratio;

   return result;
}

setprop("/controls/engines/engine[0]/rating-n",1);
setprop("/controls/engines/engine[1]/rating-n",1);
setprop("/controls/engines/engine[2]/rating-n",1);
setprop("/controls/engines/engine[3]/rating-n",1);

setlistener("/controls/engines/engine[0]/rating", func() {
  ratingn=getprop("/controls/engines/engine[0]/rating");
  if (ratingn=="takeoff"){
    setprop("/controls/engines/engine[0]/rating-n",1);
  }
  else{
    setprop("/controls/engines/engine[0]/rating-n",0);
  };
});

setlistener("/controls/engines/engine[1]/rating", func() {
  ratingn=getprop("/controls/engines/engine[1]/rating");
  if (ratingn=="takeoff"){
    setprop("/controls/engines/engine[1]/rating-n",1);
  }
  else{
    setprop("/controls/engines/engine[1]/rating-n",0);
  };
});

setlistener("/controls/engines/engine[2]/rating", func() {
  ratingn=getprop("/controls/engines/engine[2]/rating");
  if (ratingn=="takeoff"){
    setprop("/controls/engines/engine[2]/rating-n",1);
  }
  else{
    setprop("/controls/engines/engine[2]/rating-n",0);
  };
});

setlistener("/controls/engines/engine[3]/rating", func() {
  ratingn=getprop("/controls/engines/engine[3]/rating");
  if (ratingn=="takeoff"){
    setprop("/controls/engines/engine[3]/rating-n",1);
  }
  else{
    setprop("/controls/engines/engine[3]/rating-n",0);
  };
});
