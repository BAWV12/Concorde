# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ================
# VIRTUAL ENGINEER
# ================

Virtualengineer = {};

Virtualengineer.new = func {
   var obj = { parents : [Virtualengineer,CommonCheck,Virtualcrew,Checklist,Emergency,System], 

               airbleedsystem : nil,
               autopilotsystem : nil,
               electricalsystem : nil,
               enginesystem : nil,
               fuelsystem : nil,
               hydraulicsystem : nil,
               voicecrew : nil,

               navigation : Navigation.new(),
               nightlighting : Nightlighting.new(),
               nightlighting2 : Nightlighting.new(),
               radiomanagement : RadioManagement.new(),
               radiomanagement2 : RadioManagement.new(),
               destination : DestinationDialog.new(),

               FUELSEC : 15.0,
               CRUISESEC : 10.0,
               TAKEOFFSEC : 5.0,
               REHEATSEC : 4.0,

               rates : 0.0,

               SAFEFT : 1500.0,

               aglft : 0.0,

               CLIMBFPM : 100,
               DESCENTFPM : -100,

               speedfpm : 0.0,

               CRUISEMACH : 1.95,
               SONICMACH : 1.0,

               speedmach : 0.0,

               ANTIICEOFF : 0,
 
               MAXPERCENT : 53.6,                                # maximum on ground
               CGPERCENT : 0.25,                                 # checklist

               FOGMETER : 1000,                                  # visibility

               RESETKG : 0,
               
               FOGDEGC : -3,
               ICEDEGC : 0
         };

    obj.init();

    return obj;
}

Virtualengineer.init = func {
    var path = "/systems/engineer";

    me.inherit_system(path);
    me.inherit_checklist(path);
    me.inherit_emergency(path);
    me.inherit_virtualcrew(path);
    me.inherit_commoncheck(path);

    settimer( func { me.setweighthuman(); }, me.CRUISESEC );
}

Virtualengineer.set_relation = func( airbleed, autopilot, electrical, engine, fuel, hydraulic, lighting, voice ) {
    me.airbleedsystem = airbleed;
    me.autopilotsystem = autopilot;
    me.electricalsystem = electrical;
    me.enginesystem = engine;
    me.fuelsystem = fuel;
    me.hydraulicsystem = hydraulic;
    me.voicecrew = voice;

    me.nightlighting.set_relation( lighting );
    me.nightlighting2.set_relation( lighting );

    me.radiomanagement.set_relation( autopilot );
    me.radiomanagement2.set_relation( autopilot );
}

Virtualengineer.toggleexport = func {
    var launch = constant.FALSE;

    if( !me.itself["root-ctrl"].getChild("activ").getValue() ) {
        launch = constant.TRUE;
    }
 
    me.itself["root-ctrl"].getChild("activ").setValue(launch);

    if( launch and !me.is_running() ) {
        # must switch lights again
        me.nightlighting.set_task();
        me.nightlighting2.set_task();

        me.radiomanagement.set_task();
        me.radiomanagement2.set_task();

        me.schedule();
        me.slowschedule();
    }
}

Virtualengineer.radioexport = func( arrival ) {
    me.radiomanagement.radioexport( arrival );
}

Virtualengineer.ordernavaidexport = func {
   me.destination.filldialog();
}

Virtualengineer.getnavaidexport = func {
   me.destination.getnavaid();
}

Virtualengineer.reheatexport = func {
    # at first engine 2 3.
    if( !me.has_reheat() ) {
        for( var i = constantaero.ENGINE2; i <= constantaero.ENGINE3 ; i = i+1 ) {
             me.dependency["engine-ctrl"][i].getChild("reheat").setValue( constant.TRUE );
        }
 
        me.toggleclick("reheat-2-3");

        # then, engineer sets engines 1 4.
        settimer(func { me.reheatcron(); }, me.REHEATSEC);
    }

    else {
        for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
             me.dependency["engine-ctrl"][i].getChild("reheat").setValue( constant.FALSE );
        }
 
        me.toggleclick("reheat-off");
    }
}

Virtualengineer.reheatcron = func {
    if( me.has_reheat() ) {
        me.dependency["engine-ctrl"][constantaero.ENGINE1].getChild("reheat").setValue( constant.TRUE );
        me.dependency["engine-ctrl"][constantaero.ENGINE4].getChild("reheat").setValue( constant.TRUE );
 
        me.toggleclick("reheat-1-4");
    }
}

Virtualengineer.veryslowschedule = func {
    me.navigation.schedule();
}

Virtualengineer.slowschedule = func {
    me.reset();

    me.rates = me.FUELSEC;

    if( me.itself["root"].getChild("serviceable").getValue() ) {
        me.speedfpm = me.dependency["ivsi"].getChild("indicated-speed-fps").getValue() * constant.MINUTETOSECOND;

        # a slow change is more natural.
        me.fuel();

        me.timestamp();
    }

    me.runslow();
}

Virtualengineer.schedule = func {
    me.reset();

    me.rates = me.CRUISESEC;

    if( me.itself["root"].getChild("serviceable").getValue() ) {
        me.supervisor();
    }
    else {
        me.itself["root"].getChild("activ").setValue(constant.FALSE);
    }

    me.run();
}

Virtualengineer.run = func {
    if( me.itself["root-ctrl"].getChild("activ").getValue() ) {
        me.set_running();

        me.rates = me.speed_ratesec( me.rates );
        settimer( func { me.schedule(); }, me.rates );
    }
}

Virtualengineer.runslow = func {
    if( me.itself["root-ctrl"].getChild("activ").getValue() ) {
        me.rates = me.speed_ratesec( me.rates );
        settimer( func { me.slowschedule(); }, me.rates );
    }
}

