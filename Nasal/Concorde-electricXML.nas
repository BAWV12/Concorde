# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =================
# ELECTRICAL PARSER
# =================
ElectricalXML = {};

ElectricalXML.new = func {
   var obj = { parents : [ElectricalXML],

               configpath : nil,
               electricalpath : nil,
               iterationspath : nil,

               forced : 0,

               components : ElecComponentArray.new(),
               connectors : ElecConnectorArray.new()
         };

   obj.init();

   return obj;
};

ElectricalXML.init = func {
}

# creates all propagate variables
ElectricalXML.init_ElectricalXML = func( path ) {
   var children = nil;
   var nb_children = 0;
   var component = nil;

   me.electricalpath = props.globals.getNode(path);
   me.configpath = me.electricalpath.getNode("internal/config");
   me.iterationspath = me.electricalpath.getNode("iterations",constant.DELAYEDNODE);

   me.forced = me.electricalpath.getNode("internal/iterations-forced").getValue();

   children = me.configpath.getChildren("supplier");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_supplier( children[i] );
        component = me.components.get_supplier( i );
        component.charge();
   }

   children = me.configpath.getChildren("transformer");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_transformer( children[i] );
        component = me.components.get_transformer( i );
        component.charge();
   }

   children = me.configpath.getChildren("bus");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_bus( children[i] );
        component = me.components.get_bus( i );
        component.charge();
   }

   children = me.configpath.getChildren("output");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_output( children[i] );
        component = me.components.get_output( i );
        component.charge();
   }

   children = me.configpath.getChildren("connector");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.connectors.add( children[i], me.components );
   }
}

# battery discharge
ElectricalXML.slowschedule = func {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.discharge();
   }
}

ElectricalXML.schedule = func {
   var component = nil;
   var iter = 0;
   var start = 0;
   var remain = constant.FALSE;

   me.clear();

   # suppliers, not real, always works
   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.supply();
   }

   if( me.electricalpath.getChild("serviceable").getValue() ) {
        iter = 0;
        remain = constant.TRUE;
        while( remain ) {
            remain = constant.FALSE;
            for( var i = 0; i < me.connectors.count(); i = i+1 ) {
                 component = me.connectors.get( i );
                 if( !me.supply( component ) ) {
                     remain = constant.TRUE;
                 }
            }
            iter = iter + 1;
       }

       # makes last iterations for voltages in parallel
       start = iter;
       for( var j = start; j < me.forced; j = j+1 ) {
            for( var i = 0; i < me.connectors.count(); i = i+1 ) {
                 component = me.connectors.get( i );
                 me.supply( component );
            }
            iter = iter + 1;
       }

       me.iterationspath.setValue(iter);
   }

   # failure : no voltage
   else {
       for( var i = 0; i < me.components.count_transformer(); i = i+1 ) {
            component = me.components.get_transformer( i );
            component.propagate();
       }

       for( var i = 0; i < me.components.count_bus(); i = i+1 ) {
            component = me.components.get_bus( i );
            component.propagate();
       }

       for( var i = 0; i < me.components.count_output(); i = i+1 ) {
            component = me.components.get_output( i );
            component.propagate();
       }
   }

   me.apply();
}

