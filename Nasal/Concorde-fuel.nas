# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence


# IMPORTANT : always uses /consumables/fuel/tank[0]/level-gal_us,
# because /level-lbs seems not synchronized with level-gal_us, during the time of a procedure.



# ===============
# FUEL MANAGEMENT
# ===============

Fuel = {};

Fuel.new = func {
   var obj = { parents : [Fuel,System], 

               tanksystem : Tanks.new(),
               parser : FuelXML.new(),
               totalfuelinstrument : TotalFuel.new(),
               fuelconsumedinstrument : FuelConsumed.new(),
               aircraftweightinstrument : AircraftWeight.new(),

               presets : 0,                                                  # saved state

               PUMPSEC : 1.0,

# at Mach 2, trim tank 10 only feeds 2 supply tanks 5 and 7 : 45200 lb/h, or 6.3 lb/s per tank.
               PUMPLBPSEC : 25,                                              # 25 lb/s for 1 pump.

               PUMPPMIN0 : 0.0,                                              # time step
               PUMPPMIN : 0.0,                                               # speed up

               PUMPLB0 : 0.0,                                                # rate for step
               PUMPLB : 0.0,                                                 # speed up

# auto trim limits
               FORWARDKG : 24000,
               AFTKG : 11000,
               EMPTYKG : 0
         };

    obj.init();

    return obj;
}

Fuel.init = func {
    me.inherit_system("/systems/fuel");

    me.PUMPPMIN0 = constant.MINUTETOSECOND / me.PUMPSEC;
    me.PUMPLB0 = me.PUMPLBPSEC * me.PUMPSEC;
    me.PUMPPMIN = me.PUMPPMIN0;
    me.PUMPLB = me.PUMPLB0;

    me.parser.init_FuelXML("/systems/fuel");
    me.tanksystem.init_TankXML();

    me.savestate();
}

Fuel.amber_fuel = func {
   return me.tanksystem.amber_fuel();
}

Fuel.schedule = func {
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       me.PUMPPMIN = me.PUMPPMIN0 / speedup;
       me.PUMPLB = me.PUMPLB0 * speedup;
   }
   else {
       me.PUMPPMIN = me.PUMPPMIN0;
       me.PUMPLB = me.PUMPLB0;
   }

   me.pumping();
}

Fuel.slowschedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       # mechanical valves are supposed
       me.inletvalve();
   }

   me.fuelconsumedinstrument.schedule();
   me.aircraftweightinstrument.schedule();
}

Fuel.menuexport = func {
   var change = me.tanksystem.menu();

   me.savestate();

   me.itself["root"].getChild("reset").setValue( change );
}

Fuel.reinitexport = func {
   # restore for reinit
   me.itself["root"].getChild("presets").setValue( me.presets );

   me.tanksystem.presetfuel();

   me.itself["root"].getChild("reset").setValue( constant.TRUE );

   me.savestate();
}

Fuel.savestate = func {
   # backup for reinit
   me.presets = me.itself["root"].getChild("presets").getValue();
}

Fuel.setweighthuman = func( totalkg ) {
   me.aircraftweightinstrument.setdatum( totalkg );
   me.fuelconsumedinstrument.reset();

   me.itself["root"].getChild("reset").setValue( constant.FALSE );
}

Fuel.inletvalve = func {
   # only 1 valve
   me.computeinletvalve( "5", 0 );
   me.computeinletvalve( "7", 0 );

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        me.computeinletvalve( "9", i );
        me.computeinletvalve( "11", i );
   }
}

Fuel.pumping = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       if( me.dependency["electric"].getChild("specific").getValue() ) {
           # controlled only by inlet valves and fuel pumps :
           # tanks pumping each other is possible !
           me.autotrim();
       }

       me.afttrim();

       me.pumpaft();

       me.jettisonvalve();


       me.hydraulicautotrim();

       me.parser.schedule( me.PUMPLB, me.tanksystem );
   }

   # to synchronized with pumping
   me.totalfuelinstrument.schedule();
}

