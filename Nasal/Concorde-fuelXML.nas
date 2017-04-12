# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ===========
# FUEL PARSER
# ===========
FuelXML = {};

FuelXML.new = func {
   var obj = { parents : [FuelXML],

               FUELSEC : 1.0,

               configpath : nil,
               iterationspath : nil,
               systempath : nil,

               components : FuelComponentArray.new(),
               connections : FuelConnectionArray.new()
         };

   obj.init();

   return obj;
};

FuelXML.init = func {
}

# creates all propagate variables
FuelXML.init_FuelXML = func( path ) {
   var children = nil;
   var nb_children = 0;
   var component = nil;

   me.systempath = props.globals.getNode(path);
   me.configpath = me.systempath.getNode("internal/config");
   me.iterationspath = me.systempath.getNode("internal/iterations");

   children = me.configpath.getChildren("supplier");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_supplier( children[i] );
   }

   children = me.configpath.getChildren("circuit");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_circuit( children[i] );
   }

   children = me.configpath.getChildren("connect");
   nb_children = size( children );
   for( i = 0; i < nb_children; i = i+1 ) {
        me.connections.add_connect( children[i], me.components );
   }

   children = me.configpath.getChildren("inter-connect");
   nb_children = size( children );
   for( i = 0; i < nb_children; i = i+1 ) {
        me.connections.add_interconnect( children[i], me.components );
   }

   children = me.configpath.getChildren("transfer");
   nb_children = size( children );
   for( i = 0; i < nb_children; i = i+1 ) {
        me.connections.add_transfer( children[i], me.components );
   }
}

FuelXML.schedule = func( pumplb, tanksystem ) {
   var remain = constant.FALSE;
   var iter = 0;
   var name = "";
   var component = nil;
   var supplier = nil;

   me.clear();

   if( me.systempath.getChild("serviceable").getValue() ) {
       # one must absolutely start by suppliers !
       iter = 1;
       for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
            supplier = me.components.get_supplier( i );
            name = supplier.get_name();
            supplier.propagate();

            for( var j = 0; j < me.connections.count(); j = j+1 ) {
                 component = me.connections.get( j );
                 if( component.get_input() == name ) {
                     me.pressurize( component );
                 }
            }
       }

       # required !
       remain = constant.TRUE;
       while( remain ) {
            remain = constant.FALSE;
            for( var i = 0; i < me.connections.count(); i = i+1 ) {
                 component = me.connections.get( i );
                 if( !me.pressurize( component ) ) {
                     remain = constant.TRUE;
                 }
            }
            iter = iter + 1;
       }

       me.iterationspath.setValue(iter);
   }

   me.apply( pumplb, tanksystem );
}

FuelXML.pressurize = func( connection ) {
   var found = constant.FALSE;
   var valve = constant.FALSE;
   var inputkind = "";
   var outputkind = "";
   var input = nil;
   var output = nil;
   var component = nil;
   var component2 = nil;

   output = connection.get_output();
   outputkind = connection.get_output_kind();

   # propagate fuel pressure
   component2 = me.components.find( output, outputkind );
   if( component2 != nil ) {
       input = connection.get_input();
       inputkind = connection.get_input_kind();
       component = me.components.find( input, inputkind );
       valve = connection.valve_opened( component );

       if( !component2.is_propagate() ) {

            # valve off means no pressure
            if( !valve ) {
                component2.propagate();
                found = constant.TRUE;
            }

            else {
                if( component != nil ) {

                    # input knows its pressure
                    if( component.is_propagate() ) {
                        component2.propagate( component );
                        found = constant.TRUE;

                        # recursive propagation to all network !
                        me.network( output );
                    }
                }
            }
       }

       # already solved
       else {

           # can accept from many tanks
           if( valve ) {
               if( component != nil ) {

                   # input knows its pressure
                   if( component.is_propagate() ) {
                       component2.propagate( component );
                   }
               }
           }

           found = constant.TRUE;
       }
   }

   return found;
}

FuelXML.network = func( output ) {
   var component = nil;

   for( var i = 0; i < me.connections.count(); i = i+1 ) {
        component = me.connections.get( i );
        if( component.get_input() == output ) {
            me.pressurize( component );
        }
   }
}