ElectricalXML.supply = func( connector ) {
   var volts = 0.0;
   var found = constant.FALSE;
   var switch = constant.FALSE;
   var inputkind = "";
   var outputkind = "";
   var input = nil;
   var output = nil;
   var component = nil;
   var component2 = nil;

   output = connector.get_output();
   outputkind = connector.get_output_kind();

   # propagate voltage
   component2 = me.components.find( output, outputkind );
   if( component2 != nil ) {
       if( !component2.is_propagate() ) {
           switch = connector.get_switch();

            # switch off means no voltage
            if( !switch ) {
                component2.propagate();
                found = constant.TRUE;
            }

            else {
                input = connector.get_input();
                inputkind = connector.get_input_kind();
                component = me.components.find( input, inputkind );
                if( component != nil ) {

                    # input knows its voltage
                    if( component.is_propagate() ) {
                        component2.propagate( component );
                        found = constant.TRUE;
                    }
                }
            }
       }

       # already solved
       else {
           volts = component2.get_volts();
           if( volts == 0 ) {
               switch = connector.get_switch();

               # voltages in parallel : if no voltage, can accept another connection
               if( switch ) {
                   input = connector.get_input();
                   inputkind = connector.get_input_kind();
                   component = me.components.find( input, inputkind );
                   if( component != nil ) {

                       # input knows its voltage
                       if( component.is_propagate() ) {
                           component2.propagate( component );
                       }
                   }
               }
           }

           found = constant.TRUE;
       }
   }

   return found;
}

ElectricalXML.apply = func {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.apply();
   }

   for( var i = 0; i < me.components.count_transformer(); i = i+1 ) {
        component = me.components.get_transformer( i );
        component.apply();
   }

   for( var i = 0; i < me.components.count_bus(); i = i+1 ) {
        component = me.components.get_bus( i );
        component.apply();
   }

   for( var i = 0; i < me.components.count_output(); i = i+1 ) {
        component = me.components.get_output( i );
        component.apply();
   }
}

ElectricalXML.clear = func {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.clear();
   }

   for( var i = 0; i < me.components.count_transformer(); i = i+1 ) {
        component = me.components.get_transformer( i );
        component.clear();
   }

   for( var i = 0; i < me.components.count_bus(); i = i+1 ) {
        component = me.components.get_bus( i );
        component.clear();
   }

   for( var i = 0; i < me.components.count_output(); i = i+1 ) {
        component = me.components.get_output( i );
        component.clear();
   }
}


# ===============
# COMPONENT ARRAY
# ===============

ElecComponentArray = {};

ElecComponentArray.new = func {
   var obj = { parents : [ElecComponentArray],

               supplier_name : [],
               transformer_name : [],
               bus_name :      [],
               output_name :   [],

               suppliers : [],
               nb_charges : 0,                                        # number of batteries
               nb_suppliers : 0,

               transformers : [],
               nb_transformers : 0,

               buses :    [],
               nb_buses : 0,

               outputs : [],
               nb_outputs : 0
         };

   return obj;
};

ElecComponentArray.add_supplier = func( node ) {
   var state = "";
   var rpm = "";
   var charge = 0;
   var amps = 0;
   var result = nil;
   var name = node.getChild("name").getValue();
   var kind = node.getChild("kind").getValue();
   var volts = node.getChild("volts").getValue();

   append(me.supplier_name, name);

   if( kind == "alternator" ) {
       state = node.getChild("prop").getValue();
       rpm = node.getChild("rpm-source").getValue();
   }

   # 1 variable per battery
   elsif( kind == "battery" ) {
       state = node.getChild("prop").getValue();

       charge = me.nb_charges;
       me.nb_charges = me.nb_charges + 1;

       amps = node.getChild("amps").getValue();
   }

   result = ElecSupplier.new( kind, state, rpm, volts, charge, amps );
   append(me.suppliers, result);

   me.nb_suppliers = me.nb_suppliers + 1;
}

ElecComponentArray.add_transformer = func( node ) {
   var result = nil;
   var name = node.getChild("name").getValue();
   var prop = node.getChild("prop").getValue();
   var allvolts = node.getNode("volts");

   append(me.transformer_name, name);

   result = ElecTransformer.new( allvolts, prop );
   append(me.transformers, result);

   me.nb_transformers = me.nb_transformers + 1;
}

ElecComponentArray.add_bus = func( node ) {
   var result = nil;
   var name = node.getChild("name").getValue();
   var allprops = node.getChildren("prop");

   append(me.bus_name, name);

   result = ElecBus.new( allprops );
   append(me.buses, result);

   me.nb_buses = me.nb_buses + 1;
}

