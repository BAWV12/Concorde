# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# =============
# CREW CALLOUTS 
# =============

Voice = {};

Voice.new = func {
   var obj = { parents : [Voice,Checklist,Emergency,Callout,System],

               autopilotsystem : nil,

               flightlevel : Altitudeperception.new(),
               acceleration : Speedperception.new(),
               crewvoice : Crewvoice.new(),
               lastcheck : Checklist.new(),

               MODIFYSEC : 15.0,                                 # to modify something
               ABSENTSEC : 15.0,                                 # less attention
               HOLDINGSEC : 5.0,

               rates : 0.0,                                      # variable time step

               ready : constant.FALSE,

               CLIMBFPM : 100,
               DECAYFPM : -50,                                   # not zero, to avoid false alarm
               DESCENTFPM : -100,
               FINALFPM : -1000,

               AGL2500FT : 2500,
               AGL1000FT : 1000,
               AGL800FT : 800,
               AGL500FT : 500,
               AGL400FT : 400,
               AGL300FT : 300,
               AGL200FT : 200,
               AGL100FT : 100,
               AGL50FT : 50,
               AGL40FT : 40,
               AGL30FT : 30,
               AGL20FT : 20,
               AGL15FT : 15,

               altitudeft : 0.0,
               lastaltitudeft : 0.0,
               altitudeselect : constant.FALSE,
               selectft : 0.0,
               delayselectftsec : 0,
               vertical : "",

               aglft : 0.0,
               category : constant.FALSE,
               alert : constant.FALSE,
               decision : constant.FALSE,
               decisiontogo : constant.FALSE,

               mach : 0.0,

               V240KT : 240.0,
               V100KT : 100.0,
               AIRSPEEDKT : 60.0,

               v1 : constant.FALSE,
               v2 : constant.FALSE,

               speedkt : 0.0,
               lastspeedkt : 0.0,
               groundkt : 0.0,

               FLAREDEG : 12.5,

               fueltransfert : constant.FALSE,

               gear : 0.0,
               lastgear : 0.0,
               nose : 0.0,
               lastnose : 0.0,

               airport : "",
               runway : "",

               # pilot in command
               captaintakeoff : {},
               captainafterstart : {},
               captaintaxi : {},
               captainbeforetakeoff : {},
               captainaftertakeoff : {},
               captainallways : {},

               # pilot not in command
               pilottakeoff : {},
               pilotclimb : {},
               pilotlanding : {},
               pilotgoaround : {},
               pilotbeforestart : {},
               pilotpushback : {},
               pilotafterstart : {},
               allwaystakeoff : {},
               allwayslanding : {},
               allwaysflight : {},
               allways : {},

               # engineer
               engineertakeoff : {},
               engineerflight : {},
               engineerclimb : {},
               engineertranssonic : {},
               engineerdescent : {},
               engineerapproach : {},
               engineerlanding : {},
               engineerbeforelanding : {},
               engineerafterlanding : {},
               engineerparking : {},
               engineerstopover : {},
               engineercockpit : {},
               engineerbeforestart : {},
               engineerpushback : {},
               engineertaxi : {},
               engineerbeforetakeoff : {},
               engineeraftertakeoff : {},

               aborted : constant.FALSE,
               real : constant.FALSE,                            # real checklist
               automata : "",
               automata2 : ""
         };

   obj.init();

   return obj;
}

Voice.init = func {
   var path = "/systems/voice";

   me.inherit_system( path );
   me.inherit_checklist( path );
   me.inherit_emergency( path );
   me.inherit_callout();

   me.selectft = me.dependency["autoflight"].getChild("altitude-select").getValue();

   me.inittext();

   me.presetcrew();

   me.callout = "holding";
   settimer( func { me.schedule(); }, constant.HUMANSEC );
}

Voice.inittable = func( path, table ) {
   var key = "";
   var text = "";
   var node = props.globals.getNode(path).getChildren("message");

   for( var i=0; i < size(node); i=i+1 ) {
        key = node[i].getChild("action").getValue();
        text = node[i].getChild("text").getValue();
        table[key] = text;
   }
}

Voice.inittext = func {
   me.inittable(me.itself["checklist"].getNode("beforetakeoff/engineer[0]").getPath(), me.engineerbeforetakeoff );
   me.inittable(me.itself["checklist"].getNode("beforetakeoff/captain[0]").getPath(), me.captainbeforetakeoff );

   me.inittable(me.itself["callout"].getNode("takeoff/captain").getPath(), me.captaintakeoff );

   me.inittable(me.itself["callout"].getNode("takeoff/pilot[0]").getPath(), me.pilottakeoff );
   me.inittable(me.itself["callout"].getNode("takeoff/pilot[1]").getPath(), me.pilotclimb );
   me.inittable(me.itself["callout"].getNode("takeoff/pilot[2]").getPath(), me.allwaystakeoff );
   me.inittable(me.itself["callout"].getNode("takeoff/engineer[0]").getPath(), me.engineertakeoff );

   me.inittable(me.itself["checklist"].getNode("aftertakeoff/engineer[0]").getPath(), me.engineeraftertakeoff );
   me.inittable(me.itself["checklist"].getNode("aftertakeoff/captain[0]").getPath(), me.captainaftertakeoff );

   me.inittable(me.itself["callout"].getNode("flight/pilot[0]").getPath(), me.allwaysflight );
   me.inittable(me.itself["callout"].getNode("flight/engineer[0]").getPath(), me.engineerflight );

   me.inittable(me.itself["checklist"].getNode("climb/engineer[0]").getPath(), me.engineerclimb );

   me.inittable(me.itself["checklist"].getNode("transsonic/engineer[0]").getPath(), me.engineertranssonic );

   me.inittable(me.itself["checklist"].getNode("descent/engineer[0]").getPath(), me.engineerdescent );

   me.inittable(me.itself["checklist"].getNode("approach/engineer[0]").getPath(), me.engineerapproach );

   me.inittable(me.itself["checklist"].getNode("beforelanding/engineer").getPath(), me.engineerbeforelanding );

   me.inittable(me.itself["callout"].getNode("landing/pilot[0]").getPath(), me.pilotlanding );
   me.inittable(me.itself["callout"].getNode("landing/pilot[1]").getPath(), me.allwayslanding );
   me.inittable(me.itself["callout"].getNode("landing/engineer[0]").getPath(), me.engineerlanding );

   me.inittable(me.itself["callout"].getNode("goaround/pilot[0]").getPath(), me.pilotgoaround );

   me.inittable(me.itself["checklist"].getNode("afterlanding/engineer[0]").getPath(), me.engineerafterlanding );

   me.inittable(me.itself["checklist"].getNode("parking/engineer[0]").getPath(), me.engineerparking );

   me.inittable(me.itself["checklist"].getNode("stopover/engineer[0]").getPath(), me.engineerstopover );

   me.inittable(me.itself["checklist"].getNode("cockpit/engineer[0]").getPath(), me.engineercockpit );

   me.inittable(me.itself["checklist"].getNode("beforestart/pilot[0]").getPath(), me.pilotbeforestart );
   me.inittable(me.itself["checklist"].getNode("beforestart/engineer[0]").getPath(), me.engineerbeforestart );

   me.inittable(me.itself["checklist"].getNode("pushback/pilot[0]").getPath(), me.pilotpushback );
   me.inittable(me.itself["checklist"].getNode("pushback/engineer[0]").getPath(), me.engineerpushback );

   me.inittable(me.itself["checklist"].getNode("afterstart/pilot[0]").getPath(), me.pilotafterstart );
   me.inittable(me.itself["checklist"].getNode("afterstart/captain[0]").getPath(), me.captainafterstart );

   me.inittable(me.itself["checklist"].getNode("taxi/engineer[0]").getPath(), me.engineertaxi );
   me.inittable(me.itself["checklist"].getNode("taxi/captain[0]").getPath(), me.captaintaxi );

   me.inittable(me.itself["checklist"].getNode("all/captain[0]").getPath(), me.captainallways );

   me.inittable(me.itself["callout"].getNode("all/pilot[0]").getPath(), me.allways );
}