FuelXML.apply = func( pumplb, tanksystem ) {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.apply( tanksystem, pumplb );
   }

   for( var i = 0; i < me.components.count_circuit(); i = i+1 ) {
        component = me.components.get_circuit( i );
        component.apply( tanksystem, pumplb );
   }

   for( var i = 0; i < me.connections.count_inter(); i = i+1 ) {
        component = me.connections.get_inter( i );
        component.apply( me.components, tanksystem, pumplb );
   }
}

FuelXML.clear = func {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.clear();
   }

   for( var i = 0; i < me.components.count_circuit(); i = i+1 ) {
        component = me.components.get_circuit( i );
        component.clear();
   }
}


# ===============
# COMPONENT ARRAY
# ===============

FuelComponentArray = {};

FuelComponentArray.new = func {
   var obj = { parents : [FuelComponentArray],

           supplier_name : [],
           circuit_name :  [],

           suppliers : [],
           nb_suppliers : 0,

           circuits : [],
           nb_circuits : 0,
         };

   return obj;
};

FuelComponentArray.add_supplier = func( node ) {
   var result = nil;
   var name = node.getChild("name").getValue();
   var kind = node.getChild("kind").getValue();
   var pumps = node.getChildren("pump");

   if( kind == "tank" ) {
      var index = node.getChild("index").getValue();

      result = FuelTank.new( name, index, pumps );
   }

   elsif( kind == "jettison" ) {
      result = FuelJettison.new( name );
   }

   if( result != nil ) {
       append(me.supplier_name, name);

       append(me.suppliers, result);

       me.nb_suppliers = me.nb_suppliers + 1;
   }
}

FuelComponentArray.add_circuit = func( node ) {
   var result = nil;
   var name = node.getChild("name").getValue();

   append(me.circuit_name, name);

   result = FuelCircuit.new( name );
   append(me.circuits, result);

   me.nb_circuits = me.nb_circuits + 1;
}

FuelComponentArray.find_supplier = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_suppliers; i = i+1 ) {
         if( me.supplier_name[i] == ident ) {
             result = me.get_supplier( i );
             break;
         }
    }

    return result;
}

FuelComponentArray.find_circuit = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_circuits; i = i+1 ) {
         if( me.circuit_name[i] == ident ) {
             result = me.get_circuit( i );
             break;
         }
    }

    return result;
}

# lookup tables accelerates the search !!!
FuelComponentArray.find = func( ident, kind ) {
   var found = constant.FALSE;
   var result = nil;


   if( kind == "supplier" ) {
       result = me.find_supplier( ident );
   }
   elsif( kind == "circuit" ) {
       result = me.find_circuit( ident );
   }

   if( result != nil ) {
       found = constant.TRUE;
   }

   if( !found ) {
       print("Fuel : component not found ", ident);
   }

   return result;
}

FuelComponentArray.find_kind = func( ident ) {
   var found = constant.FALSE;
   var result = "";

   if( me.find_supplier( ident ) == nil ) {
       if( me.find_circuit( ident ) == nil ) {
       }
       else {
           result = "circuit";
       }
   }
   else {
       result = "supplier";
   }

   if( result != "" ) {
       found = constant.TRUE;
   }

   if( !found ) {
       print("Fuel : component kind not found ", ident);
   }

   return result;
}

FuelComponentArray.count_supplier = func {
   return me.nb_suppliers;
}

FuelComponentArray.count_circuit = func {
   return me.nb_circuits;
}

FuelComponentArray.get_supplier = func( index ) {
   return me.suppliers[ index ];
}

FuelComponentArray.get_circuit = func( index ) {
   return me.circuits[ index ];
}


# =========
# COMPONENT
# =========

# for inheritance, the component must be the last of parents.
FuelComponent = {};

