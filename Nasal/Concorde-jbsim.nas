# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - too many operations on 1 line.
# - variable with hyphen (?).



# =================
# OVERRIDING JSBSIM
# =================

ConcordeJSBsim = {};

ConcordeJSBsim.new = func {
   var obj = { parents : [ConcordeJSBsim,System]
         };

   obj.init();

   return obj;
}

ConcordeJSBsim.init = func {
   me.inherit_system("/systems/flight");
}

ConcordeJSBsim.specific = func {
   # disable JSBSim stand alone mode
   for( var i=0; i < constantaero.NBENGINES; i=i+1 ) {
        me.itself["tank"][i].getChild("priority").setValue( 0 );
   }
}


# ==============
# INITIALIZATION
# ==============

ConcordeMain = {};

ConcordeMain.new = func {
   var obj = { parents : [ConcordeMain]
         };

   obj.init();

   return obj;
}

# ----------------------
# The possible relations :
# ----------------------

# - pumpsystem : Pump.new(),
#   inside another system / instrument, to synchronize the objects.

# - me.electricalsystem = electrical;
#   local pointer to the global object, to call its nasal code.

# - <dependency>/systems/electrical</dependency>
#   tag in the instrumentation / system initialization, to read the properties.

# - <static-port>/systems/static</static-port>
#   tag in the instrumentation file, to customize a C++ instrument.

# - <noinstrument>/position/altitude-agl-ft</noinstrument>.
#   no relation to an instrument / system failure.

ConcordeMain.putinrelation = func {
   autopilotsystem.set_relation( autothrottlesystem );
   MWSsystem.set_relation( ADCinstrument, CGinstrument, INSinstrument,
                           airbleedsystem, electricalsystem, enginesystem,
                           flightsystem, fuelsystem, hydraulicsystem, antiicingsystem,
                           pressuresystem, tankpressuresystem );

   wiperinstrument.set_relation( noseinstrument );

   copilotcrew.set_relation( airbleedsystem, autopilotsystem, electricalsystem, flightsystem,
                             hydraulicsystem, lightingsystem, MWSsystem, voicecrew );
   engineercrew.set_relation( airbleedsystem, autopilotsystem, electricalsystem, enginesystem,
                              fuelsystem, hydraulicsystem, lightingsystem, voicecrew );
   voicecrew.set_relation( autopilotsystem );

   engineerhuman.set_relation( seatsystem );
}

ConcordeMain.synchronize = func {
   electricalsystem.set_rate( fuelsystem.PUMPSEC );
   hydraulicsystem.set_rate( fuelsystem.PUMPSEC );
   airbleedsystem.set_rate( fuelsystem.PUMPSEC );
   enginesystem.set_rate( fuelsystem.PUMPSEC );
}

ConcordeMain.startupcron = func {
   if( getprop( "/controls/crew/startup" ) ) {
       copilotcrew.toggleexport();
       copilothuman.wakeupexport();
       engineercrew.toggleexport();
       engineerhuman.wakeupexport();
       crewscreen.toggleexport();
       voicecrew.toggleexport();
   }
}

# 1 seconds cron (only, to spare frame rate)
ConcordeMain.sec1cron = func {
   electricalsystem.schedule();
   hydraulicsystem.schedule();
   fuelsystem.schedule();
   airbleedsystem.schedule();
   enginesystem.schedule();
   GPWSsystem.schedule();
   lightingsystem.schedule();
   ADCinstrument.schedule();
   altimeterinstrument.schedule();
   IASinstrument.schedule();
   VSIinstrument.schedule();
   machinstrument.schedule();
   AOAinstrument.schedule();
   wiperinstrument.schedule();
   daytimeinstrument.schedule();

   # schedule the next call
   settimer(func { me.sec1cron(); },fuelsystem.PUMPSEC);
}

# 3 seconds cron
ConcordeMain.sec3cron = func {
   autopilotsystem.schedule();
   autothrottlesystem.schedule();
   MWSsystem.schedule();
   flightsystem.schedule();
   fuelsystem.slowschedule();
   antiicingsystem.schedule();
   INSinstrument.schedule();
   Compassinstrument.schedule();
   crewscreen.schedule();

   # schedule the next call
   settimer(func { me.sec3cron(); },autopilotsystem.AUTOPILOTSEC);
}

# 5 seconds cron
ConcordeMain.sec5cron = func {
   CGinstrument.schedule();
   standbyIASinstrument.schedule();
   autopilotsystem.slowschedule();
   autothrottlesystem.slowschedule();
   pressuresystem.schedule();
   enginesystem.slowschedule();
   copilotcrew.fastschedule();
   copilothuman.schedule();
   engineerhuman.schedule();
   tractorexternal.schedule();

   # schedule the next call
   settimer(func { me.sec5cron(); },pressuresystem.PRESSURIZESEC);
}

