# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by sched are called from cron



# ===============================
# GROUND PROXIMITY WARNING SYSTEM
# ===============================

Gpws = {};

Gpws.new = func {
   var obj = { parents : [Gpws,System],

               RADIOFT : 2500,
               TAKEOFFFT : 700,
               GEARFT : 500,
               NOSEFT : 200,

               OVERFTPS : -50,                          # 3000 ft / min
               TOUCHFTPS : -15,                         # touch-down below 900 ft / min
               TAXIFTPS : -5                            # not null on taxi
         };

   obj.init();

   return obj;
};

Gpws.init = func {
   me.inherit_system("/systems/gpws");

   me.decision_init();
}

Gpws.schedule = func {
   me.sound_terrain();
}

Gpws.slowschedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.decision_reset();
   }
}

Gpws.decision_init = func {
   var decisionft = 0.0;

   # reads the user customization, JSBSim has an offset of 11 ft
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        decisionft = me.dependency["radio-altimeter"][i].getChild("dial-decision-ft").getValue();
        decisionft = decisionft + constantaero.AGLFT;
        me.dependency["radio-altimeter"][i].getChild("decision-ft").setValue(decisionft);
   }
}

Gpws.sound_terrain = func {
   var alarm = constant.FALSE;

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       var aglft = 0.0;
       var speedftps = 0.0;

       for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
            aglft = me.dependency["radio-altimeter"][i].getChild("indicated-altitude-ft").getValue();
            speedftps = me.dependency["adc"][i].getNode("output").getChild("vertical-speed-fps").getValue();

            # excessive rate of descent below 2500 ft.
            if( aglft < me.RADIOFT ) {
                if( speedftps < me.OVERFTPS ) {
                    alarm = constant.TRUE;
                    break;
                }

                # excessive closure rate with ground.
                if( aglft < me.NOSEFT ) {
                    if( speedftps < me.TOUCHFTPS ) {
                        alarm = constant.TRUE;
                        break;
                    }
                }
            }

            # loss of altitude
            if( speedftps < me.TAXIFTPS ) {
                if( aglft < me.TAKEOFFFT ) {
  
                    # loss of altitude below 700 ft,after takeoff.
                    if( me.dependency["nose"].getValue() < constantaero.NOSEDOWN ) {
                        alarm = constant.TRUE;
                        break;
                    }

                    # loss of altitude below 700 ft, after goaround.
                    if( me.dependency["autoflight"].getChild("vertical").getValue() == "goaround" ) {
                        alarm = constant.TRUE;
                        break;
                    }

                    # gear not locked below 500 ft.
                    if( aglft < me.GEARFT ) {
                        if( me.dependency["gear"].getValue() < constantaero.GEARDOWN ) {
                            alarm = constant.TRUE;
                            break;
                        }

                        # nose not down below 200 ft on approach.
                        if( aglft < me.NOSEFT ) {
                            if( me.dependency["nose"].getValue() < constantaero.NOSEDOWN ) {
                                alarm = constant.TRUE;
                                break;
                            }
                        }
                    }
                }
            }
       }
   }

   me.itself["root"].getChild("terrain").setValue(alarm);
}

Gpws.decision_reset = func {
   var decisionft = 0.0;
   var aglft = 0.0;

   # GPWS depends of radio-altimeter 1
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        if( me.dependency["radio-altimeter"][i].getChild("serviceable").getValue() ) {
            if( !me.dependency["radio-altimeter"][i].getChild("decision-height").getValue() ) {
                decisionft = me.dependency["radio-altimeter"][i].getChild("decision-ft").getValue();
                aglft = me.dependency["radio-altimeter"][i].getChild("indicated-altitude-ft").getValue();

                # reset the DH light
                if( aglft > decisionft ) {
                    me.dependency["radio-altimeter"][i].getChild("decision-height").setValue( constant.TRUE );
                }
            }
        }
   }
}


# =============
# ICE DETECTION
# =============

Icedetection = {};

Icedetection.new = func {
   var obj = { parents : [Icedetection,System],

# airframe heating is ignored
               temperaturedegc : {},
               durationmin : {},

               maxclouds : 0,

               inside : constant.FALSE,
               insidemin : 0,
               warning : constant.FALSE
         };

   obj.init();

   return obj;
};

Icedetection.init = func {
   me.inherit_system("/systems/anti-icing");

   me.loadmodel();

   me.maxclouds = size( me.noinstrument["cloud"] );
}

Icedetection.schedule = func {
   me.runmodel();
}

