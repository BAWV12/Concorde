# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# =====
# SEATS
# =====

Seats = {};

Seats.new = func {
   var obj = { parents : [Seats,System],

               audio : AudioPanel.new(),
               rail : SeatRail.new(),

               lookup : {},
               names : {},
               nb_seats : 0,

               firstseat : constant.FALSE,
               firstseatview : 0,
               fullcockpit : constant.FALSE,

               CAPTINDEX : 0,

               floating : {},
               recoverfloating : constant.FALSE,
               last_recover : {},
               initial : {}
         };

   obj.init();

   return obj;
};

Seats.init = func {
   var child = nil;
   var name = "";

   me.inherit_system("/systems/seat");


   # retrieve the index as created by FG
   for( var i = me.CAPTINDEX; i < size(me.dependency["views"]); i=i+1 ) {
        child = me.dependency["views"][i].getChild("name");

        # nasal doesn't see yet the views of preferences.xml
        if( child != nil ) {
            name = child.getValue();
            if( name == "Engineer View" ) {
                me.save_lookup("engineer", i);
            }
            elsif( name == "Overhead View" ) {
                me.save_lookup("overhead", i);
            }
            elsif( name == "Copilot View" ) {
                me.save_lookup("copilot", i);
            }
            elsif( name == "Steward View" ) {
                 me.save_lookup("steward", i);
                 me.save_initial( "steward", me.dependency["views"][i] );
            }
            elsif( name == "Observer View" ) {
                 me.save_lookup("observer", i);
                 me.save_initial( "observer", me.dependency["views"][i] );
            }
            elsif( name == "Observer 2 View" ) {
                 me.save_lookup("observer2", i);
                 me.save_initial( "observer2", me.dependency["views"][i] );
            }
            elsif( name == "Main Gear View" ) {
                me.save_lookup("gear-main", i);
                me.save_initial( "gear-main", me.dependency["views"][i] );
            }
            elsif( name == "Front Gear View" ) {
                me.save_lookup("gear-front", i);
                me.save_initial( "gear-front", me.dependency["views"][i] );
            }
        }
   }

   # default
   me.recoverfloating = me.itself["root-ctrl"].getChild("recover").getValue();
   me.fullcockpit = me.itself["root-ctrl"].getChild("all").getValue();
}

Seats.railexport = func( name ) {
   me.rail.toggle( name );
}

Seats.fullexport = func {
   if( me.fullcockpit ) {
       me.fullcockpit = constant.FALSE;
   }
   else {
       me.fullcockpit = constant.TRUE;
   }

   me.itself["root-ctrl"].getChild("all").setValue( me.fullcockpit );
}

Seats.viewexport = func( name ) {
   var index = 0;

   me.engineerhead();

   # cannot disable captain view, because of userarchive
   if( name != "captain" ) {
       index = me.lookup[name];

       # swap to view
       if( !me.itself["root"].getChild(name).getValue() ) {
           me.dependency["current-view"].getChild("view-number").setValue(index);
           me.itself["root"].getChild(name).setValue(constant.TRUE);
           me.itself["root"].getChild("captain").setValue(constant.FALSE);

           me.dependency["views"][index].getChild("enabled").setValue(constant.TRUE);
       }

       # return to captain view
       else {
           me.dependency["current-view"].getChild("view-number").setValue(me.CAPTINDEX);
           me.itself["root"].getChild(name).setValue(constant.FALSE);
           me.itself["root"].getChild("captain").setValue(constant.TRUE);

           me.dependency["views"][index].getChild("enabled").setValue(constant.FALSE);
       }

       # disable all other views
       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            if( name != me.names[i] ) {
                me.itself["root"].getChild(me.names[i]).setValue(constant.FALSE);
   
                index = me.lookup[me.names[i]];
                me.dependency["views"][index].getChild("enabled").setValue(constant.FALSE);
            }
       }

       me.recover();
   }

   # captain view
   else {
       me.dependency["current-view"].getChild("view-number").setValue(me.CAPTINDEX);
       me.itself["root"].getChild("captain").setValue(constant.TRUE);

       # disable all other views
       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            me.itself["root"].getChild(me.names[i]).setValue(constant.FALSE);

            index = me.lookup[me.names[i]];
            me.dependency["views"][index].getChild("enabled").setValue(constant.FALSE);
       }
   }

   me.audioexport();

   me.itself["root-ctrl"].getChild("all").setValue( me.fullcockpit );
}

