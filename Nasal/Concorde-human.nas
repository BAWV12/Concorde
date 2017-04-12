# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains 3D feedbacks.
# Code is heavily optimized, to not use ressource when disabled (heavy mesh).



# ==========
# HUMAN CREW
# ==========

# for inheritance, the component must be the last of parents.
Crewhuman = {};

# not called by child classes !!!
Crewhuman.new = func {
   var obj = { parents : [Crewhuman,System],

           crew : nil,
           crewcontrol : nil,

           HEADSEC : 45.0,
           EYEMAXSEC : 7.0,                              # human eye blinks every 3 - 7 s
           EYEMINSEC : 3.0,
           WAITSEC : 3.0,
           CHARACTERSEC : 0.15,
           BLINKSEC : 0.15,
           STOPSEC : -999.0,

           heads : 0.0,

           TURNDEG : 60.0,
           RAISEDEG : 15.0,
           FORWARDSDEG : 0.0,

           MUSCLEDEGPSEC : 8.0,

           crewpath : "",
           crewvoice : "",

           mooth : nil,

           sleephead : constant.TRUE,
           sleepeye : constant.TRUE,

           movehead : constant.FALSE,
           openeye : constant.TRUE
         };

   obj.init();

   return obj;
}

Crewhuman.init = func {
}

Crewhuman.inherit_crewhuman = func( path, member, voice ) {
   # child will also have to inherit from System
   me.inherit_system("/systems/human");

   var obj = Crewhuman.new();

   me.HEADSEC  = obj.HEADSEC;
   me.EYEMAXSEC = obj.EYEMAXSEC;
   me.EYEMINSEC = obj.EYEMINSEC;
   me.WAITSEC = obj.WAITSEC;
   me.CHARACTERSEC = obj.CHARACTERSEC;
   me.BLINKSEC = obj.BLINKSEC;
   me.STOPSEC = obj.STOPSEC;
   me.heads = obj.heads;
   me.TURNDEG = obj.TURNDEG;
   me.RAISEDEG = obj.RAISEDEG;
   me.FORWARDSDEG = obj.FORWARDSDEG;
   me.MUSCLEDEGPSEC = obj.MUSCLEDEGPSEC;
   me.crewpath = path;
   me.crewvoice = voice;
   me.mooth = obj.mooth;
   me.sleephead = obj.sleephead;
   me.sleepeye = obj.sleepeye;
   me.movehead = obj.movehead;
   me.openeye = obj.openeye;

   me.crew = props.globals.getNode( me.crewpath );
   me.crewcontrol = props.globals.getNode("/controls/" ~ member);

   me.listenmooth();

   # must wait for initialization
   settimer(func { me.eyescron(); }, 0);
   settimer(func { me.headcron(); }, 0);
}

Crewhuman.wakeup = func {
   if( me.sleepeye ) {
       me.eyescron();
   }
   if( me.sleephead ) {
       me.headcron();
   }

   me.listenmooth();
}

Crewhuman.wakeupexport = func {
   me.wakeup();
}

Crewhuman.schedule = func {
   var headset = constant.TRUE;

   # headset less used during these phases
   if( me.dependency["voice"].getChild("callout").getValue() == "gate" or
       me.dependency["voice"].getChild("checklist").getValue() == "cruiseclimb" ) {
       headset = constant.FALSE;
   }

   me.crew.getChild("headset").setValue( headset );
}

Crewhuman.talkrates = func {
   # opens the mooth according to phrase length
   var phrase = me.dependency["sound"].getChild(me.crewvoice).getValue();
   var steps = size( phrase ) * me.CHARACTERSEC;

   return steps;
}

Crewhuman.endtalk = func {
   me.crew.getChild("teeth").setValue(constant.FALSE);
}

Crewhuman.eyesrates = func {
   var steps = 0.0;
   var factor = 0.0;

   if( me.crewcontrol.getChild("activ").getValue() and
       me.itself["root"].getChild("serviceable").getValue() ) {
       me.sleepeye = constant.FALSE;

       if( me.openeye ) {
           steps = me.BLINKSEC * rand();
           me.openeye = constant.FALSE;
       }

       else {
           factor = rand();
           steps = me.EYEMAXSEC * factor + me.EYEMINSEC * ( 1.0 - factor );
           me.openeye = constant.TRUE;
       }

       me.crew.getChild("eyes").setValue(me.openeye);
   }

   else {
       me.sleepeye = constant.TRUE;
       me.removemooth();
       steps = me.STOPSEC;
   }
 
   return steps;
}