Icedetection.loadmodel = func {
   var child = me.itself["model"].getNode("temperature"); 

   me.temperaturedegc["max"] = child.getChild("max-degc").getValue();
   me.temperaturedegc["min"] = child.getChild("min-degc").getValue();

   child = me.itself["model"].getNode("duration"); 

   me.durationmin["few"] = child.getChild("few-min").getValue();
   me.durationmin["scattered"] = child.getChild("scattered-min").getValue();
   me.durationmin["broken"] = child.getChild("broken-min").getValue();
   me.durationmin["overcast"] = child.getChild("overcast-min").getValue();
   me.durationmin["clear"] = child.getChild("clear-min").getValue();
}

Icedetection.runmodel = func {
   var airdegc = 0.0;
   var altft = 0.0;
   var elevationft = 0.0;
   var thicknessft = 0.0;
   var coverage = "";
   var found = constant.FALSE;

   if( me.itself["root"].getChild("serviceable").getValue() and
       me.dependency["electric"].getChild("specific").getValue() ) {

       airdegc =  me.noinstrument["temperature"].getValue();

       if( airdegc >= me.temperaturedegc["min"] and airdegc <= me.temperaturedegc["max"] ) {
           altft = me.noinstrument["altitude"].getValue();

           for( var i = 0; i < me.maxclouds; i = i+1 ) {
                coverage = me.noinstrument["cloud"][i].getChild("coverage").getValue();

                # ignores the kind of cloud
                if( coverage != "" and coverage != nil ) {
                    elevationft = me.noinstrument["cloud"][i].getChild("elevation-ft").getValue();
                    thicknessft = me.noinstrument["cloud"][i].getChild("thickness-ft").getValue();

                    if( elevationft != nil and thicknessft != nil ) {
                        # inside layer
                        if( ( altft > elevationft and altft < elevationft + thicknessft ) or
                            coverage == "clear" ) {

                            # enters layer
                            if( !me.inside ) {
                                 me.inside = constant.TRUE;
                                 me.insidemin = 0;
                            }

                            # ignores the coverage of cloud, and airframe speed
                            else {
                                 me.insidemin = me.insidemin + 1;
                            }

                            if( me.insidemin >= me.durationmin[coverage] ) {
                                 me.warning = constant.TRUE;
                            }

                            me.itself["detection"].getChild("duration-min").setValue(me.insidemin);
                            me.itself["detection"].getChild("coverage").setValue(coverage);
 
                            found = constant.TRUE;
                            break;
                        }
                    }
                }
           }
       }
   } 

   if( !found ) {
       me.inside = constant.FALSE;
       me.warning = constant.FALSE;
   }

   me.itself["detection"].getChild("icing").setValue(me.inside);

   me.itself["root"].getChild("warning").setValue(me.warning);
}


# =====================
# MASTER WARNING SYSTEM
# =====================

Mws = {};

Mws.new = func {
   var obj = { parents : [Mws,System],

           adcinstrument : nil,
           cginstrument : nil,
           insinstrument : nil,

           airbleedsystem : nil,
           electricalsystem : nil,
           enginesystem : nil,
           flightsystem : nil,
           hydraulicsystem : nil,
           antiicingsystem : nil,
           pressuresystem : nil,
           tankpressuresystem : nil,

           AUXILIARYSEC : 10,

           STALLDEG : 16.5,
           OVERSPEEDDEG : -5.5,

           FL41FT : 41000,
           FL15FT : 15000,

           SOUNDMACH : 1.0,
           OVERSPEEDMACH : 0.04,

           VLA41KT : 300,
           VLA15KT : 250,
           STALLKT : 20,
           OVERSPEEDKT : 10,

           NOSEDOWN : 1.0,
           NOSEUP : 0.0,

           nbambers : 0,
           amberwords : [ "adc", "air", "electrical", "fuel", "hydraulics" ],
           nbamber4s : 0,
           amber4words : [ "intake" ],

           nbreds : 0,
           redwords : [ "ads", "cg", "doors", "electrical", "feel", "ice", "ins", "pfc", "pressure", "throttle" ],
           nbred4s : 0,
           red4words : [ "engine", "intake" ],

           class1 : constant.FALSE,
           class2 : constant.FALSE
         };

   obj.init();

   return obj;
};

Mws.init = func {
   me.inherit_system("/systems/mws");

   me.nbambers = size( me.amberwords );
   me.nbamber4s = size( me.amber4words );

   me.nbreds = size( me.redwords );
   me.nbred4s = size( me.red4words );
}

