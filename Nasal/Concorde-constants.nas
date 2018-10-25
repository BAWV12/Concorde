# ==================
# CONCORDE CONSTANTS
# ==================

Constantaero = {};

Constantaero.new = func {
   var obj = { parents : [Constantaero],

               NBENGINES : 4,
               NBINS : 3,
               NBAUTOPILOTS : 2,                                 # and any system in double

               ENGINE4 : 3,
               ENGINE3 : 2,
               ENGINE2 : 1,
               ENGINE1 : 0,

               TANKLP : 13,                                      # tank emulating LP valve

               INS3 : 2,
               INS2 : 1,
               INS1 : 0,

               INSOFF : -2,
               INSSTANDBY : -1,
               INSALIGN : 0,

               AP2 : 1,
               AP1 : 0,
               APNONE : -1,

               THROTTLEMAX : 1.0,
               THROTTLEREV : 0.1,
               THROTTLEIDLE : 0.0,

               GEARDOWN : 1.0,
               GEARUP : 0.0,

               GEARFRONT : 0,
               GEARLEFT : 1,
               GEARRIGHT : 3,

               NOSEDOWN : 1.0,
               NOSEUP : 0.0,

               BRAKEPARKING : 1.0,
               BRAKEEMERGENCY : 0.5,
               BRAKENORMAL : 0.0,

               RATINGTAKEOFF : "takeoff",
               RATINGFLIGHT : "flight",
               RATINGCLIMB : "climb",
               RATINGCRUISE : "cruise",

               SCHEDULEAPPROACH : 1,
               SCHEDULENORMAL : 0,

               RADIONM : 200,                                    # radio range
               
               FULLLB : 408000,
               LANDINGLB : 245000,
               EMPTYLB : 203000,

               MAXFPM : 7000.0,                                  # max descent rate

               REHEATMACH : 1.7,
               SOUNDMACH : 1.0,
               SUBSONICMACH : 0.95,
               CLIMBMACH : 0.7,

               NOSEKT : 270,
               APPROACHKT : 250,
               GEARKT : 220,
               V2FULLKT : 220,
               V2EMPTYKT : 205,                                  # guess
               VRFULLKT : 195,
               LANDINGKT : 190,
               VREMPTYKT : 180,                                  # guess
               V1FULLKT : 165,
               VREFFULLKT : 182,
               VREFEMPTYKT : 172,
               V1EMPTYKT : 150,                                  # guess
               TAXIKT : 15,

               MAXCRUISEFT : 50190,                              # max cruise mode 
               CRUISEFT : 50000,
               TRANSITIONFT : 18000,
               APPROACHFT : 10000,                               # 250 kt
               LANDINGFT : 3000,                                 # 190 kt
               CLIMBFT : 1000,
               REHEATFT : 500,                                   # reheat off
               GEARFT : 20,                                      # gear retraction
               LIFTOFFFT : 20,

# AGL altitude, where the gears touch the ground
               AGLTOUCHFT : 14,

# AGL altitude when on ground : radio altimeter is above gear
# (Z height of center of gravity minus Z height of main landing gear)
               AGLFT : 11,

# Center of gravity
               CGMAXTON : 165,
               CGMINTON : 105,

               CGMLAXLB : 0,
               CGMINLB : 0,

               T105mach :    [ 0.82, 0.92, 1.15, 1.50, 2.20 ],
               Tcgmin105 :    [ 52.00, 53.50, 55.00, 56.50, 57.25 ],
               Tcgmin105ext : [ 51.30, 53.00, 54.50, 56.00, 56.70 ],
               CG105 : 0,

               T165mach :    [ 0.00, 0.80, 0.92, 1.15, 1.50, 2.20 ],
               Tcgmin165 :    [ 51.80, 51.80, 54.00, 55.50, 57.00, 57.70 ],
               CG165 : 0,

               Tmaxmach :    [ 0.00, 0.27, 0.50, 0.94, 1.65 ],
               Tcgmax :       [ 53.80, 53.80, 54.00, 57.00, 59.30 ],
               CGMAX : 0,

               Tperfmach :   [ 0.00, 0.10, 0.45 ],
               Tcgperf :      [ 54.20, 54.20, 54.50 ],
               CGPERF : 0,

               Tmaxextmach : [ 0.45, 0.50, 0.94, 1.60 ],
               Tcgmaxext :    [ 54.25, 54.40, 57.25, 59.50 ],
               CGMAXEXT : 0,

               CGFLY : 1,                                        # in flight
               CGREST : 0                                        # on ground
         };

   obj.init();

   return obj;
}

