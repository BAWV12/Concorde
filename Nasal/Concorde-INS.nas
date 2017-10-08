# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ==========================
# INERTIAL NAVIGATION SYSTEM
# ==========================

Inertial = {};

Inertial.new = func {
   var obj = { parents : [Inertial,System],

               last : nil,
               route : nil,
               waypoints : nil,

               SELECTORGROUND : -3,
               SELECTORHEADING : -2,
               SELECTORTRACK : -1,
               SELECTORPOS : 0,
               SELECTORWPTPOS : 1,
               SELECTORWPTTIME : 2,
               SELECTORWIND : 3,
               SELECTORSTATUS : 4,

               MODEOFF : -2,
               MODEALIGN : 0,
               MODENAV : 1,
               MODEATT : 2,

               QUALITYPOOR : 9,
               QUALITYREADY : 5,
               QUALITYGOOD : 1,

               ACTIONGROUND : 4,
               ACTIONATT : 2,
               ACTIONOFF : 0,

               ALIGNEDSEC : 900,                                # 15 minutes
               QUALITYSEC : 225,
               INSSEC : 3,

               QUICK : 15,                                      # factor for quick alignment (not real)

               GROUNDFT : 20,

               GROUNDKT : 75,

               MAXWPTNM : 9999.0,
               MAXXTKNM : 999.99,

               UNKNOWN : -999,

               bearingdeg : 0.0,
               trackdeg : 0.0,

               left : 0.0,
               right : 0.0,
               waypoint : ""
         };

   obj.init();

   return obj;
};

Inertial.init = func {
   me.inherit_system("/instrumentation","ins");

   me.last = me.dependency["autopilot"].getChild("wp-last");
   me.waypoints = me.dependency["autopilot"].getChildren("wp");
}

Inertial.red_ins = func {
   var result = constant.FALSE;

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        if( me.itself["root"][i].getNode("light/warning").getValue() ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

Inertial.schedule = func {
   var ACvoltage = me.dependency["electric"].getChild("specific").getValue();

   if( ACvoltage ) {
       me.track();
       me.display();
       me.alertlight();
   } 

   me.alignment();

   me.failure();

   me.testlight( ACvoltage );
}

Inertial.computeexport = func {
   if( me.dependency["electric"].getChild("specific").getValue() ) {
       me.display();
   } 
}

Inertial.testlight = func( voltage ) {
   var test = constant.FALSE;
   var light = constant.FALSE;

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        if( voltage ) {
            test = me.itself["root"][i].getNode("control/test").getValue();
        }


        # test only
        me.itself["root"][i].getNode("light/hold").setValue(test);
        me.itself["root"][i].getNode("light/insert").setValue(test);
        me.itself["root"][i].getNode("light/battery").setValue(test);


        # clear light when no voltage
        if( !me.itself["root"][i].getNode("light/alert").getValue() or !voltage ) {
            me.itself["root"][i].getNode("light/alert").setValue(test);
        }

        if( !me.itself["root"][i].getNode("light/warning").getValue() or !voltage ) {
            me.itself["root"][i].getNode("light/warning").setValue(test);
        }

        if( !me.itself["root"][i].getNode("control/remote").getValue() or !voltage ) {
            me.itself["root"][i].getNode("light/remote").setValue(test);
        }
        else {
            light = me.itself["root"][i].getNode("control/remote").getValue();
            me.itself["root"][i].getNode("light/remote").setValue(light);
        }
   }
}

Inertial.alertlight = func {
   var value = 0.0;
   var speedfps = 0.0;
   var rangenm = 0.0;
   var alert = constant.FALSE;

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        if( me.route_active() ) {
            value = me.waypoints[0].getChild("dist").getValue();
            if( value != nil and value != "" ) {
                speedfps = me.itself["root"][i].getNode("computed/ground-speed-fps").getValue();
                rangenm = speedfps * constant.MINUTETOSECOND * constant.FEETTONM;

                # alert 1 minute before track change
                if( value < rangenm ) {
                    alert = constant.TRUE;
                }
            } 
        }

        # send to all remote INS
        me.itself["root"][i].getNode("light/alert").setValue(alert);
   }
}