Virtualengineer.supervisor = func {
    if( me.itself["root-ctrl"].getChild("activ").getValue() ) {
        me.rates = me.TAKEOFFSEC;

        me.airspeedperception( constant.FALSE );
        me.speedmach = me.noinstrument["mach"].getValue();
        me.aglft = me.noinstrument["agl"].getValue();
        me.altitudeperception( constant.FALSE );

        me.set_checklist();
        me.set_emergency();


        # normal
        if( me.is_beforetakeoff() ) {
            me.set_activ();
            me.beforetakeoff();
            me.rates = me.TAKEOFFSEC;
        }

        elsif( me.is_taxi() ) {
            me.set_activ();
            me.taxi( constant.TRUE );
        }

        elsif( me.is_afterstart() ) {
            me.set_activ();
            me.afterstart();
        }

        elsif( me.is_pushback() ) {
            me.set_activ();
            me.pushback();
        }

        elsif( me.is_enginestart() ) {
            me.set_activ();
            me.enginestart();
        }

        elsif( me.is_beforestart() ) {
            me.set_activ();
            me.beforestart();
        }

        elsif( me.is_cockpit() ) {
            me.set_activ();
            me.cockpit();
        }

        elsif( me.is_preliminary() ) {
            me.set_activ();
            me.preliminary();
        }

        elsif( me.is_external() ) {
            me.set_activ();
            me.external();
        }

        elsif( me.is_stopover() ) {
            me.set_activ();
            me.stopover();
        }

        elsif( me.is_parking() ) {
            me.set_activ();
            me.parking();
        }

        elsif( me.is_afterlanding() ) {
            me.set_activ();
            me.afterlanding();
        }

        elsif( me.is_beforelanding() ) {
            me.set_activ();
            me.beforelanding();
        }

        elsif( me.is_approach() ) {
            me.set_activ();
            me.approach();
            me.rates = me.TAKEOFFSEC;
        }

        elsif( me.is_descent() ) {
            me.set_activ();
            me.descent();
        }

        elsif( me.is_transsonic() ) {
            me.set_activ();
            me.transsonic();
        }

        elsif( me.is_climb() ) {
            me.set_activ();
            me.climb();
        }

        elsif( me.is_aftertakeoff() ) {
            me.set_activ();
            me.aftertakeoff();
            me.rates = me.TAKEOFFSEC;
        }


        # emergency
        elsif( me.is_fourengineflameout() ) {
            me.set_activ();
            me.fourengineflameout();
        }

        elsif( me.is_fourengineflameoutmach1() ) {
            me.set_activ();
            me.fourengineflameoutmach1();
        }


        me.allways();

        me.rates = me.randoms( me.rates );

        me.timestamp();
    }

    me.itself["root"].getChild("activ").setValue(me.is_activ());
}


# ------
# FLIGHT
# ------
Virtualengineer.allways = func {
    me.setweight();

    me.nightlighting.engineer( me );
    me.radiomanagement.engineer( me );

    if( me.is_busy() ) {
        me.nightlighting2.captain( me );
        me.radiomanagement2.captain( me );
    }

    me.allinsready();
}

Virtualengineer.aftertakeoff = func {
    if( me.aglft > constantaero.REHEATFT or me.speedkt >= constantaero.APPROACHKT ) {
        me.reheatcut();
    }

    if( me.aglft > constantaero.CLIMBFT ) {
        me.enginerating( constantaero.RATINGFLIGHT );

        if( me.has_completed() ) {
            me.voicecrew.engineercheck( "completed" );
            me.voicecrew.nochecklistinit();
        }
    }
}

Virtualengineer.climb = func {
    me.setenginecontrol( constantaero.SCHEDULENORMAL );

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.transsonic = func {
    me.staticheater( constant.FALSE );

    me.engineantiicing( constant.FALSE );
    me.wingantiicing( constant.FALSE );

    if( me.can() ) {
        if( me.is_cruising() ) {
            me.reheatcut();
        }

        # waits
        else {
            me.done_allways();
        }
    }

    if( me.can() ) {
        if( me.altitudeft > constantaero.CRUISEFT ) {
            me.flightrating( constantaero.RATINGCRUISE );
        }

        # waits
        else {
            me.done_allways();
        }
    }

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.cruiseclimbinit();
    }
}