Constantaero.init = func {
   me.CGMINLB = me.CGMINTON * constant.TONTOLB;
   me.CGMLAXLB = me.CGMAXTON * constant.TONTOLB;

   me.CG165 = size(me.T165mach) - 1;
   me.CGMAX = size(me.Tmaxmach) - 1;
   me.CG105 = size(me.T105mach) - 1;
   me.CGMAXEXT = size(me.Tmaxextmach) - 1;
   me.CGPERF = size(me.Tperfmach) - 1;
}

Constantaero.weight_inside = func( weightlb ) {
   var result = constant.FALSE;

   if( weightlb > me.CGMINLB and weightlb < me.CGMLAXLB ) {
       result = constant.TRUE;
   }

   return result;
}

Constantaero.weight_below = func( weightlb ) {
   var result = constant.FALSE;

   if( weightlb <= me.CGMINLB ) {
       result = constant.TRUE;
   }

   return result;
}

Constantaero.weight_above = func( weightlb ) {
   var result = constant.FALSE;

   if( weightlb >= me.CGMLAXLB ) {
       result = constant.TRUE;
   }

   return result;
}

Constantaero.interpolate_weight = func( weightlb, min, min0 ) {
   var offset = min - min0;
   var stepweight = weightlb - me.CGMINLB;
   var offsetweight = me.CGMLAXLB - me.CGMINLB;
   var ratio = stepweight / offsetweight;
   var step = offset * ratio;

   min = min0 + step;

   return min;
}

# interpolate between 105 and 165 t
Constantaero.interpolateweight = func( weightlb, vmokt, vmokt0 ) {
   if( me.weight_inside( weightlb ) ) {
       vmokt = me.interpolate_weight( weightlb, vmokt, vmokt0 );
   }
   elsif( me.weight_below( weightlb ) ) {
       vmokt = vmokt0;
   }

   return vmokt;
}

Constantaero.interpolate = func( find, vmokt, vmaxkt, vminkt, altmaxft, altminft, altitudeft ) {
   if( find ) {
       var offsetkt = vmaxkt - vminkt;
       var offsetft = altmaxft - altminft;
       var stepft = altitudeft - altminft;
       var ratio = stepft / offsetft;
       var stepkt = offsetkt * ratio;

       vmokt = vminkt + stepkt;
   }

   # otherwise vmokt in argument

   return vmokt;
}

Constantaero.Vkt = func( weightlb, minkt, maxkt ) {
    return me.weightratio( weightlb, minkt, maxkt );
}

Constantaero.Vrefkt = func( weightlb ) {
    var valuekt = me.weightratio( weightlb, me.VREFEMPTYKT, me.VREFFULLKT );
    var ratio = 0.0;

    # structural limit
    if( weightlb > me.LANDINGLB ) {
        valuekt = me.VREFFULLKT;
    }

    return valuekt;
}

Constantaero.weightratio = func( weightlb, empty, full ) {
    var value = 0.0;
    var ratio = 0.0;

    if( weightlb > me.FULLLB ) {
        valuekt = full;
    }
    elsif( weightlb < me.EMPTYLB ) {
        valuekt = empty;
    }
    else {
        ratio = ( me.FULLLB - weightlb ) / ( me.FULLLB - me.EMPTYLB );
        value = full + ( empty - full ) * ratio;
    }

    return value;
}

Constantaero.inboardengine = func( index ) {
    var result = constant.FALSE;

    if( index == constantaero.ENGINE2 or index == constantaero.ENGINE3 ) {
        result = constant.TRUE;
    }

    return result;
}