Mws.set_relation = func( adc, cg, ins, airbleed, electrical, engine, flight, fuel, hydraulical, ice,
                         pressure, tankpressure ) {
   me.adcinstrument = adc;
   me.cginstrument = cg;
   me.insinstrument = ins;

   me.airbleedsystem = airbleed;
   me.electricalsystem = electrical;
   me.enginesystem = engine;
   me.flightsystem = flight;
   me.fuelsystem = fuel;
   me.hydraulicsystem = hydraulical;
   me.antiicingsystem = ice;
   me.pressuresystem = pressure;
   me.tankpressuresystem = tankpressure;
}

Mws.cancelexport = func {
   me.cancel();
   me.recall();
}

Mws.recallexport = func {
   me.itself["root-ctrl"].getChild("inhibit").setValue(constant.FALSE);

   me.cancel();
   me.recall();
   me.instantiate();

   me.dependency["audio"].getChild("cancel").setValue( constant.FALSE );

   # records that crew has pressed the button
   me.dependency["crew"].getChild("recall").setValue(constant.TRUE);
}

Mws.schedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       # avoid false warning caused by FDM or system initialization
       if( me.is_ready() ) {
           me.sound_cavalry();
           me.sound_singlegong();
           me.sound_overspeed();
           me.sound_stall();
       }

       else {
           me.cancelexport();
       }
   }
}

Mws.slowschedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.sound_auxiliary();
   }
}

Mws.sound_cavalry = func {
   var cavalry = constant.FALSE;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        if( me.dependency["autopilot"].getChild("failure",i).getValue() ) {
            cavalry = constant.TRUE;
            break;
        }
   }

   me.itself["root"].getChild("cavalry").setValue( cavalry );
}

Mws.sound_auxiliary = func {
   var auxiliary = constant.FALSE;

   if( me.class1_check() ) {
       # single gong every 10 s, if class 1 red light remains illuminated.
       auxiliary = constant.TRUE;
   }

   me.itself["root"].getChild("auxiliary").setValue( auxiliary );

   # must clear to repeat.
   settimer(func { me.auxiliarycron(); }, me.AUXILIARYSEC / 2);
}

Mws.auxiliarycron = func {
   me.itself["root"].getChild("auxiliary").setValue( constant.FALSE );
}

Mws.sound_overspeed = func {
   var speedkt = 0.0;
   var speedmach = 0.0;
   var overspeed = constant.FALSE;
   var nose = me.dependency["nose"].getValue();


   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        if( me.dependency["asi"][i].getChild("serviceable").getValue() ) {
            speedkt = me.dependency["asi"][i].getChild("indicated-speed-kt").getValue();

            # VMO exceeded.
            if( speedkt > me.dependency["asi"][i].getChild("vmo-kt").getValue() + me.OVERSPEEDKT ) {
                overspeed = constant.TRUE;
                break;
            }

            # nose down above 270 kt.
            else if( speedkt > constantaero.NOSEKT and nose == me.NOSEDOWN ) {
                overspeed = constant.TRUE;
                break;
            }
        }

        # pitch below -6 deg above Mach 1.0.
        if( me.dependency["attitude"][i].getChild("serviceable").getValue() ) {
            if( me.dependency["attitude"][i].getChild("indicated-pitch-deg").getValue() < me.OVERSPEEDDEG ) {
                if( me.dependency["mach"].getChild("serviceable").getValue() ) {
                    if( me.dependency["mach"].getChild("indicated-mach").getValue() > me.SOUNDMACH ) {
                        overspeed = constant.TRUE;
                        break;
                    }
                }
            }
        }

        # test of ADC
        if( me.dependency["adc"][i].getChild("selector").getValue() == -3 ) {
            overspeed = constant.TRUE;
            break;
        }
   }

   if( me.dependency["mach"].getChild("serviceable").getValue() ) {
       speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();

       # MMO exceeded.
       if( speedmach > me.dependency["mach"].getChild("mmo-mach").getValue() + me.OVERSPEEDMACH ) {
           overspeed = constant.TRUE;
       }

       # visor not locked up at speed above Mach 0.95.
       else if( ( speedmach > constantaero.SUBSONICMACH ) and ( nose < me.NOSEUP ) ) {
           overspeed = constant.TRUE;
       }
   }

   me.itself["root"].getChild("overspeed").setValue( overspeed );
}