Fuel.autotrim = func {
   var tank9kg = 0.0;
   var tank10kg = 0.0;
   var level910kg = 0.0;
   var level11kg = 0.0;
   var empty9 = constant.FALSE;
   var empty11 = constant.FALSE;
   var forwardoverride = me.itself["pumps"].getChild("forward-override").getValue();

   if( !me.itself["pumps"].getChild("auto-off").getValue() or forwardoverride ) {
       tank9kg = me.tanksystem.getlevelkg("9");
       tank10kg = me.tanksystem.getlevelkg("10");
       level910kg = tank9kg + tank10kg;
       level11kg = me.tanksystem.getlevelkg("11");

       # forward or emergency override (which ignores the load limits)
       if( me.itself["pumps"].getChild("auto-forward").getValue() or forwardoverride ) {
           if( me.tanksystem.controls( "11", "pump-auto", 0 ).getValue() and
               me.tanksystem.controls( "11", "pump-auto", 1 ).getValue() ) {

               empty11 = me.empty( "11" );

               # stop everything
               if( empty11 or
                   ( level11kg <= me.tanksystem.controls( "11", "limit-kg" ).getValue() and
                     !forwardoverride ) ) {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }

               # 11 to 5 and 7, until limit of 11
               elsif( me.full( "9" ) or
                      ( level910kg >= me.tanksystem.controls( "9", "limit-kg" ).getValue() and
                        !forwardoverride ) ) {
                   if ( me.tanksystem.controls( "5", "inlet-auto" ).getValue() and
                        me.tanksystem.controls( "7", "inlet-auto" ).getValue() ) {
                        me.forwardautopumps( constant.FALSE, constant.FALSE );
                        me.enginehuman( constant.TRUE );
                        me.forwardhuman( constant.TRUE );
                   }
               }

               # 11 to 9 until limit of 9 + 10
               elsif ( me.tanksystem.controls( "9", "inlet-auto", 0 ).getValue() and
                       me.tanksystem.controls( "9", "inlet-auto", 1 ).getValue() ) {
                   me.forwardautopumps( constant.FALSE, constant.FALSE );
                   me.enginehuman( constant.FALSE );
                   me.forwardhuman( constant.TRUE );
               }

               # stop
               else {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }
           }
       }

       # rearward
       else {
           if( me.tanksystem.controls( "9", "pump-auto", 0 ).getValue() and
               me.tanksystem.controls( "9", "pump-auto", 1 ).getValue() and
               me.tanksystem.controls( "10", "pump-auto", 0 ).getValue() and
               me.tanksystem.controls( "10", "pump-auto", 1 ).getValue() ) {

               empty9 = me.empty( "9" );

               # stop everything
               if( ( empty9 and me.empty( "10" ) ) or
                   level910kg <= me.tanksystem.controls( "9", "limit-kg" ).getValue() ) {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }

               # 9 + 10 to 5 and 7, until limit of 9 + 10 
               elsif( me.full( "11" ) or
                      level11kg >= me.tanksystem.controls( "11", "limit-kg" ).getValue() ) {
                   if ( me.tanksystem.controls( "5", "inlet-auto" ).getValue() and
                        me.tanksystem.controls( "7", "inlet-auto" ).getValue() ) {
                        me.forwardautopumps( constant.TRUE, empty9 );
                        me.enginehuman( constant.TRUE );
                        me.afthuman( constant.TRUE );
                   }
               }

               # 9 + 10 to 11 until limit of 11
               elsif ( me.tanksystem.controls( "11", "inlet-auto", 0 ).getValue() and
                       me.tanksystem.controls( "11", "inlet-auto", 1 ).getValue() ) {
                   me.forwardautopumps( constant.TRUE, empty9 );
                   me.enginehuman( constant.FALSE );
                   me.afthuman( constant.TRUE );
               }

               # stop
               else {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }
           }
       }
   }


   # not driven by auto
   else {
       me.stopautopumps();
   }
}

Fuel.stopautopumps = func {
   var status = constant.FALSE;

   # driven by switch
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        status = me.tanksystem.controls( "9", "pump-on", i ).getValue();
        me.tanksystem.controls( "9", "pump", i ).setValue( status );
        status = me.tanksystem.controls( "10", "pump-on", i ).getValue();
        me.tanksystem.controls( "10", "pump", i ).setValue( status );
        status = me.tanksystem.controls( "11", "pump-on", i ).getValue();
        me.tanksystem.controls( "11", "pump", i ).setValue( status );
   }
}

Fuel.forwardautopumps = func( forward, empty9 ) {
   if( forward ) {
       for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
            me.tanksystem.controls( "9", "pump", i ).setValue( !empty9 );
            me.tanksystem.controls( "10", "pump", i ).setValue( empty9 );
            me.tanksystem.controls( "11", "pump", i ).setValue( constant.FALSE );
       }
   }
   else {
       for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
            me.tanksystem.controls( "9", "pump", i ).setValue( constant.FALSE );
            me.tanksystem.controls( "10", "pump", i ).setValue( constant.FALSE );
            me.tanksystem.controls( "11", "pump", i ).setValue( constant.TRUE );
       }
   }
}

