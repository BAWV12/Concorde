# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ================
# HYDRAULIC PARSER
# ================
HydraulicXML = {};

HydraulicXML.new = func {
   var obj = { parents : [HydraulicXML],

               HYDSEC : 1.0,

               configpath : nil,
               hydraulicpath : nil,
               iterationspath : nil,

               components : HydComponentArray.new(),
               connections : HydConnectionArray.new()
         };

   obj.init();

   return obj;
};

# creates all propagate variables
HydraulicXML.init = func {
   var children = nil;
   var nb_children = 0;
   var component = nil;

   me.hydraulicpath = props.globals.getNode("/systems/hydraulic");
   me.configpath = me.hydraulicpath.getNode("internal/config");
   me.iterationspath = me.hydraulicpath.getNode("internal/iterations");

   children = me.configpath.getChildren("supplier");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_supplier( children[i], me.HYDSEC );
        component = me.components.get_supplier( i );
        component.fill();
   }

   children = me.configpath.getChildren("circuit");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_circuit( children[i], me.HYDSEC );
        component = me.components.get_circuit( i );
        component.fill();
   }

   children = me.configpath.getChildren("connection");
   nb_children = size( children );
   for( i = 0; i < nb_children; i = i+1 ) {
        me.connections.add( children[i], me.components );
   }
}

HydraulicXML.set_rate = func( rates ) {
    me.HYDSEC = rates;
}

HydraulicXML.schedule = func {
   var component = nil;
   var iter = 0;
   var remain = constant.FALSE;

   me.clear();

   # suppliers, not real, always works
   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.pressurize();
   }

   if( me.hydraulicpath.getChild("serviceable").getValue() ) {
        iter = 0;
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

   # failure : no pressure
   else {
       for( var i = 0; i < me.components.count_circuit(); i = i+1 ) {
            component = me.components.get_circuit( i );
            component.propagate();
       }
   }

   me.apply();
}

