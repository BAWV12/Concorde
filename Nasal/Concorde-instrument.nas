# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ===
# VMO
# ===

VMO = {};

VMO.new = func {
   var obj = { parents : [VMO],

               Talt105ft : [ 0, 4500, 6000, 34500, 43000, 44000, 51000, 60000 ],
               Talt165ft : [ 0, 4000, 6000, 32000, 43000, 44000, 51000, 60000 ],
               Tspeed105kt : [ 300, 385, 390, 390, 520, 530, 530, 430 ],
               Tspeed165kt : [ 300, 395, 400, 400, 520, 530, 530, 430 ],

               CEILING : 7,
               UNDERSEA : 0,

               weightlb : 0.0,

# lowest CG
               find0 : constant.FALSE,
               vminkt0 : 0.0,
               vmaxkt0 : 0.0,
               altminft0 : 0.0,
               altmaxft0 : 0.0,
               vmokt0 : 0.0,
# CG
               find : constant.FALSE,
               vminkt : 0.0,
               vmaxkt : 0.0,
               altminft : 0.0,
               altmaxft : 0.0,
               vmokt : 0.0
         };

   obj.init();

   return obj;
};

VMO.init = func {
}

VMO.getvmokt = func( altitudeft, acweightlb ) {
   me.weightlb = acweightlb;

   me.speed105t( altitudeft );
   me.speed165t( altitudeft );

   var vmokt0 = me.interpolatealtitude0( altitudeft );
   var vmokt = me.interpolatealtitude( altitudeft );

   # interpolate between 105 and 165 t
   vmokt = constantaero.interpolateweight( me.weightlb, vmokt, vmokt0 );

   return vmokt;
}  

VMO.interpolatealtitude0 = func( altitudeft ) {
   var vmokt = constantaero.interpolate( me.find0, me.vmokt0, me.vmaxkt0, me.vminkt0,
                                         me.altmaxft0, me.altminft0, altitudeft );

   return vmokt;
}

VMO.interpolatealtitude = func( altitudeft ) {
   var vmokt = constantaero.interpolate( me.find, me.vmokt, me.vmaxkt, me.vminkt,
                                         me.altmaxft, me.altminft, altitudeft );

   return vmokt;
}

# below 105 t
VMO.speed105t = func( altitudeft ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( me.weightlb ) ) {
       me.find0 = constant.TRUE;

       # at startup, altitude may be negativ
       if( altitudeft <= me.Talt105ft[me.UNDERSEA] ) {
           me.find0 = constant.FALSE;
           me.vmokt0 = me.Tspeed105kt[me.UNDERSEA];
       }

       elsif( altitudeft > me.Talt105ft[me.CEILING] ) {
           me.find0 = constant.FALSE;
           me.vmokt0 = me.Tspeed105kt[me.CEILING];
       }

       else {
           var j = 0;

           for( var i = 0; i < me.CEILING; i = i+1 ) {
                j = i+1;

                if( altitudeft > me.Talt105ft[i] and altitudeft <= me.Talt105ft[j] ) {
                    me.vminkt0 = me.Tspeed105kt[i];
                    me.vmaxkt0 = me.Tspeed105kt[j];
                    me.altminft0 = me.Talt105ft[i];
                    me.altmaxft0 = me.Talt105ft[j];

                    break;
                }
           }
       }
   }
}

# above 165 t
VMO.speed165t = func( altitudeft ) {
   me.find = constant.FALSE;

   if( !constantaero.weight_below( me.weightlb ) ) {
       me.find  = constant.TRUE;

       # at startup, altitude may be negativ
       if( altitudeft <= me.Talt165ft[me.UNDERSEA] ) {
           me.find = constant.FALSE;
           me.vmokt = me.Tspeed165kt[me.UNDERSEA];
       }

       elsif( altitudeft > me.Talt165ft[me.CEILING] ) {
           me.find = constant.FALSE;
           me.vmokt = me.Tspeed165kt[me.CEILING];
       }

       else {
           var j = 0;

           for( var i = 0; i < me.CEILING; i = i+1 ) {
                j = i+1;

                if( altitudeft > me.Talt165ft[i] and altitudeft <= me.Talt165ft[j] ) {
                    me.vminkt = me.Tspeed165kt[i];
                    me.vmaxkt = me.Tspeed165kt[j];
                    me.altminft = me.Talt165ft[i];
                    me.altmaxft = me.Talt165ft[j];

                    break;
                }
           }
       }
   }
}


# =================
# AIR DATA COMPUTER
# =================

AirDataComputer = {};

AirDataComputer.new = func {
   var obj = { parents : [AirDataComputer,System],

               vmo : VMO.new(),

               MAXMMO : 2.04,

               GROUNDKT : 50,

               ivsi_instrument : [ constant.TRUE, constant.TRUE ],
               ivsi_status : [ constant.TRUE, constant.TRUE ],

               last_status : [ constant.TRUE, constant.TRUE ]
             };

   obj.init();

   return obj;
};

AirDataComputer.init = func {
   me.inherit_system("/instrumentation","adc");
}

AirDataComputer.amber_adc = func {
    var result = constant.FALSE;

    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         if( me.itself["root"][i].getChild("fault").getValue() ) {
             result = constant.TRUE;
             break;
         }
    }

    return result;
}

AirDataComputer.red_ads = func {
    var result = constant.FALSE;

    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         if( !me.itself["root"][i].getChild("data").getValue() ) {
             result = constant.TRUE;
             break;
         }
    }

    return result;
}

AirDataComputer.schedule = func {
    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         me.failure( i );
         me.ivsisensor( i );
    }

    me.computer();
}

