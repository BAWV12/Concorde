Concorde instruments
====================
- most instruments are optimized with "group" and "switch", the first layer is the most used
  (except if too complex) : priority to autoland (high load on CPU), otherwise the most common
  layer in flight.
- color templates :
  * concorde-amber-fault.png
  *          black-bg
  *          blue-indicator
  *          green-warning
  *          red-alarm
  *          yellow-warning
  *          white-button
- warning lights are emissive by night :
  * concorde-bulb-on/off           : warning-lamps.png (rectangular).
  *          bulb-white-on/off     : orange would be barely visible below white light.
  *          bulb-led-on/off       : led.png (circular).
  *          bulb-led-white-on/off : orange would be barely visible below white light.
- low light is obtained without emission of the second layer (behind the color template).
- specific textures (IVSI, Machmeter, etc ...) are made with Metafont (template by M. Franz);
  Gimp adds the alpha layer and the transparent areas.


TO DO
=====
- replace digital instruments by real analog 2D textures.
- night vision : replace fonts by textures.
- white sliding tape for AoA (not possible with 2D instrument).
- replace LED digits by textures.
- avoid manual manipulations to add the alpha layer (conversion to SVG ?).
- 3D instruments, keeping the 3D cockpit complete (cohabitation 2D/3D instruments).
- spot lights.
- release the Metafont font files.

3D instruments
--------------
- transparent 2D textures (warning lights) in 3D instruments : 2 mesh surfaces,
  or instrument emissivity ?
- transparent 2D background (to get the lighting of panel) will need a background painting.
- 3D instruments do not seem to affect much frame rate;
  but as 2D instruments are dynamic to keep performances, frame rate is expected to drop
  significantly (50 % external view, 25 % cockpit view).



Known problems
==============
- transparent textures have a brighter strip along one of their edges.
- when click doesn't work always and everywhere, there is another instrument overlapping it.
  Even a title (instrument with only font) can disturb another instrument hotspot.
  Example : instrument having all layers shifted upwards,
  so that its bottom starts on the disturbed hotspot;
  but the bottom is not visible because without texture !
- missing hotspots are caused by a panel side lower than the underlying 3D surface.
- sometimes a bug (the condition doesn't work) appears in such a situation :

      <or include="concorde-cond-flashing-light.xml">
       <not include="concorde-cond-terrain.xml"/>
      </or>

 the solution is :

      <or>
       <or include="concorde-cond-flashing-light.xml"/>  <!-- bug -->
       <not include="concorde-cond-terrain.xml"/>
      </or>

- Gimp white textures become dark blurred when one zooms out (DME, INS).
- a few instrument files are not more used in CVS, because of renaming :
  remove is possible, if not used by /Panels/Instruments (condition -cond-), /Panels, /Models
  (condition) and /Sounds (condition).


8 November 2009.