Virtualengineer.descent = func {
    me.flightrating( constantaero.RATINGCLIMB );

    me.staticheater( constant.TRUE );

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.approach = func {
    me.setenginecontrol( constantaero.SCHEDULEAPPROACH );

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.beforelanding = func {
    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}


# ------
# GROUND
# ------
Virtualengineer.afterlanding = func {
    me.groundidle( constant.TRUE );
    me.autoignition( constant.FALSE );

    me.taxioutboard();

    # because of engine shutdown
    me.cancelaudio();

    me.staticheater( constant.FALSE );
    me.airdataheater( constant.FALSE );
    me.drainmastheater( constant.FALSE );

    me.engineantiicing( constant.FALSE );
    me.wingantiicing( constant.FALSE );

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.parking = func {
    me.groundpower( constant.TRUE );

    me.throttleidle();

    me.waitgroundpowerbreaker( constant.TRUE );

    # must wait for nose raise (copilot)
    if( me.dependency["nose"].getValue() > constantaero.NOSEUP ) {
        me.done();
    }

    me.shutengines();
    me.throttlemaster( constant.TRUE );

    me.anticollision( constant.FALSE );
    me.engineantiicing( constant.FALSE );
    me.autoignition( constant.FALSE );

    me.shutairbleeds();
    me.airconditioning( constant.TRUE );

    me.battery( constant.FALSE );

    me.ins( constantaero.INS3, constantaero.INSALIGN );

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.stopover = func {
    if( me.is_startup() ) {
        me.autoignition( constant.FALSE );
        me.shutengines();

        if( me.can() ) {
            me.not_startup();
        }
    }

    me.adc( constant.FALSE );
    me.allins( constantaero.INSOFF );

    me.groundpowerbreaker( constant.FALSE );

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.external = func {
    # check availability of connections
    me.groundpower( constant.FALSE );
    me.airconditioning( constant.FALSE );
    me.airbleed();

    if( me.has_completed() ) {
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.preliminary = func {
    me.waitgroundpowerbreaker( constant.TRUE );

    # because of electrical power
    me.cancelaudio();

    if( me.dependency["temperature"].getValue() < me.ICEDEGC ) {
        me.drainmastheater( constant.TRUE );
    }

    me.ins( constantaero.INS1, constantaero.INSALIGN );
    me.ins( constantaero.INS3, constantaero.INSALIGN );
    me.ins( constantaero.INS2, constantaero.INSALIGN );

    me.adc( constant.TRUE );

    if( me.has_completed() ) {
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.cockpit = func {
    me.flightrating( constantaero.RATINGCLIMB );
    me.throttlemaster( constant.TRUE );
    me.autoignition( constant.FALSE );
    me.enginerating( constantaero.RATINGTAKEOFF );

    me.ins( constantaero.INS1, constantaero.INSALIGN );
    me.ins( constantaero.INS3, constantaero.INSALIGN );
    me.ins( constantaero.INS2, constantaero.INSALIGN );

    me.compass();

    me.crossbleedvalve( constantaero.ENGINE1, constant.FALSE );
    me.crossbleedvalve( constantaero.ENGINE2, constant.TRUE );
    me.crossbleedvalve( constantaero.ENGINE3, constant.TRUE );
    me.crossbleedvalve( constantaero.ENGINE4, constant.FALSE );

    me.fuelconsumed();

    if( me.has_completed() ) {
        me.voicecrew.nochecklistinit();
    }
}

Virtualengineer.beforestart = func {
    me.throttleidle();
    me.throttlemaster( constant.FALSE );

    me.battery( constant.TRUE );
    me.anticollision( constant.TRUE );

    if( me.has_completed() ) {
        if( !me.wait_ground() ) {
            me.voicecrew.engineercheck( "clearance" );

            # must wait for ground answer
            me.done_ground();
        }
    
        else {
            me.voicecrew.engineercheck( "clear" );

            me.reset_ground();
            me.voicecrew.nochecklistinit();
        }
    }
}

Virtualengineer.enginestart = func {
    me.startengine( constantaero.ENGINE3 );
    me.startengine( constantaero.ENGINE4 );

    me.startengine( constantaero.ENGINE2 );
    me.startengine( constantaero.ENGINE1 );

    if( me.has_completed() ) {
        me.voicecrew.startedinit();
    }
}

Virtualengineer.pushback = func {
    me.startengine( constantaero.ENGINE3 );
    me.startengine( constantaero.ENGINE2 );

    me.crossbleedvalve( constantaero.ENGINE2, constant.TRUE );
    me.crossbleedvalve( constantaero.ENGINE3, constant.TRUE );

    if( me.dependency["tractor"].getChild("engine14").getValue() ) {
        me.crossbleedvalve( constantaero.ENGINE4, constant.TRUE );
        me.startengine( constantaero.ENGINE4 );

        me.crossbleedvalve( constantaero.ENGINE1, constant.TRUE );
        me.startengine( constantaero.ENGINE1 );

        me.completed();
    }

    # waits for pushback
    else {
        me.done();
    }

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.startedinit();
    }
}

Virtualengineer.afterstart = func {
    me.groundidle( constant.TRUE );

    if( me.noinstrument["temperature"].getValue() < me.FOGDEGC and
        me.noinstrument["visibility"].getValue() < me.FOGMETER ) {
        me.engineantiicing( constant.TRUE );
    }

    # should do it
    me.waitgroundpowerbreaker( constant.FALSE );

    if( me.can() ) {
        if( !me.is_completed() ) {
            me.completed();
        }
    }
}

Virtualengineer.taxi = func( callout ) {
    me.enginerating( constantaero.RATINGTAKEOFF );
    me.autoignition( constant.TRUE );

    me.drainmastheater( constant.TRUE );

    me.flightrating( constantaero.RATINGCLIMB );

    me.staticheater( constant.TRUE );
    me.airdataheater( constant.FALSE );

    # normal or flyover at takeoff
    me.setenginecontrol( constantaero.SCHEDULENORMAL );

    if( callout ) {
        if( me.has_completed() ) {
            me.voicecrew.engineercheck( "completed" );
            me.voicecrew.runwayinit();
        }
    }
}

Virtualengineer.beforetakeoff = func {
    # not ready at FG launch
    me.taxi( constant.FALSE );

    me.groundidle( constant.FALSE );

    if( me.has_completed() ) {
        me.voicecrew.engineercheck( "completed" );
        me.voicecrew.nochecklistinit();
    }
}


# ---------
# EMERGENCY
# ---------
Virtualengineer.fourengineflameout = func {
    if( !me.allenginesrunning() ) {
        # easier to work
        me.cancelaudio();

        me.unguardrat( constantaero.AP2 );
        me.deployrat( constantaero.AP2 );

        me.throttleidle();
        me.autoignition( constant.FALSE );
        me.throttlemaster( constant.FALSE );
        me.relightallengines( constant.TRUE );

        me.emergencyenginestart( constantaero.ENGINE2 );
        me.emergencyenginestart( constantaero.ENGINE4 );
        me.emergencyenginestart( constantaero.ENGINE3 );
        me.emergencyenginestart( constantaero.ENGINE1 );
    }

    # restores situation, before emergency
    else {
        me.emergencyrelight( -1 );
        me.relightallengines( constant.FALSE );
        me.autoignition( constant.TRUE );
    }

    if( me.has_completed() ) {
        me.voicecrew.noemergencyinit();
    }
}

Virtualengineer.fourengineflameoutmach1 = func {
    if( !me.allenginesrunning() ) {
        # easier to work
        me.cancelaudio();

        me.throttleidle();
        me.autoignition( constant.FALSE );
        me.relightallengines( constant.TRUE );

        me.emergencyenginestart( constantaero.ENGINE2 );
        me.emergencyenginestart( constantaero.ENGINE4 );
        me.emergencyenginestart( constantaero.ENGINE3 );
        me.emergencyenginestart( constantaero.ENGINE1 );
    }

    # restores situation, before emergency
    else {
        me.emergencyrelight( -1 );
        me.relightallengines( constant.FALSE );
        me.autoignition( constant.TRUE );
    }

    if( me.has_completed() ) {
        me.voicecrew.noemergencyinit();
    }
}


# -------
# ENGINES
# -------
Virtualengineer.taxioutboard = func {
    # optional in checklist
    if( me.dependency["crew-ctrl"].getChild("stop-engine23").getValue() ) {
        for( i = constantaero.ENGINE2; i <= constantaero.ENGINE3; i=i+1 ) {
             if( me.can() ) {
                 # taxi with outboard engines
                 me.hpvalve( i, constant.FALSE );
             }
         }
    }
    else {
        me.voicecrew.terminalinit();
    }
}

Virtualengineer.groundidle = func( set ) {
    if( me.can() ) {
        var path = "";

        path = "ground-idle14";

        if( me.dependency["engine-all"].getChild(path).getValue() != set ) {
            me.dependency["engine-all"].getChild(path).setValue( set );
        }

        path = "ground-idle23";

        if( me.dependency["engine-all"].getChild(path).getValue() != set ) {
            me.dependency["engine-all"].getChild(path).setValue( set );
        }
    }
}

Virtualengineer.reheatcut = func {
    if( me.can() ) {
        if( me.has_reheat() ) {
            me.reheatexport();
        }
    }
}

Virtualengineer.has_reheat = func {
    var augmentation = constant.FALSE;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.dependency["engine-ctrl"][i].getChild("reheat").getValue() ) {
             augmentation = constant.TRUE;
             break;
         }
    }

    return augmentation;
}

Virtualengineer.hpvalve = func( index, set ) {
    if( me.can() ) {
        if( me.dependency["engine-ctrl"][index].getChild("hp-valve").getValue() != set ) {
            me.dependency["engine-ctrl"][index].getChild("hp-valve").setValue( set );
            me.toggleclick("hp-valve-" ~ index);
        }
    }
}

Virtualengineer.autoignition = func( set ) {
    if( me.can() ) {
        for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
             if( me.dependency["engine-ctrl"][i].getChild("autoignition").getValue() != set ) {
                 me.dependency["engine-ctrl"][i].getChild("autoignition").setValue( set );
                 me.toggleclick("autoignition-" ~ i);
                 break;
             }
        }
    }
}

Virtualengineer.enginestarter = func( index ) {
    if( me.can() ) {
        if( !me.dependency["engine-ctrl"][index].getChild("starter").getValue() ) {
            me.enginesystem.starter( index );
            me.toggleclick("starter-" ~ index);
        }
    }
}

Virtualengineer.flightrating = func( flight ) {
    if( me.can() ) {
        var flightnow = "";

        for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
             flightnow = me.dependency["engine-ctrl"][i].getChild("rating-flight").getValue();
             if( flightnow != flight ) {
                 me.dependency["engine-ctrl"][i].getChild("rating-flight").setValue(flight);
                 me.toggleclick("rating-" ~ i ~ "-" ~ flight);
                 break;
             }
        }
    }
}

Virtualengineer.enginerating = func( rating ) {
    if( me.can() ) {
        var ratingnow = "";

        for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
             ratingnow = me.dependency["engine-ctrl"][i].getChild("rating").getValue();
             if( ratingnow != rating and rating == constantaero.RATINGFLIGHT ) {
                 if( !me.dependency["gear-ctrl"].getChild("gear-down").getValue() ) {
                     me.dependency["engine-ctrl"][i].getChild("rating").setValue(rating);
                     me.toggleclick("rating-" ~ i ~ "-" ~ rating);
                     break;
                 }
             }
        }
    }
}

Virtualengineer.setenginecontrol = func( set ) {
    if( me.can() ) {
        if( !me.dependency["engine-all"].getChild("schedule-auto").getValue() ) {
            me.dependency["engine-all"].getChild("schedule-auto").setValue( constant.TRUE );
            me.toggleclick("engine-sched-auto");
        }

        elsif( me.dependency["engine-all"].getChild("schedule").getValue() != set ) {
            me.dependency["engine-all"].getChild("schedule").setValue( set );
            me.toggleclick("engine-schedule");
        }
    }
}

Virtualengineer.shutengines = func {
    if( me.can() ) {
        for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
             me.hpvalve( i, constant.FALSE );
        }
    }
}

Virtualengineer.startengine = func( index ) {
    me.crossbleedvalve( index, constant.TRUE );

    if( me.can() ) {
        if( !me.dependency["engine"][index].getChild("running").getValue() ) {
            me.enginestarter( index );
            me.hpvalve( index, constant.TRUE );
        }

        # waits for shut of start valve
        if( me.can() )  {
           if( me.dependency["engine-ctrl"][index].getChild("starter").getValue() ) {
               me.done();
           }

           else {
               me.bleedvalve( index, constant.TRUE );
           }
        }
    }
}

Virtualengineer.emergencyenginestart = func( index ) {
    if( me.can() ) {
        if( !me.dependency["engine"][index].getChild("running").getValue() ) {
            var set = me.electricalsystem.enginerelightexport( index );

            me.emergencyrelight( set );
            me.hpvalve( index, constant.TRUE );

            # waits for engine running
            if( me.can() ) {
                me.done();
            }
        }
    }
}

Virtualengineer.relightallengines = func( set ) {
    if( me.can() ) {
        for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
             me.relightengine( i, set );
        }
    }
}

Virtualengineer.relightengine = func( index, set ) {
    if( me.can() ) {
        if( me.dependency["engine-sys"][index].getChild("relight").getValue() != set ) {
            me.enginesystem.relight( index, set );
            me.toggleclick("relight-" ~ index);
        }
    }
}

Virtualengineer.throttleidle = func {
    if( me.can() ) {
        var found = constant.FALSE;

        for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
             if( me.dependency["engine-ctrl"][i].getChild("throttle-manual").getValue() != constantaero.THROTTLEIDLE ) {
                 me.enginesystem.set_throttle( constantaero.THROTTLEIDLE );
                 found = constant.TRUE;
             }
        }

        # the 4 levers at once
        if( found ) {
            me.done("idle");
        }
    }
}