AirDataComputer.computer = func {
   var altitudeft = 0.0;
   var vmokt = 0.0;
   var soundkt = 0.0;
   var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
   var child = nil;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        # ADC computes with its sensors
        child = me.itself["root"][i].getNode("output");

        altitudeft = child.getChild("altitude-ft").getValue();
           
        # maximum operating speed (kt)
        vmokt = me.vmo.getvmokt( altitudeft, weightlb ) ;

        # maximum operating speed (Mach)
        soundkt = me.getsoundkt( child );

       # mach number
       var mmomach = vmokt / soundkt;

       # MMO Mach 2.04
       if( mmomach > me.MAXMMO ) {
           mmomach = me.MAXMMO;
       }
       # always mach number (= makes the consumption constant)
       elsif( altitudeft >= constantaero.MAXCRUISEFT ) {
           mmomach = me.MAXMMO;
           vmokt = mmomach * soundkt;
       }


       if( me.itself["root"][i].getChild("serviceable").getValue() and
           me.itself["adc-sys"][i].getChild("switch").getValue() ) {
           child.getChild("vmo-kt").setValue(vmokt);
           child.getChild("mmo-mach").setValue(mmomach);
       }
   }
}  

AirDataComputer.failure = func( index ) {
    var fault = constant.FALSE;
    var serviceable = me.itself["root"][index].getChild("serviceable").getValue();

    # instrument failure
    if( !serviceable ) {
        fault = constant.TRUE;
    }

    # power failure
    if( !me.dependency["electric"].getChild("specific").getValue() ) {
        serviceable = constant.FALSE;
        fault = constant.TRUE;
    }

    # isolation disables warnings
    if( !me.itself["adc-sys"][index].getChild("switch").getValue() ) {
        serviceable = constant.FALSE;
    }

    if( serviceable != me.last_status[index] ) {
        me.last_status[index] = serviceable;

        # failure is caused by sensor
        me.noinstrument["altimeter"][index].getChild("serviceable").setValue( serviceable );
        me.noinstrument["asi"][index].getChild("serviceable").setValue( serviceable );
        me.noinstrument["ivsi"][index].getChild("serviceable").setValue( serviceable );

        var child = me.itself["root"][index].getNode("output");

        me.failuresensor( child, serviceable, "alpha", "alpha-deg", "alpha-failure-deg" );
        me.failuresensor( child, serviceable, "beta", "beta-deg", "beta-failure-deg" );
        me.failuresensor( child, serviceable, "mach", "mach", "mach-failure" );
        me.failuresensor( child, serviceable, "temperature", "static-degc", "static-failure-degc" );
        me.failuresensor( child, serviceable, "tat", "tmo-degc", "tmo-failure-degc" );

        # data status
        me.itself["root"][index].getChild("data").setValue( serviceable );
    }

    # fault status
    me.itself["root"][index].getChild("fault").setValue( fault );
}

AirDataComputer.failuresensor = func( child, serviceable, sensor, output, alternate ) {
    var path = "";
    var indication = nil;

    if( serviceable ) {
        indication = me.noinstrument[sensor];
    }
    else {
        # blocked on last measure
        indication = child.getNode(alternate);
        indication.setValue( me.noinstrument[sensor].getValue() );
    }            

    path = child.getNode(output).getAliasTarget().getPath();
    if( path != indication ) {
        child.getNode(output).unalias();
        child.getNode(output).alias( indication );
    }
}

AirDataComputer.ivsisensor = func( index ) {
    var change = constant.FALSE;
    var path = "";
    var child = nil;

    # cruise above 50000 ft
    if( me.itself["adc-ctrl"].getChild("ivsi-in-cruise").getValue() and
        ( me.itself["root"][index].getNode("output/altitude-ft").getValue() > constantaero.CRUISEFT ) ) {
        me.ivsi_instrument[index] = constant.TRUE;
        change = constant.TRUE;

        path = me.noinstrument["ivsi"][index].getChild("indicated-speed-fps").getPath();
    }

    # toggles IVSI instrument
    elsif( me.itself["adc-sys"][index].getChild("ivsi-emulated").getValue() != me.ivsi_instrument[index] ) {
        me.ivsi_instrument[index] = me.itself["adc-sys"][index].getChild("ivsi-emulated").getValue();
        change = constant.TRUE;

        if( me.ivsi_instrument[index] ) {
            path = me.noinstrument["ivsi"][index].getChild("indicated-speed-fps").getPath();
        }

        else {
            path = me.noinstrument["vertical-speed"].getPath();
        }
    }

    # only IVSI instrument manages failure
    if( me.ivsi_status[index] != me.last_status[index] ) {
        me.ivsi_status[index] = me.last_status[index];
        change = constant.TRUE;

        if( !me.ivsi_status[index] ) {
            if( me.ivsi_instrument[index] ) {
                path = me.noinstrument["ivsi"][index].getChild("indicated-speed-fps").getPath();
            }
            else {
                path = me.itself["root"][index].getNode("output/vertical-speed-failure-fps").getPath();
            }
        }
        else {
            if( me.ivsi_instrument[index] ) {
                path = me.noinstrument["ivsi"][index].getChild("indicated-speed-fps").getPath();
            }
            else {
                path = me.noinstrument["vertical-speed"].getPath();
            }
        }
    }

    if( change ) {
        child = me.itself["root"][index].getNode("output/vertical-speed-fps");
        if( me.itself["adc-ctrl"].getChild("ivsi-log").getValue() ) {
            print( "alias " ~ child.getPath() ~ " to " ~ path );
        }
        child.unalias();
        child.alias( path );
    }
}

# speed of sound
AirDataComputer.getsoundkt = func( child ) {
   var soundkt = 0.0;

   # simplification
   var speedkt = child.getChild("airspeed-kt").getValue();

   if( speedkt > me.GROUNDKT ) {
       var speedmach = child.getChild("mach").getValue();

       soundkt = speedkt / speedmach;
   }
   else {
       var Tdegc = child.getChild("static-degc").getValue();
       var soundmps = constant.newtonsoundmps( Tdegc );

       soundkt = soundmps * constant.MPSTOKT;
   }

   return soundkt;
}


# =========
# ALTIMETER
# =========

Altimeter = {};