Voice.presetcrew = func {
   var value = me.dependency["crew-ctrl"].getChild("presets").getValue();
   var dialog = me.dependency["crew-presets"][value].getValue();

   # copy to dialog
   me.dependency["crew"].getChild("dialog").setValue(dialog);
}

Voice.set_relation = func( autopilot ) {
    me.autopilotsystem = autopilot;
}

Voice.set_rates = func( steps ) {
    me.rates = steps;

    me.flightlevel.set_rates( me.rates );
    me.acceleration.set_rates( me.rates );
}

Voice.crewtextexport = func {
    me.crewvoice.textexport();
}

Voice.menuexport = func {
   var label = me.dependency["crew"].getChild("dialog").getValue();

   for( var i=0; i < size(me.dependency["crew-presets"]); i=i+1 ) {
        if( me.dependency["crew-presets"][i].getValue() == label ) {

            # for aicraft-data
            me.dependency["crew-ctrl"].getChild("presets").setValue(i);

            break;
        }
   }
}


# -------------------------------
# ground checklists not in flight
# -------------------------------
Voice.afterlandingexport = func {
   if( me.has_crew() ) {
       var result = constant.FALSE;

       # abort takeoff
       if( me.is_holding() ) {
           result = constant.TRUE;
       }

       # aborted takeoff before V1
       elsif( me.is_takeoff() and !me.v1 ) {
           result = constant.TRUE;
       }

       # after landing
       elsif( me.is_taxiway() ) {
           result = constant.TRUE;
       }

       # abort taxi
       elsif( me.is_started() or me.is_runway() ) {
           result = constant.TRUE;
       }

       if( result ) {
           me.afterlandinginit();
       }
   }
}

Voice.parkingexport = func {
   if( me.has_crew() ) {
       if( me.is_terminal() ) {
           me.parkinginit();
       }
   }
}

Voice.stopoverexport = func {
   if( me.has_crew() ) {
       # at FG start, default is holding without checklist.
       if( me.is_gate() or ( me.is_holding() or me.is_takeoff() ) ) {
           me.set_startup();
           me.stopoverinit();
       }
   }
}

Voice.externalexport = func {
   if( me.has_crew() ) {
       if( me.is_gate() ) {
           me.externalinit();
       }
   }
}

Voice.preliminaryexport = func {
   if( me.has_crew() ) {
       if( me.is_gate() ) {
           me.preliminaryinit();
       }
   }
}

Voice.cockpitexport = func {
   if( me.has_crew() ) {
       if( me.is_gate() ) {
           me.cockpitinit();
       }
   }
}

Voice.beforestartexport = func {
   if( me.has_crew() ) {
       if( me.is_gate() ) {
           me.beforestartinit();
       }
   }
}

Voice.enginestartexport = func {
   if( me.has_crew() ) {
       if( me.is_gate() ) {
           me.enginestartinit();
       }
   }
}

Voice.pushbackexport = func {
   if( me.has_crew() ) {
       if( me.is_gate() ) {
           me.pushbackinit();
       }
   }
}

Voice.afterstartexport = func {
   if( me.has_crew() ) {
       if( me.is_started() ) {
           me.afterstartinit();
       }
   }
}

Voice.taxiexport = func {
   if( me.has_crew() ) {
       # at FG start, default is holding without checklist.
       if( me.is_started() or ( me.is_holding() or me.is_takeoff() ) ) {
           me.set_startup();
           me.taxiinit();
       }
   }
}

Voice.beforetakeoffexport = func {
   if( me.has_crew() ) {
       if( me.is_holding() or me.is_takeoff() ) {
           me.set_startup();
           me.beforetakeoffinit();
       }
   }
}

Voice.toggleexport = func {
   if( me.has_AI() ) {
       var presets = me.dependency["crew-ctrl"].getChild("presets").getValue();

       if( presets == 0 ) {
           me.beforetakeoffexport();
       }

       elsif( presets == 1 ) {
           me.taxiexport();
       }

       elsif( presets == 2 ) {
           me.stopoverexport();
       }
   }
}


# ------------------------------------------
# flight checklists can be trained on ground
# ------------------------------------------
Voice.aftertakeoffexport = func {
   if( me.has_crew() ) {
       me.aftertakeoffinit();
   }
}

Voice.climbexport = func {
   if( me.has_crew() ) {
       me.climbinit();
   }
}

Voice.transsonicexport = func {
   if( me.has_crew() ) {
       me.transsonicinit();
   }
}

Voice.descentexport = func {
   if( me.has_crew() ) {
       me.descentinit();
   }
}

Voice.approachexport = func {
   if( me.has_crew() ) {
       me.approachinit();
   }
}

Voice.beforelandingexport = func {
   if( me.has_crew() ) {
       me.beforelandinginit();
   }
}


# --------------------
# emergency procedures
# --------------------
Voice.fourengineflameoutexport = func {
   if( me.has_crew() ) {
       me.nochecklistinit();
       me.fourengineflameoutinit();
   }
}

Voice.fourengineflameoutmach1export = func {
   if( me.has_crew() ) {
       me.nochecklistinit();
       me.fourengineflameoutmach1init();
   }
}


# ------------------------
# to unlock checklists bug
# ------------------------
Voice.abortexport = func {
   me.nochecklistinit();

   me.captainfeedback("abort");

   me.aborted = constant.TRUE;
}


# ----------------------
# to unlock callouts bug
# ----------------------
Voice.taxiwayexport = func {
   me.taxiwayinit();
}

Voice.terminalexport = func {
   me.terminalinit();
}

Voice.gateexport = func {
   me.gateinit();
}

Voice.takeoffexport = func {
   me.takeoffinit();
}

Voice.flightexport = func {
   me.flightinit();
}

Voice.landingexport = func {
   me.landinginit();
}


# ------------
# voice checks
# ------------
Voice.captainfeedback = func( action ) {
   me.crewvoice.nowcaptain( action, me.captainallways );
}

Voice.captaincheck = func( action ) {
   if( me.is_aftertakeoff() ) {
       me.crewvoice.nowcaptain( action, me.captainaftertakeoff );
   }

   elsif( me.is_afterstart() ) {
       me.crewvoice.nowcaptain( action, me.captainafterstart );
   }

   elsif( me.is_taxi() ) {
       me.crewvoice.nowcaptain( action, me.captaintaxi );
   }

   elsif( me.is_beforetakeoff() ) {
       me.crewvoice.nowcaptain( action, me.captainbeforetakeoff );
   }

   else {
       print("captain check not found : ", action);
   }
}



Voice.pilotcheck = func( action, argument = "" ) {
   me.itself["root"].getChild("argument").setValue( argument );

   if( me.is_beforestart() ) {
       me.crewvoice.nowpilot( action, me.pilotbeforestart );
   }

   elsif( me.is_pushback() ) {
       me.crewvoice.nowpilot( action, me.pilotpushback );
   }

   elsif( me.is_afterstart() ) {
       me.crewvoice.nowpilot( action, me.pilotafterstart );
   }

   else {
       print("check not found : ", action);
   }
}