ElecComponentArray.add_output = func( node ) {
   var result = nil;
   var name = node.getChild("name").getValue();
   var prop = node.getChild("prop").getValue();

   append(me.output_name, name);

   result = ElecOutput.new( prop );
   append(me.outputs, result);

   me.nb_outputs = me.nb_outputs + 1;
}

ElecComponentArray.find_supplier = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_suppliers; i = i+1 ) {
         if( me.supplier_name[i] == ident ) {
             result = me.get_supplier( i );
             break;
         }
    }

    return result;
}

ElecComponentArray.find_transformer = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_transformers; i = i+1 ) {
         if( me.transformer_name[i] == ident ) {
             result = me.get_transformer( i );
             break;
         }
    }

    return result;
}

ElecComponentArray.find_bus = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_buses; i = i+1 ) {
         if( me.bus_name[i] == ident ) {
             result = me.get_bus( i );
             break;
         }
    }

    return result;
}

ElecComponentArray.find_output = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_outputs; i = i+1 ) {
         if( me.output_name[i] == ident ) {
             result = me.get_output( i );
             break;
         }
    }

    return result;
}

# lookup tables accelerates the search !!!
ElecComponentArray.find = func( ident, kind ) {
   var found = constant.FALSE;
   var result = nil;

   if( kind == "supplier" ) { 
       result = me.find_supplier( ident );
   }
   elsif( kind == "transformer" ) {
       result = me.find_transformer( ident );
   }
   elsif( kind == "bus" ) {
       result = me.find_bus( ident );
   }
   elsif( kind == "output" ) {
       result = me.find_output( ident );
   }

   if( result != nil ) {
       found = constant.TRUE;
   }

   if( !found ) {
       print("Electrical : component not found ", ident);
   }

   return result;
}

ElecComponentArray.find_kind = func( ident ) {
   var found = constant.FALSE;
   var result = "";

   if( me.find_supplier( ident ) == nil ) {
       if( me.find_transformer( ident ) == nil ) {
           if( me.find_bus( ident ) == nil ) {
               if( me.find_output( ident ) == nil ) {
               }
               else {
                   result = "output";
               }
           }
           else {
               result = "bus";
           }
           
       }
       else {
           result = "transformer";
       }
   }
   else {
      result = "supplier";
   }

   if( result != "" ) {
       found = constant.TRUE;
   }

   if( !found ) {
       print("Electrical : component kind not found ", ident);
   }

   return result;
}

ElecComponentArray.count_supplier = func {
   return me.nb_suppliers;
}

ElecComponentArray.count_transformer = func {
   return me.nb_transformers;
}

ElecComponentArray.count_bus = func {
   return me.nb_buses;
}

ElecComponentArray.count_output = func {
   return me.nb_outputs;
}

ElecComponentArray.get_supplier = func( index ) {
   return me.suppliers[ index ];
}

ElecComponentArray.get_transformer = func( index ) {
   return me.transformers[ index ];
}

ElecComponentArray.get_bus = func( index ) {
   return me.buses[ index ];
}

ElecComponentArray.get_output = func( index ) {
   return me.outputs[ index ];
}


# =========
# COMPONENT
# =========

# for inheritance, the component must be the last of parents.
ElecComponent = {};

# not called by child classes !!!
ElecComponent.new = func {
   var obj = { parents : [ElecComponent],

               NOVOLT : 0.0,

               done : constant.FALSE
         };

   return obj;
};

ElecComponent.inherit_eleccomponent = func {
   var obj = ElecComponent.new();

   me.NOVOLT = obj.NOVOLT;
   me.done = obj.done;
}

# is voltage known ?
ElecComponent.is_propagate = func {
   return me.done;
}

# battery charge
ElecComponent.charge = func {
   me.clear_propagate();
}

# battery discharge
ElecComponent.discharge = func {
} 

# supplies voltage
ElecComponent.supply = func {
} 

# propagates voltage to all properties
ElecComponent.propagate = func( component = nil ) {
}