Altimeter.new = func {
   var obj = { parents : [Altimeter,System],

               ADC : [ 0, 1, 1 ],

               lastinhg : 29.92,

               serviceable : [ constant.TRUE, constant.TRUE, constant.TRUE ],
               standby : [ constant.FALSE, constant.FALSE ]
         };

   obj.init();

   return obj;
};

Altimeter.init = func {
   me.inherit_system("/instrumentation","altimeter");
}

Altimeter.schedule = func {
   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        if( i < constantaero.NBAUTOPILOTS ) {
            me.sensor( i );
            me.failure( i, me.standby[i] );
        }

        # no standby mode for engineer altimeter
        else {
            me.failure( i, constant.FALSE );
        }
   }

   me.updategui();
}

Altimeter.sensor = func( index ) {
   var status = constant.FALSE;
   var settinginhg = 0.0;
   var indication = "";
   var setting = "";
   var setting2 = "";
   var child = nil;

   # sensor swap
   status = me.itself["root"][index].getChild("standby").getValue();
   if( status != me.standby[index] ) {
       me.standby[index] = status;

       settinginhg = me.itself["root"][index].getChild("setting-inhg").getValue();

       if( me.standby[index] ) {
           indication = me.noinstrument["sensor"][index].getChild("indicated-altitude-ft").getPath();
           setting2 = me.noinstrument["sensor"][index].getChild("setting-hpa").getPath();
           setting = me.noinstrument["sensor"][index].getChild("setting-inhg").getPath();
       }
            
       else {
           child = me.dependency["adc"][index].getChild("output");
           indication = child.getChild("altitude-ft").getPath();
           setting2 = child.getChild("alt-setting-hpa").getPath();
           setting = child.getChild("alt-setting-inhg").getPath();
       }

       child = me.itself["root"][index].getNode("indicated-altitude-ft");
       child.unalias();
       child.alias( indication );

       child = me.itself["root"][index].getNode("setting-hpa");
       child.unalias();
       child.alias( setting2 );
       child = me.itself["root"][index].getNode("setting-inhg");
       child.unalias();
       child.alias( setting );
       child.setValue( settinginhg );
   }


   # instrument failure
   status = me.itself["root"][index].getChild("serviceable").getValue();
   if( status != me.serviceable[index] ) {
       me.serviceable[index] = status;

       # TO DO : failure is visible, only if standby mode
       me.noinstrument["sensor"][index].getChild("serviceable").setValue( status );
   }
}

Altimeter.failure = func( index, standbymode ) {
   var warning = constant.FALSE;

   # instrument failure
   if( !me.serviceable[index] ) {
       warning = constant.TRUE;
   }

   # TO DO : 1 power supply per mode
   if( !me.dependency["electric"].getChild("specific").getValue() ) {
       warning = constant.TRUE;
   }

   # ADC failure
   if( !standbymode ) {
       if( !me.dependency["adc"][me.ADC[index]].getChild("data").getValue() ) {
           warning = constant.TRUE;
       }
   }

   # warning flag
   me.itself["root"][index].getChild("warning-flag").setValue( warning );
}

# update GUI of instrument setting
Altimeter.updategui = func {
   var currentinhg = me.itself["root"][0].getNode("setting-inhg").getValue();

   if( currentinhg != me.lastinhg ) {
       me.lastinhg = currentinhg;

       var settinginhg = currentinhg;
       var settinghpa = me.itself["root"][0].getNode("setting-hpa").getValue();

       me.noinstrument["gui-hpa"].setValue(int(math.round(settinghpa)));
       me.noinstrument["gui-inhg"].setValue(int(math.round(settinginhg*100.0))/100.0);
   }
}


# ========
# AIRSPEED
# ========

Airspeed = {};

Airspeed.new = func {
   var obj = { parents : [Airspeed,System],

               serviceable : [ constant.TRUE, constant.TRUE ],
               standby : [ constant.FALSE, constant.FALSE ]
         };

   obj.init();

   return obj;
};

Airspeed.init = func {
   me.inherit_system("/instrumentation","airspeed-indicator");
}

Airspeed.schedule = func {
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        me.sensor( i );
        me.failure( i );
   }
}

Airspeed.sensor = func( index ) {
   var status = constant.FALSE;
   var indication = "";
   var child = nil;

   # sensor swap
   status = me.itself["root"][index].getChild("standby").getValue();
   if( status != me.standby[index] ) {
       me.standby[index] = status;

       if( me.standby[index] ) {
           indication = me.noinstrument["sensor"][index].getChild("indicated-speed-kt").getPath();
       }
            
       else {
           child = me.dependency["adc"][index].getChild("output");
           indication = child.getChild("airspeed-kt").getPath();
       }

       child = me.itself["root"][index].getNode("indicated-speed-kt");
       child.unalias();
       child.alias( indication );
   }


   # instrument failure
   status = me.itself["root"][index].getChild("serviceable").getValue();
   if( status != me.serviceable[index] ) {
       me.serviceable[index] = status;

       # TO DO : failure is visible, only if standby mode
       me.noinstrument["sensor"][index].getChild("serviceable").setValue( status );
   }
}

Airspeed.failure = func( index ) {
   var warning = constant.FALSE;
   var vmofailure = constant.FALSE;

   # instrument failure
   if( !me.serviceable[index] ) {
       warning = constant.TRUE;
       vmofailure = constant.TRUE;
   }

   # TO DO : 1 power supply per mode
   if( !me.dependency["electric"].getChild("specific").getValue() ) {
       warning = constant.TRUE;
       vmofailure = constant.TRUE;
   }

   # ADC failure
   if( !me.dependency["adc"][index].getChild("data").getValue() ) {
       if( !me.standby[index] ) {
           warning = constant.TRUE;
       }
       vmofailure = constant.TRUE;
   }

   # failure flag
   me.itself["root"][index].getChild("failure-flag").setValue( warning );
   me.itself["root"][index].getChild("vmo-failure-flag").setValue( vmofailure );
}