Inertial.display = func {
   var aligned = constant.FALSE;
   var selector = 0;
   var digit = 0;
   var value = 0.0;

   me.left = 0.0;
   me.right = 0.0;

   # may input waypoints
   me.route = me.dependency["autopilot"].getNode("route").getChildren("wp");

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        selector = me.itself["root"][i].getNode("control/selector").getValue();
        aligned = me.itself["root"][i].getNode("msu/aligned").getValue();

        me.left = me.UNKNOWN;
        me.right = me.UNKNOWN;

        # present track
        if( selector == me.SELECTORGROUND ) {
            me.right = me.itself["root"][i].getNode("computed/ground-speed-fps").getValue() * constant.FPSTOKT;

            if( me.right < me.GROUNDKT ) {
                me.left = me.noinstrument["true"].getValue();
            }
            else {
                me.left = me.trackdeg;
            }
        }

        # cross track distance
        elsif( selector == me.SELECTORHEADING ) {
            me.left = me.noinstrument["true"].getValue();
        }

        # cross track distance
        elsif( selector == me.SELECTORTRACK ) {
            me.left = me.itself["root"][i].getNode("computed/leg-course-error-nm").getValue();
            me.right = me.itself["root"][i].getNode("computed/leg-course-deviation-deg").getValue();
        }

        # current position
        elsif( selector == me.SELECTORPOS ) {
            if( aligned ) {
                me.left = me.noinstrument["position"].getChild("latitude-deg").getValue();
                me.right = me.noinstrument["position"].getChild("longitude-deg").getValue();
            }
        }

        # waypoint
        elsif( selector >= me.SELECTORWPTPOS and selector <= me.SELECTORWPTTIME ) {
            me.display_waypoint( i, selector, aligned );
        }

        # wind
        elsif( selector == me.SELECTORWIND ) {
            if( me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue() > me.GROUNDFT ) {
                me.left = me.itself["root"][i].getNode("computed/wind-from-heading-deg").getValue();
                me.right = me.itself["root"][i].getNode("computed/wind-speed-kt").getValue();
            }
        }

        # desired track & status
        elsif( selector == me.SELECTORSTATUS ) {
            me.left = me.itself["root"][i].getNode("computed/leg-true-course-deg").getValue();

            me.right = 0;
            digit = 1;

            for( var k = 5; k >= 0; k = k-1 ) {
                 value = me.itself["root"][i].getNode("msu/status[" ~ k ~ "]").getValue() * digit;
                 me.right += value;
                 digit *= 10;
            }
        }

        me.itself["root"][i].getNode("data/left").setValue(me.left);
        me.itself["root"][i].getNode("data/right").setValue(me.right);
   }
}

Inertial.display_waypoint = func( i, selector, aligned ) {
   var pos = 0;
   var value = 0.0;
   var value_str = "";
   var last_ident = "";
   var node = nil;

   var j = me.itself["root"][i].getNode("control/waypoint").getValue();
   var nbwaypoints = me.dependency["autopilot"].getNode("route/num").getValue();


   if( !me.route_active() ) {
       nbwaypoints = 0;
   }
  
   if( j <= nbwaypoints ) {
       j = j - 1;
       node = me.route[j];

       # position
       if( selector == me.SELECTORWPTPOS ) {
           me.left = node.getChild("latitude-deg").getValue();
           me.right = node.getChild("longitude-deg").getValue();
       }

       # distance and time.
       elsif( aligned ) {
           node = nil;

           # only the first 2 waypoints.
           if( j < 2 ) {
               node = me.waypoints[j];
           }

           # search for last one.
           else {
               last_ident = me.last.getChild("id").getValue();

               for( var k = 0; k < nbwaypoints; k = k+1 ) {
                    if( me.route[k].getChild("id").getValue() == last_ident ) {
                        # only if displays the last one.
                        if( k == j ) {
                            node = me.last;
                        }
                        break;
                    }
               }
           }

           if( node != nil ) {
               value = node.getChild("dist").getValue();

               # node doesn't exist, if no waypoint yet.
               if( value !=  nil ) {
                   if( value > me.MAXWPTNM ) {
                       value = me.MAXWPTNM;
                   }

                   me.left = value;

                   # replace 99:59 by 99.59, because the right display is a double.
                   value_str = node.getChild("eta").getValue();

                   pos = find(":",value_str);
                   if( pos >= 0 ) {
                       value = num(substr( value_str, 0, pos ));
                       pos = pos + 1;
                       value_str = substr( value_str, pos, size( value_str ) - pos );
                       value = value + num(value_str) * constant.MINUTETODECIMAL;
                   }
                   else {
                       value = 0.0;
                   }

                   me.right = value;
               }
           }
       }
   }
}