# not called by child classes !!!
FuelComponent.new = func {
   var obj = { parents : [FuelComponent],

               name : "",

               # tank receiving fuel (many if circuit)
               nb_index : 0,
               MAXINDEX : 20,
               tank_index : [ "", "", "", "", "", "", "", "", "", "",
                              "", "", "", "", "", "", "", "", "", "" ],

               # tank sending fuel (many if multiple connections)
               nb_source : 0,
               MAXSOURCE : 20,
               tank_source : [ "", "", "", "", "", "", "", "", "", "",
                               "", "", "", "", "", "", "", "", "", "" ],

               nb_pumps : 0,
               pump_switch : [],
               pump_energy : [],

               done : constant.FALSE
         };

   return obj;
};

FuelComponent.inherit_fuelcomponent = func( name ) {
   var obj = FuelComponent.new();

   me.nb_index = obj.nb_index;
   me.MAXINDEX = obj.MAXINDEX;
   me.tank_index = obj.tank_index;

   me.nb_source = obj.nb_source;
   me.MAXSOURCE = obj.MAXSOURCE;
   me.tank_source = obj.tank_source;

   me.nb_pumps = obj.nb_pumps;
   me.pump_switch = obj.pump_switch;
   me.pump_energy = obj.pump_energy;

   me.done = obj.done;

   me.name = name;
}

# is fuel known ?
FuelComponent.is_propagate = func {
   return me.done;
}

# propagates fuel pressure
FuelComponent.propagate = func( component = nil ) {
   if( component != nil ) {
       var source = component.get_index();

       # filling by another tank
       for( var i = 0; i < component.count_index(); i = i+1 ) {
            me.set_source( source[i] );
       }
   }

   me.set_propagate();
}

# reset propagate
FuelComponent.clear = func() {
   me.clear_propagate();

   # clears tanks
   me.clear_index();
   me.clear_source();
}

FuelComponent.clear_index = func {
   me.nb_index = 0;
}

FuelComponent.clear_source = func {
   me.nb_source = 0;
}

FuelComponent.count_index = func {
   return me.nb_index;
}

FuelComponent.count_source = func {
   return me.nb_source;
}

FuelComponent.clear_propagate = func {
   me.done = constant.FALSE;
}

FuelComponent.set_propagate = func {
   me.done = constant.TRUE;
}

FuelComponent.get_name = func {
   return me.name;
}

FuelComponent.get_index = func {
   return me.tank_index;
}

FuelComponent.get_tank = func {
   return me.tank_index[0];
}

FuelComponent.set_index = func( index ) {
   if( me.nb_index < me.MAXINDEX ) {
       me.tank_index[ me.nb_index ] = index;
       me.nb_index = me.nb_index + 1;
   }

   else {
       print( me.error(), "tank index overflow ", index );
   }
}

FuelComponent.get_source = func {
   return me.tank_source;
}

FuelComponent.set_source = func( source ) {
   if( me.nb_source < me.MAXSOURCE ) {
       me.tank_source[ me.nb_source ] = source;
       me.nb_source = me.nb_source + 1;
   }

   else {
       print( me.error(), "tank source overflow ", source );
   }
}

FuelComponent.set_pumps = func( allpumps ) {
   var value = "";
   var child = nil;


   me.nb_pumps = size(allpumps);

   for( var i = 0; i < me.nb_pumps; i = i+1 ) {
        value = "";

        child = allpumps[i].getNode("switch");
        if( child != nil ) {
            value = child.getValue();
        }

        if( value == "" ) {
            print( me.error(), "switch missing" );
        }
        append( me.pump_switch, value );

        value = "";

        child = allpumps[i].getNode("energy");
        if( child != nil ) {
            value = child.getValue();
        }

        if( value == "" ) {
            print( me.error(), "energy missing" );
        }
        append( me.pump_energy, value );
   }
}

FuelComponent.pump_opened = func( no ) {
   var result = constant.TRUE;

   if( no < me.nb_pumps ) {
       var switch = constant.FALSE;
       var energy = constant.FALSE;

       switch = getprop( me.pump_switch[no] );
       energy = getprop( me.pump_energy[no] );

       if( !switch or !energy ) {
           result = constant.FALSE;
       }
   }

   return result;
}