Virtualengineer.throttlemaster = func( set ) {
    if( me.can() ) {
        for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
             if( me.dependency["throttle"][i].getChild("off").getValue() != set ) {
                 me.dependency["throttle"][i].getChild("off").setValue( set );
                 me.toggleclick("throttle-master-" ~ i);
                 break;
             }
        }
    }
}

Virtualengineer.allenginesrunning = func {
    var result = constant.TRUE;

    for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
         if( !me.dependency["engine"][i].getChild("running").getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}


# ----------
# NAVIGATION
# ----------
Virtualengineer.allins = func( mode ) {
    for( var i = 0; i < constantaero.NBINS; i = i + 1 ) {
         me.ins( i, mode );
    }
}

Virtualengineer.allinsready = func {
    for( var i = 0; i < constantaero.NBINS; i = i + 1 ) {
         me.insready( i );
    }
}

Virtualengineer.insready = func( index ) {
    if( me.can() ) {
        if( me.dependency["ins"][index].getNode("msu").getChild("aligned").getValue() ) {
            var INSNAV = 1;

            if( me.dependency["ins"][index].getNode("msu").getChild("mode").getValue() != INSNAV ) {
                # highest quality
                if( me.dependency["ins"][index].getNode("msu/status[4]").getValue() == 1 ) {
                    me.dependency["ins"][index].getNode("msu").getChild("mode").setValue( INSNAV );
                    me.toggleclick("ins-ready-" ~ index);
                }
            }
        }
    }
}

Virtualengineer.compass = func {
    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i + 1 ) {
         if( me.can() ) {
             if( me.dependency["compass"][i].getChild("mode-dg").getValue() ) {
                 me.dependency["compass"][i].getChild("mode-dg").setValue( constant.FALSE );
                 me.toggleclick("mode-dg-" ~ i);
             }
         }
    }
}

