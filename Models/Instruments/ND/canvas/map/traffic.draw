# WARNING: *.draw files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var draw_traffic = func(group, traffic, lod=0)
{
		var a = traffic;
		var tcas_group = group;
		
			var callsign = a.getNode("callsign").getValue();
			# print("Drawing traffic for:", callsign );
			var lat = a.getNode("position/latitude-deg").getValue();
			var lon = a.getNode("position/longitude-deg").getValue();
			var alt = a.getNode("position/altitude-ft").getValue();
			var dist =  a.getNode("radar/range-nm").getValue();
			var threatLvl =  a.getNode("tcas/threat-level",1).getValue();
			var raSense =  a.getNode("tcas/ra-sense",1).getValue();
			var vspeed =  a.getNode("velocities/vertical-speed-fps").getValue()*60;
			var altDiff = alt - getprop("/position/altitude-ft");
			
			var tcas_grp = tcas_group.createChild("group", callsign);
			
			var text_tcas = tcas_grp.createChild("text")
				.setDrawMode( canvas.Text.TEXT )
				.setText(sprintf("%+02.0f",altDiff/100))
				.setFont("LiberationFonts/LiberationSans-Regular.ttf")
				.setColor(1,1,1)
				.setFontSize(28)
				.setAlignment("center-center");
			if (altDiff > 0)
				text_tcas.setTranslation(0,-40);
			else
				text_tcas.setTranslation(0,40);
			if(vspeed >= 500) {
				var arrow_tcas = canvas.draw_tcas_arrow_above_500(tcas_grp);
			} elsif (vspeed < 500) {
				var arrow_tcas = canvas.draw_tcas_arrow_below_500(tcas_grp);
			}
				
			## TODO: threat level symbols should also be moved to *.draw files
			var icon_tcas = tcas_grp.createChild("path")
				.setStrokeLineWidth(3);
			if (threatLvl == 3) {
				# resolution advisory
				icon_tcas.moveTo(-17,-17)
					.horiz(34)
					.vert(34)
					.horiz(-34)
					.close()
					.setColor(1,0,0)
					.setColorFill(1,0,0);
				text_tcas.setColor(1,0,0);
				arrow_tcas.setColor(1,0,0);
			} elsif (threatLvl == 2) {
				# traffic advisory
				icon_tcas.moveTo(-17,0)
					.arcSmallCW(17,17,0,34,0)
					.arcSmallCW(17,17,0,-34,0)
					.setColor(1,0.5,0)
					.setColorFill(1,0.5,0);
				text_tcas.setColor(1,0.5,0);
				arrow_tcas.setColor(1,0.5,0);
			} elsif (threatLvl == 1) {
				# proximate traffic
				icon_tcas.moveTo(-10,0)
					.lineTo(0,-17)
					.lineTo(10,0)
					.lineTo(0,17)
					.close()
					.setColor(1,1,1)
					.setColorFill(1,1,1);
			} else {
				# other traffic
				icon_tcas.moveTo(-10,0)
					.lineTo(0,-17)
					.lineTo(10,0)
					.lineTo(0,17)
					.close()
					.setColor(1,1,1);
			}
			
			tcas_grp.setGeoPosition(lat, lon)
				.set("z-index",4);
		

		#settimer(func drawtraffic(group), 2); # updates are handled by the model, not by the view!
};
