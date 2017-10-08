# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var draw_taxiways = func(group, apt, lod) {     # TODO: the LOD arg isn't stricly needed here, 
                                                # the layer is a conventional canvas group, so it can access its map 
                                                # parent and just read the "range" property to do LOD handling
	group.set("z-index",-100) # HACK: we need to encapsulate this
		 .set("stroke", "none");

	# print("drawing taxiways for:", apt.id);
	# Taxiways drawn first so the runways and parking positions end up on top.

	# Preallocate all paths at once to gain some speed
	var taxi_paths = group.createChildren("path", size(apt.taxiways));
	var i = 0;
	foreach(var taxi; apt.taxiways) {
		var clr = SURFACECOLORS[taxi.surface];
		if (clr == nil) { clr = SURFACECOLORS[0]};

		var txi = Runway.new(taxi);
		var beg1 = txi.pointOffCenterline(0,  0.5 * taxi.width);
		var beg2 = txi.pointOffCenterline(0, -0.5 * taxi.width);
		var end1 = txi.pointOffCenterline(taxi.length,  0.5 * taxi.width);
		var end2 = txi.pointOffCenterline(taxi.length, -0.5 * taxi.width);

		taxi_paths[i].setColorFill(clr.r, clr.g, clr.b)
		            .setDataGeo
		            (
		              [ canvas.Path.VG_MOVE_TO,
		                canvas.Path.VG_LINE_TO,
		                canvas.Path.VG_LINE_TO,
		                canvas.Path.VG_LINE_TO,
		                canvas.Path.VG_CLOSE_PATH ],
		              [ beg1[0], beg1[1],
		                beg2[0], beg2[1],
		                end2[0], end2[1],
		                end1[0], end1[1] ]
		            );
		i += 1;
	}
}