Seats.recoverexport = func {
   me.recoverfloating = !me.recoverfloating;
   me.itself["root-ctrl"].getChild("recover").setValue(me.recoverfloating);
}

Seats.engineerhead = func {
   # current orientation, before leaving view
   if( me.itself["root"].getChild("engineer").getValue() ) {
       # except, when 3D engineer is rotating the seat
       if( me.dependency["engineer"].getChild("seat-deg").getValue() == 0.0 ) {
           var headdeg = me.dependency["current-view"].getChild("goal-heading-offset-deg").getValue();
           me.itself["position"].getNode("engineer").getChild("heading-deg").setValue(headdeg);
       }
   }
}

Seats.scrollexport = func{
   me.stepView(1);
}

Seats.scrollreverseexport = func{
   me.stepView(-1);
}

Seats.stepView = func( step ) {
   var targetview = 0;
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            targetview = me.lookup[name];
            break;
        }
   }

   # ignores captain view
   if( targetview > me.CAPTINDEX ) {
       me.dependency["views"][me.CAPTINDEX].getChild("enabled").setValue(constant.FALSE);
   }

   view.stepView(step);

   # restores because of userarchive
   if( targetview > me.CAPTINDEX ) {
       me.dependency["views"][me.CAPTINDEX].getChild("enabled").setValue(constant.TRUE);
   }

   me.audioexport();

   me.restorefull();
}

# forwards is positiv
Seats.movelengthexport = func( step ) {
   var headdeg = 0.0;
   var prop = "";
   var sign = 0;
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       headdeg = me.dependency["current-view"].getChild("goal-heading-offset-deg").getValue();

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "z-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "z-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "x-offset-m";
           sign = -1;
       }
       else {
           prop = "x-offset-m";
           sign = 1;
       }

       pos = me.dependency["current-view"].getChild(prop).getValue();
       pos = pos + sign * step;
       me.dependency["current-view"].getChild(prop).setValue(pos);

       result = constant.TRUE;
   }

   return result;
}

# left is negativ
Seats.movewidthexport = func( step ) {
   var headdeg = 0.0;
   var prop = "";
   var sign = 0;
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       headdeg = me.dependency["current-view"].getChild("goal-heading-offset-deg").getValue();

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "x-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "x-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "z-offset-m";
           sign = 1;
       }
       else {
           prop = "z-offset-m";
           sign = -1;
       }

       pos = me.dependency["current-view"].getChild(prop).getValue();
       pos = pos + sign * step;
       me.dependency["current-view"].getChild(prop).setValue(pos);

       result = constant.TRUE;
   }

   return result;
}

# up is positiv
Seats.moveheightexport = func( step ) {
   var result = constant.FALSE;

   if( me.move() ) {
       pos = me.dependency["current-view"].getChild("y-offset-m").getValue();
       pos = pos + step;
       me.dependency["current-view"].getChild("y-offset-m").setValue(pos);

       result = constant.TRUE;
   }

   return result;
}

Seats.save_lookup = func( name, index ) {
   me.names[me.nb_seats] = name;

   me.lookup[name] = index;

   if( !me.firstseat ) {
       me.firstseatview = index;
       me.firstseat = constant.TRUE;
   }

   me.floating[name] = constant.FALSE;

   me.nb_seats = me.nb_seats + 1;
}

Seats.restorefull = func {
   var found = constant.FALSE;
   var index = me.dependency["current-view"].getChild("view-number").getValue();

   if( index == me.CAPTINDEX or index >= me.firstseatview ) {
       found = constant.TRUE;
   }

   if( found ) {
       me.itself["root-ctrl"].getChild("all").setValue( me.fullcockpit );
   }
   # systematically disable all instruments in external view
   else {
       me.itself["root-ctrl"].getChild("all").setValue( constant.FALSE );
   }
}

# backup initial position
Seats.save_initial = func( name, view ) {
   var pos = {};
   var config = view.getNode("config");

   pos["x"] = config.getChild("x-offset-m").getValue();
   pos["y"] = config.getChild("y-offset-m").getValue();
   pos["z"] = config.getChild("z-offset-m").getValue();

   me.initial[name] = pos;

   me.floating[name] = constant.TRUE;
   me.last_recover[name] = constant.FALSE;
}

