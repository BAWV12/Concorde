# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =======
# COMPASS
# =======

Compass = {};

Compass.new = func {
   var obj = { parents : [Compass,System],

               ok : [ constant.TRUE, constant.TRUE ]
             };

   obj.init();

   return obj;
};

Compass.init = func {
   me.inherit_system("/instrumentation","compass");
}

Compass.toggleexport = func {
   var source = nil;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        source = me.get_source( i );

        me.set_source( i, source );
   }
}

Compass.schedule = func {
   var status = constant.FALSE;
   var indication = nil;
   var source = nil;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        status = me.itself["root"][i].getChild("serviceable").getValue();

        if( status != me.ok[ i ] ) {
            me.ok[ i ] = status;

            if( status ) {
                source = me.get_source( i );
            }

            else {
                indication = me.itself["root"][i].getChild("heading-deg");

                # blocked on last measure
                source = me.itself["root"][i].getChild("heading-failure-deg");
                source.setValue( indication.getValue() );
            }

            me.set_source( i, source );
        }
   }
}

Compass.set_source = func( index, source ) {
   var path = me.itself["root"][index].getChild("heading-deg").getAliasTarget().getPath();

   if( path != source ) {
       me.itself["root"][index].getChild("heading-deg").unalias();
       me.itself["root"][index].getChild("heading-deg").alias( source );
   }
}

Compass.get_source = func( index ) {
   var source = nil;

   if( me.itself["root"][index].getChild("mode-dg").getValue() ) {
       source = me.dependency["ins"][index].getNode("computed/heading-deg");
   }
   else {
       source = me.noinstrument["magnetic"];
   }

   return source;
}


# ==============================
# HORIZONTAL SITUATION INDICATOR
# ==============================

HSI = {};

HSI.new = func {
   var obj = { parents : [HSI,System]
             };

   obj.init();

   return obj;
};

HSI.init = func {
   me.inherit_system("/instrumentation","hsi");
}

HSI.toggleexport = func {
   var path = "";
   var source = nil;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        source = me.get_source( i );

        path = me.itself["root"][i].getChild("heading-deg").getAliasTarget().getPath();
        if( path != source ) {
            me.itself["root"][i].getChild("heading-deg").unalias();
            me.itself["root"][i].getChild("heading-deg").alias( source );
        }
   }
}

HSI.get_source = func( index ) {
   var source = nil;

   if( me.itself["root"][index].getChild("ins-source").getValue() ) {
       if( me.itself["root"][index].getChild("nav-ins2").getValue() ) {
           source = me.dependency["ins"][constantaero.INS2];
       }
       else {
           source = me.dependency["ins"][constantaero.INS1];
       }

       source = source.getChild("computed");
   }
   else {
       if( me.itself["root"][index].getChild("compass2").getValue() ) {
           source = me.dependency["compass"][constantaero.AP2];
       }
       else {
           source = me.dependency["compass"][constantaero.AP1];
       }
   }

   source = source.getChild("heading-deg");

   return source;
}