HydraulicXML.pressurize = func( connection ) {
   var found = constant.FALSE;
   var switch = constant.FALSE;
   var inputkind = "";
   var outputkind = "";
   var input = nil;
   var output = nil;
   var component = nil;
   var component2 = nil;

   output = connection.get_output();
   outputkind = connection.get_output_kind();

   # propagate pressure
   component2 = me.components.find( output, outputkind );
   if( component2 != nil ) {
       if( !component2.is_propagate() ) {
           switch = connection.get_switch();

            # switch off means no pressure
            if( !switch ) {
                component2.propagate();
                found = constant.TRUE;
            }

            else {
                input = connection.get_input();
                inputkind = connection.get_input_kind();
                component = me.components.find( input, inputkind );
                if( component != nil ) {

                    # input knows its pressure
                    if( component.is_propagate() ) {
                        component2.propagate( component );
                        found = constant.TRUE;
                    }
                }
            }
       }

       # already solved
       else {
           switch = connection.get_switch();

           # reservoir can accept pressurization
           if( switch ) {
               input = connection.get_input();
               inputkind = connection.get_input_kind();
               component = me.components.find( input, inputkind );
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

HydraulicXML.apply = func {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.apply();
   }

   for( var i = 0; i < me.components.count_circuit(); i = i+1 ) {
        component = me.components.get_circuit( i );
        component.apply();
   }
}

HydraulicXML.clear = func {
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

HydComponentArray = {};

HydComponentArray.new = func {
   var obj = { parents : [HydComponentArray],

               supplier_name : [],
               circuit_name :  [],

               suppliers : [],
               nb_suppliers : 0,

               circuits : [],
               nb_circuits : 0,
         };

   return obj;
};

HydComponentArray.add_supplier = func( node, rates ) {
   var source = "";
   var factor = 0;
   var minpsi = 0;
   var psi = 0;
   var galus = 0;
   var result = nil;
   var name = node.getChild("name").getValue();
   var kind = node.getChild("kind").getValue();
   var prop = node.getChild("prop").getValue();

   append(me.supplier_name, name);

   if( kind == "pump" ) {
       source = node.getChild("psi-source").getValue();
       factor = node.getChild("factor").getValue();
       minpsi = node.getChild("min-psi").getValue();
       psi = node.getChild("psi").getValue();
   }

   elsif( kind == "reservoir" ) {
       prop = node.getChild("prop").getValue();
       galus = node.getChild("gal_us").getValue();
   }


   result = HydSupplier.new( kind, prop, source, factor, minpsi, psi, galus, rates );
   append(me.suppliers, result);

   me.nb_suppliers = me.nb_suppliers + 1;
}

HydComponentArray.add_circuit = func( node, rates ) {
   var result = nil;
   var name = node.getChild("name").getValue();
   var allprops = node.getChildren("prop");
   var galus = node.getChild("gal_us");

   append(me.circuit_name, name);

   result = HydCircuit.new( galus, allprops, rates );
   append(me.circuits, result);

   me.nb_circuits = me.nb_circuits + 1;
}

HydComponentArray.find_supplier = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_suppliers; i = i+1 ) {
         if( me.supplier_name[i] == ident ) {
             result = me.get_supplier( i );
             break;
         }
    }

    return result;
}

HydComponentArray.find_circuit = func( ident ) {
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
HydComponentArray.find = func( ident, kind ) {
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
       print("Hydraulic : component not found ", ident, " (", kind, ")");
   }

   return result;
}

HydComponentArray.find_kind = func( ident ) {
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
       print("Hydraulic : component kind not found ", ident);
   }

   return result;
}

HydComponentArray.count_supplier = func {
   return me.nb_suppliers;
}

HydComponentArray.count_circuit = func {
   return me.nb_circuits;
}

HydComponentArray.get_supplier = func( index ) {
   return me.suppliers[ index ];
}

HydComponentArray.get_circuit = func( index ) {
   return me.circuits[ index ];
}


# =========
# COMPONENT
# =========

# for inheritance, the component must be the last of parents.
HydComponent = {};

# not called by child classes !!!
HydComponent.new = func {
   var obj = { parents : [HydComponent],

               HYDSEC : 1.0,

               NOGALUS : 0.0,

               NOPSI : 0.0,

               done : constant.FALSE
         };

   return obj;
};

HydComponent.inherit_hydcomponent = func {
   var obj = HydComponent.new();

   me.NOGALUS = obj.NOGALUS;
   me.NOPSI = obj.NOPSI;
}

HydComponent.set_rate = func( rates ) {
   me.HYDSEC = rates;
}

# is pressure known ?
HydComponent.is_propagate = func {
   return me.done;
}

# fills reservoir
HydComponent.fill = func {
} 

# pressurize circuit
HydComponent.pressurize = func {
} 

# propagates pressure to all properties
HydComponent.propagate = func( component = nil ) {
}

# reset propagate
HydComponent.clear = func() {
   me.clear_propagate();
}

HydComponent.clear_propagate = func {
   me.done = constant.FALSE;
}

HydComponent.set_propagate = func {
   me.done = constant.TRUE;
}

HydComponent.inertia = func( prop, value ) {
   var result = getprop(prop);

   if( result != value ) {
       interpolate(prop, value, me.HYDSEC);
   }
}


# ========
# SUPPLIER 
# ========

HydSupplier = {};

HydSupplier.new = func( kind, prop, source, factor, minpsi, psi, galus, rates ) {
   var obj = { parents : [HydSupplier,HydComponent],

               value : 0.0,

               kind : kind,
               props : prop,
               source : source,
               factor : factor,
               minpsi : minpsi,
               psi : psi,
               galus : galus
         };

   obj.init( rates );

   return obj;
};

HydSupplier.init = func( rates ) {
   me.inherit_hydcomponent();

   me.set_rate( rates );
}

HydSupplier.get_psi = func {
   var result = 0.0;

   if( me.kind == "reservoir" ) {
       result = me.NOPSI;
   }
   elsif( me.kind == "pump" ) {
       result = me.value;
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }

   return result;
}

HydSupplier.get_galus = func {
   var result = 0.0;

   if( me.kind == "reservoir" ) {
       result = me.value;
   }
   elsif( me.kind == "pump" ) {
       result = me.NOGALUS;
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }

   return result;
}

HydSupplier.fill = func {
   if( me.kind == "reservoir" ) {
       me.value = me.galus;
       me.set_propagate();
   }

   elsif( me.kind == "pump" ) {
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }
}

HydSupplier.pressurize = func {
   if( me.kind == "reservoir" ) {
   }

   elsif( me.kind == "pump" ) {
       me.value = getprop(me.source);
       me.value = me.value * me.factor;

       if( me.value > me.psi ) {
           me.value = me.psi;
       }
       elsif( me.value < me.minpsi ) {
           me.value = me.NOPSI;
       }

       me.set_propagate();
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }
} 

HydSupplier.clear = func() {
   if( me.kind == "reservoir" ) {
   }

   elsif( me.kind == "pump" ) {
       me.clear_propagate();
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }
}

HydSupplier.apply = func {
   me.inertia(me.props, me.value);
}


# =======
# CIRCUIT
# =======

HydCircuit = {};

HydCircuit.new = func( contentnode, allprops, rates ) {
   var obj = { parents : [HydCircuit,HydComponent],

               contentgalus : 0.0,

               RESERVOIRCOEF : 0.8,

               contentprop : "",

               values : [],

               nb_props : 0,
               props : []
         };

   obj.init( contentnode, allprops, rates );

   return obj;
};

HydCircuit.init = func( contentnode, allprops, rates ) {
   me.inherit_hydcomponent();

   me.set_rate( rates );

   if( contentnode != nil ) {
       me.contentprop = contentnode.getValue();
   }

   me.nb_props = size( allprops );

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        append( me.props, allprops[i].getValue() );
        append( me.values, me.NOPSI );
   }
}