Fuel.hydraulicautotrim = func {
   var tank9kg = 0.0;
   var tank10kg = 0.0;
   var level910kg = 0.0;
   var level11kg = 0.0;
   var forwardoverride = me.itself["pumps"].getChild("forward-override").getValue();

   if( !me.itself["pumps"].getChild("auto-off").getValue() or forwardoverride ) {
       tank9kg = me.tanksystem.getlevelkg("9");
       tank10kg = me.tanksystem.getlevelkg("10");
       level910kg = tank9kg + tank10kg;
       level11kg = me.tanksystem.getlevelkg("11");

       # forward or emergency override (which ignores the load limits)
       if( me.itself["pumps"].getChild("auto-forward").getValue() or forwardoverride ) {
           if( me.tanksystem.controls( "11", "pump-blue-auto" ).getValue() and
               me.tanksystem.controls( "11", "pump-green-auto" ).getValue() ) {

               # stop everything
               if( me.empty( "11" ) or
                   ( level11kg <= me.tanksystem.controls( "11", "limit-kg" ).getValue() and
                     !forwardoverride ) ) {
                   me.stophydraulicpumps();
                   me.enginehuman( constant.FALSE );
               }

               # 11 to 5 and 7, until limit of 11
               elsif( me.full( "9" ) or
                      ( level910kg >= me.tanksystem.controls( "9", "limit-kg" ).getValue() and
                        !forwardoverride ) ) {
                   if ( me.tanksystem.controls( "5", "inlet-auto" ).getValue() and
                        me.tanksystem.controls( "7", "inlet-auto" ).getValue() ) {
                        me.starthydraulicpumps();
                        me.enginehuman( constant.TRUE );
                        me.forwardhuman( constant.TRUE );
                   }
               }

               # 11 to 9 until limit of 9 + 10
               elsif ( me.tanksystem.controls( "9", "inlet-auto", 0 ).getValue() and
                       me.tanksystem.controls( "9", "inlet-auto", 1 ).getValue() ) {
                   me.starthydraulicpumps();
                   me.enginehuman( constant.FALSE );
                   me.forwardhuman( constant.TRUE );
               }

               # stop
               else {
                   me.stophydraulicpumps();
                   me.enginehuman( constant.FALSE );
               }
           }
       }
   }


   # not driven by auto
   else {
        me.stophydraulicpumps();
   }
}

Fuel.stophydraulicpumps = func {
   var status = constant.FALSE;

   # driven by switch
   status = me.tanksystem.controls( "11", "pump-green-on" ).getValue();
   me.tanksystem.controls( "11", "pump-green" ).setValue( status );
   status = me.tanksystem.controls( "11", "pump-blue-on" ).getValue();
   me.tanksystem.controls( "11", "pump-blue" ).setValue( status );
}

Fuel.starthydraulicpumps = func {
   me.tanksystem.controls( "11", "pump-green" ).setValue( constant.TRUE );
   me.tanksystem.controls( "11", "pump-blue" ).setValue( constant.TRUE );
}

Fuel.forwardautohuman = func( forward ) {
   if( forward ) {
       me.tanksystem.controls( "9", "limit-kg" ).setValue( me.FORWARDKG );
       me.tanksystem.controls( "11", "limit-kg" ).setValue( me.EMPTYKG );
   }
   else {
       me.tanksystem.controls( "9", "limit-kg" ).setValue( me.EMPTYKG );
       me.tanksystem.controls( "11", "limit-kg" ).setValue( me.AFTKG );
   }

   me.itself["pumps"].getChild("auto-forward").setValue( forward );
   me.itself["pumps"].getChild("auto-off").setValue( constant.FALSE );
   me.itself["pumps"].getChild("auto-guard").setValue( constant.FALSE );

   me.engineautotrim( constant.TRUE );

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        me.tanksystem.controls( "9", "inlet-auto", i ).setValue( forward );
        me.tanksystem.controls( "11", "inlet-auto", i ).setValue( !forward );
        me.tanksystem.controls( "9", "pump-auto", i ).setValue( !forward );
        me.tanksystem.controls( "10", "pump-auto", i ).setValue( !forward );
        me.tanksystem.controls( "11", "pump-auto", i ).setValue( forward );
   }

   me.offhydraulicautotrim();
}

Fuel.engineautotrim = func( set ) {
   # only 1 valve
   me.tanksystem.controls( "5", "inlet-auto" ).setValue( set );
   me.tanksystem.controls( "7", "inlet-auto" ).setValue( set );
}

Fuel.offautohuman = func {
   me.itself["pumps"].getChild("auto-off").setValue( constant.TRUE );
   me.itself["pumps"].getChild("auto-guard").setValue( constant.TRUE );

   me.engineautotrim( constant.FALSE );

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        me.tanksystem.controls( "9", "inlet-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "11", "inlet-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "9", "pump-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "10", "pump-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "11", "pump-auto", i ).setValue( constant.FALSE );
   }

   me.offhydraulicautotrim();
}