Crewhuman.headrates = func {
   var headingdeg = 0.0;
   var pitchdeg = 0.0;
   var steps = 0.0;

   if( me.crewcontrol.getChild("activ").getValue() and
       me.itself["root"].getChild("serviceable").getValue() ) {
       me.sleephead = constant.FALSE;

       if( !me.movehead ) {
           me.movehead = constant.TRUE;
           headingdeg = me.TURNDEG * ( rand() - 0.5 );
           pitchdeg = me.RAISEDEG * ( rand() - 0.5 );
           me.heads = math.abs( headingdeg / me.MUSCLEDEGPSEC );

           # waits for end of rotation
           steps = me.heads + me.WAITSEC * rand();
       }

       # restores head
       else {
           me.movehead = constant.FALSE;
           headingdeg = me.FORWARDSDEG;
           pitchdeg = me.FORWARDSDEG;
           steps = me.HEADSEC * ( 1 + rand() );
       }

       interpolate( me.crewpath ~ "/heading-deg", headingdeg, me.heads );
       interpolate( me.crewpath ~ "/pitch-deg", pitchdeg, me.heads );
   }

   else {
       me.sleephead = constant.TRUE;
       me.removemooth();
       steps = me.STOPSEC;
   }
 
   return steps;
}

Crewhuman.moothcron = func {
   var steps = me.talkrates();

   settimer(func { me.endtalk(); }, steps);
}

Crewhuman.eyescron = func {
   var steps = me.eyesrates();

   if( steps > 0 ) {
       settimer(func { me.eyescron(); }, steps);
   }
}

Crewhuman.headcron = func {
   var steps = me.headrates();

   if( steps > 0 ) {
       settimer(func { me.headcron(); }, steps);
   }
}

Crewhuman.listenmooth = func {
   if( me.mooth == nil ) {
       me.mooth = setlistener(me.crewpath ~ "/teeth", func { me.moothcron(); });
   }
}

Crewhuman.removemooth = func {
   if( me.mooth != nil ) {
       removelistener(me.mooth);
       me.mooth = nil;
   }
}


# =============
# HUMAN COPILOT
# =============
Copilothuman = {};

Copilothuman.new = func {
   var obj = { parents : [Copilothuman,Crewhuman,System]
         };

   obj.init();

   return obj;
}

Copilothuman.init = func {
   me.inherit_crewhuman( "/systems/human/copilot", "copilot", "copilot" );
}


# ==============
# HUMAN ENGINEER
# ==============
Engineerhuman = {};

Engineerhuman.new = func {
   var obj = { parents : [Engineerhuman,Crewhuman,System],

               seat : Engineerseat.new()
         };

   obj.init();

   return obj;
}

Engineerhuman.init = func {
   me.inherit_crewhuman( "/systems/human/engineer", "engineer", "pilot" );
}

Engineerhuman.set_relation = func( seat ) {
   me.seat.set_relation( seat );
}

Engineerhuman.slowschedule = func {
   # 15 s is enough time, to interpolate each step
   if( me.crewcontrol.getChild("activ").getValue() ) {
       if( me.itself["root"].getChild("serviceable").getValue() ) {
           me.seat.schedule();
       }
   }

   # reset seat position, when no crew
   else {
       me.seat.reset();
   }
}


# =============
# ENGINEER SEAT
# =============

Engineerseat = {};

Engineerseat.new = func {
   var obj = { parents : [Engineerseat,Callout,System],

               seatsystem : nil,

               SEATDEGPSEC : 25.0,
               BOGGIESEC : 5.0,

               TAKEOFFDEG : 360,                                        # towards pedestal
               FLIGHTDEG : 270,

               headdeg : 0,

               STATICDEG : 0,

               TAKEOFFM : 0.40,                                         # near pedestal
               FLIGHTM : 0.0,

               headm : 0.0,

               STATICM : 0.0
         };

   obj.init();

   return obj;
}

Engineerseat.init = func {
   me.inherit_system("/systems/human");
   me.inherit_callout();

   me.headdeg = me.dependency["engineer"].getChild("heading-deg").getValue();
}

Engineerseat.set_relation = func( seat ) {
   me.seatsystem = seat;
}