Seats.initial_position = func( name ) {
   var position = me.itself["position"].getNode(name);
   var posx = me.initial[name]["x"];
   var posy = me.initial[name]["y"];
   var posz = me.initial[name]["z"];

   me.dependency["current-view"].getChild("x-offset-m").setValue(posx);
   me.dependency["current-view"].getChild("y-offset-m").setValue(posy);
   me.dependency["current-view"].getChild("z-offset-m").setValue(posz);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);
   position.getChild("z-m").setValue(posz);

   position.getChild("move").setValue(constant.FALSE);
}

Seats.last_position = func( name ) {
   var position = nil;
   var posx = 0.0;
   var posy = 0.0;
   var posz = 0.0;

   # 1st restore
   if( !me.last_recover[ name ] and me.recoverfloating ) {
       position = me.itself["position"].getNode(name);

       posx = position.getChild("x-m").getValue();
       posy = position.getChild("y-m").getValue();
       posz = position.getChild("z-m").getValue();

       if( posx != me.initial[name]["x"] or
           posy != me.initial[name]["y"] or
           posz != me.initial[name]["z"] ) {

           me.dependency["current-view"].getChild("x-offset-m").setValue(posx);
           me.dependency["current-view"].getChild("y-offset-m").setValue(posy);
           me.dependency["current-view"].getChild("z-offset-m").setValue(posz);

           position.getChild("move").setValue(constant.TRUE);
       }

       me.last_recover[ name ] = constant.TRUE;
   }
}

Seats.recover = func {
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.last_position( name );
            }
            break;
        }
   }
}

Seats.move_position = func( name ) {
   var posx = me.dependency["current-view"].getChild("x-offset-m").getValue();
   var posy = me.dependency["current-view"].getChild("y-offset-m").getValue();
   var posz = me.dependency["current-view"].getChild("z-offset-m").getValue();

   var position = me.itself["position"].getNode(name);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);
   position.getChild("z-m").setValue(posz);

   position.getChild("move").setValue(constant.TRUE);
}

Seats.move = func {
   var result = constant.FALSE;

   # saves previous position
   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.move_position( name );
                result = constant.TRUE;
            }
            break;
        }
   }

   return result;
}

# restore view
Seats.restoreexport = func {
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.initial_position( name );
            }
            break;
        }
   }
}

# restore view pitch
Seats.restorepitchexport = func {
   var index = me.dependency["current-view"].getChild("view-number").getValue();

   if( index == me.CAPTINDEX ) {
       var headingdeg = me.dependency["views"][index].getNode("config").getChild("heading-offset-deg").getValue();
       var pitchdeg = me.dependency["views"][index].getNode("config").getChild("pitch-offset-deg").getValue();

       me.dependency["current-view"].getChild("heading-offset-deg").setValue(headingdeg);
       me.dependency["current-view"].getChild("pitch-offset-deg").setValue(pitchdeg);
   }

   # only cockpit views
   else {
       var name = "";

       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            name = me.names[i];
            if( me.itself["root"].getChild(name).getValue() ) {
                var headingdeg = me.dependency["views"][index].getNode("config").getChild("heading-offset-deg").getValue();
                var pitchdeg = me.dependency["views"][index].getNode("config").getChild("pitch-offset-deg").getValue();

                me.dependency["current-view"].getChild("heading-offset-deg").setValue(headingdeg);
                me.dependency["current-view"].getChild("pitch-offset-deg").setValue(pitchdeg);
                break;
            }
        }
   }
}

Seats.audioexport = func {
   var name = "";
   var panel = constant.TRUE;
   var marker = me.dependency["current-view"].getChild("internal").getValue();

   if( me.itself["root"].getChild("captain").getValue() ) {
       name = "captain";
   }
   elsif( me.itself["root"].getChild("copilot").getValue() ) {
       name = "copilot";
   }
   elsif( me.itself["root"].getChild("engineer").getValue() ) {
       name = "engineer";
   }
   elsif( me.itself["root"].getChild("observer").getValue() ) {
       name = "observer";
   }
   else {
       panel = constant.FALSE;
   }

   me.audio.headphones( marker, panel, name );
}


# ====
# MENU
# ====

Menu = {};