Fuel.offhydraulicautotrim = func {
   me.tanksystem.controls( "11", "pump-blue-auto" ).setValue( constant.FALSE );
   me.tanksystem.controls( "11", "pump-green-auto" ).setValue( constant.FALSE );
}

Fuel.shutstandbyhuman = func {
   me.tanksystem.controls( "1", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "2", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "3", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "4", "inlet-standby" ).setValue( constant.FALSE );

   me.tanksystem.controls( "5", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "6", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "7", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "8", "inlet-standby" ).setValue( constant.FALSE );

   me.tanksystem.controls( "10", "inlet-standby" ).setValue( constant.FALSE );
}

Fuel.full = func( tank ) {
   return me.tanksystem.full( tank );
}

Fuel.empty = func( tank ) {
   return me.tanksystem.empty( tank );
}

Fuel.lowlevel = func {
   return me.tanksystem.lowlevel();
}

# set manually the switch
Fuel.pumphuman = func( tank, set ) {
   # for trim tank, auto may also drive the pump
   if( tank == "9" or tank == "10" or tank == "11" ) {
       for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
             me.tanksystem.controls(tank, "pump-on", i).setValue( set );
       }
   }

   else {
       for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
             me.tanksystem.controls(tank, "pump", i).setValue( set );
       }
   }
}

Fuel.transvalvehuman = func( tank, set ) {
   me.tanksystem.controls(tank, "trans-valve").setValue( set );
}

Fuel.toggleinterconnectvalve = func( tank, set ) {
   me.tanksystem.controls(tank, "interconnect-valve").setValue( set );
}

Fuel.togglecrossfeedvalve = func( tank, set ) {
   me.tanksystem.controls(tank, "cross-feed-valve").setValue( set );
}

Fuel.afttrimhuman = func( set ) {
   me.tanksystem.controls("1", "aft-trim").setValue( set );
   me.tanksystem.controls("4", "aft-trim").setValue( set );
}

Fuel.valveforward = func( set, toengine ) {
   me.itself["pumps"].getChild("forward").setValue( set );
   if( !toengine ) {
       for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
            me.toggleinletvalve( "9", i, set );
       }
   }
}

Fuel.valveaft = func( set, toengine ) {
   me.itself["pumps"].getChild("aft").setValue( set);
   if( !toengine ) {
       for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
            me.toggleinletvalve( "11", i, set );
       }
   }
}

Fuel.togglecross = func( set ) {
   me.itself["pumps"].getChild("cross").setValue( set );

   me.toggleinterconnectvalve( "6", set );
   me.toggleinterconnectvalve( "8", set );

   me.togglecrossfeedvalve( "1", set );
   me.togglecrossfeedvalve( "2", set );
   me.togglecrossfeedvalve( "3", set );
   me.togglecrossfeedvalve( "4", set );
}

Fuel.forwardhuman = func( set ) {
   var toengine = me.itself["pumps"].getChild("engine").getValue();

   me.valveforward( set, toengine );
   me.valveaft( constant.FALSE, toengine );
}

Fuel.afthuman = func( set ) {
   var toengine = me.itself["pumps"].getChild("engine").getValue();

   me.valveaft( set, toengine );
   me.valveforward( constant.FALSE, toengine );
}

Fuel.enginehuman = func( set ) {
   me.itself["pumps"].getChild("engine").setValue( set );

   # only 1 valve
   me.toggleinletvalve( "5", 0, set );
   me.toggleinletvalve( "7", 0, set );

   me.aft2Dhuman( constant.FALSE );

   me.valveaft( constant.FALSE, constant.FALSE );
   me.valveforward( constant.FALSE, constant.FALSE );
}

Fuel.aft2Dhuman = func( set ) {
   me.itself["pumps"].getChild("aft-2D").setValue( set );
}

Fuel.toggleinletvalve = func( tank, valve, state ) {
   # - with main selector only
   # - auto is unchanged
   me.tanksystem.controls(tank, "inlet-off", valve).setValue( constant.TRUE );
   me.tanksystem.controls(tank, "inlet-main", valve).setValue( state );
   me.computeinletvalve(tank, valve);
}