HydCircuit.get_psi = func {
   var value = me.NOPSI;

   # takes the 1st property
   if( me.nb_props > 0 ) {
       value = me.values[0];
   }

   if( value == nil ) {
       value = me.NOPSI;
   }

   return value;
}

HydCircuit.get_galus = func {
   return me.contentgalus;
}

# propagates pressure to all properties
HydCircuit.propagate = func( component = nil ) {
   var psi = me.NOPSI;
   var galus = me.NOGALUS;

   if( component != nil ) {
       psi = component.get_psi();
       galus = component.get_galus();
   }

   if( me.contentgalus < galus ) {
       me.contentgalus = galus;
   }

   # pressurization with 2 circuits
   if( me.nb_props > 0 ) {
       if( me.values[0] > me.NOPSI and psi > me.NOPSI ) {
           # at full load, reservoir decreases
           me.contentgalus = me.contentgalus * me.RESERVOIRCOEF;
       }
   }

   # pressurization requires a reservoir
   if( me.contentgalus > me.NOGALUS ) {
       for( var i = 0; i < me.nb_props; i = i+1 ) {
            if( me.values[i] < psi ) {
                me.values[i] = psi;
            }
        }
   }

   me.set_propagate();
}

HydCircuit.clear = func() {
   me.contentgalus = me.NOGALUS;

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        me.values[i] = me.NOPSI;
   }
   
   me.clear_propagate();
}

HydCircuit.apply = func {
   if( me.contentprop != "" ) {
        me.inertia( me.contentprop, me.contentgalus );
   }

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        me.inertia( me.props[i], me.values[i] );
   }
}


# ================
# CONNECTION ARRAY
# ================

HydConnectionArray = {};

HydConnectionArray.new = func {
   var obj = { parents : [HydConnectionArray],

               connections : [],
               nb_connections : 0
         };

   return obj;
};

HydConnectionArray.add = func( node, components ) {
   var prop = "";
   var child = nil;
   var result = nil;
   var input = node.getChild("input").getValue();
   var output = node.getChild("output").getValue();
   var inputkind = components.find_kind( input );
   var outputkind = components.find_kind( output );
   var switch = node.getNode("switch");

   if( switch != nil ) {
       child = switch.getChild("prop");
       # switch should always have a property !
       if( child != nil ) {
           prop = child.getValue();
       }
   }

   result = HydConnection.new( input, inputkind, output, outputkind, prop );
   append(me.connections, result);

   me.nb_connections = me.nb_connections + 1;
}

HydConnectionArray.count = func {
   return me.nb_connections;
}

HydConnectionArray.get = func( index ) {
   return me.connections[ index ];
}


# ==========
# CONNECTION
# ==========

HydConnection = {};

HydConnection.new = func( input, inputkind, output, outputkind, prop ) {
   var obj = { parents : [HydConnection],

               input : input,
               input_kind : inputkind,
               output : output,
               output_kind : outputkind,
               prop : prop
         };

   return obj;
};

HydConnection.get_input = func {
   return me.input;
}

HydConnection.get_input_kind = func {
   return me.input_kind;
}

HydConnection.get_output = func {
   return me.output;
}

HydConnection.get_output_kind = func {
   return me.output_kind;
}

HydConnection.get_switch = func {
    # switch is optional, on by default
    var switch = constant.TRUE;

    if( me.prop != "" ) {
        switch = getprop(me.prop);
    }

    return switch;
}