Inertial.track = func {
   var offsetdeg = 0.0;
   var offsetrad = 0.0;
   var distancenm = 0.0;
   var offsetnm = 0.0;
   var id = me.waypoints[0].getChild("id").getValue();

   if( me.route_active() ) {
       # new waypoint
       if( id != me.waypoint and id != nil ) {
           me.waypoint = id;

           # initial track
           me.bearingdeg = me.noinstrument["track"].getValue();
           for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
                me.itself["root"][i].getNode("computed/leg-true-course-deg").setValue(me.bearingdeg);
           }
       }

       # deviation from initial track
       if( me.waypoint != "" ) {
           me.trackdeg = me.noinstrument["track"].getValue();
           offsetdeg = me.trackdeg - me.bearingdeg;
           offsetdeg = constant.crossnorth( offsetdeg );

           distancenm = me.waypoints[0].getChild("dist").getValue();
           offsetrad = offsetdeg * constant.DEGTORAD;
           offsetnm = math.sin( offsetrad ) * distancenm;

           if( offsetnm > me.MAXXTKNM ) {
               offsetnm = me.MAXXTKNM;
           }
           elsif( offsetnm < - me.MAXXTKNM ) {
               offsetnm = - me.MAXXTKNM;
           }

           for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
                me.itself["root"][i].getNode("computed/leg-course-deviation-deg").setValue(offsetdeg);
                me.itself["root"][i].getNode("computed/leg-course-error-nm").setValue(offsetnm);
           }
       }
   }
}

Inertial.failure = func {
   var warning = constant.FALSE;
   var lastwarning = constant.FALSE;
   var path = "";
   var indication = nil;

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        lastwarning = me.itself["root"][i].getNode("light/warning").getValue();

        if( !me.itself["root"][i].getChild("serviceable").getValue() or
            !me.itself["root"][i].getNode("msu/aligned").getValue() ) {
            warning = constant.TRUE;
        }
        else {
            warning = constant.FALSE;
        }

        if( warning != lastwarning ) {
            me.itself["root"][i].getNode("light/warning").setValue( warning );

            if( warning ) {
                # blocked on last measure
                indication = me.itself["root"][i].getNode("computed/heading-failure-deg");
                indication.setValue( me.noinstrument["true"].getValue() );
            }
            else {
                indication = me.noinstrument["true"];
            }

            path = me.itself["root"][i].getNode("computed/heading-deg").getAliasTarget().getPath();
            if( path != indication ) {
                me.itself["root"][i].getNode("computed/heading-deg").unalias();
                me.itself["root"][i].getNode("computed/heading-deg").alias( indication );
            }
        }
   }
}