Voice.engineercheck = func( action ) {
   if( me.is_aftertakeoff() ) {
       me.crewvoice.nowengineer( action, me.engineeraftertakeoff );
   }

   elsif( me.is_climb() ) {
       me.crewvoice.nowengineer( action, me.engineerclimb );
   }

   elsif( me.is_transsonic() ) {
       me.crewvoice.nowengineer( action, me.engineertranssonic );
   }

   elsif( me.is_descent() ) {
       me.crewvoice.nowengineer( action, me.engineerdescent );
   }

   elsif( me.is_approach() ) {
       me.crewvoice.nowengineer( action, me.engineerapproach );
   }

   elsif( me.is_beforelanding() ) {
       me.crewvoice.nowengineer( action, me.engineerbeforelanding );
   }

   elsif( me.is_afterlanding() ) {
       me.crewvoice.nowengineer( action, me.engineerafterlanding );
   }

   elsif( me.is_parking() ) {
       me.crewvoice.nowengineer( action, me.engineerparking );
   }

   elsif( me.is_stopover() ) {
       me.crewvoice.nowengineer( action, me.engineerstopover );
   }

   elsif( me.is_cockpit() ) {
       me.crewvoice.nowengineer( action, me.engineercockpit );
   }

   elsif( me.is_beforestart() ) {
       me.crewvoice.nowengineer( action, me.engineerbeforestart );
   }

   elsif( me.is_pushback() ) {
       me.crewvoice.nowengineer( action, me.engineerpushback );
   }

   elsif( me.is_taxi() ) {
       me.crewvoice.nowengineer( action, me.engineertaxi );
   }

   elsif( me.is_beforetakeoff() ) {
       me.crewvoice.nowengineer( action, me.engineerbeforetakeoff );
   }

   else {
       print("engineer check not found : ", action);
   }
}


# -----------
# voice calls
# -----------
Voice.pilotcall = func( action ) {
   var result = "";

   if( me.is_holding() or me.is_takeoff() or me.is_aftertakeoff() ) {
       result = me.crewvoice.steppilot( action, me.pilottakeoff );
   }

   elsif( me.is_beforelanding() or me.is_landing() ) {
       result = me.crewvoice.steppilot( action, me.pilotlanding );
   }

   elsif( me.is_goaround() ) {
       result = me.crewvoice.steppilot( action, me.pilotgoaround );
   }

   else {
       print("call not found : ", action);
   }

   return result;
}

Voice.captaincall = func( action ) {
   var result = "";

   if( me.is_holding() ) {
       result = me.crewvoice.stepcaptain( action, me.captaintakeoff );
   }

   else {
       print("captain call not found : ", action);
   }

   return result;
}

Voice.engineercall = func( action ) {
   var result = "";

   if( me.is_holding() or me.is_takeoff() or me.is_aftertakeoff() ) {
       result = me.crewvoice.stepengineer( action, me.engineertakeoff );
   }

   elsif( me.is_beforelanding() or me.is_landing() ) {
       result = me.crewvoice.stepengineer( action, me.engineerlanding );
   }

   else {
       print("engineer call not found : ", action);
   }

   return result;
}


Voice.schedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.set_rates( me.ABSENTSEC );

       me.vertical = me.dependency["autoflight"].getChild("vertical").getValue();
       me.mach = me.dependency["mach"].getChild("indicated-mach").getValue();
       me.speedkt = me.dependency["asi"].getChild("indicated-speed-kt").getValue();
       me.groundkt = me.dependency["ins"].getChild("ground-speed-fps").getValue() * constant.FPSTOKT;
       me.altitudeft = me.dependency["altimeter"].getChild("indicated-altitude-ft").getValue();
       me.aglft = me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue();
       me.speedfpm = me.dependency["ivsi"].getChild("indicated-speed-fps").getValue() * constant.MINUTETOSECOND;
       me.gear = me.dependency["gear"].getChild("position-norm").getValue();
       me.nose = me.dependency["nose"].getChild("pos-norm").getValue();

       # 1 cycle
       me.flightlevel.schedule( me.speedfpm );
       me.acceleration.schedule( me.speedkt, me.lastspeedkt );

       me.crewvoice.schedule();

       me.nextcallout();

       me.whichcallout();
       me.whichchecklist();

       me.playvoices();

       me.snapshot();
   }

   else {
       me.rates = me.ABSENTSEC;

       me.nocalloutinit();
       me.nochecklistinit();
       me.noemergencyinit();
   }

   settimer( func { me.schedule(); }, me.rates );
}

Voice.nextcallout = func {
   if( me.is_landing() or me.is_beforelanding() ) {
       me.landing();
   }
   elsif( me.is_takeoff() or me.is_aftertakeoff() ) {
       me.takeoff();
   }
   # not on taxi
   elsif( me.is_holding() and !me.is_runway() ) {
       me.holding();
   }
   elsif( me.is_goaround() ) {
       me.goaround();
   }
   elsif( !me.on_ground() ) {
       me.flight();
   }
}

# the voice must work with and without virtual crew.
Voice.whichcallout = func {
   # user is on ground
   if( !me.is_moving() ) {
       me.userground();
   }

   # user has performed a go around
   elsif( me.vertical == "goaround" and ( me.is_landing() or me.is_goaround() ) ) {
       if( me.is_landing() ) {
           me.goaroundinit();
       }
   }

   # checklists required all crew members.
   elsif( !me.on_ground() ) {
       me.userair();
   }
}

Voice.whichchecklist = func {
   if( me.has_crew() ) {
       # AI triggers automatically checklists
       if( me.has_AI() and !me.is_emergency() ) {

           # aircraft is climbing
           if( me.is_climbing() ) {
               me.crewclimb();
           }

           # aircraft is descending
           elsif( me.is_descending() ) {
               me.crewdescent();
           }

           # aircraft cruise
           elsif( !me.on_ground() ) {
               me.crewcruise();
           }
       }
   }

   else {
       me.nochecklistinit();
   }
}

Voice.userground = func {
    var curairport = me.noinstrument["presets"].getChild("airport-id").getValue();
    var currunway = me.noinstrument["presets"].getChild("runway").getValue();

    
    # user has started all engines
    if( me.is_allengines() ) {
        if( me.is_landing() ) {
            # when missed by callout
            if( me.speedkt < me.acceleration.velocitykt( 20 ) ) {
                me.landingend();
            }
        }
        
        # taxi with all engines, without AI
        elsif( me.is_taxiway() ) {
        }
        
        # taxi with all engines
        elsif( me.is_terminal() ) {
        }
       
        else {
            if( !me.is_taxiway() and !me.is_holding() ) {
                me.takeoffinit();
            }

            # user has relocated on ground
            if( !me.is_takeoff() and !me.is_holding() ) {
                # flight may trigger at FG startup !
                if( curairport != me.airport or currunway != me.runway ) {
                    me.takeoffinit();
                }
            }

            # user has set parking brakes at runway threshold
            if( me.is_takeoff() ) {
                if( me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
                    me.holdinginit();
                }
            }
        }
    }

    # user has stopped all engines
    elsif( me.is_noengines() ) {
        me.gateinit();
    }

    # user has stopped inboard engines
    elsif( !me.dependency["engine"][constantaero.ENGINE2].getChild("running").getValue() and
           !me.dependency["engine"][constantaero.ENGINE3].getChild("running").getValue() ) {
        me.terminalinit();
    }


    me.airport = curairport;
    me.runway = currunway;
}

Voice.userair = func {
    # aircraft is climbing
    if( me.is_climbing() and me.aglft > constantaero.CLIMBFT ) {
        me.flightinit();
    }

    # aircraft is descending
    elsif( me.is_descending() ) {
        if( me.is_approaching() ) {
            me.landinginit();
        }

        else {
            me.flightinit();
        }
    }

    # aircraft is flying
    elsif( !me.is_takeoff() ) {
        me.flightinit();
    }
}

Voice.crewcruise = func {
    if( me.is_cruising() ) {
        # waits for checklist end
        if( !me.is_transsonic() ) {
            me.cruiseclimbinit();
        }
    }

    elsif( me.is_cruisingsubsonic() ) {
        me.flightinit();
    }

    elsif( !me.is_takeoff() and !me.is_aftertakeoff() ) {
        me.flightinit();
    }
}

Voice.crewclimb = func {
    if( me.is_cruising() ) {
        # waits for checklist end
        if( !me.is_transsonic() ) {
            me.cruiseclimbinit();
        }
    }

    # transsonic
    elsif( me.is_supersonic() ) {
        me.transsonicinit();
    }

    # subsonic
    elsif( me.is_cruisingsubsonic() ) {
        if( !me.lastcheck.is_climb() ) {
            me.climbinit();
        }
    }

    # starting climb
    elsif( !me.is_takeoff() and !me.is_aftertakeoff() ) {
        me.flightinit();
    }
}