# ================
# STANDBY AIRSPEED
# ================

StandbyAirspeed = {};

StandbyAirspeed.new = func {
   var obj = { parents : [StandbyAirspeed,System],

               vmo : VMO.new()
         };

   obj.init();

   return obj;
};

StandbyAirspeed.init = func {
   me.inherit_system("/instrumentation/airspeed-standby");
}

# maximum operating speed (kt)
StandbyAirspeed.schedule = func {
   var altitudeft = me.noinstrument["altitude"].getValue();

   if( altitudeft != nil ) {
       var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
       var vmokt = me.vmo.getvmokt( altitudeft, weightlb ) ;

       me.itself["root"].getChild("vmo-kt").setValue(vmokt);
   }
}  


# ==============
# VERTICAL SPEED
# ==============

VerticalSpeed = {};

VerticalSpeed.new = func {
   var obj = { parents : [VerticalSpeed,System]
         };

   obj.init();

   return obj;
};

VerticalSpeed.init = func {
   me.inherit_system("/instrumentation","vertical-speed-indicator");
}

VerticalSpeed.schedule = func {
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        me.failure( i );
   }
}

VerticalSpeed.failure = func( index ) {
   var warning = constant.FALSE;

   # instrument failure
   if( !me.itself["root"][index].getChild("serviceable").getValue() ) {
       warning = constant.TRUE;
   }

   # power failure
   if( !me.dependency["electric"].getChild("specific").getValue() ) {
       warning = constant.TRUE;
   }

   # ADC failure
   if( !me.dependency["adc"][index].getChild("data").getValue() ) {
        warning = constant.TRUE;
   }

   # alarm flag
   me.itself["root"][index].getChild("alarm-flag").setValue( warning );
}


# =================
# CENTER OF GRAVITY
# =================

Centergravity= {};

Centergravity.new = func {
   var obj = { parents : [Centergravity,System],

               C0stationin : 736.22,                   # 18.7 m from nose
               C0in : 1089,                            # C0  90'9"

               NONEMIN : 0.0,                          # 105 t curve is not complete
               NONEMAX : 100.0,                        # exterme forward cureve is not complete

# lowest CG
               find0 : constant.FALSE,
               corrmin0 : 0.0,
               corrmax0 : 0.0,
               machmin0 : 0.0,
               machmax0 : 0.0,
               cgmin0 : 0.0,

# CG
               find : constant.FALSE,
               corrmin : 0.0,
               corrmax : 0.0,
               machmin : 0.0,
               machmax : 0.0,
               cgmin : 0.0,

# forward CG
               cgmax : 0.0
         };

   obj.init();

   return obj;
};

Centergravity.init = func {
   me.inherit_system("/instrumentation","cg");
}

Centergravity.red_cg = func {
   var result = constant.FALSE;
   var percent = 0.0;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        percent = me.itself["root"][i].getChild("percent").getValue();

        if( percent <= me.itself["root"][i].getChild("min-percent").getValue() or
            percent >= me.itself["root"][i].getChild("max-percent").getValue() ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

Centergravity.takeoffexport = func {
   me.schedule();
}

Centergravity.schedule = func {
   var cgfraction = 0.0;
   var cgpercent = 0.0;
   var cgxin = me.itself["root"][0].getChild("cg-x-in").getValue();

   # % of aerodynamic chord C0 (18.7 m from nose).
   cgxin = cgxin - me.C0stationin;
   me.itself["root"][0].getChild("cg-c0-in").setValue(cgxin);

   # C0 = 90'9".
   cgfraction = cgxin / me.C0in;
   cgpercent = cgfraction * 100;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        if( me.itself["root"][i].getChild("serviceable").getValue() ) {
            me.itself["root"][i].getChild("percent").setValue(cgpercent);

            me.corridor( i );
        }
   }
}  

Centergravity.corridor = func( index ) {
   var cgmin = 0.0;
   var cgmax = 0.0;
   var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
   var speedmach = me.dependency["adc"][index].getNode("output").getChild("mach").getValue();

   # ===============
   # normal corridor
   # ===============
   me.min105t( weightlb, speedmach );
   me.interpolate0( speedmach );

   me.min165t( weightlb, speedmach );
   me.interpolate( speedmach );

   # interpolate between 105 and 165 t
   cgmin = me.interpolateweight( weightlb );


   # normal corridor maximum
   # ------------------------
   cgmax = me.max( speedmach );

   me.itself["root"][index].getChild("min-percent").setValue(cgmin);
   me.itself["root"][index].getChild("max-percent").setValue(cgmax);


   # ================
   # extreme corridor
   # ================
   # CAUTION : overwrites cgmin0 !!!
   me.extrememin165t( weightlb, speedmach );
   me.interpolate( speedmach );

   me.extrememin105t( weightlb, speedmach );
   me.interpolate0( speedmach );

   # interpolate between 105 and 165 t
   cgmin = me.interpolateweight( weightlb );


   # extreme corridor maximum
   # ------------------------
   cgmax = me.extrememax( speedmach );

   me.itself["root"][index].getChild("min-extreme-percent").setValue(cgmin);
   me.itself["root"][index].getChild("max-extreme-percent").setValue(cgmax);
}  

# normal below 105 t, extreme above 165 t
Centergravity.min = func( speedmach ) {
    me.find0 = constant.TRUE;

    if( speedmach <= constantaero.T105mach[constantaero.CGREST] ) {
        me.find0 = constant.FALSE;
        me.cgmin0 = me.NONEMIN;
    }

    elsif( speedmach > constantaero.T105mach[constantaero.CG105] ) {
       me.find0 = constant.FALSE;
       me.cgmin0 = constantaero.Tcgmin105[constantaero.CG105];
    }

    else {
       var j = 0;

       for( var i = 0; i < constantaero.CG105; i = i+1 ) {
            j = i+1;

            if( speedmach > constantaero.T105mach[i] and speedmach <= constantaero.T105mach[j] ) {
                me.corrmin0 = constantaero.Tcgmin105[i];
                me.corrmax0 = constantaero.Tcgmin105[j];
                me.machmin0 = constantaero.T105mach[i];
                me.machmax0 = constantaero.T105mach[j];

                break;
            }
       }
    }
}

# extreme below 105 t 
Centergravity.extrememin105t = func( weightlb, speedmach ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( weightlb ) ) {
       me.find0 = constant.TRUE;

       if( speedmach <= constantaero.T105mach[constantaero.CGREST] ) {
           me.find0 = constant.FALSE;
           me.cgmin0 = constantaero.Tcgmin105ext[constantaero.CGREST];
       }

       elsif( speedmach > constantaero.T105mach[constantaero.CG105] ) {
           me.find0 = constant.FALSE;
           me.cgmin0 = constantaero.Tcgmin105ext[constantaero.CG105];
       }

       else {
          var j = 0;

          for( var i = 0; i < constantaero.CG105; i = i+1 ) {
               j = i+1;

               if( speedmach > constantaero.T105mach[i] and speedmach <= constantaero.T105mach[j] ) {
                   me.corrmin0 = constantaero.Tcgmin105ext[i];
                   me.corrmax0 = constantaero.Tcgmin105ext[j];
                   me.machmin0 = constantaero.T105mach[i];
                   me.machmax0 = constantaero.T105mach[j];

                   break;
               }
          }
       }
   }
}