# reset propagate
ElecComponent.clear = func() {
}

ElecComponent.clear_propagate = func {
   me.done = constant.FALSE;
}

ElecComponent.set_propagate = func {
   me.done = constant.TRUE;
}

ElecComponent.log = func( message, value ) {
   message = "Electrical: " ~ message ~ " ";
   print( message, value );
}

ElecComponent.apply = func {
}


# ========
# SUPPLIER 
# ========

ElecSupplier = {};

ElecSupplier.new = func( kind, prop, rpm, volts, nb_charges, amps ) {
   var obj = { parents : [ElecSupplier,ElecComponent],

               value : 0.0,

               kind : kind,
               rpm : rpm,
               volts : volts,
               propcharge : "",
               amps : amps,

               props : prop
         };

   obj.init( nb_charges );

   return obj;
};

ElecSupplier.init = func( nb_charges ) {
   me.inherit_eleccomponent();

   if( me.is_battery() ) {
       me.propcharge = "/systems/electrical/suppliers/battery-amps[" ~ nb_charges ~ "]";
   }
}

# present voltage
ElecSupplier.get_volts = func {
   var value = getprop(me.props);

   if( value == nil ) {
       value = me.NOVOLT;
   }

   return value;
}

# battery charge
ElecSupplier.charge = func {
   if( me.is_battery() ) {
   }

   me.clear_propagate();
}

# battery discharge
ElecSupplier.discharge = func {
   if( me.is_battery() ) {
       me.value = me.volts;

       me.set_propagate();
   }

   elsif( me.is_alternator() ) {
   }

   else {
       me.log("supplier not found ", me.kind);
   }
} 

# supplies voltage
ElecSupplier.supply = func {
   # discharge only
   if( me.is_battery() ) {
   }

   elsif( me.is_alternator() ) {
       me.value = getprop(me.rpm);
       if( me.value == nil ) {
           me.value = me.NOVOLT;
       }
       elsif( me.value > me.volts ) {
           me.value = me.volts;
       }

       me.set_propagate();
   }

   else {
       me.log("supplier not found ", me.kind);
   }
} 

# reset propagate
ElecSupplier.clear = func() {
   # always knows its voltage
   if( me.is_battery() ) {
   }

   elsif( me.is_alternator() ) {
       me.clear_propagate();
   }

   else {
       me.log("clear not found ", me.kind);
   }
}

ElecSupplier.apply = func {
   setprop(me.props, me.value);

   if( me.is_battery() ) {
       setprop(me.propcharge, me.amps);
   }
}

ElecSupplier.is_battery = func {
   var result = constant.FALSE;

   if( me.kind == "battery" ) {
       result = constant.TRUE;
   }
}

ElecSupplier.is_alternator = func {
   var result = constant.FALSE;

   if( me.kind == "alternator" ) {
       result = constant.TRUE;
   }
}


# ===========
# TRANSFORMER
# ===========

ElecTransformer = {};

ElecTransformer.new = func( allvolts, prop ) {
   var obj = { parents : [ElecTransformer,ElecComponent],

               value : 0.0,

               ratio : 0,

               prop : prop
         };

   obj.init( allvolts );

   return obj;
};

ElecTransformer.init = func( allvolts ) {
   me.inherit_eleccomponent();

   var primary = allvolts.getChild("primary").getValue();

   if( primary > me.NOVOLT ) {
       var secondary = allvolts.getChild("secondary").getValue();

       me.ratio = secondary / primary;
   }
}

ElecTransformer.get_volts = func {
   return me.value;
}

ElecTransformer.propagate = func( component = nil ) {
   me.value = me.NOVOLT;

   if( component != nil ) {
       me.value = component.get_volts();
       me.value = me.ratio * me.value;
   }

   me.set_propagate();
}

ElecTransformer.clear = func() {
   me.clear_propagate();
}

ElecTransformer.apply = func {
   setprop(me.prop,me.value);
}