Voice.crewdescent = func {
    # landing
    if( me.aglft < constantaero.LANDINGFT ) {
        # impossible just after a takeoff, must climb enough
        if( !me.is_takeoff() ) {
            if( !me.lastcheck.is_beforelanding() ) {
                me.beforelandinginit();
            }
        }
    }

    # approaching
    elsif( me.is_approaching() ) {
        if( !me.lastcheck.is_approach() ) {
            me.approachinit();
        }
    }

    # ending cruise
    elsif( me.is_supersonic() ) {
        me.descentinit();
    }
}

Voice.has_AI = func {
   var result = constant.FALSE;

   # AI triggers flight checklists
   if( me.dependency["crew-ctrl"].getChild("checklist").getValue() ) {
       result = me.has_crew();
   }

   return result;
}

Voice.has_crew = func {
   var result = constant.FALSE;

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       if( me.dependency["copilot-ctrl"].getChild("activ").getValue() and
           me.dependency["engineer-ctrl"].getChild("activ").getValue() ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Voice.has_reheat = func {
    var augmentation = constant.FALSE;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.dependency["engine-ctrl"][i].getChild("reheat").getValue() ) {
             augmentation = constant.TRUE;
             break;
         }
    }

    return augmentation;
}

Voice.sendcallout = func {
   me.itself["root"].getChild("callout").setValue(me.callout);
   me.itself["automata"][0].setValue( me.automata );
   me.itself["automata"][1].setValue( me.automata2 );
}

Voice.sendchecklist = func {
   me.itself["root"].getChild("checklist").setValue(me.checklist);
   me.itself["root"].getChild("real").setValue(me.real);
}

Voice.sendemergency = func {
   me.itself["root"].getChild("emergency").setValue(me.emergency);
   me.itself["root"].getChild("real").setValue(me.real);
}

Voice.snapshot = func {
   me.lastspeedkt = me.speedkt;
   me.lastaltitudeft = me.altitudeft;
   me.lastnose = me.nose;
}

Voice.playvoices = func {
   if( me.crewvoice.willplay() ) {
       me.set_rates( constant.HUMANSEC );
   }

   me.crewvoice.playvoices( me.rates );
}

Voice.Vkt = func( minkt, maxkt ) {
    var weightlb = me.noinstrument["weight"].getValue();
    var valuekt = constantaero.Vkt( weightlb, minkt, maxkt );

    return valuekt;
}

Voice.calloutinit = func( state, state2, state3 ) {
   me.callout = state;
   me.automata = state2;
   me.automata2 = state3;

   me.flightlevel.setlevel( me.altitudeft );

   me.sendcallout();
}

Voice.checklistinit = func( state, real ) {
   me.checklist = state;
   me.real = real;

   # red : processing
   if( me.real ) {
       me.itself["display"].getChild("processing").setValue(me.checklist);
   }

   else {
       var processing = me.itself["display"].getChild("processing").getValue();

       # blue : completed
       if( processing != "" ) {
           me.lastcheck.checklist = processing;

           me.itself["display"].getChild("processing").setValue("");
           me.itself["display"].getChild("completed").setValue(me.lastcheck.checklist);
       }
   }

   me.not_completed();

   me.sendchecklist();
}

Voice.emergencyinit = func( state, real ) {
   me.emergency = state;
   me.real = real;

   # red : processing
   if( me.real ) {
       me.itself["display"].getChild("processing").setValue(me.emergency);
   }

   else {
       var processing = me.itself["display"].getChild("processing").getValue();

       # blue : completed
       if( processing != "" ) {
           me.itself["display"].getChild("processing").setValue("");
           me.itself["display"].getChild("completed").setValue(processing);
       }
   }

   me.not_completed();

   me.sendemergency();
}


# -------
# NOTHING
# -------
Voice.noemergencyinit = func {
   me.emergencyinit( "", constant.FALSE );
}

Voice.nochecklistinit = func {
   me.checklistinit( "", constant.FALSE );
}

Voice.nocalloutinit = func {
   me.calloutinit( "not serviceable", "", "" );
}


# -------
# TAXIWAY
# -------
Voice.taxiwayinit = func {
   var result = constant.TRUE;

   if( me.is_taxiway() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "taxiway", "", "" );
   }
}


# -------------
# AFTER LANDING
# -------------
Voice.afterlandinginit = func {
   var result = constant.TRUE;

   if( me.is_afterlanding() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "afterlanding", constant.TRUE );
   }
}


# --------
# TERMINAL
# --------
Voice.terminalinit = func {
   var result = constant.TRUE;

   if( me.is_terminal() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "terminal", "", "" );
   }
}


# -------
# PARKING
# -------
Voice.parkinginit = func {
   var result = constant.TRUE;

   if( me.is_parking() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "parking", constant.TRUE );
   }
}


# ----
# GATE
# ----
Voice.gateinit = func {
   var result = constant.TRUE;

   if( me.is_gate() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "gate", "", "", constant.FALSE );
   }
}


# --------
# STOPOVER
# --------
Voice.stopoverinit = func {
   var result = constant.TRUE;

   if( me.is_stopover() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "stopover", constant.TRUE );
   }
}


# --------
# EXTERNAL
# --------
Voice.externalinit = func {
   var result = constant.TRUE;

   if( me.is_external() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "external", constant.TRUE );
   }
}


# -------------------------------
# COCKPIT PRELIMINARY PREPARATION
# -------------------------------
Voice.preliminaryinit = func {
   var result = constant.TRUE;

   if( me.is_preliminary() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "preliminary", constant.TRUE );
   }
}


# -------------------
# COCKPIT PREPARATION
# -------------------
Voice.cockpitinit = func {
   var result = constant.TRUE;

   if( me.is_cockpit() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "cockpit", constant.TRUE );
   }
}


# ------------
# BEFORE START
# ------------
Voice.beforestartinit = func {
   var result = constant.TRUE;

   if( me.is_beforestart() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "beforestart", constant.TRUE );
   }
}


# ------------
# ENGINE START
# ------------
Voice.enginestartinit = func {
   var result = constant.TRUE;

   if( me.is_enginestart() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "enginestart", constant.TRUE );
   }
}


# --------
# PUSHBACK
# --------
Voice.pushbackinit = func {
   var result = constant.TRUE;

   if( me.is_pushback() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "pushback", constant.TRUE );
   }
}


# -------
# STARTED
# -------
Voice.startedinit = func {
   var result = constant.TRUE;

   if( me.is_started() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "started", constant.FALSE );
   }
}


# -----------
# AFTER START
# -----------
Voice.afterstartinit = func {
   var result = constant.TRUE;

   if( me.is_afterstart() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "afterstart", constant.TRUE );
   }
}


# ----
# TAXI
# ----
Voice.taxiinit = func {
   var result = constant.TRUE;

   if( me.is_taxi() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "taxi", constant.TRUE );
   }
}


# ------
# RUNWAY
# ------
Voice.runwayinit = func {
   var result = constant.TRUE;

   if( me.is_runway() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "runway", constant.FALSE );
   }
}


# --------------
# BEFORE TAKEOFF
# --------------
Voice.beforetakeoffinit = func {
   var result = constant.TRUE;

   if( me.is_beforetakeoff() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "beforetakeoff", constant.TRUE );
   }
}


# -------
# HOLDING
# -------
Voice.holdinginit = func {
   var result = constant.TRUE;

   if( me.is_holding() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "holding", "holding", "holding" );
   }
}