# =========
# CONSTANTS
# =========

Constant = {};

Constant.new = func {
   var obj = { parents : [Constant],

               NIGHTRAD : 1.57,                        # sun below horizon

# artificial intelligence
               HUMANSEC : 1.0,                         # human reaction time

# angles
               DEG360 : 360,
               DEG180 : 180,
               DEG90 : 90,

# nasal has no boolean
               TRUE : 1.0,                             # faster than "true"/"false"
               FALSE : 0.0,

# property not yet created at startup (should through XML)
               DELAYEDNODE : 1,

# ---------------
# unit conversion
# ---------------

# angle
               DEGTORAD : 0.01745329,
               RADTODEG : 57.2957795,
# length
               FEETTOMETER : 0.3048,
               METERTOFEET : 3.28083989501,
               NMTOFEET : 6076.11548556,
               FEETTONM : 0.0001645788,
               NMTOMETER : 1852,
               KMTOMETER : 1000,
# pressure
               INHGTOPSI : 0.491154077497,
               MBARTOINHG : 0.029529987508,
               PSITOINHG : 2.03602096738,
# temperature
               CELSIUSTOK : 273.15,
               CELSIUSTOF : 1.8,
               CELSIUS0TOF : 32.0,
               FTOCELSIUS : 0.0,
               F0TOCELSIUS : 0.0,
# time
               HOURTOMINUTE : 60,
               HOURTOSECOND : 3600,
               MINUTETOSECOND : 60,
               MINUTETODECIMAL : 0.01,
# velocity
               FPSTOKT : 0.592483801296,
               MPSTOKT : 1.943844,
# weight
               GALUSTOKG : 0.0,
               GALUSTOLB : 6.6,                        # 1 US gallon = 6.6 pound
               KGTOLB : 2.20462,
               LBTOGALUS : 0.0,
               LBTOKG : 0.453592,
               TONTOLB : 2204.62,

# --------
# physical
# --------
               gammaairstp : 1.4,                      # ratio of specific heats at STP
               Rpm2ps2pK : 286.0                       # gas constant 286 /m2/s2/K for air
         };

   obj.init();

   return obj;
};

Constant.init = func {
   me.GALUSTOKG = me.GALUSTOLB * me.LBTOKG;
   me.LBTOGALUS = 1 / me.GALUSTOLB;
   me.FTOCELSIUS = 1 / me.CELSIUSTOF;
   me.F0TOCELSIUS = - me.CELSIUS0TOF * me.FTOCELSIUS;
}

Constant.clip = func( min, max, value ) {
   if( value < min ) {
       value = min;
   }
   elsif( value > max ) {
       value = max;
   }

   return value;
}

Constant.intensity = func( value, max ) {
   if( value < max ) {
       value = max;
   }

   return value;
}

Constant.within = func( value, limit, margin ) {
   var result = constant.TRUE;

   if( ( value > ( limit + margin ) ) or ( value < ( limit - margin ) ) ) {
       result = constant.FALSE;
   }

   return result;
}

Constant.not = func( value ) {
   var result = constant.FALSE;

   if( !value ) {
       result = constant.TRUE;
   }

   return result;
}

# north crossing
Constant.crossnorth = func( offsetdeg ) {
   if( offsetdeg > me.DEG180 ) {
       offsetdeg = offsetdeg - me.DEG360;
   }
   elsif( offsetdeg < - me.DEG180 ) {
       offsetdeg = offsetdeg + me.DEG360;
   }

   return offsetdeg;
}

Constant.truncatenorth = func( offsetdeg ) {
   if( offsetdeg > me.DEG360 ) {
       offsetdeg = offsetdeg - me.DEG360;
   }
   elsif( offsetdeg < 0 ) {
       offsetdeg = offsetdeg + me.DEG360;
   }

   return offsetdeg;
}

Constant.fahrenheit_to_celsius = func ( degf ) {
   var degc = me.FTOCELSIUS * degf + me.F0TOCELSIUS;

   return degc;
}