Virtualengineer.adc = func( set ) {
    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i + 1 ) {
         if( me.can() ) {
             if( me.dependency["adc"][i].getChild("switch").getValue() != set ) {
                 me.dependency["adc"][i].getChild("switch").setValue( set );
                 me.toggleclick("adc-" ~ i);
             }
         }
    }
}


# -----
# ICING
# -----
Virtualengineer.airdataheater = func( set ) {
}

Virtualengineer.drainmastheater = func( set ) {
    var path = "";

    for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
         if( me.can() ) {
             path = "mast/heater[" ~ i ~ "]";

             if( me.dependency["anti-icing"].getNode(path).getValue() != set ) {
                 me.dependency["anti-icing"].getNode(path).setValue( set );
                 me.toggleclick("icing-mast-" ~ i);
                 break;
             }
         }
    }
}

Virtualengineer.staticheater = func( set ) {
    var path = "";

    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         if( me.can() ) {
             path = "static/heater[" ~ i ~ "]";

             if( me.dependency["anti-icing"].getNode(path).getValue() != set ) {
                 if( set and me.is_supersonic() ) {
                     # waits
                     me.done_allways();
                 }

                 else {
                     me.dependency["anti-icing"].getNode(path).setValue( set );
                     me.toggleclick("icing-static-" ~ i);
                 }

                 break;
             }
         }
    }
}

Virtualengineer.engineantiicing = func( set ) {
    var child = nil;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.can() ) {
             child = me.dependency["anti-icing"].getChild("engine",i);

             if( child.getChild("inlet-vane").getValue() != set ) {
                 child.getChild("inlet-vane").setValue( set );
                 me.toggleclick("icing-engine-" ~ i);
                 break;
             }
         }
    }
}

Virtualengineer.wingantiicing = func( set ) {
    var path = "";

    if( me.can() ) {
        path = "wing/main-selector";

        if( me.dependency["anti-icing"].getNode(path).getValue() != set ) {
            me.dependency["anti-icing"].getNode(path).setValue( set );
            me.toggleclick("icing-main-" ~ i);
        }
    }

    if( me.can() ) {
        path = "wing/alternate-selector";

        if( me.dependency["anti-icing"].getNode(path).getValue() != set ) {
            me.dependency["anti-icing"].getNode(path).setValue( set );
            me.toggleclick("icing-alt-" ~ i);
        }
    }
}


# --------
# LIGHTING
# --------
Virtualengineer.anticollision = func( set ) {
    if( me.can() ) {
        if( me.dependency["lighting"].getChild("strobe").getValue() != set ) {
            me.dependency["lighting"].getChild("strobe").setValue( set );
            me.toggleclick("anti-collision");
        }
    }
}