# extreme above 165 t
Centergravity.extrememin165t = func( weightlb, speedmach ) {
   me.find = constant.FALSE;

   if( constantaero.weight_above( weightlb ) ) {
       me.min( speedmach );
   }

   me.find = me.find0;
   me.corrmin = me.corrmin0;
   me.corrmax = me.corrmax0;
   me.machmin = me.machmin0;
   me.machmax = me.machmax0;
   me.cgmin = me.cgmin0;
}

# normal below 105 t
Centergravity.min105t = func( weightlb, speedmach ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( weightlb ) ) {
       me.min( speedmach );
   }
}

# normal above 165 t
Centergravity.min165t = func( weightlb, speedmach ) {
   me.find  = constant.FALSE;

   if( !constantaero.weight_below( weightlb ) ) {
       me.find = constant.TRUE;

       # at startup, speed may be negativ
       if( speedmach <= constantaero.T165mach[constantaero.CGREST] ) {
           me.find = constant.FALSE;
           me.cgmin = constantaero.Tcgmin165[constantaero.CGREST];
       }

       elsif( speedmach > constantaero.T165mach[constantaero.CG165] ) {
           me.find = constant.FALSE;
           me.cgmin = constantaero.Tcgmin165[constantaero.CG165];
       }

       else {
          var j = 0;

          for( var i = 0; i < constantaero.CG165; i = i+1 ) {
               j = i+1;

               if( speedmach > constantaero.T165mach[i] and speedmach <= constantaero.T165mach[j] ) {
                   me.corrmin = constantaero.Tcgmin165[i];
                   me.corrmax = constantaero.Tcgmin165[j];
                   me.machmin = constantaero.T165mach[i];
                   me.machmax = constantaero.T165mach[j];

                   break;
               }
          }
       }
   }
}

# normal forward
Centergravity.max = func( speedmach ) {
   var cgmax = 0.0;

   me.find = constant.TRUE;

   # at startup, speed may be negativ
   if( speedmach <= constantaero.Tmaxmach[constantaero.CGREST] ) {
       me.find = constant.FALSE;
       me.cgmax = constantaero.Tcgmax[constantaero.CGREST];
   }

   elsif( speedmach > constantaero.Tmaxmach[constantaero.CGMAX] ) {
      me.find = constant.FALSE;
      me.cgmax = constantaero.Tcgmax[constantaero.CGMAX];
   }

   else {
      var j = 0;

      for( var i = 0; i < constantaero.CGMAX; i = i+1 ) {
           j = i+1;

           if( speedmach > constantaero.Tmaxmach[i] and speedmach <= constantaero.Tmaxmach[j] ) {
               me.corrmin = constantaero.Tcgmax[i];
               me.corrmax = constantaero.Tcgmax[j];
               me.machmin = constantaero.Tmaxmach[i];
               me.machmax = constantaero.Tmaxmach[j];

               break;
           }
      }
   }

   # Max performance Takeoff
   if( me.itself["root"][0].getChild("max-performance-to" ).getValue() ) {
       if( speedmach <= constantaero.Tperfmach[constantaero.CGREST] ) {
           me.find = constant.FALSE;
           me.cgmax = constantaero.Tcgperf[constantaero.CGREST];
       }

       else {
           var j = 0;

           for( var i = 0; i < constantaero.CGPERF; i = i+1 ) {
                j = i+1;

                if( speedmach > constantaero.Tperfmach[i] and speedmach <= constantaero.Tperfmach[j] ) {
                    me.corrmin = constantaero.Tcgperf[i];
                    me.corrmax = constantaero.Tcgperf[j];
                    me.machmin = constantaero.Tperfmach[i];
                    me.machmax = constantaero.Tperfmach[j];

                    break;
                }
           }
       }
   }

   cgmax = constantaero.interpolate( me.find, me.cgmax, me.corrmax, me.corrmin,
                                     me.machmax, me.machmin, speedmach );

   return cgmax;
}