Mws.sound_stall = func {
   var speedkt = 0.0;
   var altft = 0.0;
   var stall = constant.FALSE;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        # pitch above 16.5 deg.
        if( me.dependency["attitude"][i].getChild("serviceable").getValue() ) {
            if( me.dependency["attitude"][i].getChild("indicated-pitch-deg").getValue() > me.STALLDEG ) {
                stall = constant.TRUE;
                break;
            }
        }

        # Vc less than Vla minus 20 kt.
        if( me.dependency["asi"][i].getChild("serviceable").getValue() ) {
            speedkt = me.dependency["asi"][i].getChild("indicated-speed-kt").getValue();

            if( me.dependency["altimeter"][i].getChild("serviceable").getValue() ) {
                altft = me.dependency["altimeter"][i].getChild("indicated-altitude-ft").getValue();

                if( speedkt < me.VLA15KT - me.STALLKT ) {
                    if( altft > me.FL15FT and altft <= me.FL41FT ) {
                        stall = constant.TRUE;
                        break;
                    }
                }

                elsif( speedkt < me.VLA41KT - me.STALLKT ) {
                    if( altft > me.FL41FT ) {
                        stall = constant.TRUE;
                        break;
                    }
                }
            }
        }

        # test of ADC
        if( me.dependency["adc"][i].getChild("selector").getValue() == -2 ) {
            stall = constant.TRUE;
            break;
        }
   }

   # extreme AFT M/CG warning.
   if( me.dependency["cg"].getChild("percent").getValue() >
       me.dependency["cg"].getChild("max-extreme-percent").getValue() ) {
       stall = constant.TRUE;
   }

   me.itself["root"].getChild("stall").setValue( stall );
}

Mws.sound_singlegong = func {
   var singlegong = constant.FALSE;

   me.instantiate();

   if( me.class1 or me.class2 ) {
       singlegong = constant.TRUE;
   }

   me.itself["root"].getChild("single-gong").setValue( singlegong );
}

Mws.instantiate = func {
   me.class1 = constant.FALSE;
   me.class2 = constant.FALSE;

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.class1_instantiate();
       me.class2_instantiate();
   }
}

Mws.class1_instantiate = func {
   # 4
   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.itself["red"].getChild( me.recallpath( "engine" ), i ).getValue() ) {
            if( me.enginesystem.red_engine( i ) ) {
                me.setred( "engine", i );
            }
        }

        if( me.itself["red"].getChild( me.recallpath( "intake" ), i ).getValue() ) {
            if( me.hydraulicsystem.red_intake( i ) ) {
                me.setredinhibit( "intake", i );
            }
        }
   }

   # red
   if( me.itself["red"].getChild( me.recallpath( "ads" ) ).getValue() ) {
       if( me.adcinstrument.red_ads() ) {
           me.setred( "ads" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "cg" ) ).getValue() ) {
       if( me.cginstrument.red_cg() ) {
           me.setredinhibit( "cg" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "doors" ) ).getValue() ) {
       if( me.airbleedsystem.red_doors() or me.electricalsystem.red_doors() ) {
           me.setredinhibit( "doors" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "electrical" ) ).getValue() ) {
       if( me.electricalsystem.red_electrical() ) {
           me.setredinhibit( "electrical" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "feel" ) ).getValue() ) {
       if( me.hydraulicsystem.red_feel() ) {
           me.setredinhibit( "feel" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "ice" ) ).getValue() ) {
       if( me.antiicingsystem.red_ice() ) {
           me.setredinhibit( "ice" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "ins" ) ).getValue() ) {
       if( me.insinstrument.red_ins() ) {
           me.setredinhibit( "ins" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "pfc" ) ).getValue() ) {
       if( me.flightsystem.red_pfc() ) {
           me.setred( "pfc" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "pressure" ) ).getValue() ) {
       if( me.pressuresystem.red_pressure() ) {
           me.setredinhibit( "pressure" );
       }
   }

   if( me.itself["red"].getChild( me.recallpath( "throttle" ) ).getValue() ) {
       if( me.enginesystem.red_throttle() ) {
           me.setredinhibit( "throttle" );
       }
   }
}

Mws.class2_instantiate = func {
   # 4
   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.itself["amber"].getChild( me.recallpath( "intake" ), i ).getValue() ) {
            if( me.enginesystem.amber_intake( i ) ) {
                me.setamber( "intake", i );
            }
        }
   }

   # amber
   if( me.itself["amber"].getChild( me.recallpath( "adc" ) ).getValue() ) {
       if( me.adcinstrument.amber_adc() ) {
           me.setamber( "adc" );
       }
   }

   if( me.itself["amber"].getChild( me.recallpath( "air" ) ).getValue() ) {
       if( me.airbleedsystem.amber_air() ) {
           me.setamber( "air" );
       }
   }

   if( me.itself["amber"].getChild( me.recallpath( "electrical" ) ).getValue() ) {
       if( me.electricalsystem.amber_electrical() ) {
           me.setamber( "electrical" );
       }
   }

   if( me.itself["amber"].getChild( me.recallpath( "fuel" ) ).getValue() ) {
       if( me.fuelsystem.amber_fuel() or me.tankpressuresystem.amber_fuel() ) {
           me.setamber( "fuel" );
       }
   }

   if( me.itself["amber"].getChild( me.recallpath( "hydraulics" ) ).getValue() ) {
       if( me.hydraulicsystem.amber_hydraulics() ) {
           me.setamber( "hydraulics" );
       }
   }
}