Menu.new = func {
   var obj = { parents : [Menu,System],
               
# menu handles
               autopilot : nil,
               crew : nil,
               environment : {},
               fuel : nil,
               ground : nil,
               instruments : {},
               navigation : {},
               procedures : {},
               radios : nil,
               systems : nil,
               views : nil,
               voice : {},
               menu : nil
         };

   obj.init();

   return obj;
};

Menu.init = func {
   me.inherit_system("/systems/crew");

   me.menu = me.dialog( "menu" );
   me.autopilot = me.dialog( "autopilot" );
   me.crew = me.dialog( "crew" );

   me.array( me.environment, 3, "environment" );

   me.fuel = me.dialog( "fuel" );
   me.ground = me.dialog( "ground" );

   me.array( me.instruments, 3, "instruments" );

   me.array( me.navigation, 2, "navigation" );

   me.array( me.procedures, 4, "procedures" );

   me.radios = me.dialog( "radios" );
   me.systems = me.dialog( "systems" );
   me.views = me.dialog( "views" );

   me.array( me.voice, 2, "voice" );
}

Menu.dialog = func( name ) {
   var item = gui.Dialog.new(me.itself["dialogs"].getPath() ~ "/" ~ name ~ "/dialog",
                             "Aircraft/Concorde/Dialogs/Concorde-" ~ name ~ ".xml");

   return item;
}

Menu.array = func( table, max, name ) {
   var j = 0;

   for( var i = 0; i < max; i=i+1 ) {
        if( j == 0 ) {
            j = "";
        }
        else {
            j = i + 1;
        }

        table[i] = gui.Dialog.new(me.itself["dialogs"].getValue() ~ "/" ~ name ~ "[" ~ i ~ "]/dialog",
                                  "Aircraft/Concorde/Dialogs/Concorde-" ~ name ~ j ~ ".xml");
   }
}


# ========
# CREW BOX
# ========

Crewbox = {};

Crewbox.new = func {
   var obj = { parents : [Crewbox,System],

           MENUSEC : 3.0,

           timers : 0.0,

# left bottom, 1 line, 10 seconds.
           BOXX : 10,
           BOXY : 34,
           BOTTOMY : -768,
           LINEY : 20,

           lineindex : { "speedup" : 0, "checklist" : 1, "engineer" : 2, "copilot" : 3 },
           lasttext : [ "", "", "", "" ],
           textbox : [ nil, nil, nil, nil ],
           nblines : 4
         };

    obj.init();

    return obj;
};

Crewbox.init = func {
    me.inherit_system("/systems/crew");

    me.resize();

    setlistener(me.noinstrument["startup"].getPath(), crewboxresizecron);
    setlistener(me.noinstrument["speed-up"].getPath(), crewboxcron);
    setlistener(me.noinstrument["freeze"].getPath(), crewboxcron);
}

Crewbox.resize = func {
    var y = 0;
    var ysize = - me.noinstrument["startup"].getValue();

    if( ysize == nil ) {
        ysize = me.BOTTOMY;
    }

    # must clear the text, otherwise text remains after close
    me.clear();

    for( var i = 0; i < me.nblines; i = i+1 ) {
         # starts at 700 if height is 768
         y = ysize + me.BOXY + me.LINEY * i;

         # not really deleted
         if( me.textbox[i] != nil ) {
             me.textbox[i].close();
         }

         # CAUTION : duration is 0 (infinite), or one must wait that the text vanishes device;
         # otherwise, overwriting the text makes the view popup tip always visible !!!
         me.textbox[i] = screen.window.new( me.BOXX, y, 1, 0 );
    }

    me.crewtext();
    me.pausetext();
}

Crewbox.pausetext = func {
    var index = me.lineindex["speedup"];
    var speedup = 0.0;
    var red = constant.FALSE;
    var text = "";

    if( me.noinstrument["freeze"].getValue() ) {
        text = "pause";
    }
    else {
        speedup = me.noinstrument["speed-up"].getValue();
        if( speedup > 1 ) {
            text = sprintf( speedup, "3f.0" ) ~ "  t";
        }
        red = constant.TRUE;
    }

    me.sendpause( index, red, text );
}

crewboxresizecron = func {
    crewscreen.resize();
}

crewboxcron = func {
    crewscreen.pausetext();
}

Crewbox.minimizeexport = func {
    var value = me.itself["root"].getChild("minimized").getValue();

    me.itself["root"].getChild("minimized").setValue(!value);

    me.resettimer();
}