# extreme forward
Centergravity.extrememax = func( speedmach ) {
   var cgmax = 0.0;

   me.find = constant.TRUE;

   # defined only within a Mach range
   if( speedmach <= constantaero.Tmaxextmach[constantaero.CGREST] ) {
       me.find = constant.FALSE;
       me.cgmax = me.NONEMAX;
   }

   elsif( speedmach > constantaero.Tmaxextmach[constantaero.CGMAXEXT] ) {
      me.find = constant.FALSE;
      me.cgmax = me.NONEMAX;
   }

   else {
      var j = 0;

      for( var i = 0; i < constantaero.CGMAXEXT; i = i+1 ) {
           j = i+1;

           if( speedmach > constantaero.Tmaxextmach[i] and speedmach <= constantaero.Tmaxextmach[j] ) {
               me.corrmin = constantaero.Tcgmaxext[i];
               me.corrmax = constantaero.Tcgmaxext[j];
               me.machmin = constantaero.Tmaxextmach[i];
               me.machmax = constantaero.Tmaxextmach[j];

               break;
           }
      }
   }

   cgmax = constantaero.interpolate( me.find, me.cgmax, me.corrmax, me.corrmin,
                                     me.machmax, me.machmin, speedmach );

   return cgmax;
}

Centergravity.interpolate0 = func( speedmach ) {
   me.cgmin0 = constantaero.interpolate( me.find0, me.cgmin0, me.corrmax0, me.corrmin0,
                                         me.machmax0, me.machmin0, speedmach );
}

Centergravity.interpolate = func( speedmach ) {
   me.cgmin = constantaero.interpolate( me.find, me.cgmin, me.corrmax, me.corrmin,
                                        me.machmax, me.machmin, speedmach );
}

# interpolate between 105 and 165 t
Centergravity.interpolateweight = func( weightlb ) {
   var cgmin = me.cgmin;

   if( constantaero.weight_inside( weightlb ) ) {
       if( me.cgmin0 != me.NONEMIN and me.cgmin != me.NONEMIN ) {
           cgmin = constantaero.interpolate_weight( weightlb, me.cgmin, me.cgmin0 );
       }

       # impossible values
       elsif( me.cgmin0 == me.NONEMIN ) {
           cgmin = me.cgmin;
       }
       elsif( me.cgmin == me.NONEMIN ) {
           cgmin = me.cgmin0;
       }
   }
   elsif( constantaero.weight_below( weightlb ) ) {
       cgmin = me.cgmin0;
   }

   return cgmin;
}


# ==========
# MACH METER
# ==========

Machmeter= {};

Machmeter.new = func {
   var obj = { parents : [Machmeter,System],

               ADC : [ 0, 1, 0 ],

# lowest CG
               find0 : constant.FALSE,
               corrmin0 : 0.0,
               corrmax0 : 0.0,
               machmax0 : 0.0,
               cgmin0 : 0.0,
               cgmax0 : 0.0,
# CG
               find : constant.FALSE,
               corrmin : 0.0,
               corrmax : 0.0,
               machmax : 0.0,
               cgmin : 0.0,
               cgmax : 0.0,
# foward CG
               machmin : 0.0
         };

   obj.init();

   return obj;
};

Machmeter.init = func {
   me.inherit_system("/instrumentation","mach-indicator");
}

Machmeter.schedule = func {
   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        me.failure( i );

        # no corridor for engineer indicator
        if( i < constantaero.NBAUTOPILOTS ) {
            if( me.dependency["electric"].getChild("specific").getValue() ) {
                me.corridor( i );
            }
        }
   }
}

Machmeter.failure = func( index ) {
   var warning = constant.FALSE;

   # instrument failure
   if( !me.itself["root"][index].getChild("serviceable").getValue() ) {
       warning = constant.TRUE;
   }

   # power failure
   if( !me.dependency["electric"].getChild("specific").getValue() ) {
        warning = constant.TRUE;
   }

   # ADC failure
   if( !me.dependency["adc"][me.ADC[index]].getChild("data").getValue() ) {
       warning = constant.TRUE;
   }

   # failure flag
   me.itself["root"][index].getChild("failure-flag").setValue( warning );
}

Machmeter.corridor = func( index ) {
   var cgpercent = 0.0;
   var machmax = 0.0;
   var machmax0 = 0.0;
   var machmin = 0.0;
   var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();


   # ================
   # corridor maximum
   # ================
   cgpercent = me.dependency["cg"][index].getChild("percent").getValue();

   me.max105t( weightlb, cgpercent );
   me.max165t( weightlb, cgpercent );

   machmax0 = constantaero.interpolate( me.find0, me.machmax0, me.corrmax0, me.corrmin0, me.cgmax0, me.cgmin0, cgpercent );
   machmax = constantaero.interpolate( me.find, me.machmax, me.corrmax, me.corrmin, me.cgmax, me.cgmin, cgpercent );

   # interpolate between 105 and 165 t
   machmax = constantaero.interpolateweight( weightlb, machmax, machmax0 );


   # ================
   # corridor minimum
   # ================
   me.min( cgpercent );

   machmin = constantaero.interpolate( me.find, me.machmin, me.corrmax, me.corrmin, me.cgmax, me.cgmin, cgpercent );

   me.itself["root"][index].getChild("min").setValue(machmin);
   me.itself["root"][index].getChild("max").setValue(machmax);
}

# normal corridor below 105 t
Machmeter.max105t = func( weightlb, cgpercent ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( weightlb ) ) {
       me.find0 = constant.TRUE;

       if( cgpercent <= constantaero.Tcgmin105[constantaero.CGREST] ) {
           me.find0 = constant.FALSE;
           me.machmax0 = constantaero.T105mach[constantaero.CGREST];
       }

       elsif( cgpercent > constantaero.Tcgmin105[constantaero.CG105] ) {
          me.find0 = constant.FALSE;
          me.machmax0 = constantaero.T105mach[constantaero.CG105];
       }

       else {
          var j = 0;

          for( var i = 0; i < constantaero.CG105; i = i+1 ) {
               j = i+1;

               if( cgpercent > constantaero.Tcgmin105[i] and cgpercent <= constantaero.Tcgmin105[j] ) {
                   me.cgmin0 = constantaero.Tcgmin105[i];
                   me.cgmax0 = constantaero.Tcgmin105[j];
                   me.corrmin0 = constantaero.T105mach[i];
                   me.corrmax0 = constantaero.T105mach[j];

                   break;
               }
          }
       }
   }
}