Mws.cancel = func {
   me.class1_cancel();
   me.class2_cancel();
}

Mws.class1_cancel = func {
   for( var i = 0; i < me.nbred4s ; i = i+1 ) {
        for( var j = 0; j < constantaero.NBENGINES ; j = j+1 ) {
             me.itself["red"].getChild( me.red4words[i], j ).setValue( constant.FALSE );
        }
   }

   for( var i = 0; i < me.nbreds ; i = i+1 ) {
        me.itself["red"].getChild( me.redwords[i] ).setValue( constant.FALSE );
   }
}

Mws.class2_cancel = func {
   for( var i = 0; i < me.nbamber4s ; i = i+1 ) {
        for( var j = 0; j < constantaero.NBENGINES ; j = j+1 ) {
             me.itself["amber"].getChild( me.amber4words[i], j ).setValue( constant.FALSE );
        }
   }

   for( var i = 0; i < me.nbambers ; i = i+1 ) {
        me.itself["amber"].getChild( me.amberwords[i] ).setValue( constant.FALSE );
   }
}

Mws.recall = func {
   me.class1_recall();
   me.class2_recall();
}

Mws.class1_recall = func {
   for( var i = 0; i < me.nbred4s ; i = i+1 ) {
        for( var j = 0; j < constantaero.NBENGINES ; j = j+1 ) {
             me.itself["red"].getChild( me.recallpath( me.red4words[i] ), j ).setValue( constant.TRUE );
        }
   }

   for( var i = 0; i < me.nbreds ; i = i+1 ) {
        me.itself["red"].getChild( me.recallpath( me.redwords[i] ) ).setValue( constant.TRUE );
   }
}

Mws.class2_recall = func {
   for( var i = 0; i < me.nbamber4s ; i = i+1 ) {
        for( var j = 0; j < constantaero.NBENGINES ; j = j+1 ) {
             me.itself["amber"].getChild( me.recallpath( me.amber4words[i] ), j ).setValue( constant.TRUE );
        }
   }

   for( var i = 0; i < me.nbambers ; i = i+1 ) {
        me.itself["amber"].getChild( me.recallpath( me.amberwords[i] ) ).setValue( constant.TRUE );
   }
}

Mws.class1_check = func {
   var result = constant.FALSE;

   for( var i = 0; i < me.nbred4s ; i = i+1 ) {
        for( var j = 0; j < constantaero.NBENGINES ; j = j+1 ) {
             if( !me.itself["red"].getChild( me.recallpath( me.red4words[i] ), j ).getValue() and
                 me.itself["red"].getChild( me.red4words[i], j ).getValue() ) {
                 result = constant.TRUE;
                 break;
             }
        }
   }

   for( var i = 0; i < me.nbreds ; i = i+1 ) {
        if( !me.itself["red"].getChild( me.recallpath( me.redwords[i] ) ).getValue() and
            me.itself["red"].getChild( me.redwords[i] ).getValue() ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

Mws.class2_check = func {
   var result = constant.FALSE;

   for( var i = 0; i < me.nbambers ; i = i+1 ) {
        if( !me.itself["amber"].getChild( me.recallpath( me.amberwords[i] ) ).getValue() and
            me.itself["amber"].getChild( me.amberwords[i] ).getValue() ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

Mws.setred = func( name, index = 0 ) {
   me.itself["red"].getChild( name, index ).setValue( constant.TRUE );
   me.itself["red"].getChild( me.recallpath( name ), index ).setValue( constant.FALSE );
   me.class1 = constant.TRUE;
}

Mws.setredinhibit = func( name, index = 0 ) {
   if( !me.itself["root-ctrl"].getChild("inhibit").getValue() ) {
       me.setred( name, index );
   }
}

Mws.setamber = func( name, index = 0 ) {
   if( !me.itself["root-ctrl"].getChild("inhibit").getValue() ) {
       me.itself["amber"].getChild( name, index ).setValue( constant.TRUE );
       me.itself["amber"].getChild( me.recallpath( name ), index ).setValue( constant.FALSE );
       me.class2 = constant.TRUE;
   }
}

Mws.recallpath = func( name ) {
   var result = name ~ "-recall";

   return result;
}