# computes the inlet valve from the main and override switches
Fuel.computeinletvalve = func( tank, valve ) {
   var state = constant.FALSE;
   var voltage = me.dependency["electric"].getChild("specific").getValue();

   if( me.tanksystem.controls( tank, "inlet-off", valve ).getValue() ) {
       # gets the switch as set either by :
       # - engineer.
       # - or 2D panel.
       # - or auto trim.
       state = me.tanksystem.controls( tank, "inlet-main", valve ).getValue();

       if( !me.tanksystem.controls( tank, "inlet-auto", valve ).getValue() ) {
           me.tanksystem.controls( tank, "inlet-valve", valve ).setValue( state );
       }

       # auto trim opens and closes device the valve
       elsif( !me.itself["pumps"].getChild("auto-off").getValue() ) {
           me.tanksystem.controls( tank, "inlet-valve", valve ).setValue( state );
       }
   }
   else {
       state = me.tanksystem.controls( tank, "inlet-override", valve ).getValue();
       me.tanksystem.controls( tank, "inlet-valve", valve ).setValue( state );
   }

   # also sets to false, when engineer toggles a switch (valve transit)
   me.tanksystem.controls( tank, "inlet-static", valve ).setValue( voltage );
}

Fuel.crossexport = func {
   var set = me.itself["pumps"].getChild("cross").getValue();

   me.togglecross( !set );
}

Fuel.forwardexport = func {
   var set = me.itself["pumps"].getChild("forward").getValue();

   me.shutstandbyhuman();
   me.offautohuman();

   me.pumphuman( "9", constant.FALSE );
   me.pumphuman( "10", constant.FALSE );
   me.pumphuman( "11", !set );

   me.aft2Dhuman( constant.FALSE );

   me.forwardhuman( !set );
}

Fuel.aftexport = func {
   var set = me.itself["pumps"].getChild("aft").getValue();
   var empty9 = me.empty("9");

   me.shutstandbyhuman();
   me.offautohuman();

   me.pumphuman( "9", !empty9 );
   me.pumphuman( "10", empty9 );
   me.pumphuman( "11", constant.FALSE );

   # will switch to tank 10
   me.aft2Dhuman( !set );

   me.afthuman( !set );
}

Fuel.engineexport = func {
   var set = me.itself["pumps"].getChild("engine").getValue();

   me.enginehuman( !set );
}

Fuel.dumpexport = func {
   var jettison = constant.FALSE;
   var shut = constant.FALSE;

   # avoid parallel updates
   var dump = me.itself["pumps"].getChild("dump").getValue();
   var dump2 = me.itself["pumps"].getChild("dump2").getValue();


   # avoid parallel events
   # 2 buttons for confirmation
   if( dump and dump2 ) {
       jettison = constant.TRUE;
   }

   me.tanksystem.controls("1", "jettison").setValue(jettison);
   me.tanksystem.controls("2", "jettison").setValue(jettison);
   me.tanksystem.controls("3", "jettison").setValue(jettison);
   me.tanksystem.controls("4", "jettison").setValue(jettison);

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        me.itself["jettison"][i].getChild("on").setValue( jettison );
        me.itself["jettison"][i].getChild("shut").setValue( shut );
   }
}

Fuel.pumpaft = func {
   # towards tank 11
   if( !me.full("11") ) {
       # from tank 9
       if( me.empty("9") ) {
           # for 2D panel, switch from tank 9 to tank 10
           if( me.itself["pumps"].getChild("aft-2D").getValue() ) {
               me.pumphuman( "9", constant.FALSE );
               me.pumphuman( "10", constant.TRUE );
           }
       }
   }
}

Fuel.afttrim = func {
   var full1 = constant.TRUE;
   var full4 = constant.TRUE;

   if( me.tanksystem.controls("1", "aft-trim").getValue() ) {
       var tank1lb = me.tanksystem.getlevellb("1");
       if( tank1lb > me.tanksystem.getafttrimlb("1") ) {
           full1 = constant.FALSE; 
       }
   }

   if( me.tanksystem.controls("4", "aft-trim").getValue() ) {
       var tank4lb = me.tanksystem.getlevellb("4");
       if( tank4lb > me.tanksystem.getafttrimlb("4") ) {
           full4 = constant.FALSE; 
       }
   }

   me.tanksystem.controls("1", "aft-trim-disabled").setValue( full1 );
   me.tanksystem.controls("4", "aft-trim-disabled").setValue( full4 );
}

Fuel.jettisonvalve = func {
   var flow = constant.FALSE;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        if( me.itself["jettison"][i].getChild("shut").getValue() or
            !me.itself["jettison"][i].getChild("on").getValue() ) {
            flow = constant.FALSE;
        }

        else {
            flow = constant.TRUE;
        }

        me.itself["jettison"][i].getChild("flow").setValue( flow );
   }
}


# =====
# TANKS
# =====

# adds an indirection to convert the tank name into an array index.

Tanks = {};