# speed of sound : v^2 = dP/dRo = gamma x R x T, where
# P = pressure
# Ro = density
# gamma = cp/cv, ratio of specific heats
# R = absolute gas constant
# T = temperature
Constant.newtonsoundmps= func( temperaturedegc ) {
    var TK = temperaturedegc + me.CELSIUSTOK;
    var dPdRoNewton = me.Rpm2ps2pK * TK;
    var dPdRo = me.gammaairstp * dPdRoNewton;
    var speedmps = math.sqrt(dPdRo);

    return speedmps;
}


# =================================
# INTERNATIONAL STANDARD ATMOSPHERE
# =================================

ConstantISA = {};

ConstantISA.new = func {
   var obj = { parents : [ConstantISA],

               Taltm : [ -900, 0, 900, 1800, 2700, 3600, 4500, 5400, 6300, 7200,
                         8100, 9000, 9900, 10800, 11700, 12600, 13500, 14400, 15300, 16200,
                         17100, 18000, 18900 ],
               Tpfactor : [ 1.09, 1.0, 0.898, 0.804, 0.719, 0.641, 0.570, 0.506, 0.447, 0.394,
                            0.347, 0.304, 0.266, 0.231, 0.201, 0.174, 0.151, 0.131, 0.114, 0.099,
                            0.086, 0.075, 0.065 ],
               Ttfactor : [ 1.02, 1.0, 0.98, 0.96, 0.94, 0.92, 0.90, 0.88, 0.86, 0.84,
                            0.82, 0.80, 0.78, 0.76, 0.75 ],
               CEILING : 0,

               SEA_inhg : 29.92,
 
               STRATODEGC : -57,
               SEA_degc : 15.0,

               STRATOSPHERE : 14,
               SLICE : 2,                         # 900 m steps
               UNDERSEA : 0                       # below sea level is extrapolated
         };

   obj.init();

   return obj;
}

ConstantISA.init = func {
   me.CEILING = size(me.Taltm) - 1;
}

ConstantISA.altitude_ft = func( pressureinhg, datuminhg ) {
   var found = constant.FALSE;
   var altmaxm = 0;
   var altminm = 0;
   var minfactor = 0.0;
   var maxfactor = 0.0;
   var step = 0.0;
   var delta = 0.0;
   var coeff = 0.0;
   var cabinaltm = 0.0;
   var altitudeft = 0.0;
#   var realalt=0;

   # calibrated by standard atmosphere
   var ratio = pressureinhg / datuminhg;

   # guess below sea level
   found = constant.TRUE;
   if( ratio > me.Tpfactor[me.UNDERSEA] ) {
       found = constant.FALSE;
   }

   # standard atmosphere from 0 m
   else {
       var j = 0;

       found = constant.FALSE;

       for( var i = 0; i < me.CEILING; i = i+1 ) {
            j = i+1;

            if( ratio > me.Tpfactor[j] and ratio <= me.Tpfactor[i] ) {
                altmaxm = me.Taltm[j];
                altminm = me.Taltm[i];
                minfactor = me.Tpfactor[j];
                maxfactor = me.Tpfactor[i];

                found = constant.TRUE;
                break;
            }
       }
   }

   if( found ) {
       step = maxfactor - ratio;
       delta = maxfactor - minfactor;
       coeff = step / delta ;
       cabinaltm = altminm + me.Taltm[me.SLICE] * coeff;
       altitudeft = cabinaltm * constant.METERTOFEET;
   }

   # out of range
   else {
       pressureinhg = datuminhg;
       altitudeft = 0;
   }

#   realalt=props.globals.getNode("/position/altitude-ft").getValue();

#   if (realalt>10000) {
#     altitudeft=realalt;
#   };
#     print (realalt,altitudeft);
   return altitudeft;
}