Engineerseat.is_rotating = func {
   var result = constant.FALSE;

   me.callout = me.dependency["voice"].getChild("callout").getValue();
   if( me.is_holding() or me.is_takeoff() or me.is_landing() ) {
       result = constant.TRUE;
   }

   return result;
}

Engineerseat.schedule = func {
   var targetdeg = 0.0;
   var targetm = 0.0;

   # takeoff position
   if( me.is_rotating() ) {
       if( me.itself["engineer"].getChild("stowe-norm").getValue() == me.FLIGHTM ) {
           targetdeg = me.TAKEOFFDEG; 
           targetm = me.TAKEOFFM; 

           # rotation, then translation, in 2 distinct steps
           if( me.headdeg != targetdeg ) {
               me.rotate( targetdeg, constant.FALSE );
           }

           elsif( me.headm != targetm ) {
               me.translate( targetm );
           }
       }
   }

   # flight position
   else {
       targetdeg = me.FLIGHTDEG; 
       targetm = me.FLIGHTM; 

       # reversed order
       if( me.headm != targetm ) {
           me.translate( targetm );
       }

       elsif( me.headdeg != targetdeg ) {
           me.rotate( targetdeg, constant.TRUE );
       }
   }
}

Engineerseat.reset = func {
   me.translateclear();
   me.rotateclear();
}

Engineerseat.rotate = func( targetdeg, clear ) {
    var movementdeg = 0.0;
    var movementsec = 0.0;

    # freezes seat angle, if still in engineer view
    me.seatsystem.engineerhead();

    me.headdeg = targetdeg;

    if( !clear ) {
        var viewdeg = me.dependency["engineer"].getChild("heading-deg").getValue();

        # correction by engineer view rotation
        movementdeg = targetdeg - viewdeg;
        movementdeg = constant.crossnorth( movementdeg );
        movementsec = math.abs( movementdeg / me.SEATDEGPSEC );
    }

    # clears engineer rotation
    else {
        var seatdeg = me.itself["engineer"].getChild("seat-deg").getValue();

        movementdeg = me.STATICDEG;
        movementsec = math.abs( seatdeg / me.SEATDEGPSEC );
    }


    interpolate(me.itself["engineer"].getChild("seat-deg").getPath(), movementdeg, movementsec );
}

Engineerseat.translate = func( targetm ) {
    me.headm = targetm;

    interpolate(me.itself["engineer"].getChild("seat-x-m").getPath(), me.headm, me.BOGGIESEC );
}

Engineerseat.rotateclear = func {
    me.headdeg = me.FLIGHTDEG;
    me.itself["engineer"].getChild("seat-deg").setValue(me.STATICDEG);
}

Engineerseat.translateclear = func {
    me.headm = me.FLIGHTM;
    me.itself["engineer"].getChild("seat-x-m").setValue(me.STATICM);
}


# =========
# SEAT RAIL
# =========

SeatRail = {};

SeatRail.new = func {
   var obj = { parents : [SeatRail,System],

               RAILSEC : 5.0,

               ENGINEERDEG : 270,
  
               FLIGHT : 0.0,
               PARK : 1.0
         };

   obj.init();

   return obj;
}

SeatRail.init = func {
   me.inherit_system("/systems/human");
}

SeatRail.toggle = func( seat ) {
   var canstowe = constant.TRUE;

   if( seat == "engineer" ) {
       if( me.itself["engineer"].getChild("stowe-norm").getValue() == me.FLIGHT ) {
           # except if seat has moved
           if( me.itself["engineer"].getChild("seat-deg").getValue() > 0 or
               me.itself["engineer"].getChild("seat-x-m").getValue() > 0 or
               me.dependency["engineer"].getChild("heading-deg").getValue() != me.ENGINEERDEG ) {
               canstowe = constant.FALSE;
           }
       }
   }

   if( canstowe ) {
       me.roll(me.itself[seat].getChild("stowe-norm").getPath());
   }
}

SeatRail.is_stowed = func( seat ) {
   var result = constant.FALSE;

   if( me.itself["root"].getNode(seat).getChild("stowe-norm").getValue() == me.PARK ) {
       result = constant.TRUE;
   }

   return result;
}

# roll on rail
SeatRail.roll = func( path ) {
   var pos = getprop(path);

   if( pos == me.FLIGHT ) {
       interpolate( path, me.PARK, me.RAILSEC );
   }
   elsif( pos == me.PARK ) {
       interpolate( path, me.FLIGHT, me.RAILSEC );
   }
}
