# WARNING: *.layer files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var RunwayNDLayer = {}; 
 RunwayNDLayer.new = func(group, name) {
        var m=Layer.new(group, name, RunwayNDModel ); 
        m.setDraw( func draw_layer(layer: m, callback: draw_rwy_nd, lod:0 ) );
        return m;
}
register_layer("runway-nd", RunwayNDLayer);