Voice.holding = func {
   me.set_rates( me.HOLDINGSEC );

   if( me.automata2 == "holding" ) {
       if( !me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
           if( me.dependency["captain-ctrl"].getChild("countdown").getValue() ) {
               me.automata2 = me.captaincall( "brakes3" );
           }

           else {
               me.takeoffinit();
           }
       }
   }

   elsif( me.automata2 == "brakes3" ) {
       me.automata2 = me.captaincall( "brakes2" );
   }

   elsif( me.automata2 == "brakes2" ) {
       me.automata2 = me.captaincall( "brakes1" );
   }

   elsif( me.automata2 == "brakes1" ) {
       me.automata2 = me.captaincall( "brakes" );
   }
   else {
       me.takeoffinit();
   }

   me.sendchecklist();
}


# -------
# TAKEOFF
# -------
Voice.takeoffinit = func ( overwrite = 0 ) {
   var result = constant.TRUE;

   if( me.is_takeoff() ) {
       result = constant.FALSE;
   }

   if( result or overwrite ) {
       me.calloutinit( "takeoff", "takeoff", "takeoff" );

       me.v1 = constant.FALSE;
       me.v2 = constant.FALSE;
   }
}

Voice.takeoff = func {
   me.set_rates( constant.HUMANSEC );

   me.takeoffpilot();

   if( !me.crewvoice.is_asynchronous() ) {
       me.takeoffclimb();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.takeoffallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.flightallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}

Voice.takeoffallways = func {
   if( !me.on_ground() ) {
       if( me.speedfpm < me.DECAYFPM ) {
           me.crewvoice.stepallways( "negativvsi", me.allwaystakeoff, constant.TRUE );
       }

       elsif( me.speedkt < constantaero.APPROACHKT and
              (  me.acceleration.climbdecrease() or
                 ( me.v2 and
                   me.speedkt < me.acceleration.velocitykt( me.Vkt( constantaero.V2EMPTYKT,
                                                                    constantaero.V2FULLKT ) ) ) ) ) {
           me.crewvoice.stepallways( "airspeeddecay", me.allwaystakeoff, constant.TRUE );
       }
   }
}

Voice.takeoffclimb = func {
   if( me.automata2 == "takeoff" ) {
       if( me.is_climbing() and me.aglft > constantaero.LIFTOFFFT ) {
           me.automata2 = me.crewvoice.steppilot( "liftoff", me.pilotclimb );
           if( me.has_AI() ) {
               me.aftertakeoffinit();
           }
       }
   }
}

Voice.takeoffpilot = func {
   if( me.automata == "takeoff" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.AIRSPEEDKT ) ) {
           me.automata = me.pilotcall( "airspeed" );
       }
   }

   elsif( me.automata == "airspeed" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.V100KT ) ) {
           me.automata = me.pilotcall( "100kt" );
           me.engineercall( "100kt" );
       }
   }

   elsif( me.automata == "100kt" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.Vkt( constantaero.V1EMPTYKT,
                                                             constantaero.V1FULLKT ) ) ) {
           me.automata = me.pilotcall( "V1" );
           me.v1 = constant.TRUE;
       }
   }

   elsif( me.automata == "V1" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.Vkt( constantaero.VREMPTYKT,
                                                             constantaero.VRFULLKT ) ) ) {
           me.automata = me.pilotcall( "VR" );
       }
   }

   elsif( me.automata == "VR" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.Vkt( constantaero.V2EMPTYKT,
                                                             constantaero.V2FULLKT ) ) ) {
           me.automata = me.pilotcall( "V2" );
           me.v2 = constant.TRUE;
       }
   }

   elsif( me.automata == "V2" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.V240KT ) ) {
           me.automata = me.pilotcall( "240kt" );
       }
   }

   # aborted takeoff
   if( me.automata != "takeoff" ) {
       if( me.speedkt < me.acceleration.velocitykt( 20 ) ) {
           me.takeoffinit( constant.TRUE );
       }
   }
}


# -------------
# AFTER TAKEOFF
# -------------
Voice.aftertakeoffinit = func {
   var result = constant.TRUE;

   if( me.is_aftertakeoff() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "aftertakeoff", constant.TRUE );
   }
}


# ------
# FLIGHT 
# ------
Voice.flightinit = func {
   var result = constant.TRUE;

   if( me.is_flight() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "flight", "", "" );
   }
}

Voice.flight = func {
   me.flightallways();

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}

Voice.flightallways = func {
   if( !me.dependency["crew"].getChild("unexpected").getValue() ) {
       altitudeft = me.dependency["autoflight"].getChild("altitude-select").getValue();
       if( me.selectft != altitudeft ) {
           me.selectft = altitudeft;
           me.delayselectftsec = me.rates;
       }
       elsif( me.delayselectftsec > 0 ) {
           if( me.delayselectftsec >= me.MODIFYSEC ) {
               if( me.crewvoice.stepallways( "altitudeset", me.allwaysflight ) ) {
                   me.delayselectftsec = 0;
               }
           }
           else {
               me.delayselectftsec = me.delayselectftsec + me.rates;
           }
       }


       if( !me.altitudeselect ) { 
           if( me.vertical == "altitude-acquire" ) {
               if( me.autopilotsystem.is_engaged() and
                   !me.autopilotsystem.altitudelight_on( me.altitudeft, me.selectft ) ) {
                   me.altitudeselect = constant.TRUE;
               }
           }
       }
       else { 
           if( me.autopilotsystem.is_engaged() and
               me.autopilotsystem.altitudelight_on( me.altitudeft, me.selectft ) ) {
               if( me.crewvoice.stepallways( "1000fttogo", me.allwaysflight ) ) {
                   me.altitudeselect = constant.FALSE;
               }
           }       
       }


       if( me.flightlevel.levelchange( me.altitudeft ) ) {
           me.crewvoice.stepallways( "altimetercheck", me.allwaysflight );

           if( me.dependency["engineer"].getNode("cg/forward").getValue() ) {
               me.fueltransfert = constant.TRUE;
               me.crewvoice.stepengineer( "cgforward", me.engineerflight );
           }
           elsif( me.dependency["engineer"].getNode("cg/aft").getValue() ) {
               me.fueltransfert = constant.TRUE;
               me.crewvoice.stepengineer( "cgaft", me.engineerflight );
           }
           else {
               me.fueltransfert = constant.FALSE;
               me.crewvoice.stepengineer( "cgcorrect", me.engineerflight );
           }
       }
       elsif( me.flightlevel.transitionchange( me.altitudeft ) ) {
           me.crewvoice.stepallways( "transition", me.allwaysflight );
       }

       # fuel transfert is completed :
       # - climb at 26000 ft.
       # - cruise above 50000 ft.
       # - descent to 38000 ft.
       # - approach to 10000 ft.
       elsif( me.fueltransfert and
              !me.dependency["engineer"].getNode("cg/forward").getValue() and
              !me.dependency["engineer"].getNode("cg/aft").getValue() ) {
           if( ( me.autopilotsystem.is_engaged() and
               ( me.autopilotsystem.is_altitude_acquire() or
                 me.autopilotsystem.is_altitude_hold() ) ) or
               me.is_cruising() or me.is_approaching() ) {
               me.fueltransfert = constant.FALSE;
               me.crewvoice.stepengineer( "cgcorrect", me.engineerflight );
           }
       }
   } 
}


# -----
# CLIMB 
# -----
Voice.climbinit = func {
   var result = constant.TRUE;

   if( me.is_climb() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "climb", constant.TRUE );
   }
}


# ----------------
# TRANSSONIC CLIMB
# ----------------
Voice.transsonicinit = func {
   var result = constant.TRUE;

   if( me.is_transsonic() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "transsonic", constant.TRUE );
   }
}


# ------------
# CRUISE CLIMB 
# ------------
Voice.cruiseclimbinit = func {
   var result = constant.TRUE;

   if( me.is_cruiseclimb() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "cruiseclimb", constant.FALSE );
   }
}


# -------
# DESCENT
# -------
Voice.descentinit = func {
   var result = constant.TRUE;

   if( me.is_descent() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "descent", constant.TRUE );
   }
}