# 10 seconds cron
ConcordeMain.sec10cron = func {
   MWSsystem.slowschedule();

   # schedule the next call
   settimer(func { me.sec10cron(); },MWSsystem.AUXILIARYSEC);
}

# 15 seconds cron
ConcordeMain.sec15cron = func {
   TMOinstrument.schedule();
   GPWSsystem.slowschedule();
   engineerhuman.slowschedule();

   # schedule the next call
   settimer(func { me.sec15cron(); },15);
}

# 30 seconds cron
ConcordeMain.sec30cron = func {
   tankpressuresystem.schedule();

   # schedule the next call
   settimer(func { me.sec30cron(); },tankpressuresystem.TANKSEC);
}

# 60 seconds cron
ConcordeMain.sec60cron = func {
   electricalsystem.slowschedule();
   airbleedsystem.slowschedule();
   antiicingsystem.slowschedule();
   copilotcrew.slowschedule();
   engineercrew.veryslowschedule();

   # schedule the next call
   settimer(func { me.sec60cron(); },60);
}

ConcordeMain.savedata = func {
   var saved_props = [ "/controls/adc/ivsi-in-cruise",
                       "/controls/adc/system[0]/ivsi-emulated",
                       "/controls/adc/system[1]/ivsi-emulated",
                       "/controls/anti-ice/icing-model/duration/few-min",
                       "/controls/anti-ice/icing-model/duration/scattered-min",
                       "/controls/anti-ice/icing-model/duration/broken-min",
                       "/controls/anti-ice/icing-model/duration/overcast-min",
                       "/controls/anti-ice/icing-model/duration/clear-min",
                       "/controls/anti-ice/icing-model/temperature/max-degc",
                       "/controls/anti-ice/icing-model/temperature/min-degc",
                       "/controls/autoflight/fg-waypoint",
                       "/controls/autoflight/real-nav",
                       "/controls/captain/countdown",
                       "/controls/crew/captain-busy",
                       "/controls/crew/checklist",
                       "/controls/crew/ins-alignment",
                       "/controls/crew/landing-lights",
                       "/controls/crew/night-lighting",
                       "/controls/crew/presets",
                       "/controls/crew/radio",
                       "/controls/crew/startup",
                       "/controls/crew/stop-engine23",
                       "/controls/crew/timeout",
                       "/controls/crew/timeout-s",
                       "/controls/environment/als/lights",
                       "/controls/environment/rain",
                       "/controls/environment/smoke",
                       "/controls/human/destination/category/diversion",
                       "/controls/human/destination/category/everything",
                       "/controls/human/destination/category/historical",
                       "/controls/human/destination/category/other",
                       "/controls/human/destination/category/regular",
                       "/controls/human/destination/filter/navaid",
                       "/controls/human/destination/filter/range",
                       "/controls/human/destination/show",
                       "/controls/human/destination/sort/distance",
                       "/controls/human/destination/sort/ident",
                       "/controls/human/destination/sort/name",
                       "/controls/fuel/reinit",
                       "/controls/tractor/distance-m",
                       "/controls/seat/recover",
                       "/controls/seat/yoke",
                       "/controls/voice/sound",
                       "/controls/voice/text",
                       "/sim/user/callsign",
                       "/systems/flight/presets",
                       "/systems/fuel/presets",
                       "/systems/human/serviceable",
                       "/systems/seat/position/gear-front/x-m",
                       "/systems/seat/position/gear-front/y-m",
                       "/systems/seat/position/gear-front/z-m",
                       "/systems/seat/position/gear-main/x-m",
                       "/systems/seat/position/gear-main/y-m",
                       "/systems/seat/position/gear-main/z-m",
                       "/systems/seat/position/observer/x-m",
                       "/systems/seat/position/observer/y-m",
                       "/systems/seat/position/observer/z-m",
                       "/systems/seat/position/observer2/x-m",
                       "/systems/seat/position/observer2/y-m",
                       "/systems/seat/position/observer2/z-m",
                       "/systems/seat/position/steward/x-m",
                       "/systems/seat/position/steward/y-m",
                       "/systems/seat/position/steward/z-m" ];

   for( var i = 0; i < size(saved_props); i = i + 1 ) {
        aircraft.data.add(saved_props[i]);
   }
}