Crewbox.wakeupexport = func {
    # display is minimized by timeout, or by picking 3D crew / clue.
    if( !me.itself["root-ctrl"].getChild("timeout").getValue() and
        !me.dependency["human"].getChild("serviceable").getValue() ) {
        # wake up display
        if( me.itself["root"].getChild("minimized").getValue() ) {
            me.itself["root"].getChild("minimized").setValue(constant.FALSE);

            me.resettimer();
        }
    }
}

Crewbox.toggleexport = func {
    # 2D feedback
    if( !me.dependency["human"].getChild("serviceable").getValue() ) {
        me.itself["root"].getChild("minimized").setValue(constant.FALSE);
        me.resettimer();
    }

    # to accelerate display
    me.crewtext();
}

Crewbox.schedule = func {
    # timeout on text box
    if( me.itself["root-ctrl"].getChild("timeout").getValue() ) {
        me.timers = me.timers + me.MENUSEC;
        if( me.timers >= me.timeoutsec() ) {
            me.itself["root"].getChild("minimized").setValue(constant.TRUE);
        }
    }

    me.crewtext();
}

Crewbox.timeoutsec = func {
    var result = me.itself["root-ctrl"].getChild("timeout-s").getValue();

    if( result < me.MENUSEC ) {
        result = me.MENUSEC;
    }

    return result;
}

Crewbox.resettimer = func {
    me.timers = 0.0;

    me.crewtext();
}

Crewbox.crewtext = func {
    # text visible, only when 2D crew is minimized
    if( !me.itself["root"].getChild("minimized").getValue() ) {
        me.checklisttext();
        me.copilottext();
        me.engineertext();
    }
    else {
        me.clearcrew();
    }
}

Crewbox.checklisttext = func {
    var white = constant.FALSE;
    var text = me.dependency["voice"].getChild("callout").getValue();
    var text2 = me.dependency["voice"].getChild("checklist").getValue();
    var index = me.lineindex["checklist"];

    if( text2 == "" ) {
        text2 = me.dependency["voice"].getChild("emergency").getValue();
    }

    if( text2 != "" ) {
        text = text2 ~ " " ~ text;
        white = me.dependency["voice"].getChild("real").getValue();
    }

    # real checklist is white
    me.sendtext( index, constant.TRUE, white, text );
}

Crewbox.copilottext = func {
    var green = constant.FALSE;
    var text = me.dependency["copilot"].getChild("state").getValue();
    var index = me.lineindex["copilot"];

    if( text == "" ) {
        if( me.dependency["copilot-ctrl"].getChild("activ").getValue() ) {
            text = "copilot";
        }
    }

    if( me.dependency["copilot"].getChild("activ").getValue() or
        me.itself["root"].getChild("unexpected").getValue() ) {
        green = constant.TRUE;
    }

    me.sendtext( index, green, constant.FALSE, text );
}

Crewbox.engineertext = func {
    var green = me.dependency["engineer"].getChild("activ").getValue();
    var text = me.dependency["engineer"].getChild("state").getValue();
    var index = me.lineindex["engineer"];

    if( text == "" ) {
        if( me.dependency["engineer-ctrl"].getChild("activ").getValue() ) {
            text = "engineer";
        }
    }

    me.sendtext( index, green, constant.FALSE, text );
}

Crewbox.sendtext = func( index, green, white, text ) {
    var box = me.textbox[index];

    me.lasttext[index] = text;

    # bright white
    if( white ) {
        box.write( text, 1.0, 1.0, 1.0 );
    }

    # dark green
    elsif( green ) {
        box.write( text, 0, 0.7, 0 );
    }

    # dark yellow
    else {
        box.write( text, 0.7, 0.7, 0 );
    }
}

Crewbox.sendpause = func( index, red, text ) {
    var box = me.textbox[index];

    me.lasttext[index] = text;

    # bright red
    if( red ) {
        box.write( text, 1.0, 0, 0 );
    }
    # bright yellow
    else {
        box.write( text, 1.0, 1.0, 0 );
    }
}

Crewbox.clearcrew = func {
    for( var i = 1; i < me.nblines; i = i+1 ) {
         if( me.lasttext[i] != "" ) {
             me.lasttext[i] = "";
             me.textbox[i].write( me.lasttext[i], 0, 0, 0 );
         }
    }
}