Tanks.new = func {
# tank contents, to be initialised from XML
   var obj = { parents : [Tanks,TankXML], 

               CONTENTLB : { "1" : 0.0, "2" : 0.0, "3" : 0.0, "4" : 0.0, "5" : 0.0, "6" : 0.0, "7" : 0.0,
                             "8" : 0.0, "9" : 0.0, "10" : 0.0, "11" : 0.0, "5A" : 0.0, "7A" : 0.0,
                            "LP1" : 0.0, "LP2" : 0.0, "LP3" : 0.0, "LP4" : 0.0 },
               TANKINDEX : { "1" : 0, "2" : 1, "3" : 2, "4" : 3, "5" : 4, "6" : 5, "7" : 6,
                             "8" : 7, "9" : 8, "10" : 9, "11" : 10, "5A" : 11, "7A" : 12,
                            "LP1" : 13, "LP2" : 14, "LP3" : 15, "LP4" : 16 },
               TANKNAME : [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "5A", "7A",
                            "LP1", "LP2", "LP3", "LP4" ],

               OVERFULL : 0.97,
               OVERFULL : 0.97,
               UNDERFULL : 0.8,
               LOWLEVELLB : [ 0.0, 0.0, 0.0, 0.0 ],
               LOWLEVEL : 0.2,

               AFTTRIMLB : { "1" : 0.0, "4" : 0.0 },
               AFTTRIM : 0.4,                                                # aft trim at 40 %

               HPVALVELB : 30.0                                              # fuel low pressure
         };

    obj.init();

    return obj;
}

Tanks.init = func {
    me.inherit_tankXML("/systems/fuel");
}

Tanks.amber_fuel = func {
   var result = constant.FALSE;

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.tankspath[i].getChild("level-lbs").getValue() <= me.LOWLEVELLB[i] ) {
            result = constant.TRUE;
            break;
        }
   }

   if( !result ) {
       # LP valve
       for( var i = 13; i <= 16; i = i+1 ) {
            if( me.tankspath[i].getChild("level-lbs").getValue() <= me.HPVALVELB ) {
                result = constant.TRUE;
                break;
            }
       }
   }

   return result;
}

# fuel initialization
Tanks.initcontent = func {
   me.inherit_initcontent();

   me.AFTTRIMLB["1"] = me.CONTENTLB["1"] * me.AFTTRIM;
   me.AFTTRIMLB["4"] = me.CONTENTLB["4"] * me.AFTTRIM;

   for( var i=0; i < constantaero.NBENGINES; i=i+1 ) {
       me.LOWLEVELLB[i] = me.CONTENTLB[me.TANKNAME[i]] * me.LOWLEVEL;
   }
}

# tank initialization
Tanks.inittank = func( no, contentlb, overfull, underfull, lowlevel ) {
   var valuelb = 0.0;

   me.inherit_inittank( no, contentlb );

   # optional :  must be created by XML
   if( overfull ) {
       valuelb = contentlb * me.OVERFULL;
       me.tankspath[no].getChild("over-full-lb").setValue( valuelb );
   }
   if( underfull ) {
       valuelb = contentlb * me.UNDERFULL;
       me.tankspath[no].getChild("under-full-lb").setValue( valuelb );
   }
   if( lowlevel ) {
       me.tankspath[no].getChild("low-level-lbs").setValue( me.LOWLEVELLB[no] );
   }
}

Tanks.initinstrument = func {
   var overfull = constant.FALSE;
   var underfull = constant.FALSE;
   var lowlevel = constant.FALSE;

   for( var i=0; i < me.nb_tanks; i=i+1 ) {
        overfull = constant.FALSE;
        underfull = constant.FALSE;
        lowlevel = constant.FALSE;

        if( ( i >= me.TANKINDEX["1"] and i <= me.TANKINDEX["4"] ) or
            i == me.TANKINDEX["5"] or i == me.TANKINDEX["7"] or
            i == me.TANKINDEX["9"] or i == me.TANKINDEX["11"] ) {
            overfull = constant.TRUE;
        }
        if( i >= me.TANKINDEX["1"] and i <= me.TANKINDEX["4"] ) {
            underfull = constant.TRUE;
        }
        if( i >= me.TANKINDEX["1"] and i <= me.TANKINDEX["4"] ) {
            lowlevel = constant.TRUE;
        }

        me.inittank( i,  me.CONTENTLB[me.TANKNAME[i]],  overfull,  underfull,  lowlevel );
   }
}

Tanks.getafttrimlb = func( name ) {
   return me.AFTTRIMLB[name];
}

Tanks.lowlevel = func {
   var result = constant.FALSE;

   for( var i=0; i < constantaero.NBENGINES; i=i+1 ) {
      levellb = me.pumpsystem.getlevellb( i ); 
      if( levellb < me.LOWLEVELLB[i] ) {
          result = constant.TRUE;
          break;
      }
   }

   return result;
}


