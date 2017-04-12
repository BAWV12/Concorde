The real aircraft
=================
The nose strakes improves the air flow over the delta wing (A).
The plane bulge at the top of the aft fuselage is the ADF antenna (A).

The black strip under the wing edge is de-icing (A).
The black holes below the front doors are the pressure discharge valves (A).

G-BOAC rests at Manchester airport.

Cockpit
-------
- blue (instrument panels), white beige (walls) and black (window pillars and sills).
- pilot seat, near the 2nd pillar. As instruments (artificial horizon, ASI) are close,
  the reading at landing is easy.
- overhead panel stops before the engineer panel.
- autopilot height = less than 1/2 of panel height.
- panel height = 1/2 of height to floor (below the panel).


Model
=====
The floor is supposed to be at the same level than the external nose strakes (blade),
which puts it slightly above the bottom of the (textured) doors.


Pitch
------
The original 3D model had a pitch and a longer front gear :
- the fuselage is always horizontal (B).
- the pitch seems to exist (C)(D) at empty load.


Gear
----
- for piston animation, left main gear is mirrored from right main gear.
- when gear is extended, main door closes over cylinder thanks to a flap (A).


VRP
---
The model is aligned vertically along the nose axis, but is still centered
horizontally on the center of gravity :
- that is more handy with the Blender grid. 
- the alignment of VRP to the nose tip is finished by XML (horizontal offset).


Texturing
---------
The cockpit texture without alpha makes the 2D instruments visible on a panel;
the other texture with alpha is for clipping of 2D instruments (doesn't work yet with OSG).

Livery works with only 1 texture per group :
- screen, front and side map a 2nd texture with alpha layer, for their transparent windows;
- exhaust has a separate texture.

Windows (hull, cockpit, nose) are extracted into a separated object.


TO DO
=====
- compression of gear spring.
- probes on nose, RAT.
- bore the doors.

TO DO cockpit
-------------
- UV map again the textured screws on pedestal and pilot panels.


Known problems
==============
- polygons with no area may be removed with Utils/Modeller/ac3d-despeckle, after Blender export.

Known problems outside
----------------------
- too many portholes.
- the tail wheel door seems too long : one part of tail gear hole is closed by the small left and
  right doors.
- the water deflector of main gear crosses the fuselage at retraction.
- closed doors of front gear are too wide.

Known problems cockpit
----------------------
- overhead slightly too large ?


References
==========
(A) http://www.concordesst.com :

(B) http://www.airliners.net/open.file/0603013/L/ :
    G-BOAD, by Stefan Welsch, without pitch.

(C) http://www.airliners.net/open.file/0229834/L/ :
    G-BOAF, by Carlos Borda, with pitch.

(D) http://www.concordesst.com/video/98airtoair.mov :
    British Airways clip.

    http://www.airliners.net/open.file/0441886/L/ :
    G-BOAE, by Harm Rutten.

    http://www.eflightmanuals.com/ :
    British Airways maintenance manual.


Credits
=======
Concorde model (without 3D cockpit) is from "Bogey" (unknown name and mail).

It has been made available to Flightgear upon a request of M. Franz.
See the forum of http://www.blender.org/, message from "Bogey", subject "Update Concord. Screen shots
and download links" (24 october 2003 6:23 pm).


Updates (-) and additions (+) to the original model                       Credit      Version
---------------------------------------------------------------------------------------------
+ door to passenger area                                                                2.12
+ dummy cabin.                                                            E. Huminiuc   2.11
- make the nosetip seperate in the model.                                 C. Schmitt    2.9
- make nose, visor and beginning of hull symmetrical.                     C. Schmitt    2.9
- deeper wells to fit the gears.                                                        2.9
- split of main gear cylinders (compression).                                           2.9
+ exhaust.                                                                C. Schmitt    2.8
- conversion of .rgb to .png.                                             C. Schmitt    2.8
+ visor well.                                                                           2.6
- shift aft the texture of front doors.                                                 2.5
- split of primary nozzles (reheat off texture).                                        2.4
- centered axis of front window (to match overhead).                                    2.4
- horizontal fuselage, without pitch (flat cockpit).                                    2.3
- higher side stays and stearing unit (front gear compression).                         2.3
- split of main gear pistons (bogie compression and torsion).                           2.3
- alignment to the nose tip, instead of the tail tip (VRP).                             2.3
- split of main gear wheels (spin).                                                     2.2
- alignment of main gear internal doors with their well.
- split of nozzles (reverser).                                                          2.1
- visibility of visor and nose from cockpit.                                            2.0
+ cockpit.                                                                              1.2
+ tail door closed.                                                                     1.1



Made with Blender 2.67a.
AC3D export :
- auto smooth is enabled (default is 30 degrees). Except seats and switches.
- AC3D groups are removed, to help import/export.


12 September 2015.