# ===
# BUS
# ===

ElecBus = {};

ElecBus.new = func( allprops ) {
   var obj = { parents : [ElecBus,ElecComponent],

               values : [],

               nb_props : 0,
               props : []
         };

   obj.init( allprops );

   return obj;
};

ElecBus.init = func( allprops ) {
   me.inherit_eleccomponent();

   me.nb_props = size( allprops );

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        append( me.props, allprops[i].getValue() );
        append( me.values, me.NOVOLT );
   }
}

# present voltage
ElecBus.get_volts = func {
   var value = me.NOVOLT;

   # takes the 1st property
   if( me.nb_props > 0 ) {
       value = me.values[0];
   }

   if( value == nil ) {
       value = me.NOVOLT;
   }

   return value;
}

# propagates voltage to all properties
ElecBus.propagate = func( component = nil ) {
   var volts = me.NOVOLT;

   if( component != nil ) {
       volts = component.get_volts();
   }

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        me.values[i] = volts;
   }

   me.set_propagate();
}

# reset propagate
ElecBus.clear = func() {
   me.clear_propagate();
}

ElecBus.apply = func {
   var state = "";

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        state = me.props[i];
        setprop(state, me.values[i]);
   }
}


# ======
# OUTPUT
# ======

ElecOutput = {};

ElecOutput.new = func( prop ) {
   var obj = { parents : [ElecOutput,ElecComponent],

               value : 0.0,

               props : prop
         };

   obj.inherit_eleccomponent();

   return obj;
};

# present voltage
ElecOutput.get_volts = func {
   return me.value;
}

# propagates voltage to all properties
ElecOutput.propagate = func( component = nil ) {
   var volts = me.NOVOLT;

   if( component != nil ) {
       volts = component.get_volts();
   }

   me.value = volts;

   me.set_propagate();
}

# reset propagate
ElecOutput.clear = func() {
   me.clear_propagate();
}

ElecOutput.apply = func {
   setprop(me.props,me.value);
}


# ===============
# CONNECTOR ARRAY
# ===============

ElecConnectorArray = {};

ElecConnectorArray.new = func {
   var obj = { parents : [ElecConnectorArray],

               connectors      :  [],
               nb_connectors : 0
         };

   return obj;
};

ElecConnectorArray.add = func( node, components ) {
   var inputkind = "";
   var outputkind = "";
   var prop = "";
   var child = nil;
   var result = nil;
   var input = node.getChild("input").getValue();
   var output = node.getChild("output").getValue();
   var switch = node.getNode("switch");

   if( switch != nil ) {
       child = switch.getChild("prop");
       # switch should always have a property !
       if( child != nil ) {
           prop = child.getValue();
       }
   }

   inputkind = components.find_kind( input );
   outputkind = components.find_kind( output );

   result = ElecConnector.new( input, inputkind, output, outputkind, prop );
   append(me.connectors, result);

   me.nb_connectors = me.nb_connectors + 1;
}

ElecConnectorArray.count = func {
   return me.nb_connectors;
}

ElecConnectorArray.get = func( index ) {
   return me.connectors[ index ];
}


# =========
# CONNECTOR
# =========

ElecConnector = {};

ElecConnector.new = func( input, inputkind, output, outputkind, prop ) {
   var obj = { parents : [ElecConnector],

               input : input,
               input_kind : inputkind,
               output : output,
               output_kind : outputkind,
               prop : prop
         };

   return obj;
};

ElecConnector.get_input = func {
   return me.input;
}

ElecConnector.get_input_kind = func {
   return me.input_kind;
}

ElecConnector.get_output = func {
   return me.output;
}

ElecConnector.get_output_kind = func {
   return me.output_kind;
}

ElecConnector.get_switch = func {
    var switch = constant.TRUE;

    # switch is optional, on by default
    if( me.prop != "" ) {
        switch = getprop(me.prop);
    }

    return switch;
}