ConstantISA.pressure_inhg = func( altitudeft ) {
   var altitudem = altitudeft * constant.FEETTOMETER;
   var found = constant.TRUE;
   var altmaxm = 0;
   var altminm = 0;
   var minfactor = 0.0;
   var maxfactor = 0.0;
   var step = 0.0;
   var delta = 0.0;
   var coeff = 0.0;
   var pressureinhg = 0.0;

   # guess below sea level
   if( altitudem < me.Taltm[me.UNDERSEA] ) {
       found = constant.FALSE;
   }

   # standard atmosphere from 0 m
   else {
       var j = 0;

       found = constant.FALSE;

       for( var i = 0; i < me.CEILING; i = i+1 ) {
            j = i+1;

            if( altitudem < me.Taltm[j] and altitudem >= me.Taltm[i] ) {
                altmaxm = me.Taltm[j];
                altminm = me.Taltm[i];
                minfactor = me.Tpfactor[j];
                maxfactor = me.Tpfactor[i];

                found = constant.TRUE;
                break;
            }
       }
   }

   if( found ) {
       step = altmaxm - altitudem;
       delta = maxfactor - minfactor;
       coeff = step / me.Taltm[me.SLICE] ;
       pressureinhg = me.SEA_inhg * ( minfactor + delta * coeff );
   }

   # out of range
   else {
       pressureinhg = me.SEA_inhg;
   }


   return pressureinhg;
}

ConstantISA.temperature_degc = func( altitudeft ) {
   var altmeter = altitudeft * constant.FEETTOMETER;
   var found = constant.FALSE;
   var isadegc = 0.0;
   var isadegk = 0.0;
   var minfactor = 0.0;
   var maxfactor = 0.0;
   var minmeter = 0;
   var delta = 0.0;
   var deltameter = 0.0;
   var coeff = 0.0;
   var factor = 0.0;

   # guess below sea level
   if( altmeter < me.Taltm[me.UNDERSEA] ) {
       isadegc = me.SEA_degc;
   }

   # factor 0.75 (stratosphere)
   elsif( altmeter > me.Taltm[me.STRATOSPHERE] and altmeter <= me.Taltm[me.CEILING] ) {
       isadegc = me.STRATODEGC;
   }

   # overflow
   elsif( altmeter > me.Taltm[me.CEILING] ) {
       isadegc = me.STRATODEGC;
   }

   # standard atmosphere from 0 m
   else {
       var j = 0;

       for( var i = 0; i < me.STRATOSPHERE; i = i+1 ) {
            j = i+1;

            if( altmeter > me.Taltm[i] and altmeter <= me.Taltm[j] ) {
                minmeter = me.Taltm[i];
                maxfactor = me.Ttfactor[i];
                minfactor = me.Ttfactor[j];

                found = constant.TRUE;
                break;
            }
       }
   }

   if( found ) {
       delta = minfactor - maxfactor;
       deltameter = altmeter - minmeter;
       coeff = deltameter / me.Taltm[me.SLICE] ;
       factor = maxfactor + delta * coeff;

       # 15 degc at sea level
       isadegk = (constant.CELSIUSTOK + me.SEA_degc) * factor;
       isadegc = isadegk - constant.CELSIUSTOK;
   }


   return isadegc;
}


# ======
# SYSTEM
# ======

# for inheritance, the system must be the last of parents.
System = {};

# not called by child classes !!!
System.new = func {
   var obj = { parents : [System],

               SYSSEC : 0.0,                               # to be defined !

               ready : constant.FALSE,                     # waits for end of initialization

               RELOCATIONFT : 0.0,                         # max descent speed around 6000 feet/minute.

               altitudeseaft : 0.0,

               dependency : {},
               itself : {},
               noinstrument : {}
         };

   return obj;
};