# normal corridor above 165 t
Machmeter.max165t = func( weightlb, cgpercent ) {
   me.find  = constant.FALSE;

   if( !constantaero.weight_below( weightlb ) ) {
       me.find  = constant.TRUE;

       if( cgpercent <= constantaero.Tcgmin165[constantaero.CGFLY] ) {
           me.find = constant.FALSE;
           me.machmax = constantaero.T165mach[constantaero.CGFLY];
       }

       elsif( cgpercent > constantaero.Tcgmin165[constantaero.CG165] ) {
          me.find = constant.FALSE;
          me.machmax = constantaero.T165mach[constantaero.CG165];
       }

       else {
          var j = 0;

          for( var i = constantaero.CGFLY; i < constantaero.CG165; i = i+1 ) {
               j = i+1;

               if( cgpercent > constantaero.Tcgmin165[i] and cgpercent <= constantaero.Tcgmin165[j] ) {
                   me.cgmin = constantaero.Tcgmin165[i];
                   me.cgmax = constantaero.Tcgmin165[j];
                   me.corrmin = constantaero.T165mach[i];
                   me.corrmax = constantaero.T165mach[j];

                   break;
               }
          }
       }
   }
}

Machmeter.min = func( cgpercent ) {
   me.find = constant.TRUE;

   # at startup, speed may be negativ
   if( cgpercent <= constantaero.Tcgmax[constantaero.CGREST] ) {
       me.find = constant.FALSE;
       me.machmin = constantaero.Tmaxmach[constantaero.CGREST];
   }

   elsif( cgpercent > constantaero.Tcgmax[constantaero.CGMAX] ) {
      me.find = constant.FALSE;
      me.machmin = constantaero.Tmaxmach[constantaero.CGMAX];
   }

   else {
      var j = 0;

      for( var i = 0; i < constantaero.CGMAX; i = i+1 ) {
           j = i+1;

           if( cgpercent > constantaero.Tcgmax[i] and cgpercent <= constantaero.Tcgmax[j] ) {
               me.cgmin = constantaero.Tcgmax[i];
               me.cgmax = constantaero.Tcgmax[j];
               me.corrmin = constantaero.Tmaxmach[i];
               me.corrmax = constantaero.Tmaxmach[j];

               break;
           }
      }
   }

   # Max performance Takeoff
   if( me.dependency["cg"][0].getChild("max-performance-to").getValue() ) {
       if( cgpercent <= constantaero.Tcgperf[constantaero.CGREST] ) {
           me.find = constant.FALSE;
           me.machmin = constantaero.Tperfmach[constantaero.CGREST];
       }

       else {
           var j = 0;

           for( var i = 0; i < constantaero.CGPERF; i = i+1 ) {
                j = i+1;

                if( cgpercent > constantaero.Tcgperf[i] and cgpercent <= constantaero.Tcgperf[j] ) {
                    me.find = constant.TRUE;
                    me.cgmin = constantaero.Tcgperf[i];
                    me.cgmax = constantaero.Tcgperf[j];
                    me.corrmin = constantaero.Tperfmach[i];
                    me.corrmax = constantaero.Tperfmach[j];

                    break;
                }
           }
       }
   }
}


# ===================
# ACCELEROMETER / AOA
# ===================

AccelerometerAOA = {};

AccelerometerAOA.new = func {
   var obj = { parents : [AccelerometerAOA,System]
         };

   obj.init();

   return obj;
};

AccelerometerAOA.init = func {
   me.inherit_system("/instrumentation","accelerometer-aoa");
}

AccelerometerAOA.schedule = func {
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        me.failure( i );
   }
}

AccelerometerAOA.failure = func( index ) {
   var warning = constant.FALSE;

   # instrument failure
   if( !me.itself["root"][index].getChild("serviceable").getValue() ) {
       warning = constant.TRUE;
   }

   # power failure
   if( !me.dependency["electric"].getChild("specific").getValue() ) {
       warning = constant.TRUE;
   }

   # ADC failure
   if( !me.dependency["adc"][index].getChild("data").getValue() ) {
       warning = constant.TRUE;
   }

   # failure flag
   me.itself["root"][index].getChild("failure-flag").setValue( warning );
}


# ===========
# TEMPERATURE
# ===========

Temperature = {};

Temperature.new = func {
   var obj = { parents : [Temperature,System]
         };

   obj.init();

   return obj;
};

Temperature.init = func {
   me.inherit_system("/instrumentation", "temperature");
}

Temperature.schedule = func {
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        if( !me.failure( i ) ) {
            me.isa( i );
        }
   }
}

Temperature.failure = func( index ) {
   var warning = constant.FALSE;
   var isafailure = constant.FALSE;


   # instrument failure
   if( !me.itself["root"][index].getChild("serviceable").getValue() ) {
       warning = constant.TRUE;
   }

   # power failure
   if( !me.dependency["electric"].getChild("specific").getValue() ) {
       warning = constant.TRUE;
   }

   # ADC failure
   if( !me.dependency["adc"][index].getChild("data").getValue() ) {
       warning = constant.TRUE;
   }

   # Static failure
   if( warning ) {
       isafailure = constant.TRUE;
   }

   # failure flags
   me.itself["root"][index].getChild("failure-flag").setValue( warning );
   me.itself["root"][index].getChild("isa-failure-flag").setValue( isafailure );


   return isafailure;
}

# International Standard Atmosphere temperature
Temperature.isa = func( index ) {
   var altft = me.dependency["adc"][index].getNode("output").getChild("altitude-ft").getValue(); 

   var isadegc = constantISA.temperature_degc( altft );

   me.itself["root"][index].getChild("isa-degc").setValue(isadegc);
}


# =============
# MARKER BEACON
# =============

Markerbeacon = {};

Markerbeacon.new = func {
   var obj = { parents : [Markerbeacon,System],

               TESTSEC : 1.5
         };

   obj.init();

   return obj;
};