# ---------------
# BEFORE APPROACH
# ---------------
Voice.approachinit = func {
   var result = constant.TRUE;

   if( me.is_approach() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "approach", constant.TRUE );
   }
}


# --------------
# BEFORE LANDING
# --------------
Voice.beforelandinginit = func {
   var result = constant.TRUE;

   if( me.is_beforelanding() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "beforelanding", constant.TRUE );
   }
}


# -------
# LANDING
# -------
Voice.landinginit = func {
   var result = constant.TRUE;

   if( me.is_landing() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "landing", "landing", "landing" );

       me.category = constant.FALSE;
       me.alert = constant.FALSE;
       me.decision = constant.FALSE;
       me.decisiontogo = constant.FALSE;
   }
}

Voice.landing = func {
   me.set_rates( constant.HUMANSEC );

   me.landingengineer();

   if( !me.crewvoice.is_asynchronous() ) {
       me.landingpilot();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.landingallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}

Voice.landingpilot = func {
   if( me.automata2 == "landing" ) {
       if( me.dependency["nav"].getChild("in-range").getValue() ) {
           if( me.autopilotsystem.is_engaged() and
               me.dependency["autoflight"].getChild("heading").getValue() == "nav1-hold" ) {
               me.automata2 = me.pilotcall( "beambar" );
           }
       }
   }
   elsif( me.automata2 == "beambar" ) {
       if( me.dependency["nav"].getChild("in-range").getValue() and
           me.dependency["nav"].getChild("has-gs").getValue() ) {
           if( me.autopilotsystem.is_engaged() and
               me.dependency["autoflight"].getChild("altitude").getValue() == "gs1-hold" ) {
               me.automata2 = me.pilotcall( "glideslope" );
           }
       }
   }
   elsif( me.automata2 == "glideslope" ) {
       if( me.speedkt < me.acceleration.velocitykt( 100 ) ) {
           me.automata2 = me.pilotcall( "100kt" );
       }
   }
   elsif( me.automata2 == "100kt" ) {
       if( me.speedkt < me.acceleration.velocitykt( 75 ) ) {
           me.automata2 = me.pilotcall( "75kt" );
       }
   }
   elsif( me.automata2 == "75kt" ) {
       if( me.speedkt < me.acceleration.velocitykt( 40 ) ) {
           me.automata2 = me.pilotcall( "40kt" );
       }
   }
   elsif( me.automata2 == "40kt" ) {
       if( me.speedkt < me.acceleration.velocitykt( 20 ) ) {
           me.automata2 = me.pilotcall( "20kt" );
           # wake up AI
           me.landingend();
       }
   }
}

Voice.landingend = func {
   if( me.has_AI() ) {
       me.afterlandinginit();
   }
   else {
       me.taxiwayinit();
   }
}

Voice.landingengineer = func {
   if( me.automata == "landing" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL2500FT ) ) {
           me.automata = me.engineercall( "2500ft" );
       }
   }

   elsif( me.automata == "2500ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL1000FT ) ) {
           me.automata = me.engineercall( "1000ft" );
       }
   }

   elsif( me.automata == "1000ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL800FT ) ) {
           me.automata = me.engineercall( "800ft" );
       }
   }

   elsif( me.automata == "800ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL500FT ) ) {
           me.automata = me.engineercall( "500ft" );
       }
   }

   elsif( me.automata == "500ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL400FT ) ) {
           me.automata = me.engineercall( "400ft" );
       }
   }

   elsif( me.automata == "400ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL300FT ) ) {
           me.automata = me.engineercall( "300ft" );
       }
   }

   elsif( me.automata == "300ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL200FT ) ) {
           me.automata = me.engineercall( "200ft" );
       }
   }

   elsif( me.automata == "200ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL100FT ) ) {
           me.automata = me.engineercall( "100ft" );
       }
   }

   elsif( me.automata == "100ft" ) {
       me.landingtouchdown( me.AGL50FT );
   }

   elsif( me.automata == "50ft" ) {
       me.landingtouchdown( me.AGL40FT );
   }

   elsif( me.automata == "40ft" ) {
       me.landingtouchdown( me.AGL30FT );
   }

   elsif( me.automata == "30ft" ) {
       me.landingtouchdown( me.AGL20FT );
   }

   elsif( me.automata == "20ft" ) {
       if( me.aglft < me.flightlevel.climbft( me.AGL15FT ) ) {
           me.automata = me.engineercall( "15ft" );
       }
   }
}

# can be faster
Voice.landingtouchdown = func( limitft ) {
   if( 15 <= limitft and me.aglft < me.flightlevel.climbft( me.AGL15FT ) ) {
       me.automata = me.engineercall( "15ft" );
   }
   elsif( 20 <= limitft and me.aglft < me.flightlevel.climbft( me.AGL20FT ) ) {
       me.automata = me.engineercall( "20ft" );
   }
   elsif( 30 <= limitft and me.aglft < me.flightlevel.climbft( me.AGL30FT ) ) {
       me.automata = me.engineercall( "30ft" );
   }
   elsif( 40 <= limitft and me.aglft < me.flightlevel.climbft( me.AGL40FT ) ) {
       me.automata = me.engineercall( "40ft" );
   }
   elsif( 50 <= limitft and me.aglft < me.flightlevel.climbft( me.AGL50FT ) ) {
       me.automata = me.engineercall( "50ft" );
   }
}

Voice.landingallways = func {
   var altitudeft = me.dependency["autoflight"].getChild("altitude-select").getValue();

   if( me.selectft != altitudeft ) {
       me.selectft = altitudeft;
       me.delayselectftsec = me.rates;
   }
   elsif( me.delayselectftsec > 0 ) {
       if( me.delayselectftsec >= me.MODIFYSEC ) {
           if( me.crewvoice.stepallways( "goaroundset", me.allwayslanding ) ) {
               me.delayselectftsec = 0;
           }
       }
       else {
           me.delayselectftsec = me.delayselectftsec + me.rates;
       }
   }

   if( me.aglft < me.AGL100FT and
       me.dependency["attitude"].getChild("indicated-pitch-deg").getValue() > me.FLAREDEG ) {
       me.crewvoice.stepallways( "attitude", me.allwayslanding, constant.TRUE );
   }

   elsif( me.aglft < me.AGL1000FT and me.speedfpm < me.FINALFPM ) {
       me.crewvoice.stepallways( "vsiexcess", me.allwayslanding, constant.TRUE );
   }

   elsif( !me.category and me.dependency["autopilot"].getChild("land3").getValue() ) {
       me.crewvoice.stepallways( "category3", me.allwayslanding );
       me.category = constant.TRUE;
   }

   elsif( !me.category and me.dependency["autopilot"].getChild("land2").getValue() ) {
       me.crewvoice.stepallways( "category2", me.allwayslanding );
       me.category = constant.TRUE;
   }

   elsif( !me.alert and me.dependency["autopilot"].getChild("land2").getValue() and
          me.aglft < me.flightlevel.climbft( me.AGL300FT ) ) {
       me.crewvoice.stepallways( "alertheight", me.allwayslanding );
       me.alert = constant.TRUE;
   }

   elsif( !me.decisiontogo and
          me.aglft <
          me.flightlevel.climbft( me.dependency["radio-altimeter"].getChild("decision-ft").getValue() + me.AGL100FT ) ) {
       me.crewvoice.stepallways( "100fttogo", me.allwayslanding );
       me.decisiontogo = constant.TRUE;
   }

   elsif( me.decisiontogo and !me.decision and
          me.aglft <
          me.flightlevel.climbft( me.dependency["radio-altimeter"].getChild("decision-ft").getValue() ) ) {
       me.crewvoice.stepallways( "decisionheight", me.allwayslanding );
       me.decision = constant.TRUE;
   }

   elsif( me.aglft < me.AGL1000FT and !me.decision and
         ( me.acceleration.finaldecrease() or
           me.speedkt < me.acceleration.velocitykt( me.Vkt( constantaero.VREFEMPTYKT,
                                                            constantaero.VREFFULLKT ) ) ) ) {
       me.crewvoice.stepallways( "approachspeed", me.allwayslanding, constant.TRUE );
   }
}