Crewbox.clear = func {
    for( var i = 0; i < me.nblines; i = i+1 ) {
         if( me.lasttext[i] != "" ) {
             me.lasttext[i] = "";
             me.textbox[i].write( me.lasttext[i], 0, 0, 0 );
         }
    }
}


# =========
# VOICE BOX
# =========

Voicebox = {};

Voicebox.new = func {
   var obj = { parents : [Voicebox,System],

               seetext : constant.TRUE,

# centered in the vision field, 1 line, 10 seconds.
               textbox : screen.window.new( nil, -200, 1, 10 )
   };

   obj.init();

   return obj;
}

Voicebox.init = func {
   me.inherit_system("/systems/voice");
}

Voicebox.schedule = func {
   me.seetext = me.itself["root-ctrl"].getChild("text").getValue();
}

Voicebox.textexport = func {
   var feedback = "";

   if( me.seetext ) {
       feedback = "crew text off";
       me.seetext = constant.FALSE;
   }
   else {
       feedback = "crew text on";
       me.seetext = constant.TRUE;
   }

   me.sendtext( feedback, !me.seetext, constant.FALSE, constant.TRUE );
   me.itself["root-ctrl"].getChild("text").setValue(me.seetext);

   return feedback;
}

Voicebox.is_on = func {
   return me.seetext;
}

Voicebox.sendtext = func( text, engineer = 0, captain = 0, force = 0 ) {
   if( me.seetext or force ) {
       # bright blue
       if( engineer ) {
           me.textbox.write( text, 0, 1, 1 );
       }

       # bright yellow
       elsif( captain ) {
           me.textbox.write( text, 1, 1, 0 );
       }

       # bright green
       else {
           me.textbox.write( text, 0, 1, 0 );
       }
   }
}


# ==================
# DESTINATION DIALOG
# ==================

DestinationDialog = {};

DestinationDialog.new = func {
   var obj = { parents : [DestinationDialog,System],
               
               airports : {}
         };

   obj.init();

   return obj;
};

DestinationDialog.init = func {
   me.inherit_system("/systems/human");
   
   me.filldialog();
}

DestinationDialog.getnavaid = func {
   var result = "";
   var dialog = me.itself["root"].getChild("dialog").getValue();
   
   var idcomment = split( " ", dialog );
   
   if( me.itself["root-ctrl"].getNode("destination/sort").getChild("name").getValue() ) {
       # EGLL  London ==> EGLL
       result = idcomment[0];
   }
   else {
       var nbstrings = size(idcomment);
       
       # last
       result = idcomment[nbstrings-1];
   }
   
   me.itself["root-ctrl"].getChild("airport-id").setValue(result);
}