Markerbeacon.init = func {
   me.inherit_system("/instrumentation/marker-beacon");
}

# test of marker beacon lights
Markerbeacon.testexport = func {
   var outer = me.itself["root"].getChild("test-outer").getValue();
   var middle = me.itself["root"].getChild("test-middle").getValue();
   var inner = me.itself["root"].getChild("test-inner").getValue();

   # may press button during test
   if( !outer and !middle and !inner ) {
       me.testmarker();
   }
}

Markerbeacon.testmarker = func {
   var end = constant.FALSE;
   var outer = me.itself["root"].getChild("test-outer").getValue();
   var middle = me.itself["root"].getChild("test-middle").getValue();
   var inner = me.itself["root"].getChild("test-inner").getValue();

   if( !outer and !middle and !inner ) {
       me.itself["root"].getChild("test-outer").setValue(constant.TRUE);
       end = constant.FALSE;
   }
   elsif( outer ) {
       me.itself["root"].getChild("test-outer").setValue("");
       me.itself["root"].getChild("test-middle").setValue(constant.TRUE);
       end = constant.FALSE;
   }
   elsif( middle ) {
       me.itself["root"].getChild("test-middle").setValue("");
       me.itself["root"].getChild("test-inner").setValue(constant.TRUE);
       end = constant.FALSE;
   }
   else  {
       me.itself["root"].getChild("test-inner").setValue(constant.FALSE);
       end = constant.TRUE;
   }

   # re-schedule the next call
   if( !end ) {
       settimer(func { me.testmarker(); }, me.TESTSEC);
   }
}


# =======
# GENERIC
# =======

Generic = {};

Generic.new = func {
   var obj = { parents : [Generic,System],

               generic : aircraft.light.new("/instrumentation/generic",[ 1.5,0.2 ])
         };

   obj.init();

   return obj;
};

Generic.init = func {
   me.inherit_system("/instrumentation/generic");

   me.generic.toggle();
}

Generic.toggleclick = func {
   var sound = constant.TRUE;
   var child = me.itself["root"].getChild("click");

   if( child.getValue() ) {
       sound = constant.FALSE;
   }

   child.setValue( sound );
}


# ===========
# TRANSPONDER
# ===========

Transponder = {};

Transponder.new = func {
   var obj = { parents : [Transponder,System],

               TESTSEC : 15
         };

   obj.init();

   return obj;
};

Transponder.init = func {
   me.inherit_system("/instrumentation/transponder");
}

Transponder.testexport = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       if( !me.itself["root-ctrl"].getChild("test").getValue() ) {
           me.itself["root-ctrl"].getChild("test").setValue( constant.TRUE );
           settimer(func { me.test(); }, me.TESTSEC);
       }
   }
}

Transponder.test = func {
   if( me.itself["root-ctrl"].getChild("test").getValue() ) {
       me.itself["root-ctrl"].getChild("test").setValue( constant.FALSE );
   }
}


# ===========
# AUDIO PANEL
# ===========

AudioPanel = {};

AudioPanel.new = func {
   var obj = { parents : [AudioPanel,System]
         };

   obj.init();

   return obj;
};

AudioPanel.init = func {
   me.inherit_system("/instrumentation/audio");
}

AudioPanel.headphones = func( marker, panel, seat ) {
   var audio = nil;

   # hears nothing outside
   var adf1 = 0.0;
   var adf2 = 0.0;
   var comm1 = 0.0;
   var comm2 = 0.0;
   var nav1 = 0.0;
   var nav2 = 0.0;

   # each crew member has an audio panel
   if( panel ) {
       audio = me.itself["root-ctrl"].getChild("crew").getNode(seat);

       if( audio != nil ) {
           adf1  = audio.getNode("adf[0]/volume").getValue();
           adf2  = audio.getNode("adf[1]/volume").getValue();
           comm1 = audio.getNode("comm[0]/volume").getValue();
           comm2 = audio.getNode("comm[1]/volume").getValue();
           nav1  = audio.getNode("nav[0]/volume").getValue();
           nav2  = audio.getNode("nav[1]/volume").getValue();
       }
   }

   me.send( adf1, adf2, comm1, comm2, nav1, nav2, marker );
}

AudioPanel.send = func( adf1, adf2, comm1, comm2, nav1, nav2, marker ) {
   me.dependency["adf"][0].getChild("volume-norm").setValue(adf1);
   me.dependency["adf"][1].getChild("volume-norm").setValue(adf2);
   me.dependency["comm"][0].getChild("volume").setValue(comm1);
   me.dependency["comm"][1].getChild("volume").setValue(comm2);
   me.dependency["nav"][1].getChild("volume").setValue(nav1);
   me.dependency["nav"][2].getChild("volume").setValue(nav2);
   me.dependency["marker"].getChild("audio-btn").setValue(marker);
}


# =============
# SPEED UP TIME
# =============

Daytime = {};

Daytime.new = func {
   var obj = { parents : [Daytime,System],

               SPEEDUPSEC : 1.0,

               CLIMBFTPMIN : 3500,                                           # max climb rate
               MAXSTEPFT : 0.0,                                              # altitude change for step

               lastft : 0.0
         };

   obj.init();

   return obj;
}

Daytime.init = func {
    me.inherit_system("/instrumentation/clock");

    var climbftpsec = me.CLIMBFTPMIN / constant.MINUTETOSECOND;

    me.MAXSTEPFT = climbftpsec * me.SPEEDUPSEC;
}

Daytime.schedule = func {
   var altitudeft = me.noinstrument["altitude"].getValue();
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       # safety
       var stepft = me.MAXSTEPFT * speedup;
       var maxft = me.lastft + stepft;
       var minft = me.lastft - stepft;

       # too fast
       if( altitudeft > maxft or altitudeft < minft ) {
           me.noinstrument["speed-up"].setValue(1);
       }
   }

   me.lastft = altitudeft;
}