# ---
# MWS
# ---
Virtualengineer.cancelaudio = func {
    if( me.can() ) {
        if( !me.dependency["audio"].getChild("cancel").getValue() ) {
            me.dependency["audio"].getChild("cancel").setValue(constant.TRUE);
            me.toggleclick("cancel-audio");
        }
    }
}


# ----------
# ELECTRICAL
# ----------
Virtualengineer.groundpower = func( call ) {
    if( me.can() ) {
        if( !me.electricalsystem.has_ground() ) {
            if( !me.wait_ground() and call ) {
                 me.voicecrew.engineercheck( "ground power" );

                 # must wait for electrical system run (ground)
                 me.done_ground();
            }

            else  {
                 me.electricalsystem.groundserviceexport();

                 me.reset_ground();
                 me.done();
            }
        }

        elsif( !me.dependency["gear-ctrl"].getChild("wheel-chocks").getValue() ) {
            if( !me.wait_ground() and call ) {
                # must wait for wheel chocks (ground)
                me.done_ground();
            }

            else  {
                me.dependency["gear-ctrl"].getChild("wheel-chocks").setValue( constant.TRUE );

                me.reset_ground();
                me.done();
           }
        }
    }
}

Virtualengineer.waitgroundpowerbreaker = func( value ) {
    if( me.electricalsystem.has_ground() == value ) {
        me.groundpowerbreaker( value );
    }

    # waits for electrical power
    else {
        me.done();
    }
}

Virtualengineer.groundpowerbreaker = func( value ) {
    if( me.can() ) {
        if( me.dependency["electric-ac"].getChild("gpb").getValue() != value ) {
            me.dependency["electric-ac"].getChild("gpb").setValue( value );
            me.toggleclick("ground-power");
        }
    }
}

Virtualengineer.battery = func( set ) {
    if( me.can() ) {
        for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i + 1 ) {
             if( me.dependency["electric-dc"].getChild("master-bat",i).getValue() != set ) {
                 me.dependency["electric-dc"].getChild("master-bat",i).setValue( set );
                 me.toggleclick("battery-" ~ i);
                 break;
             }
        }
    }
}

Virtualengineer.emergencyrelight = func( set ) {
    if( me.can() ) {
        if( me.dependency["electric-ac"].getNode("emergency").getChild("relight-selector").getValue() != set ) {
            me.dependency["electric-ac"].getNode("emergency").getChild("relight-selector").setValue( set );
            me.electricalsystem.emergencyrelightexport();
            me.toggleclick("emerg-relight-" ~ set);
        }
    }
}


# ---------
# AIR BLEED
# ---------
Virtualengineer.airconditioning = func( call ) {
    if( me.can() ) {
        if( !me.airbleedsystem.has_reargroundservice() ) {
            if( !me.wait_ground() and call ) {
                me.voicecrew.engineercheck( "air conditioning" );

                # must wait for temperature system run (ground)
                me.done_ground();
            }

            else  {
                 me.airbleedsystem.reargroundserviceexport();

                 me.reset_ground();
                 me.done();
            }
        }
    }
}

Virtualengineer.airbleed = func {
    if( me.can() ) {
        if( !me.airbleedsystem.has_groundservice() ) {
            me.airbleedsystem.groundserviceexport();

            me.done();
        }
    }
}

Virtualengineer.shutairbleeds = func {
    if( me.can() ) {
        for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
             if( me.can() ) {
                 me.bleedvalve( i, constant.FALSE );
             }
        }
    }
}

Virtualengineer.bleedvalve = func( index, set ) {
    if( me.can() ) {
        if( me.dependency["air-bleed"][index].getChild("bleed-valve").getValue() != set ) {
            me.dependency["air-bleed"][index].getChild("bleed-valve").setValue( set );
            me.toggleclick("bleed-valve-" ~ index);
        }
    }
}

Virtualengineer.crossbleedvalve = func( index, set ) {
    if( me.can() ) {
        if( me.dependency["air-bleed"][index].getChild("cross-bleed-valve").getValue() != set ) {
            me.dependency["air-bleed"][index].getChild("cross-bleed-valve").setValue( set );
            me.toggleclick("cross-bleed-valve-" ~ index);
        }
    }
}


# ----------
# HYDRAULICS
# ----------
Virtualengineer.unguardrat = func( index ) {
    if( me.can() ) {
        if( me.dependency["rat"][index].getChild("guard").getValue() ) {
            me.dependency["rat"][index].getChild("guard").setValue( constant.FALSE );
            me.toggleclick("rat-guard-" ~ index);
        }
    }
}

Virtualengineer.deployrat = func( index ) {
    if( me.can() ) {
        if( !me.dependency["rat"][index].getChild("on").getValue() ) {
            me.dependency["rat"][index].getChild("on").setValue( constant.TRUE );
            me.hydraulicsystem.ratdeployexport();
            me.toggleclick("rat-" ~ index);
        }
    }
}


# ----
# FUEL
# ----

# set weight datum
Virtualengineer.setweight = func {
    if( me.can() ) {

        # after fuel loading
        var reset = me.dependency["fuel-sys"].getChild("reset").getValue();

        # after 1 reset of fuel consumed
        if( !reset ) {
            for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
                 if( me.dependency["fuel-consumed"][i].getChild("reset").getValue() ) {
                     reset = constant.TRUE;
                     break;
                 }
            }
        }

        if( reset ) {
            me.setweighthuman();
            me.toggleclick("set-weight");
        }
    }
}

Virtualengineer.setweighthuman = func {
    var totallb = me.dependency["fuel"].getChild("total-lbs").getValue();

    me.fuelsystem.setweighthuman( totallb * constant.LBTOKG );
}