System.inherit_system = func( path, subpath = "" ) {
   var fullpath = path;
   var ctrlpath = "";

   var obj = System.new();

   me.SYSSEC = obj.SYSSEC;
   me.ready = obj.ready;
   me.RELOCATIONFT = obj.RELOCATIONFT;
   me.altitudeseaft = obj.altitudeseaft;
   me.dependency = obj.dependency;
   me.itself = obj.itself;
   me.noinstrument = obj.noinstrument;


   ctrlpath = string.replace(path,"systems","controls");
   if( fullpath == ctrlpath ) {
       ctrlpath = string.replace(path,"instrumentation","controls");
   }

   # reserved entries
   if( subpath == "" ) {
       # instrumentation/fuel
       me.itself["root"] = props.globals.getNode(path);

       # controls/fuel
       me.itself["root-ctrl"] = props.globals.getNode(ctrlpath);
   }
   else {
       # instrumentation/fuel-consumed[0]
       # instrumentation/fuel-consumed[1]
       # instrumentation/fuel-consumed[2]
       if( find("instrumentation/", fullpath) < 0 and
           find("systems/", fullpath ) < 0 ) {
           fullpath = fullpath ~ "/" ~ subpath;
       }

       # systems/engines/engine[0]
       # systems/engines/engine[1]
       # systems/engines/engine[2]
       # systems/engines/engine[3]
       me.itself["root"] = props.globals.getNode(path).getChildren(subpath);

       # controls/engines/engine
       me.itself["root-ctrl"] = props.globals.getNode(ctrlpath).getChildren(subpath);
   }

   fullpath = fullpath ~ "/relations";

   me.loadtree( fullpath ~ "/dependency", me.dependency );
   me.loadtree( fullpath ~ "/itself", me.itself );
   me.loadtree( fullpath ~ "/noinstrument", me.noinstrument );
}

System.set_rate_ancestor = func( rates ) {
   me.SYSSEC = rates;

   me.RELOCATIONFT = constantaero.MAXFPM / ( constant.MINUTETOSECOND / me.SYSSEC );
}

# property access is faster through its node, than parsing its string
System.loadtree = func( path, table ) {
   var children = nil;
   var subchildren = nil;
   var name = "";
   var component = "";
   var subcomponent = "";
   var value = "";

   if( props.globals.getNode(path) != nil ) {
       children = props.globals.getNode(path).getChildren();
       foreach( var c; children ) {
          name = c.getName();
          subchildren = c.getChildren();

          # <slave>
          #  <engine>
          #   <component>/engines</component>
          #   <subcomponent>engine</subcomponent>
          #  </engine>
          if( size(subchildren) > 0 ) {
              component = c.getChild("component").getValue();
              subcomponent = c.getChild("subcomponent").getValue();
              table[name] = props.globals.getNode(component).getChildren(subcomponent);
          }

          #  <altimeter>/instrumentation/altimeter[0]</altimeter>
          # </slave>
          else {
              value = c.getValue();
              table[name] = props.globals.getNode(value);
          }
      }
   }
}

System.is_moving = func {
   var result = constant.FALSE;

   # must exist in XML !
   var aglft = me.noinstrument["agl"].getValue();
   var speedkt = me.noinstrument["speed"].getValue();

   if( aglft >=  constantaero.AGLTOUCHFT or speedkt >= constantaero.TAXIKT ) {
       result = constant.TRUE;
   }

   return result;
}

System.is_relocating = func {
   var result = constant.FALSE;
   var variationftpm = 0.0;

   # must exist in XML !
   var altft = me.noinstrument["altitude"].getValue();

   # relocation in flight, or at another airport
   variationftpm = altft - me.altitudeseaft;
   if( variationftpm < - me.RELOCATIONFT or variationftpm > me.RELOCATIONFT ) {
       result = constant.TRUE;
   }

   me.altitudeseaft = altft;

   return result;
}

# ready to enter the system loop
System.is_ready = func {
    if( !me.ready ) {
        # must exist in XML !
        if( me.noinstrument["electric"].getChild("specific").getValue() and
            me.noinstrument["hydraulic"].getChild("green").getValue() and
            me.noinstrument["hydraulic"].getChild("blue").getValue() ) {
            me.ready = constant.TRUE;
        }
    }

    return me.ready;
}

System.speed_ratesec = func( steps ) {
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       steps = steps / speedup;
   }

   return steps;
}

System.speed_timesec = func( steps ) {
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       steps = steps * speedup;
   }

   return steps;
}