# ===================
# TANK PRESSURIZATION
# ===================

Pressurizetank = {};

Pressurizetank.new = func {
   var obj = { parents : [Pressurizetank,System],

               diffpressure : TankPressure.new(),

               TANKSEC : 30.0,                          # refresh rate
               PRESSURIZEINHG : 9.73,                   # 28000 ft
               MAXPSI : 1.5,
               MINPSI : 0.0
         };

   obj.init();

   return obj;
};

Pressurizetank.init = func {
    me.inherit_system("/systems/tank");

    me.diffpressure.set_rate( me.TANKSEC );
}

Pressurizetank.amber_fuel = func {
    return me.diffpressure.amber_fuel();
}

# tank pressurization
Pressurizetank.schedule = func {
    var atmosinhg = 0.0;
    var tankinhg = 0.0;
    var pressurepsi = 0.0;

    if( me.dependency["electric"].getChild("specific").getValue() ) {
        if( me.itself["root"].getChild("serviceable").getValue() and
            me.dependency["air"].getChild("pressurization").getValue() ) {
            atmosinhg = me.dependency["static-port"].getValue();

            # pressurize above 28000 ft (this is a guess)
            if( atmosinhg < me.PRESSURIZEINHG ) {
                pressurepsi = me.MAXPSI;
            }  
            else {
                pressurepsi = me.MINPSI;
            }

            tankinhg = atmosinhg + pressurepsi * constant.PSITOINHG;

            me.itself["root"].getChild("pressure-inhg").setValue(tankinhg);
        }
    }

    me.diffpressure.schedule();
}


# ==========================
# TANK DIFFERENTIAL PRESSURE
# ==========================

TankPressure = {};

TankPressure.new = func {
   var obj = { parents : [TankPressure,System],

               TANKSEC : 30.0,                         # refresh rate

# energy provided by differential pressure
               HIGHPSI : 4.0,
               RAISINGPSI : 1.5,
               FALLINGPSI : -0.8,
               LOWPSI : -1.75
         };

   obj.init();

   return obj;
};

TankPressure.init = func {
    me.inherit_system("/instrumentation/tank-pressure");
}

TankPressure.set_rate = func( rates ) {
    me.TANKSEC = rates;
}

TankPressure.amber_fuel = func {
    var result = constant.FALSE;
    var diffpsi = me.itself["root"].getChild("differential-psi").getValue();
    var falling = me.itself["root"].getChild("falling").getValue();
    var raising = me.itself["root"].getChild("raising").getValue();

    if( diffpsi < me.LOWPSI or diffpsi > me.HIGHPSI or
        ( diffpsi < me.FALLINGPSI and falling ) or
        ( diffpsi > me.RAISINGPSI and raising ) ) {
        result = constant.TRUE;
    }

    return result;
}

TankPressure.schedule = func {
    var raising = constant.FALSE;
    var falling = constant.FALSE;

    var atmosinhg = me.dependency["static-port"].getValue();
    var tankinhg = me.dependency["tank"].getValue();
    var diffpsi = ( tankinhg - atmosinhg ) * constant.INHGTOPSI; 

    if( diffpsi > 0.0 ) {
        raising = constant.TRUE;
        falling = constant.FALSE;
    }
    elsif( diffpsi < 0.0 ) {
        falling = constant.TRUE;
        raising = constant.FALSE;
    }

    me.itself["root"].getChild("raising").setValue(raising);
    me.itself["root"].getChild("falling").setValue(falling);

    interpolate(me.itself["root"].getChild("differential-psi").getPath(),diffpsi,me.TANKSEC);
}


# ==========
# TOTAL FUEL
# ==========
TotalFuel = {};

TotalFuel.new = func {
   var obj = { parents : [TotalFuel,System],

               STEPSEC : 1.0,                     # 3 s would be enough, but needs 1 s for kg/h

               nb_tanks : 0
         };

   obj.init();

   return obj;
};

TotalFuel.init = func {
   me.inherit_system("/instrumentation/fuel");

   me.nb_tanks = size(me.dependency["tank"]);
}

# total of fuel in kg
TotalFuel.schedule = func {
   var fuelgalus = 0.0;

   # last total
   var tanksgalus = me.itself["root"].getChild("total-gal_us").getValue();
   var tankskg = tanksgalus * constant.GALUSTOKG;


   for(var i=0; i<me.nb_tanks; i=i+1) {
       fuelgalus = fuelgalus + me.dependency["tank"][i].getChild("level-gal_us").getValue();
   }
   # not real
   me.itself["root"].getChild("total-gal_us").setValue(fuelgalus);


   # real
   var fuelkg = fuelgalus * constant.GALUSTOKG;


   # ======================================================================
   # - MUST BE CONSTANT with speed up : pumping is accelerated.
   # - not real, used to check errors in pumping.
   # - JSBSim consumes more with speed up, at the same indicated fuel flow.
   # ======================================================================
   var stepkg = tankskg - fuelkg;
   var fuelkgpmin = stepkg * constant.MINUTETOSECOND / ( me.STEPSEC );
   var fuelkgph = fuelkgpmin * constant.HOURTOMINUTE;

   # not real
   me.itself["root"].getChild("fuel-flow-kg_ph").setValue(int(math.round(fuelkgph)));
}