Virtualengineer.fuel = func {
    if( me.can() ) {
        var engine = constant.FALSE;
        var forward = constant.FALSE;
        var aft = constant.FALSE;
        var afttrim = constant.FALSE;
        var max = 0.0;
        var min = 0.0;
        var cg = 0.0;
        var mean = 0.0;
        var offset = 0.0;

        if( me.dependency["cg"].getChild("serviceable").getValue() ) {
            max = me.dependency["cg"].getChild("max-percent").getValue();
            min = me.dependency["cg"].getChild("min-percent").getValue();
            cg = me.dependency["cg"].getChild("percent").getValue();

            engine = constant.FALSE;
            afttrim = constant.FALSE;

            # emergency
            if( cg < min ) {
                me.log("below-min");
                aft = constant.TRUE;
                engine = constant.TRUE;
                afttrim = constant.TRUE;
            }
            elsif( cg > max ) {
                me.log("above-max");
                forward = constant.TRUE;
                engine = constant.TRUE;
            }

            # above 250 kt beyond 10000 ft
            elsif( me.noinstrument["altitude"].getValue() > constantaero.APPROACHFT ) {
                # anticipates aft shift
                if( me.is_climbing() and me.is_subsonic() ) {
                    mean = min + ( max - min ) / ( 3 / 4 );
                }

                # anticipates forwards shift
                elsif( me.is_descending() and me.is_subsonic() ) {
                    mean = min + ( max - min ) / 4;
                }

                # cruise
                else {
                    mean = min + ( max - min ) / 2;
                }

                if( cg < mean - me.CGPERCENT and cg < max - me.CGPERCENT ) {
                    me.log("aft");
                    aft = constant.TRUE;
                    engine = constant.TRUE;
                }

                # don't move on ground, if within limits
                elsif( cg > mean + me.CGPERCENT and cg > min + me.CGPERCENT and cg > me.MAXPERCENT ) {
                    me.log("forward");
                    forward = constant.TRUE;
                    engine = constant.TRUE;
                }
           }

           me.applyfuel( forward, aft, engine, afttrim );
       }


       if( me.itself["root"].getNode("cg/aft").getValue() != aft or
           me.itself["root"].getNode("cg/forward").getValue() != forward ) {
           me.itself["root"].getNode("cg/aft").setValue(aft);
           me.itself["root"].getNode("cg/forward").setValue(forward);

           me.toggleclick();
       }
    }
}

Virtualengineer.applyfuel = func( forward, aft, engine, afttrim) {
    var pump6 = constant.FALSE;
    var pump8 = constant.FALSE;
    var auxilliary = constant.FALSE;

    # pumps
    var empty5 = me.fuelsystem.empty("5");
    var empty5A = me.fuelsystem.empty("5A");
    var empty6 = me.fuelsystem.empty("6");
    var empty7 = me.fuelsystem.empty("7");
    var empty7A = me.fuelsystem.empty("7A");
    var empty8 = me.fuelsystem.empty("8");
    var empty9 = me.fuelsystem.empty("9");
    var empty10 = me.fuelsystem.empty("10");
    var empty11 = me.fuelsystem.empty("11");

    # no 2D panel
    me.fuelsystem.aft2Dhuman( constant.FALSE );


    # shut all unused pumps
    me.fuelsystem.pumphuman( "5", !empty5 );
    me.fuelsystem.pumphuman( "7", !empty7 );
    me.fuelsystem.pumphuman( "5A", constant.FALSE );
    me.fuelsystem.pumphuman( "7A", constant.FALSE );

    if( empty5 and !empty6 ) {
        pump6 = constant.TRUE;
    }
    me.fuelsystem.pumphuman( "6", pump6 );

    if( empty7 and !empty8 ) {
        pump8 = constant.TRUE;
    }
    me.fuelsystem.pumphuman( "8", pump8 );

    # engineer normally uses auto trim
    me.fuelsystem.pumphuman( "9", constant.FALSE );
    me.fuelsystem.pumphuman( "10", constant.FALSE );
    me.fuelsystem.pumphuman( "11", constant.FALSE );

    me.fuelsystem.shutstandbyhuman();


    # aft trim
    me.fuelsystem.afttrimhuman( afttrim );


    # transfers auxilliary tanks
    if( empty5 and empty6 ) {
        if( !empty5A ) {
            auxilliary = constant.TRUE;
            me.fuelsystem.transvalvehuman( "5A", constant.TRUE );
            me.fuelsystem.pumphuman( "5A", constant.TRUE );
        }
    }
    if( empty7 and empty8 ) {
        if( !empty7A ) {
            auxilliary = constant.TRUE;
            me.fuelsystem.transvalvehuman( "7A", constant.TRUE );
            me.fuelsystem.pumphuman( "7A", constant.TRUE );
        }
    }
    if( auxilliary ) {
        me.log("auxilliary");
    }


    # low level (emergency)
    if( !auxilliary and me.fuelsystem.lowlevel() ) {
        me.fuelsystem.offautohuman();

        # avoid aft CG  
        if( ( forward or !aft ) and !empty11 ) {
            me.log("low-level");
            me.fuelsystem.pumphuman( "11", constant.TRUE );
            me.fuelsystem.enginehuman( constant.TRUE );
            me.fuelsystem.forwardhuman( constant.TRUE );
        }
        elsif( !empty9 or !empty10 ) {
            me.log("low-level");
            me.fuelsystem.pumphuman( "9", !empty9 );
            me.fuelsystem.pumphuman( "10", !empty10 );
            me.fuelsystem.enginehuman( constant.TRUE );
            me.fuelsystem.afthuman( constant.TRUE );
        }
        # last fuel
        elsif( !empty11 ) {
            me.log("low-level");
            me.fuelsystem.pumphuman( "11", constant.TRUE );
            me.fuelsystem.enginehuman( constant.TRUE );
            me.fuelsystem.forwardhuman( constant.TRUE );
        }
        else {
            me.fuelsystem.enginehuman( constant.FALSE );
        }
    }

    # aft transfert
    elsif( aft ) {
        me.fuelsystem.forwardautohuman( constant.FALSE );
    }

    # forward transfert
    elsif( forward ) {
        me.fuelsystem.forwardautohuman( constant.TRUE );
    }

    # no transfert
    else {
        me.fuelsystem.offautohuman();
        me.fuelsystem.enginehuman( constant.FALSE );
    }
}