# global variables in Concorde namespace, for call by XML
ConcordeMain.instantiate = func {
   globals.Concorde.constant = Concorde.Constant.new();
   globals.Concorde.constantaero = Concorde.Constantaero.new();
   globals.Concorde.constantISA = Concorde.ConstantISA.new();
   globals.Concorde.FDM = Concorde.ConcordeJSBsim.new();

   globals.Concorde.electricalsystem = Concorde.Electrical.new();
   globals.Concorde.hydraulicsystem = Concorde.Hydraulic.new();
   globals.Concorde.flightsystem = Concorde.Flight.new();
   globals.Concorde.airbleedsystem = Concorde.Airbleed.new();
   globals.Concorde.pressuresystem = Concorde.Pressurization.new();
   globals.Concorde.antiicingsystem = Concorde.Antiicing.new();
   globals.Concorde.fuelsystem = Concorde.Fuel.new();
   globals.Concorde.tankpressuresystem = Concorde.Pressurizetank.new();
   globals.Concorde.autopilotsystem = Concorde.Autopilot.new();
   globals.Concorde.autothrottlesystem = Concorde.Autothrottle.new();
   globals.Concorde.GPWSsystem = Concorde.Gpws.new();
   globals.Concorde.MWSsystem = Concorde.Mws.new();
   globals.Concorde.enginesystem = Concorde.Engine.new();
   globals.Concorde.lightingsystem = Concorde.Lighting.new();
   globals.Concorde.gearsystem = Concorde.Gear.new();

   globals.Concorde.CGinstrument = Concorde.Centergravity.new();
   globals.Concorde.machinstrument = Concorde.Machmeter.new();
   globals.Concorde.TMOinstrument = Concorde.Temperature.new();
   globals.Concorde.ADCinstrument = Concorde.AirDataComputer.new();
   globals.Concorde.altimeterinstrument = Concorde.Altimeter.new();
   globals.Concorde.IASinstrument = Concorde.Airspeed.new();
   globals.Concorde.standbyIASinstrument = Concorde.StandbyAirspeed.new();
   globals.Concorde.VSIinstrument = Concorde.VerticalSpeed.new();
   globals.Concorde.AOAinstrument = Concorde.AccelerometerAOA.new();
   globals.Concorde.INSinstrument = Concorde.Inertial.new();
   globals.Concorde.Compassinstrument = Concorde.Compass.new();
   globals.Concorde.HSIinstrument = Concorde.HSI.new();
   globals.Concorde.transponderinstrument = Concorde.Transponder.new();
   globals.Concorde.wiperinstrument = Concorde.Wiper.new();
   globals.Concorde.noseinstrument = Concorde.NoseVisor.new();
   globals.Concorde.markerinstrument = Concorde.Markerbeacon.new();
   globals.Concorde.daytimeinstrument = Concorde.Daytime.new();
   globals.Concorde.genericinstrument = Concorde.Generic.new();

   globals.Concorde.doorsystem = Concorde.Doors.new();
   globals.Concorde.seatsystem = Concorde.Seats.new();

   globals.Concorde.menuscreen = Menu.new();
   globals.Concorde.crewscreen = Crewbox.new();

   globals.Concorde.copilotcrew = Concorde.Virtualcopilot.new();
   globals.Concorde.engineercrew = Concorde.Virtualengineer.new();
   globals.Concorde.voicecrew = Concorde.Voice.new();

   globals.Concorde.copilothuman = Concorde.Copilothuman.new();
   globals.Concorde.engineerhuman = Concorde.Engineerhuman.new();

   globals.Concorde.tractorexternal = Concorde.Tractor.new();
}

# general initialization
ConcordeMain.init = func {
   aircraft.livery.init( "Aircraft/Concorde/Models/Liveries",
                         "sim/model/livery/name",
                         "sim/model/livery/index" );

   me.instantiate();
   me.putinrelation();
   me.synchronize();

   # JSBSim specific
   globals.Concorde.FDM.specific();

   # schedule the 1st call
   settimer(func { me.sec1cron(); },0);
   settimer(func { me.sec3cron(); },0);
   settimer(func { me.sec5cron(); },0);
   settimer(func { me.sec10cron(); },0);
   settimer(func { me.sec15cron(); },0);
   settimer(func { me.sec30cron(); },0);
   settimer(func { me.sec60cron(); },0);

   # saved on exit, restored at launch
   me.savedata();

   # waits that systems are ready
   settimer(func { me.startupcron(); },2.0);

   # the 3D is soon visible
   print("concorde systems started, version ", getprop("/sim/aircraft-version"));
}

# state reset
ConcordeMain.reinit = func {
   if( getprop("/controls/fuel/reinit") ) {
       # default is JSBSim state, which loses fuel selection.
       globals.Concorde.fuelsystem.reinitexport();
   }
}

# object creation
concordeL  = setlistener("/sim/signals/fdm-initialized", func { globals.Concorde.main = ConcordeMain.new(); removelistener(concordeL); });

# state reset
concordeL2 = setlistener("/sim/signals/reinit", func { globals.Concorde.main.reinit(); });