DestinationDialog.filldialog = func {
   var byDistance = constant.FALSE;
   var byName = constant.FALSE;
   var categoryRegular = constant.FALSE;
   var categoryDiversion = constant.FALSE;
   var categoryHistorical = constant.FALSE;
   var categoryOther = constant.FALSE;
   var destinationName = constant.FALSE;
   var filterNavaid = constant.TRUE;
   var filterRange = constant.TRUE;
   var has_navaid = constant.FALSE;
   var include = constant.TRUE;
   var distancemeter = 0.0;
   var distancenm = 0;
   var destination = "";
   var name = "";
   var child = nil;
   var info = nil;
   var flight = geo.aircraft_position();
   var navaid = geo.Coord.new();


   filterNavaid = me.itself["root-ctrl"].getNode("destination/filter").getChild("navaid").getValue();
   filterRange = me.itself["root-ctrl"].getNode("destination/filter").getChild("range").getValue();

   categoryRegular = me.itself["root-ctrl"].getNode("destination/category").getChild("regular").getValue();
   categoryDiversion = me.itself["root-ctrl"].getNode("destination/category").getChild("diversion").getValue();
   categoryHistorical = me.itself["root-ctrl"].getNode("destination/category").getChild("historical").getValue();
   categoryOther = me.itself["root-ctrl"].getNode("destination/category").getChild("other").getValue();
   
   destinationName = me.itself["root-ctrl"].getNode("destination").getChild("show").getValue();

   
   me.airports = {};
   
   for( var i=0; i<size(me.itself["airport"]); i=i+1 ) {
        destination = me.itself["airport"][ i ].getChild("airport-id").getValue();
        
        info = airportinfo( destination );
        if( info != nil ) {
            navaid.set_latlon( info.lat, info.lon );
            distancemeter = flight.distance_to( navaid );
            distancenm = int(distancemeter / constant.NMTOMETER);
            
            include = constant.TRUE;      
            
            child = me.itself["airport"][ i ].getChild("non-historical");
            if( child != nil ) {
                if( child.getValue() ) {
                    include = constant.FALSE;
                }
            }
            
            if( include and categoryRegular ) {
		include = me.getService( i, "regular" );
            }
            
            elsif( include and categoryDiversion ) {
		include = me.getService( i, "diversion" );
            }
            
            elsif( include and categoryHistorical ) {
		include = me.getService( i, "historical" );
            }
            
            elsif( include and categoryOther ) {
                if( me.getService( i, "regular" ) or me.getService( i, "diversion" ) or me.getService( i, "historical" ) ) {
		    include = constant.FALSE;
		}
            }
            
            if( destinationName ) {
                name = me.itself["airport"][ i ].getChild("name").getValue();
            }
            else {
                name = info.name;
            }
        
            has_navaid = constant.TRUE;   
            child = me.itself["airport"][ i ].getChild("arrival");
            if( child == nil ) {
                child = me.itself["airport"][ i ].getChild("departure");
                if( child == nil ) {
                    has_navaid = constant.FALSE;
                
                    # identify airport without navaid
                    name = name ~ " *"
                }
            }
                
            # only within radio range
            if( include and filterRange and distancenm > constantaero.RADIONM ) {
                include = constant.FALSE;
            }
            
            # only with navaids
            elsif( include and filterNavaid and !has_navaid ) {
                include = constant.FALSE;
            }
            
            if( include ) {
                me.airports[destination] = { id : destination, label : name, rangenm : distancenm };
            }
        }
        elsif( me.itself["root-ctrl"].getNode("destination").getChild("unknown").getValue() ) {
            print( "no airport info found for ", destination );
        }
   }
   
   var node = me.itself["root"].getNode("list");
   var sortedairports = {};
   
   byDistance = me.itself["root-ctrl"].getNode("destination/sort").getChild("distance").getValue();
   byName = me.itself["root-ctrl"].getNode("destination/sort").getChild("name").getValue();
   
   if( byDistance ) {
       sortedairports = sort (keys(me.airports), func (a,b) me.compare_distance(a,b));
   }
   elsif( byName ) {
       sortedairports = sort (keys(me.airports), func (a,b) cmp (me.airports[a].label, me.airports[b].label));
   }
   else {
       sortedairports = sort (keys(me.airports), func (a,b) cmp (me.airports[a].id, me.airports[b].id));
   }
   
   var k = 0;
   foreach( var ident; sortedairports ) {
       if( byDistance ) {
           name = me.airports[ident].label ~ "  " ~ me.airports[ident].rangenm ~ "  " ~ ident;
       }
       elsif( byName ) {
           name = me.airports[ident].label ~ "  " ~ ident;
       }
       else {
           name = ident ~ "  " ~ me.airports[ident].label;
       }
        
       child = node.getNode("value[" ~ k ~ "]",constant.DELAYEDNODE);
       child.setValue(name);
       
       k = k+1;
   }
   
   # remove older entries of the list on screen
   var listLength = size(me.itself["root"].getNode("list").getChildren("value"));
   for( var i=listLength-1; i>=k; i=i-1 ) {
        me.itself["root"].getNode("list").removeChild("value",i);
   }
}

DestinationDialog.getService = func( index, service ) {
   var result = constant.FALSE;
   var child = nil;
   
   child = me.itself["airport"][ index ].getChild(service);
   if( child != nil ) {
       result = child.getValue();
   }
   else {
       result = constant.FALSE;
   }
            
   return result;
}

DestinationDialog.compare_distance = func( a, b ) {
   var result = 0;
   var distancenm = 0;
   var distancenm = 0;
  
   distancenm = me.airports[a].rangenm;
   distancenm2 = me.airports[b].rangenm;
  
   if( distancenm < distancenm2 ) {
       result = -1;
   }
   elsif( distancenm > distancenm2 ) {
       result = 1;
   }
   
   return result;
}