Virtualengineer.fuelconsumed = func {
    if( me.can() ) {
        for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
             if( me.can() ) {
                 me.resetfuelconsumed( i );
             }
        }
    }
}

Virtualengineer.resetfuelconsumed = func( index ) {
    if( me.can() ) {
        if( me.dependency["fuel-consumed"][index].getChild("total-kg").getValue() > me.RESETKG ) {
            if( !me.dependency["fuel-consumed"][index].getChild("reset").getValue() ) {
                me.dependency["fuel-consumed"][index].getChild("reset").setValue( constant.TRUE );
                me.toggleclick("fuel-consumed-" ~ index);
            }
        }
    }
}


# ----------
# PERCEPTION
# ----------
Virtualengineer.is_cruising = func {
   var result = constant.FALSE;

   if( me.speedmach > constantaero.REHEATMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Virtualengineer.is_subsonic = func {
   var result = constant.FALSE;

   if( me.speedmach > constantaero.CLIMBMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Virtualengineer.is_supersonic = func {
   var result = constant.FALSE;

   if( me.speedmach > constantaero.SOUNDMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Virtualengineer.is_climbing = func {
   var result = constant.FALSE;

   if( me.speedfpm > me.CLIMBFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Virtualengineer.is_descending = func {
   var result = constant.FALSE;

   if( me.speedfpm < me.DESCENTFPM ) {
       result = constant.TRUE;
   }

   return result;
}


# ==========
# NAVIGATION
# ==========

Navigation = {};

Navigation.new = func {
   var obj = { parents : [Navigation,System], 

               altitudeft : 0.0,

               last : constant.FALSE,

               NOSPEEDFPM : 0.0,

               SUBSONICKT : 480,                                 # estimated ground speed
               FLIGHTKT : 150,                                   # minimum ground speed

               groundkt : 0,

               SUBSONICKGPH : 20000,                             # subsonic consumption

               kgph : 0,

               NOFUELKG : -999,

               totalkg : 0
         };

   obj.init();

   return obj;
}

Navigation.init = func {
   me.inherit_system("/systems/engineer");
}

Navigation.schedule = func {
   var groundfps = me.dependency["ins"][2].getNode("computed").getChild("ground-speed-fps").getValue();
   var id = "";
   var distnm = 0.0;
   var targetft = 0;
   var selectft = 0.0;
   var fuelkg = 0.0;
   var speedfpm = 0.0;

   if( groundfps != nil ) {
       me.groundkt = groundfps * constant.FPSTOKT;
   }

   me.totalkg = me.dependency["fuel"].getChild("total-lbs").getValue() * constant.LBTOKG;

   # on ground
   if( me.groundkt < me.FLIGHTKT ) {
       me.groundkt = me.SUBSONICKT;
       me.kgph = me.SUBSONICKGPH;
   }
   else {
       # gauge is NOT REAL
       me.kgph = me.dependency["fuel"].getNode("fuel-flow-kg_ph").getValue();
   }

   me.altitudeft = me.noinstrument["altitude"].getValue();
   selectft = me.dependency["autoflight"].getChild("altitude-select").getValue();
   me.last = constant.FALSE;


   # waypoint
   for( var i = 2; i >= 0; i = i-1 ) {
        if( i < 2 ) {
            id = me.dependency["waypoint"][i].getChild("id").getValue();
            distnm = me.dependency["waypoint"][i].getChild("dist").getValue();
            targetft = selectft;
        }

        # last
        else {
            id = me.dependency["route-manager"].getNode("wp-last/id",constant.DELAYEDNODE).getValue(); 
            distnm = me.dependency["route-manager"].getNode("wp-last/dist",constant.DELAYEDNODE).getValue(); 
        }

        fuelkg = me.estimatefuelkg( id, distnm );
        speedfpm = me.estimatespeedfpm( id, distnm, targetft );

        # display for FDM debug, or navigation
        me.itself["waypoint"][i].getChild("fuel-kg").setValue(int(math.round(fuelkg)));
        me.itself["waypoint"][i].getChild("speed-fpm").setValue(int(math.round(speedfpm)));
   }
}

Navigation.estimatespeedfpm = func( id, distnm, targetft ) {
   var speedfpm = me.NOSPEEDFPM;
   var minutes = 0.0;

   if( id != "" and distnm != nil ) {
       # last waypoint at sea level
       if( !me.last ) {
           targetft = me.itself["root-ctrl"].getChild("destination-ft").getValue();
           me.last = constant.TRUE;
       }

       minutes = ( distnm / me.groundkt ) * constant.HOURTOMINUTE;
       speedfpm = ( targetft - me.altitudeft ) / minutes;
   }

   return speedfpm;
}

Navigation.estimatefuelkg = func( id, distnm ) {
   var fuelkg = me.NOFUELKG;
   var ratio = 0.0;

   if( id != "" and distnm != nil ) {
       ratio = distnm / me.groundkt;
       fuelkg = me.kgph * ratio;
       fuelkg = me.totalkg - fuelkg;
       if( fuelkg < 0 ) {
           fuelkg = 0;
       }
   }

   return fuelkg;
}


setprop("instrumentation/transponder/id-code","5732");