# ---------
# GO AROUND
# ---------
Voice.goaroundinit = func {
   var result = constant.TRUE;

   if( me.is_goaround() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "goaround", "goaround", "goaround" );
   }
}

Voice.goaround = func {
   me.set_rates( constant.HUMANSEC );

   if( me.automata == "goaround" ) {
       if( me.speedfpm > 0 ) {
           me.automata = me.pilotcall( "positivclimb" );
           if( me.has_AI() ) {
               me.aftertakeoffinit();
           }

           me.flightinit();
       }
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.takeoffallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}


# ------
# ALWAYS 
# ------
Voice.checkallways = func {
   var change = constant.FALSE;

   if( me.nose != me.lastnose or me.gear != me.lastgear ) {
       change = constant.TRUE;
       if( me.nose == constantaero.NOSEDOWN and me.gear == constantaero.GEARDOWN ) {
           if( !me.crewvoice.stepallways( "5greens", me.allways ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.lastnose = me.nose;
       }
   }

   if( me.gear != me.lastgear ) {
       change = constant.TRUE;
       # on pull of lever
       if( me.lastgear == constantaero.GEARDOWN and me.gear < constantaero.GEARDOWN ) {
           if( !me.crewvoice.stepallways( "gearup", me.allways ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.lastgear = me.gear;
       }
   }
}


# ---------------------
# FOUR ENGINE FLAME OUT
# ---------------------
Voice.fourengineflameoutinit = func {
   var result = constant.TRUE;

   if( me.is_fourengineflameout() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.emergencyinit( "fourengineflameout", constant.TRUE );
   }
}

# ----------------------------------
# FOUR ENGINE FLAME OUT (SUPERSONIC)
# ----------------------------------
Voice.fourengineflameoutmach1init = func {
   var result = constant.TRUE;

   if( me.is_fourengineflameoutmach1() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.emergencyinit( "fourengineflameoutmach1", constant.TRUE );
   }
}


Voice.on_ground = func {
   var result = constant.FALSE;

   if( me.aglft < constantaero.AGLTOUCHFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voice.is_climbing = func {
   var result = constant.FALSE;

   if( me.speedfpm > me.CLIMBFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voice.is_cruisingsubsonic = func {
   var result = constant.FALSE;

   if( me.mach > constantaero.CLIMBMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Voice.is_supersonic = func {
   var result = constant.FALSE;

   if( me.mach >= constantaero.SOUNDMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Voice.is_cruising = func {
   var result = constant.FALSE;

   if( me.altitudeft >= constantaero.CRUISEFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voice.is_descending = func {
   var result = constant.FALSE;

   if( me.speedfpm < me.DESCENTFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voice.is_approaching = func {
   var result = constant.FALSE;

   if( me.aglft < constantaero.APPROACHFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voice.is_allengines = func {
    var result = constant.TRUE;

    for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
         if( !me.dependency["engine"][i].getChild("running").getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}

Voice.is_noengines = func {
    var result = constant.TRUE;

    for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
         if( me.dependency["engine"][i].getChild("running").getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}


# ==========
# CREW VOICE 
# ==========

Crewvoice = {};

Crewvoice.new = func {
   var obj = { parents : [Crewvoice,System],

               voicebox : Voicebox.new(),

               CONVERSATIONSEC : 4.0,                            # until next message
               REPEATSEC : 4.0,                                  # between 2 messages

               # pilot in command
               phrasecaptain : "",
               delaycaptainsec : 0.0,

               # pilot not in command
               phrase : "",
               delaysec : 0.0,                                   # delay this phrase
               nextsec : 0.0,                                    # delay the next phrase

               # engineer
               phraseengineer : "",
               delayengineersec : 0.0,

               asynchronous : constant.FALSE,

               hearsound : constant.FALSE,
               hearvoice : constant.FALSE
         };

   obj.init();

   return obj;
}

Crewvoice.init = func {
   me.inherit_system("/systems/voice");

   me.hearsound = me.itself["sound"].getChild("enabled").getValue();
}

Crewvoice.textexport = func {
   var feedback = me.voicebox.textexport();

   # also to test sound
   if( me.voicebox.is_on() ) {
       me.talkpilot( feedback );
   }
   else {
       me.talkengineer( feedback );
   }
}

Crewvoice.schedule = func {
   if( me.hearsound ) {
       me.hearvoice = me.itself["root-ctrl"].getNode("sound").getValue();
   }

   me.voicebox.schedule();
}

Crewvoice.stepallways = func( state, table, repeat = 0 ) {
   var result = constant.FALSE;

   if( !me.asynchronous ) {
       if( me.nextsec <= 0 ) {
           me.phrase = table[state];
           me.delaysec = 0;

           if( repeat ) {
               me.nextsec = me.REPEATSEC;
           }

           if( me.phrase == "" ) {
               print("missing voice text : ",state);
           }

           me.asynchronous = constant.TRUE;
           result = constant.TRUE;
       }
   }

   return result;
}

Crewvoice.steppilot = func( state, table ) {
   me.talkpilot( table[state] );

   if( me.phrase == "" ) {
       print("missing voice text : ",state);
   }

   me.asynchronous = constant.TRUE;

   return state;
}

Crewvoice.nowpilot = func( state, table ) {
   me.steppilot( state, table );

   me.playvoices( constant.HUMANSEC );
}

Crewvoice.talkpilot = func( phrase ) {
   if( me.phrase != "" ) {
       print("phrase overflow : ", phrase);
   }

   # add an optional argument
   if( find("%s", phrase) >= 0 ) {
       phrase = sprintf( phrase, me.itself["root"].getChild("argument").getValue() );
   }

   me.phrase = phrase;
   me.delaysec = 0;
}

Crewvoice.stepengineer = func( state, table ) {
   me.talkengineer( table[state] );

   if( me.phraseengineer == "" ) {
       print("missing voice text : ",state);
   }

   return state;
}

Crewvoice.nowengineer = func( state, table ) {
   me.stepengineer( state, table );

   me.playvoices( constant.HUMANSEC );
}

Crewvoice.talkengineer = func( phrase ) {
   if( me.phraseengineer != "" ) {
       print("engineer phrase overflow : ", phrase);
   }

   me.phraseengineer = phrase;
   me.delayengineersec = 0;
}

Crewvoice.stepcaptain = func( state, table ) {
   me.talkcaptain( table[state] );

   if( me.phrasecaptain == "" ) {
       print("missing voice text : ",state);
   }

   me.asynchronous = constant.TRUE;

   return state;
}

Crewvoice.nowcaptain = func( state, table ) {
   me.stepcaptain( state, table );

   me.playvoices( constant.HUMANSEC );
}

Crewvoice.talkcaptain = func( phrase ) {
   if( me.phrasecaptain != "" ) {
       print("captain phrase overflow : ", phrase);
   }

   me.phrasecaptain = phrase;
   me.delaycaptainsec = 0;
}

Crewvoice.willplay = func {
   var result = constant.FALSE;

   if( me.phrase != "" or me.phraseengineer != "" or me.phrasecaptain != "" ) {
       result = constant.TRUE;
   }

   return result;
}

Crewvoice.is_asynchronous = func {
   return me.asynchronous;
}

Crewvoice.playvoices = func( rates ) {
   # pilot not in command calls out
   if( me.delaysec <= 0 ) {
       if( me.phrase != "" ) {
           me.itself["display"].getChild("copilot").setValue(me.phrase);

           if( me.hearvoice ) {
               me.itself["sound"].getChild("copilot").setValue(me.phrase);
               me.dependency["copilot-3d"].getNode("teeth").setValue(constant.TRUE);
           }
           me.voicebox.sendtext(me.phrase);
           me.phrase = "";

           # engineer lets pilot speak
           if( me.phraseengineer != "" ) {
               me.delayengineersec = me.CONVERSATIONSEC;
           }
        }
   }
   else {
       me.delaysec = me.delaysec - rates;
   }

   # no engineer voice yet
   if( me.delayengineersec <= 0 ) {
       if( me.phraseengineer != "" ) {
           me.itself["display"].getChild("engineer").setValue(me.phraseengineer);

           if( me.hearvoice ) {
               me.itself["sound"].getChild("pilot").setValue(me.phraseengineer);
               me.dependency["engineer-3d"].getNode("teeth").setValue(constant.TRUE);
           }
           me.voicebox.sendtext(me.phraseengineer, constant.TRUE);
           me.phraseengineer = "";
       }
   }
   else {
       me.delayengineersec = me.delayengineersec - rates;
   }

   # pilot in command calls out
   if( me.delaycaptainsec <= 0 ) {
       if( me.phrasecaptain != "" ) {
           me.itself["display"].getChild("captain").setValue(me.phrasecaptain);

           if( me.hearvoice ) {
               me.itself["sound"].getChild("pilot").setValue(me.phrasecaptain);
           }
           me.voicebox.sendtext(me.phrasecaptain, constant.FALSE, constant.TRUE);
           me.phrasecaptain = "";
       }
   }
   else {
       me.delaycaptainsec = me.delaycaptainsec - rates;
   }

   if( me.nextsec > 0 ) {
       me.nextsec = me.nextsec - rates;
   }

   me.asynchronous = constant.FALSE;
}


# ================
# SPEED PERCEPTION
# ================

Speedperception = {};

Speedperception.new = func {
   var obj = { parents : [Speedperception],

               ratiostep : 0.0,                                  # rates

               DECAYKT : 0.0,
               FINALKT : 0.0,

               reactionkt : 0.0,

               DECAYKTPS : -2.0,                                 # climb
               FINALKTPS : -3.0                                  # descent
         };

   obj.init();

   return obj;
}

Speedperception.init = func {
}

Speedperception.set_rates = func( rates ) {
    me.ratiostep = rates / constant.HUMANSEC;

    me.DECAYKT = me.DECAYKTPS * rates;
    me.FINALKT = me.FINALKTPS * rates;
}

Speedperception.schedule = func( speedkt, lastspeedkt ) {
    me.reactionkt = speedkt - lastspeedkt;
}

Speedperception.climbdecrease = func {
    var result = constant.FALSE;

    if( me.reactionkt < me.DECAYKT ) {
        result = constant.TRUE;
    }

    return result;
}

Speedperception.finaldecrease = func {
    var result = constant.FALSE;

    if( me.reactionkt < me.FINALKT ) {
        result = constant.TRUE;
    }

    return result;
}

Speedperception.velocitykt = func( speedkt ) {
    var valuekt = speedkt - me.reactionkt * me.ratiostep;

    return valuekt;
}


# ===================
# ALTITUDE PERCEPTION
# ===================

Altitudeperception = {};

Altitudeperception.new = func {
   var obj = { parents : [Altitudeperception],

               ratio1s : 0.0,                                    # 1 s
               ratiostep : 0.0,                                  # rates

               FLIGHTLEVELFT : 10000,  
               MARGINFT : 200,                                   # for altitude detection

               MAXFT : 0.0,

               reactionft : 0.0,

               level10000 : 0,                                   # current flight level
               levelabove : constant.TRUE,                       # above sea level
               levelbelow : constant.FALSE,
               transition : constant.FALSE                       # below transition level
         };

   obj.init();

   return obj;
}

Altitudeperception.init = func {
   me.ratio1s = 1 / constant.HUMANSEC;
}

Altitudeperception.set_rates = func( steps ) {
   me.ratiostep = steps / constant.HUMANSEC;

   me.MAXFT = constantaero.MAXFPM * steps / constant.MINUTETOSECOND;
}

Altitudeperception.schedule = func( speedfpm ) {
   me.reactionft = speedfpm / constant.MINUTETOSECOND;
}

Altitudeperception.climbft = func( altitudeft ) {
   # adds 1 seconds for better matching
   var valueft = altitudeft - me.reactionft * ( me.ratiostep + me.ratio1s );

   return valueft;
}

Altitudeperception.insideft = func( altitudeft, targetft ) {
    var result = constant.FALSE;

    if( altitudeft >= targetft - me.MAXFT and altitudeft <= targetft + me.MAXFT  ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.inside = func {
    var result = constant.FALSE;

    if( !me.levelabove and !me.levelbelow ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.aboveft = func( altitudeft, targetft, marginft ) {
    var result = constant.FALSE;

    if( altitudeft > targetft + marginft  ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.belowft = func( altitudeft, targetft, marginft ) {
    var result = constant.FALSE;

    if( altitudeft < targetft - marginft  ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.setlevel = func( altitudeft ) {
   var levelft = 0.0;

   # default
   var level = 0;

   if( altitudeft >= 10000 and altitudeft < 20000 ) {
       level = 1;
   }
   elsif( altitudeft >= 20000 and altitudeft < 30000 ) {
       level = 2;
   }
   elsif( altitudeft >= 30000 and altitudeft < 40000 ) {
       level = 3;
   }
   elsif( altitudeft >= 40000 and altitudeft < 50000 ) {
       level = 4;
   }
   elsif( altitudeft >= 50000 ) {
       level = 5;
   }

   me.level10000 = level;

   # snapshot
   levelft = me.level10000 * me.FLIGHTLEVELFT;
   me.levelabove = me.aboveft( altitudeft, levelft, me.MARGINFT );
   me.levelbelow = me.belowft( altitudeft, levelft, me.MARGINFT );

   if( altitudeft > constantaero.TRANSITIONFT ) {
       me.transition = constant.TRUE;
   }
   else {
       me.transition = constant.FALSE;
   }
}

Altitudeperception.levelchange = func( altitudeft ) {
   var level = 0;
   var previousft = 0.0;
   var nextft = 0.0;
   var currentft = 0.0;
   var below = constant.FALSE;
   var above = constant.FALSE;
   var result = constant.FALSE;

   # reaches lower flight level
   if( me.level10000 > 0 ) {
       level = me.level10000 - 1;
       previousft = me.climbft( level * me.FLIGHTLEVELFT );
       if( altitudeft < previousft ) {
           result = constant.TRUE;
           me.level10000 = level;
           me.levelabove= constant.FALSE;
           me.levelbelow = constant.TRUE;
       }
   }

   # reaches higher flight level
   if( !result ) {
       level = me.level10000 + 1;
       nextft = me.climbft( level * me.FLIGHTLEVELFT );
       if( altitudeft > nextft ) {
           result = constant.TRUE;
           me.level10000 = level;
           me.levelabove = constant.TRUE;
           me.levelbelow = constant.FALSE;
       }
   }

   # crosses current flight level
   if( !result and me.level10000 > 0 ) {
       currentft = me.climbft( me.level10000 * me.FLIGHTLEVELFT );

       below = me.belowft( altitudeft, currentft, me.MARGINFT );
       above = me.aboveft( altitudeft, currentft, me.MARGINFT );

       if( me.levelabove and below ) {
           result = constant.TRUE;
           me.levelabove= constant.FALSE;
           me.levelbelow = constant.TRUE;
       }
       elsif( me.levelbelow and above ) {
           result = constant.TRUE;
           me.levelabove = constant.TRUE;
           me.levelbelow = constant.FALSE;
       }
       else {
           result = constant.FALSE;
       }
   }

   return result;
}

Altitudeperception.transitionchange = func( altitudeft ) {
   var result = constant.FALSE;
   var levelft = me.climbft( constantaero.TRANSITIONFT );

   if( ( !me.transition and me.aboveft( altitudeft, levelft, me.MARGINFT ) ) or
       ( me.transition and me.belowft( altitudeft, levelft, me.MARGINFT ) ) ) {
       me.transition = !me.transition;
       result = constant.TRUE;
   }

   return result;
}