# =============
# FUEL CONSUMED
# =============
FuelConsumed = {};

FuelConsumed.new = func {
   var obj = { parents : [FuelConsumed,System],

               STEPSEC : 3.0,
 
               RESETKG : 0
         };

   obj.init();

   return obj;
};

FuelConsumed.init = func {
   me.inherit_system("/instrumentation", "fuel-consumed");
}

FuelConsumed.schedule = func {
   me.reset();
   me.compute();
}

FuelConsumed.compute = func {
   var resetkg = 0.0;
   var usedkg = 0.0;
   var totalkg = 0.0;
   var usedlb = 0.0;

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        resetkg = me.itself["root"][i].getChild("reset-kg").getValue();
        
        usedlb = me.dependency["propulsion"][i].getChild("fuel-used-lbs").getValue();
        usedkg = usedlb * constant.LBTOKG;

        totalkg = usedkg - resetkg;
        me.itself["root"][i].getChild("total-kg").setValue( totalkg );
   }
   
   me.reset();
}

FuelConsumed.reset = func {
   var usedkg = 0.0;
   var usedlb = 0.0;
   
   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.itself["root"][i].getChild("reset").getValue() ) {
            me.itself["root"][i].getChild("total-kg").setValue( me.RESETKG );
        
            usedlb = me.dependency["propulsion"][i].getChild("fuel-used-lbs").getValue();
            usedkg = usedlb * constant.LBTOKG;
            me.itself["root"][i].getChild("reset-kg").setValue( usedkg );
        
            me.itself["root"][i].getChild("reset").setValue( constant.FALSE );
        }
   }
}


# ===============
# AIRCRAFT WEIGHT
# ===============
AircraftWeight = {};

AircraftWeight.new = func {
   var obj = { parents : [AircraftWeight,System],

               clear : constant.TRUE,

               weightdatumlb : 0.0,

               NOFUELKG : -9999,

               fueldatumkg : 0.0
         };

   obj.init();

   return obj;
};

AircraftWeight.init = func {
   me.inherit_system("/instrumentation/ac-weight");
}

AircraftWeight.schedule = func {
   var consumedkg = 0.0;
   var fuelkg = 0.0;
   var weightlb = 0.0;

   # set manually by engineer
   me.fueldatumkg = me.itself["root"].getChild("fuel-datum-kg").getValue();
   me.weightdatumlb = me.itself["root"].getChild("weight-datum-lb").getValue();

   # substract fuel flow consumed from the manually set datum,
   # to cross check with fuel gauge reading (leaks)
   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        consumedkg = consumedkg + me.dependency["fuel-consumed"][i].getChild("total-kg").getValue();
   }

   fuelkg = me.fueldatumkg - consumedkg;
   me.itself["root"].getChild("fuel-remaining-kg").setValue( fuelkg );

   # add the remaining fuel to the manually set datum
   me.setweightdatum();
   if( !me.clear ) {
       weightlb = me.weightdatumlb + ( fuelkg * constant.KGTOLB );
       me.itself["root"].getChild("weight-lb").setValue( weightlb );
   }
}

AircraftWeight.setdatum = func( fuelkg ) {
   me.fueldatumkg = fuelkg;
   me.itself["root"].getChild("fuel-datum-kg").setValue( me.fueldatumkg );

   # compute weight datum at the next iteration, once FDM is refreshed with the fuel
   me.clear = constant.TRUE;

   # feedback for display
   me.itself["root"].getChild("fuel-remaining-kg").setValue( me.NOFUELKG );
}

# TODO : replace by manual input (engineer)
AircraftWeight.setweightdatum = func {
   if( me.clear ) {
       me.weightdatumlb = me.itself["root"].getChild("weight-real-lb").getValue();
       
       # substract fuel datum
       if( me.weightdatumlb != nil ) {
           if( me.weightdatumlb > 0.0 ) {
               me.weightdatumlb = me.weightdatumlb - ( me.fueldatumkg * constant.KGTOLB );
               me.itself["root"].getChild("weight-datum-lb").setValue( me.weightdatumlb );
               me.clear = constant.FALSE;
           }
       }
   }
}