FuelComponent.find_index = func( index ) {
   var result = constant.FALSE;

   for( var i = 0; i < me.nb_index; i = i+1 ) {
        if( me.tank_index[i] == index ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

FuelComponent.find_source = func( source ) {
   var result = constant.FALSE;

   for( var i = 0; i < me.nb_source; i = i+1 ) {
        if( me.tank_source[i] == source ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

FuelComponent.apply = func( pumpsystem, pumplb ) {
}

FuelComponent.error = func {
   var result = "Fuel tank " ~ me.name ~ " : ";

   return result;
}


# ====
# TANK
# ====

FuelTank = {};

FuelTank.new = func( name, index, allpumps ) {
   var obj = { parents : [FuelTank,FuelComponent],
         };

   obj.init( name, index, allpumps );

   return obj;
};

FuelTank.init = func( name, index, allpumps ) {
   me.inherit_fuelcomponent( name );

   me.set_index( index );
   me.set_pumps( allpumps );
}

FuelTank.clear = func() {
   me.clear_propagate();

   # keep its target tank
   me.clear_source();
}

FuelTank.apply = func( pumpsystem, pumplb ) {
   if( me.nb_source > 1 ) {
       var steplb = 0.0;
       var levellb = 0.0;
       var flowlb = 0.0;

       # destination tank almost full
       var freelb = pumpsystem.getspacelb( me.tank_index[0] );

       if( freelb < ( pumplb * me.nb_source ) ) {
           pumplb = freelb / me.nb_source;
       }

       # source tank almost empty
       for( var i = 0; i < me.nb_source; i = i+1 ) {
            steplb = pumplb;
            levellb = pumpsystem.getlevellb( me.tank_source[i] );
            if( levellb < pumplb ) {
                steplb = levellb;
            }

            flowlb = flowlb + steplb;
       }

       if( flowlb < ( pumplb * me.nb_source ) ) {
           pumplb = flowlb / me.nb_source;
       }
   }

   for( var i = 0; i < me.nb_source; i = i+1 ) {
        pumpsystem.transfertanks( me.tank_index[0], me.tank_source[i], pumplb );
   }
}


# ========
# JETTISON
# ========

FuelJettison = {};

FuelJettison.new = func( name ) {
   var obj = { parents : [FuelJettison,FuelComponent]
         };

   obj.init( name );

   return obj;
};

FuelJettison.init = func( name ) {
   me.inherit_fuelcomponent( name );
}

FuelJettison.apply = func( pumpsystem, pumplb ) {
   for( var i = 0; i < me.nb_source; i = i+1 ) {
        pumpsystem.dumptank( me.tank_source[i], pumplb );
   }
}


# =======
# CIRCUIT
# =======

FuelCircuit = {};

FuelCircuit.new = func( name ) {
   var obj = { parents : [FuelCircuit,FuelComponent]
         };

   obj.init( name );

   return obj;
};

FuelCircuit.init = func( name ) {
   me.inherit_fuelcomponent( name );
}

FuelCircuit.propagate = func( component = nil ) {
   if( component != nil ) {
       var index = component.get_index();

       # transfers fuel from another tank
       for( var i = 0; i < component.count_index(); i = i+1 ) {
            me.set_index( index[i] );
       }
   }

   me.set_propagate();
}


# ================
# CONNECTION ARRAY
# ================

FuelConnectionArray = {};

FuelConnectionArray.new = func {
   var obj = { parents : [FuelConnectionArray],

               interconnections : [],
               nb_interconnections : 0,

               connections : [],
               nb_connections : 0
         };

   return obj;
};

FuelConnectionArray.add_connect = func( node, components ) {
   var result = nil;
   var input = node.getChild("input").getValue();
   var output = node.getChild("output").getValue();
   var inputkind = components.find_kind( input );
   var outputkind = components.find_kind( output );
   var valves = node.getChildren("valve");

   result = FuelConnect.new( input, inputkind, output, outputkind, valves );
   me.add( result );
}

FuelConnectionArray.add_interconnect = func( node, components ) {
   var result = nil;
   var input = node.getChild("input").getValue();
   var output = node.getChild("output").getValue();
   var inputkind = components.find_kind( input );
   var outputkind = components.find_kind( output );
   var valves = node.getChildren("valve");

   result = FuelInterconnect.new( input, inputkind, output, outputkind, valves );
   me.add_inter( result );
}

FuelConnectionArray.add_transfer = func( node, components ) {
   var result = nil;
   var input = node.getChild("input").getValue();
   var output = node.getChild("output").getValue();
   var inputkind = components.find_kind( input );
   var outputkind = components.find_kind( output );
   var valves = node.getChildren("valve");
   var pumps = node.getChildren("pump");

   result = FuelTransfer.new( input, inputkind, output, outputkind, valves, pumps );
   me.add( result );
}

FuelConnectionArray.add = func( obj ) {
   append(me.connections, obj);

   me.nb_connections = me.nb_connections + 1;
}

FuelConnectionArray.add_inter = func( obj ) {
   append(me.interconnections, obj);

   me.nb_interconnections = me.nb_interconnections + 1;
}

FuelConnectionArray.count = func {
   return me.nb_connections;
}

FuelConnectionArray.count_inter = func {
   return me.nb_interconnections;
}

FuelConnectionArray.get = func( index ) {
   return me.connections[ index ];
}

FuelConnectionArray.get_inter = func( index ) {
   return me.interconnections[ index ];
}


# ==========
# CONNECTION
# ==========

FuelConnection = {};

FuelConnection.new = func( input, inputkind, output, outputkind ) {
   var obj = { parents : [FuelConnection],

           input : input,
           input_kind : inputkind,
           output : output,
           output_kind : outputkind,

           nb_valves : 0,
           valves : [],

           done : constant.FALSE
         };

   return obj;
};

FuelConnection.inherit_connection = func( input, inputkind, output, outputkind, allvalves ) {
   var obj = FuelConnection.new( input, inputkind, output, outputkind );

   me.input = obj.input;
   me.output = obj.output;

   me.input_kind = obj.input_kind;
   me.output_kind = obj.output_kind;

   me.nb_valves = obj.nb_valves;
   me.valves = obj.valves;

   me.done = obj.done;


   me.nb_valves = size( allvalves );

   for( var i = 0; i < me.nb_valves; i = i+1 ) {
        append( me.valves, allvalves[i].getValue() );
   }
}

FuelConnection.get_input = func {
   return me.input;
}

FuelConnection.get_input_kind = func {
   return me.input_kind;
}

FuelConnection.get_output = func {
   return me.output;
}

FuelConnection.get_output_kind = func {
   return me.output_kind;
}

FuelConnection.get_valve = func {
   var result = constant.FALSE;

   if( me.nb_valves == 0 ) {
       result = constant.TRUE;
   }

   else {
       for( var i = 0; i < me.nb_valves; i = i+1 ) {
            if( getprop( me.valves[i] ) ) {
                result = constant.TRUE;
                break;
            }
       }
   }

   return result;
}

FuelConnection.valve_opened = func( component ) {
   return me.get_valve();
}


# =======
# CONNECT
# =======

FuelConnect = {};

FuelConnect.new = func( input, inputkind, output, outputkind, allvalves ) {
   var obj = { parents : [FuelConnect,FuelConnection]

         };

   obj.init( input, inputkind, output, outputkind, allvalves );

   return obj;
};

FuelConnect.init = func( input, inputkind, output, outputkind, allvalves ) {
   me.inherit_connection( input, inputkind, output, outputkind, allvalves );
}


# ============
# INTERCONNECT
# ============

FuelInterconnect = {};

FuelInterconnect.new = func( input, inputkind, output, outputkind, allvalves ) {
   var obj = { parents : [FuelInterconnect,FuelConnection]

         };

   obj.init( input, inputkind, output, outputkind, allvalves );

   return obj;
};

FuelInterconnect.init = func( input, inputkind, output, outputkind, allvalves ) {
   me.inherit_connection( input, inputkind, output, outputkind, allvalves );
}

FuelInterconnect.apply = func( componentarray, pumpsystem, pumplb ) {
   if( me.get_valve() ) {
       var component = componentarray.find_supplier( me.input );
       var component2 = componentarray.find_supplier( me.output );

       if( component != nil and component2 != nil ) {
           var left = component.get_tank();
           var right  = component2.get_tank();

           if( left != "" and right != "" ) {
               pumpsystem.pumpcross( left, right, pumplb );
           }
       }
   }
}


# ========
# TRANSFER
# ========

FuelTransfer = {};

FuelTransfer.new = func( input, inputkind, output, outputkind, allvalves, allpumps ) {
   var obj = { parents : [FuelTransfer,FuelConnection],

               nb_pumps : 0,
               pumps : []
         };

   obj.init( input, inputkind, output, outputkind, allvalves, allpumps );

   return obj;
};

FuelTransfer.init = func( input, inputkind, output, outputkind, allvalves, allpumps ) {
   me.inherit_connection( input, inputkind, output, outputkind, allvalves );

   me.nb_pumps = size( allpumps );

   for( var i = 0; i < me.nb_pumps; i = i+1 ) {
        append( me.pumps, allpumps[i].getValue() );
   }
}

FuelTransfer.valve_opened = func( component ) {
   var result = me.get_valve();

   if( me.nb_pumps > 0 and component != nil ) {
       if( result ) {
           result = constant.FALSE;

           # at least one pump must be on
           for( var i = 0; i < me.nb_pumps; i = i+1 ) {
                if( component.pump_opened( me.pumps[i] ) ) {
                    result = constant.TRUE;
                    break;
                }
           }
       }
   }

   return result;
}


# ===========
# TANK PARSER
# ===========

# adds an indirection to convert the tank name into an array index.

TankXML = {};

TankXML.new = func {
# tank contents, to be initialised from XML
   var obj = { parents : [TankXML], 

               pumpsystem : Pump.new(),
   
               CONTENTLB : {},
               TANKINDEX : {},
               TANKNAME : [],

               nb_tanks : 0,

               controlspath : nil,
               dialogpath : nil,
               fillingspath : nil,
               systempath : nil,
               tankspath : nil
         };

    return obj;
}

TankXML.inherit_tankXML = func( path ) {
    var obj = TankXML.new();

    me.pumpsystem = obj.pumpsystem;

    me.systempath = props.globals.getNode(path);
    me.dialogpath = me.systempath.getNode("tanks/dialog");
    me.controlspath = props.globals.getNode("/controls/fuel").getChildren("tank");
    me.tankspath = props.globals.getNode("/consumables/fuel").getChildren("tank");
    me.fillingspath = me.systempath.getChild("tanks").getChildren("filling");

    me.nb_tanks = size(me.tankspath);

    me.initcontent();
}

TankXML.init_TankXML = func {
    me.initinstrument();
    me.presetfuel();
}

TankXML.initcontent = func {
    me.inherit_initcontent();
}

# fuel initialization
TankXML.inherit_initcontent = func {
   var densityppg = 0.0;

   for( var i=0; i < me.nb_tanks; i=i+1 ) {
        densityppg = me.tankspath[i].getChild("density-ppg").getValue();
        me.CONTENTLB[me.TANKNAME[i]] = me.tankspath[i].getChild("capacity-gal_us").getValue() * densityppg;
   }
}

# change by dialog
TankXML.menu = func {
   var change = constant.FALSE;
   var last = me.systempath.getChild("presets").getValue();
   var comment = me.dialogpath.getValue();

   for( var i=0; i < size(me.fillingspath); i=i+1 ) {
        if( me.fillingspath[i].getChild("comment").getValue() == comment ) {
            me.load( i );

            # for aircraft-data
            me.systempath.getChild("presets").setValue(i);
            if( i != last ) {
                change = constant.TRUE;
            }

            break;
        }
   }

   return change;
}

# fuel configuration
TankXML.presetfuel = func {
   var value = "";
   var fuel = me.systempath.getChild("presets").getValue();
   var dialog = me.dialogpath.getValue();

   # default is 0
   if( fuel == nil ) {
       fuel = 0;
   }

   if( fuel < 0 or fuel >= size(me.fillingspath) ) {
       fuel = 0;
   } 

   # to detect change
   me.systempath.getChild("presets").setValue(fuel);

   # copy to dialog
   if( dialog == "" or dialog == nil ) {
       value = me.fillingspath[fuel].getChild("comment").getValue();
       me.dialogpath.setValue(value);
   }

   me.load( fuel );
}

TankXML.load = func( fuel ) {
   var child = nil;
   var levelgalus = 0.0;
   var presets = me.fillingspath[fuel].getChildren("tank");

   for( var i=0; i < size(presets); i=i+1 ) {
        child = presets[i].getChild("level-gal_us");
        if( child != nil ) {
            levelgalus = child.getValue();
        }

        # new load through dialog
        else {
            levelgalus = me.CONTENTLB[me.TANKNAME[i]] * constant.LBTOGALUS;
        } 

        me.pumpsystem.setlevel(i, levelgalus);
   } 
}

# tank initialization
TankXML.inherit_inittank = func( no, contentlb ) {
   me.tankspath[no].getChild("content-lb").setValue( contentlb );
}

TankXML.initinstrument = func {
   for( var i=0; i < me.nb_tanks; i=i+1 ) {
        me.inherit_inittank( i, me.CONTENTLB[me.TANKNAME[i]] );
   }
}

TankXML.controls = func( name, switch, index = 0 ) {
   return me.controlspath[me.TANKINDEX[name]].getChild( switch, index );
}

TankXML.getlevellb = func( name ) {
   return me.pumpsystem.getlevellb( me.TANKINDEX[name] );
}

TankXML.getlevelkg = func( name ) {
   return me.pumpsystem.getlevelkg( me.TANKINDEX[name] );
}

TankXML.getspacelb = func( name ) {
   return me.pumpsystem.getspacelb( me.TANKINDEX[name], me.CONTENTLB[name] );
}

TankXML.empty = func( name ) {
   return me.pumpsystem.empty( me.TANKINDEX[name] );
}

TankXML.full = func( name ) {
   return me.pumpsystem.full( me.TANKINDEX[name], me.CONTENTLB[name] );
}

TankXML.reduce = func( name, enginegal ) {
   me.pumpsystem.reduce( me.TANKINDEX[name], enginegal );
}

TankXML.dumptank = func( name, pumplb ) {
   me.pumpsystem.dumptank( me.TANKINDEX[name], pumplb );
}

TankXML.pumpcross = func( left, right, pumplb ) {
   me.pumpsystem.pumpcross( me.TANKINDEX[left], me.CONTENTLB[left],
                            me.TANKINDEX[right], me.CONTENTLB[right], pumplb );
}

TankXML.transfertanks = func( dest, sour, pumplb ) {
   me.pumpsystem.transfertanks( me.TANKINDEX[dest], me.CONTENTLB[dest], me.TANKINDEX[sour], pumplb );
}

# fills completely a tank
TankXML.filltank = func( dest, sour ) {
   var pumplb = me.getspacelb( dest );

   me.pumpsystem.transfertanks( me.TANKINDEX[dest], me.CONTENTLB[dest], me.TANKINDEX[sour], pumplb );
}


# ==========
# FUEL PUMPS
# ==========

# does the transfers between the tanks

Pump = {};

Pump.new = func {
   var obj = { parents : [Pump],

               EMPTYGAL : 0.1,                  # if interconnect, level is never 0.0

               tanks : nil 
         };

   obj.init();

   return obj;
}

Pump.init = func {
   me.tankspath = props.globals.getNode("/consumables/fuel").getChildren("tank");
}

Pump.getlevel = func( index ) {
   var tankgalus = me.tankspath[index].getChild("level-gal_us").getValue();

   return tankgalus;
}

Pump.getlevellb = func( index ) {
   var tanklb = me.getlevel(index) * constant.GALUSTOLB;

   return tanklb;
}

Pump.getlevelkg = func( index ) {
   var tankkg = me.getlevel(index) * constant.GALUSTOKG;

   return tankkg;
}

Pump.getspacelb = func( index, contentlb ) {
   var freelb = contentlb - me.getlevellb(index);

   return freelb;
}

Pump.empty = func( index ) {
   var tankgal = me.getlevel(index);
   var result = constant.FALSE;

   if( tankgal < me.EMPTYGAL ) {
       result = constant.TRUE;
   }

   return result;
}

Pump.full = func( index, contentlb ) {
   var tanklb = me.getlevellb(index);
   var result = constant.TRUE;

   if( contentlb - tanklb > me.EMPTYGAL ) {
       result = constant.FALSE;
   }

   return result;
}

Pump.setlevel = func( index, levelgalus ) {
   me.tankspath[index].getChild("level-gal_us").setValue(levelgalus);
}

Pump.setlevellb = func( index, levellb ) {
   var levelgalus = levellb / constant.GALUSTOLB;

   me.setlevel( index, levelgalus );
}

Pump.reduce = func( enginetank, enginegal ) {
   var tankgal = 0.0;

   if( enginegal > 0 ) {
       tankgal = me.getlevel(enginetank);
       if( tankgal > 0 ) {
           if( tankgal > enginegal ) {
               tankgal = tankgal - enginegal;
               enginegal = 0;
           }
           else {
               enginegal = enginegal - tankgal;
               tankgal = 0;
           }
           me.setlevel(enginetank,tankgal);
       }
   }
}


# balance 2 tanks
# - number of left tank
# - content of left tank
# - number of right tank
# - content of right tank
# - dumped volume (lb)
Pump.pumpcross = func( ileft, contentleftlb, iright, contentrightlb, pumplb ) {
   var tankleftlb = me.getlevellb(ileft);
   var tankrightlb = me.getlevellb(iright);
   var difflb = tankleftlb - tankrightlb;

   difflb = difflb / 2;

   # right too heavy
   if( difflb < 0 ) {
       difflb = - difflb;
       if( difflb > pumplb ) {
           difflb = pumplb;
       }
       me.transfertanks( ileft, contentleftlb, iright, difflb );
   }
   # left too heavy
   elsif( difflb > 0 )  {
       if( difflb > pumplb ) {
           difflb = pumplb;
       }
       me.transfertanks( iright, contentrightlb, ileft, difflb );
   }
}

# dump a tank
# - number of tank
# - dumped volume (lb)
Pump.dumptank = func( itank, dumplb ) {
   var tanklb = me.getlevellb(itank);

   # can fill destination
   if( tanklb > 0 ) {
       if( tanklb > dumplb ) {
           tanklb = tanklb - dumplb;
       }
       # empty
       else {
           tanklb = 0;
       }
       # JBSim only sees US gallons
       me.setlevellb(itank,tanklb);
   }
}

# transfer between 2 tanks, arguments :
# - number of tank destination
# - content of tank destination (lb)
# - number of tank source
# - pumped volume (lb)
Pump.transfertanks = func( idest, contentdestlb, isour, pumplb ) {
   var tankdestlb = me.getlevellb(idest);
   var tanksourlb = me.getlevellb(isour);
   var maxdestlb = contentdestlb - tankdestlb;
   var maxsourlb = tanksourlb - 0;


   # can fill destination
   if( maxdestlb > 0 ) {
       # can with source
       if( maxsourlb > 0 and idest != isour) {
           if( pumplb <= maxsourlb and pumplb <= maxdestlb ) {
               tanksourlb = tanksourlb - pumplb;
               tankdestlb = tankdestlb + pumplb;
           }
           # destination full
           elsif( pumplb <= maxsourlb and pumplb > maxdestlb ) {
               tanksourlb = tanksourlb - maxdestlb;
               tankdestlb = contentdestlb;
           }
           # source empty
           elsif( pumplb > maxsourlb and pumplb <= maxdestlb ) {
               tanksourlb = 0;
               tankdestlb = tankdestlb + maxsourlb;
           }
           # source empty and destination full
           elsif( pumplb > maxsourlb and pumplb > maxdestlb ) {
               # source empty
               if( maxdestlb > maxsourlb ) {
                   tanksourlb = 0;
                   tankdestlb = tankdestlb + maxsourlb;
               }
               # destination full
               elsif( maxdestlb < maxsourlb ) {
                   tanksourlb = tanksourlb - maxdestlb;
                   tankdestlb = contentdestlb;
               }
               # source empty and destination full
               else {
                  tanksourlb = 0;
                  tankdestlb = contentdestlb;
               }
           }
           # user sees emptying first
           # JBSim only sees US gallons
           me.setlevellb(isour,tanksourlb);
           me.setlevellb(idest,tankdestlb);
       }
   }
}
