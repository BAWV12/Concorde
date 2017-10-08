# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure

#TODO: split: draw_single_runway(pos)

var draw_runways = func(group, apt, controller=nil, lod=0) {
  DEBUG and print("Drawing runways for:", apt.id);

  foreach(var rw1; apt.runwaysWithoutReciprocals())
  {
    var clr = SURFACECOLORS[rw1.surface];
    if (clr == nil) { clr = SURFACECOLORS[0]};

    var icon_rw =
    group.createChild("path", "runway-" ~ rw1.id)
    .setStrokeLineWidth(0.5)
    .setColor(1.0,1.0,1.0)
    .setColorFill(clr.r, clr.g, clr.b);

    var rwy1 = Runway.new(rw1);
    var beg_thr  = rwy1.pointOffCenterline(rw1.threshold);
    var beg_thr1 = rwy1.pointOffCenterline(rw1.threshold,  0.5 * rw1.width);
    var beg_thr2 = rwy1.pointOffCenterline(rw1.threshold, -0.5 * rw1.width);
    var beg1 = rwy1.pointOffCenterline(0,  0.5 * rw1.width);
    var beg2 = rwy1.pointOffCenterline(0, -0.5 * rw1.width);

    var rw2 = rw1.reciprocal;
    var rwy2 = Runway.new(rw2);
    var end_thr  = rwy2.pointOffCenterline(rw2.threshold);
    var end_thr1 = rwy2.pointOffCenterline(rw2.threshold,  0.5 * rw2.width);
    var end_thr2 = rwy2.pointOffCenterline(rw2.threshold, -0.5 * rw2.width);
    var end1 = rwy2.pointOffCenterline(0,  0.5 * rw2.width);
    var end2 = rwy2.pointOffCenterline(0, -0.5 * rw2.width);

    icon_rw.setDataGeo
    (
    [ canvas.Path.VG_MOVE_TO,
    canvas.Path.VG_LINE_TO,
    canvas.Path.VG_LINE_TO,
    canvas.Path.VG_LINE_TO,
    canvas.Path.VG_CLOSE_PATH ],
    [ beg1[0], beg1[1],
    beg2[0], beg2[1],
    end1[0], end1[1],
    end2[0], end2[1] ]
    );

    var icon_cl =
    group.createChild("path", "centerline")
    .setStrokeLineWidth(0.5)
    .setColor(1,1,1)
    .setStrokeDashArray([15, 10]);

    icon_cl.setDataGeo
    (
    [ canvas.Path.VG_MOVE_TO,
    canvas.Path.VG_LINE_TO ],
    [ beg_thr[0], beg_thr[1],
    end_thr[0], end_thr[1] ]
    );

    var icon_thr =
    group.createChild("path", "threshold")
    .setStrokeLineWidth(1.5)
    .setColor(1,1,1);

    icon_thr.setDataGeo
    (
    [ canvas.Path.VG_MOVE_TO,
    canvas.Path.VG_LINE_TO,
    canvas.Path.VG_MOVE_TO,
    canvas.Path.VG_LINE_TO ],
    [ beg_thr1[0], beg_thr1[1],
      beg_thr2[0], beg_thr2[1],
      end_thr1[0], end_thr1[1],
      end_thr2[0], end_thr2[1] ]
    );
  }

  #draw helipads
  foreach(var hp; keys(apt.helipads))
  {
    var hp = apt.runway(hp);
    var clr = SURFACECOLORS[hp.surface];
    if (clr == nil) { clr = SURFACECOLORS[0]};

    var icon_hp =
    group.createChild("path", "helipad-" ~ hp.id)
    .setStrokeLineWidth(0.5)
    .setColor(1.0,1.0,1.0)
    .setColorFill(clr.r, clr.g, clr.b);

    var heli = Runway.new(hp);
    var p1  = heli.pointOffCenterline(0.5 * hp.length, 0.5 * hp.width);
    var p2 = heli.pointOffCenterline(0.5 * hp.length, -0.5 * hp.width);
    var p3 = heli.pointOffCenterline(-0.5 * hp.length, -0.5 * hp.width);
    var p4 = heli.pointOffCenterline(-0.5 * hp.length, 0.5 * hp.width);

    icon_hp.setDataGeo
    (
    [ canvas.Path.VG_MOVE_TO,
    canvas.Path.VG_LINE_TO,
    canvas.Path.VG_LINE_TO,
    canvas.Path.VG_LINE_TO,
    canvas.Path.VG_CLOSE_PATH ],
    [ p1[0], p1[1],
    p2[0], p2[1],
    p3[0], p3[1],
    p4[0], p4[1] ]
    );
  }
}