Inertial.alignment = func {
   var mode = 0;
   var aligned = constant.FALSE;
   var ready = constant.FALSE;
   var alignmentsec = 0.0;
   var thresholdsec = 0.0;
   var step = 0.0;
   var quality = 0.0;
   var speedup = 0.0;


   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        mode = me.itself["root"][i].getNode("msu/mode").getValue();
        aligned = me.itself["root"][i].getNode("msu/aligned").getValue();
        ready = me.itself["root"][i].getNode("msu/ready").getValue();

        if( mode == me.MODEALIGN or mode == me.MODENAV ) {
            # start new alignment
            if( mode == me.MODEALIGN ) {
                if( aligned and !ready ) {
                    aligned = constant.FALSE;
                    me.lose_alignment( i, mode );
                }
            }

            # during alignment in NAV mode, ready light is on momentarily.
            elsif( mode == me.MODENAV ) {
                if( aligned and ready ) {
                    me.reach_ready( i );
                }
            }

            # alignment in ALIGN or NAV mode.
            if( !aligned or ( aligned and mode == me.MODEALIGN ) ) {
                alignmentsec = me.itself["root"][i].getNode("msu/alignment-s").getValue();

                # ready
                thresholdsec = me.quicksec( me.ALIGNEDSEC );
                if( alignmentsec >= thresholdsec ) {
                   aligned = constant.TRUE;
                   me.reach_alignment( i );
                }
                else {
                   me.aligning( i );
                }

                # quality measured only during alignment
                thresholdsec = me.quicksec( me.QUALITYSEC );
                step = ( alignmentsec - math.mod( alignmentsec, thresholdsec ) ) / thresholdsec; 
                quality = me.QUALITYPOOR - step;
                if( quality < me.QUALITYGOOD ) {
                    quality = me.QUALITYGOOD;
                }

                me.set_quality( i, quality );

                speedup = me.noinstrument["speed-up"].getValue();
                alignmentsec = alignmentsec + speedup * me.INSSEC;
                me.itself["root"][i].getNode("msu/alignment-s").setValue( alignmentsec );
            }
        }

        # alignment is lost.
        else {
            me.lose_alignment( i, mode );
        }
   }
}

Inertial.route_active = func {
   var result = constant.FALSE;

   # autopilot/route-manager/wp is updated only once airborne
   if( me.dependency["autopilot"].getChild("active").getValue() and
       me.dependency["autopilot"].getChild("airborne").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Inertial.quicksec = func( thresholdsec ) {
   var result = thresholdsec;

   # quick alignment of INS (not real)
   if( me.dependency["quick"].getValue() ) {
       result = result / me.QUICK;
   }

   return result;
}

Inertial.reach_ready = func( index ) {
   me.itself["root"][index].getNode("msu/ready").setValue( constant.FALSE );
}

Inertial.aligning = func( index ) {
   me.set_mode( index, me.MODEALIGN );
   me.set_action( index, me.ACTIONGROUND );
}

Inertial.reach_alignment = func( index ) {
   me.itself["root"][index].getNode("msu/aligned").setValue( constant.TRUE );
   me.itself["root"][index].getNode("msu/ready").setValue( constant.TRUE );

   me.set_mode( index, me.MODENAV );
}

Inertial.lose_alignment = func( index, mode ) {
   me.itself["root"][index].getNode("msu/alignment-s").setValue( 0 );
   me.itself["root"][index].getNode("msu/aligned").setValue( constant.FALSE );
   me.itself["root"][index].getNode("msu/ready").setValue( constant.FALSE );

   me.set_mode( index, me.MODEALIGN );
   if( mode == me.MODEATT ) {
       me.set_action( index, me.ACTIONATT );
   }
   elsif( mode == me.MODEOFF ) {
       me.set_action( index, me.ACTIONOFF );
   }
   me.set_quality( index, me.QUALITYPOOR );
   me.set_index( index, me.QUALITYREADY );
}

Inertial.set_mode = func( index, mode ) {
   me.itself["root"][index].getNode("msu/status[0]").setValue( mode );
}

Inertial.set_action = func( index, action ) {
   var digit = int( action / 10 );

   me.itself["root"][index].getNode("msu/status[1]").setValue( digit );

   digit = math.mod( action, 10 );
   me.itself["root"][index].getNode("msu/status[2]").setValue( digit );
}

Inertial.set_quality = func( index, quality ) {
   me.itself["root"][index].getNode("msu/status[4]").setValue( quality );
}

Inertial.set_index = func( index, modeindex ) {
   me.itself["root"][index].getNode("msu/status[5]").setValue( modeindex );
}
