# VTM - Visualisation Tête Moyenne
# aka. écran radar
# The display just below the HUD and the Visualisation Tête Bas (VTB): head level display.
# Basically it is a bit like the Fire Control Radar in the F-16: https://github.com/NikolaiVChr/f16/wiki/FCR
#
# Measurements from ac-model 2000-5:
#	* height (y) = top: 0.036 bottom: -0.036 = 72 mm, middle = 0.0
#	* width (z)	= left: 0.0576 right: -0.0576 = 115.2 mm, middle = 0.0
#
# From measurements of cockpit pictures it looks like the screen width/height is ca. 75% of an MFD.
#
# Looking at photos it looks like a 4:3 screen ration - but given the total geometry of the box
# 16:10 is used - some of it covered by the round corners.
#
# The main visual source for the VTM is the picture on page 71 in the following book:
# Alexandre Paringaux, Mirage 2000-5; Groupe de chasse 1/2 Cigognes. Zéphyr.
#


print("*** LOADING vtm.nas ... ***");

var FALSE = 0;
var TRUE = 1;


# It is basically a black and green screen.
var COLOR_BACKGROUND = [0,0.02,0]; # almost black with a bit of green
var COLOR_FOREGROUND = [0.75,1,0.25]; # between yellow and green with some white
var COLOR_RADAR = [0,1,0]; # green

var SCREEN_WIDTH = 1228;
var SCREEN_HEIGHT = 768;

# The main dimensions and corners of the screen.
# x=0, y=0 is in the top left corner; x increases towards right; y increases downwards
# There is a small padding around the drawable screen area, because the pilot moves the head etc.
var PADDING_TOP = 38;
var PADDING_BOTTOM = 60;
var PADDING_HORIZONTAL = 144;

# The radar view is where radar stuff gets displayed - between the 4 corners
var RADAR_VIEW_VERTICAL = SCREEN_HEIGHT - PADDING_TOP - PADDING_BOTTOM; # 768 - 38 - 60 = 670 left
var RADAR_VIEW_HORIZONTAL = SCREEN_WIDTH - 2 * PADDING_HORIZONTAL; # 1228 - 2*144 = 940 left

var CORNER_LINE_LENGTH = 75;
var LINE_WIDTH = 4;
var GRID_TICK_LENGTH = 12;

var FONT_SIZE = 36;
var FONT_SIZE_BIG = 48;
var FONT_ASPECT_RATIO = 1;
var FONT_MONO_REGULAR = "LiberationFonts/LiberationMono-Regular.ttf";
var FONT_MONO_BOLD = "LiberationFonts/LiberationMono-Bold.ttf";
var TEXT_PADDING = 6; # when a text needs to be away from something else a bit

var MAX_CONTACTS = 28; # max nb of aircrafts for which radar echoes can be displayed
var TARGET_WIDTH = 36;

var VTM = {
	new: func() {
		var vtm_obj = {parents: [VTM]};
		vtm_obj.vtm_canvas = canvas.new({
		                     "name": "vtm_canvas",
		                     "size": [SCREEN_WIDTH, SCREEN_HEIGHT],
		                     "view": [SCREEN_WIDTH, SCREEN_HEIGHT],
		                     "mipmapping": 0
		});

		vtm_obj.cursor_pos = [RADAR_VIEW_HORIZONTAL/8,-RADAR_VIEW_VERTICAL*3/8]; # a bit off middle towards right and the top part of the screen
		vtm_obj.cursor_trigger_prev = FALSE;
		vtm_obj.n_contacts = 0;


		vtm_obj.vtm_canvas.addPlacement({"node": "vtm_ac_object"});
		vtm_obj.vtm_canvas.setColorBackground(COLOR_BACKGROUND);

		vtm_obj.root = vtm_obj.vtm_canvas.createGroup("root");
		vtm_obj.root.setTranslation(_getCenterCoord());

		vtm_obj._createVisibleCorners();
		vtm_obj._createScreenModeGroup();
		vtm_obj._createRectangularFieldOfViewGrid();
		vtm_obj._createPPIView();
		vtm_obj._createCursors();
		vtm_obj._createTargets();
		vtm_obj._createStandbyText();
		vtm_obj._createRadarModesGroup();

		return vtm_obj;
	},

	# The 4 visible corners at the edges of the main screen estate
	_createVisibleCorners: func() {
		me.corners_group = me.root.createChild("group", "corners_group");
		me.corners_group.setTranslation(_getTopLeftTranslation());
		me.left_upper_corner  = me.corners_group.createChild("path", "left_upper_corner")
		                                        .setColor(COLOR_FOREGROUND)
		                                        .moveTo(PADDING_HORIZONTAL + CORNER_LINE_LENGTH,
		                                                PADDING_TOP)
		                                        .horizTo(PADDING_HORIZONTAL)
		                                        .vertTo(PADDING_TOP + CORNER_LINE_LENGTH)
		                                        .setStrokeLineWidth(LINE_WIDTH);
		me.right_upper_corner = me.corners_group.createChild("path", "right_upper_corner")
		                                        .setColor(COLOR_FOREGROUND)
		                                        .moveTo(SCREEN_WIDTH - PADDING_HORIZONTAL - CORNER_LINE_LENGTH,
		                                                PADDING_TOP)
		                                        .horizTo(SCREEN_WIDTH - PADDING_HORIZONTAL)
		                                        .vertTo(PADDING_TOP + CORNER_LINE_LENGTH)
		                                        .setStrokeLineWidth(LINE_WIDTH);
		me.left_lower_corner  = me.corners_group.createChild("path", "left_lower_corner")
		                                        .setColor(COLOR_FOREGROUND)
		                                        .moveTo(PADDING_HORIZONTAL + CORNER_LINE_LENGTH,
		                                                SCREEN_HEIGHT - PADDING_BOTTOM)
		                                        .horizTo(PADDING_HORIZONTAL)
		                                        .vertTo(SCREEN_HEIGHT - PADDING_BOTTOM - CORNER_LINE_LENGTH)
		                                        .setStrokeLineWidth(LINE_WIDTH);
		me.right_lower_corner = me.corners_group.createChild("path", "right_lower_corner")
		                                        .setColor(COLOR_FOREGROUND)
		                                        .moveTo(SCREEN_WIDTH - PADDING_HORIZONTAL - CORNER_LINE_LENGTH,
		                                                SCREEN_HEIGHT - PADDING_BOTTOM)
		                                        .horizTo(SCREEN_WIDTH - PADDING_HORIZONTAL)
		                                        .vertTo(SCREEN_HEIGHT - PADDING_BOTTOM - CORNER_LINE_LENGTH)
		                                        .setStrokeLineWidth(LINE_WIDTH);
		me.corners_group.hide();
	},

	# The text for the screen main modes: RDR (radar) and LDP (laser designation point)
	# appears at the bottom of the screen
	_createScreenModeGroup: func() {
		me.screen_mode_group = me.root.createChild("group", "screen_mode_group");
		me.screen_mode_group.setTranslation(_getTopLeftTranslation());
		me.screen_mode_rdr     = me.screen_mode_group.createChild("text", "screen_mode_rdr")
		                                             .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
		                                             .setFont(FONT_MONO_BOLD)
		                                             .setColor(COLOR_FOREGROUND)
		                                             .setAlignment("left-top")
		                                             .setText("RDR")
		                                             .setTranslation(PADDING_HORIZONTAL + 0.5*0.25*RADAR_VIEW_HORIZONTAL,
		                                                             SCREEN_HEIGHT - PADDING_BOTTOM + TEXT_PADDING);
		me.screen_mode_ldp     = me.screen_mode_group.createChild("text", "screen_mode_ldp")
		                                             .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
		                                             .setFont(FONT_MONO_BOLD)
		                                             .setColor(COLOR_FOREGROUND)
		                                             .setAlignment("left-top")
		                                             .setText("LDP")
		                                             .setTranslation(PADDING_HORIZONTAL + 1.5*0.25*RADAR_VIEW_HORIZONTAL,
		                                                             SCREEN_HEIGHT - PADDING_BOTTOM + TEXT_PADDING);
		me.screen_mode_rdr_box = me.screen_mode_group.createChild("path", "screen_mode_rdr_box")
		                                             .setColor(COLOR_FOREGROUND)
		                                             .rect(PADDING_HORIZONTAL + 0.4*0.25*RADAR_VIEW_HORIZONTAL,
		                                                   SCREEN_HEIGHT - PADDING_BOTTOM + 1,
		                                                   0.5*0.25*RADAR_VIEW_HORIZONTAL, 30)
		                                             .setStrokeLineWidth(LINE_WIDTH);
		me.screen_mode_ldp_box = me.screen_mode_group.createChild("path", "screen_mode_ldp_box")
		                                             .setColor(COLOR_FOREGROUND)
		                                             .rect(PADDING_HORIZONTAL + 1.4*0.25*RADAR_VIEW_HORIZONTAL,
		                                                   SCREEN_HEIGHT - PADDING_BOTTOM + 1,
		                                                   0.5*0.25*RADAR_VIEW_HORIZONTAL, 30)
		                                             .setStrokeLineWidth(LINE_WIDTH);
		me.screen_mode_ldp_box.hide();
		me.screen_mode_group.hide();
	},

	# Create the stippled grid for B-scope
	_createRectangularFieldOfViewGrid: func() {
		me.rectangular_fov_grid_group = me.root.createChild("group", "rectangular_fov_grid");
		me.rectangular_fov_grid_group.setTranslation(_getTopLeftTranslation());
		me.top_grid_line = me.rectangular_fov_grid_group.createChild("path", "top_grid_line")
		                                                .setColor(COLOR_RADAR)
		                                                .moveTo(PADDING_HORIZONTAL + GRID_TICK_LENGTH, PADDING_TOP - GRID_TICK_LENGTH)
		                                                .horizTo(SCREEN_WIDTH - PADDING_HORIZONTAL - GRID_TICK_LENGTH)
		                                                .setStrokeLineWidth(LINE_WIDTH);
		me.top_ticks     = me.rectangular_fov_grid_group.createChild("path", "top_ticks")
		                                                .setColor(COLOR_RADAR)
		                                                .moveTo(PADDING_HORIZONTAL + 0.25*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP - GRID_TICK_LENGTH)
		                                                .vertTo(PADDING_TOP)
		                                                .moveTo(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP - GRID_TICK_LENGTH)
		                                                .vertTo(PADDING_TOP)
		                                                .moveTo(PADDING_HORIZONTAL + 0.75*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP - GRID_TICK_LENGTH)
		                                                .vertTo(PADDING_TOP)
		                                                .setStrokeLineWidth(LINE_WIDTH);
		var spacing = (RADAR_VIEW_VERTICAL - 4 * 2 * GRID_TICK_LENGTH) / 4;
		me.line_ticks    = me.rectangular_fov_grid_group.createChild("path", "line_ticks")
		                                                .setColor(COLOR_FOREGROUND)
		                                                # left
		                                                .moveTo(PADDING_HORIZONTAL + 0.25*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + spacing)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .moveTo(PADDING_HORIZONTAL + 0.25*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + 2*spacing + 2*GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .moveTo(PADDING_HORIZONTAL + 0.25*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + 3*spacing + 2*2*GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .moveTo(PADDING_HORIZONTAL + 0.25*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + RADAR_VIEW_VERTICAL - GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                # right
		                                                .moveTo(PADDING_HORIZONTAL + 0.75*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + spacing)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .moveTo(PADDING_HORIZONTAL + 0.75*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + 2*spacing + 2*GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .moveTo(PADDING_HORIZONTAL + 0.75*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + 3*spacing + 2*2*GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .moveTo(PADDING_HORIZONTAL + 0.75*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + RADAR_VIEW_VERTICAL - GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                # middle
		                                                .moveTo(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + RADAR_VIEW_VERTICAL - CORNER_LINE_LENGTH - 2*GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .moveTo(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL,
		                                                        PADDING_TOP + RADAR_VIEW_VERTICAL - GRID_TICK_LENGTH)
		                                                .vert(2*GRID_TICK_LENGTH)
		                                                .setStrokeLineWidth(LINE_WIDTH);
		me.rectangular_fov_grid_group.hide();
	},


	# Create circle sector grid for PPI view. We draw stippled lines at 30 and 60 degs to each side.
	# Because the sectors can have different angles, the circle at the top cannot be drawn fixed.
	_createPPIView: func() {
		me.ppi_fov_grid_group = me.root.createChild("group", "ppi_fov_grid");
		me.ppi_fov_grid_group.setTranslation(0, 0.5 * SCREEN_HEIGHT - PADDING_BOTTOM);

		me.ppi_circle_group = me.ppi_fov_grid_group.createChild("group", "ppi_circle_group");

		me.angle_markers = setsize([],5);
		var angle_rad = 30 * D2R;
		var circle_x = RADAR_VIEW_VERTICAL * math.sin(angle_rad);
		var circle_y = RADAR_VIEW_VERTICAL * math.cos(angle_rad);
		var dash_array = [1*GRID_TICK_LENGTH, 4*GRID_TICK_LENGTH];
		me.angle_markers[0] = me.ppi_fov_grid_group.createChild("path")
		                                           .moveTo(0, 0)
		                                           .lineTo(-circle_x, -circle_y)
		                                           .setStrokeLineWidth(LINE_WIDTH)
		                                           .setColor(COLOR_FOREGROUND)
		                                           .setStrokeDashArray(dash_array);
		me.angle_markers[1] = me.ppi_fov_grid_group.createChild("path")
		                                           .moveTo(0, 0)
		                                           .lineTo(circle_x, -circle_y)
		                                           .setStrokeLineWidth(LINE_WIDTH)
		                                           .setColor(COLOR_FOREGROUND)
		                                           .setStrokeDashArray(dash_array);
		angle_rad = 60 * D2R;
		circle_x = RADAR_VIEW_VERTICAL * math.sin(angle_rad);
		circle_y = RADAR_VIEW_VERTICAL * math.cos(angle_rad);
		me.angle_markers[2] = me.ppi_fov_grid_group.createChild("path")
		                                           .moveTo(0, 0)
		                                           .lineTo(-circle_x, -circle_y)
		                                           .setStrokeLineWidth(LINE_WIDTH)
		                                           .setColor(COLOR_FOREGROUND)
		                                           .setStrokeDashArray(dash_array);
		me.angle_markers[3] = me.ppi_fov_grid_group.createChild("path")
		                                           .moveTo(0, 0)
		                                           .lineTo(circle_x, -circle_y)
		                                           .setStrokeLineWidth(LINE_WIDTH)
		                                           .setColor(COLOR_FOREGROUND)
		                                           .setStrokeDashArray(dash_array);
		me.angle_markers[4] = me.ppi_fov_grid_group.createChild("path")
		                                           .moveTo(0, -RADAR_VIEW_VERTICAL)
		                                           .lineTo(0, -RADAR_VIEW_VERTICAL + 2*GRID_TICK_LENGTH)
		                                           .setStrokeLineWidth(LINE_WIDTH)
		                                           .setColor(COLOR_RADAR);
		me.ppi_fov_grid_group.hide();
	},

	_createCursors: func() { # Selection cursor
		me.cursor_group = me.root.createChild("group");
		me.cursor_stt = me.cursor_group.createChild("path")
		                               .moveTo(0, GRID_TICK_LENGTH/2).vert(GRID_TICK_LENGTH*3)
		                               .moveTo(0, -GRID_TICK_LENGTH/2).vert(-GRID_TICK_LENGTH*3)
		                               .moveTo(-GRID_TICK_LENGTH/2, 0).horiz(-GRID_TICK_LENGTH*3)
		                               .moveTo(GRID_TICK_LENGTH/2, 0).horiz(GRID_TICK_LENGTH*3)
		                               .setStrokeLineWidth(LINE_WIDTH)
		                               .setColor(COLOR_RADAR);
		me.cursor_group.hide();
	},

	# 3 types of targets: selected target, friend targets, foe targets.
	# The selected target (max 1) is a cross.
	# The friendly targets (given the IFF) are drawn as a filled circle.
	# Foe targets are drawn as open squares - with the opening being on the back side of the target
	_createTargets: func() {
		me.targets_group = me.root.createChild("group", "targets_group");
		me.selected_target          = me.targets_group.createChild("path", "selected_target")
		                                              .setColor(COLOR_RADAR)
		                                              .moveTo(-0.5 * TARGET_WIDTH, 0)
		                                              .horiz(TARGET_WIDTH)
		                                              .moveTo(0, -0.5 * TARGET_WIDTH)
		                                              .vert(TARGET_WIDTH)
		                                              .setStrokeLineWidth(2*LINE_WIDTH);

		me.selected_target_callsign = me.targets_group.createChild("text", "selected_target_callsign")
		                                              .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
		                                              .setFont(FONT_MONO_BOLD)
		                                              .setColor(COLOR_RADAR)
		                                              .setAlignment("right-top")
		                                              .setText("")
		                                              .setTranslation(0.5 * RADAR_VIEW_HORIZONTAL - TEXT_PADDING,
		                                                              0.5 * RADAR_VIEW_VERTICAL + TEXT_PADDING);
		me.selected_target_callsign.enableUpdate();

		me.friend_contacts = setsize([],MAX_CONTACTS);
		for (var i = 0; i<MAX_CONTACTS; i += 1) {
			me.friend_contacts[i] = me.targets_group.createChild("path")
			                                       .setColor(COLOR_RADAR)
			                                       .circle(0.5 * TARGET_WIDTH, 0, 0)
			                                       .setStrokeLineWidth(2*LINE_WIDTH);
		}

		me.air_targets = setsize([],MAX_CONTACTS); # foe's in the air - which are not on the ground or at sea
		for (var i = 0; i<MAX_CONTACTS; i += 1) {
			me.air_targets[i]    = me.targets_group.createChild("path")
			                                       .setColor(COLOR_RADAR)
			                                       .moveTo(-0.5 * TARGET_WIDTH, -0.5 * TARGET_WIDTH)
			                                       .vert(TARGET_WIDTH)
			                                       .moveTo(-0.5 * TARGET_WIDTH, -0.5 * TARGET_WIDTH)
			                                       .horiz(TARGET_WIDTH)
			                                       .vert(TARGET_WIDTH)
			                                       .setStrokeLineWidth(LINE_WIDTH);
		}

		me.gnd_targets = setsize([],MAX_CONTACTS); # targets on the ground or at sea
		for (var i = 0; i<MAX_CONTACTS; i += 1) {
			me.gnd_targets[i]    = me.targets_group.createChild("path")
			                                       .setColor(COLOR_RADAR)
			                                       .setColorFill(COLOR_RADAR)
			                                       .moveTo(0, -0.5 * TARGET_WIDTH)
			                                       .lineTo(0.5 * TARGET_WIDTH, 0)
			                                       .lineTo(0, 0.5 * TARGET_WIDTH)
			                                       .lineTo(-0.5 * TARGET_WIDTH, 0)
			                                       .setStrokeLineWidth(LINE_WIDTH);
		}

		me.targets_group.hide();

		# a special group for drawing a speed indicating line for targets with a minimum speed
		me.targets_speed_group = me.root.createChild("group", "targets_speed_group");
		me.targets_speeds = setsize([],MAX_CONTACTS);
	},

	# When the radar goes into stand-by mode
	_createStandbyText: func () {
		me.standby_group = me.root.createChild("group", "standby_group");
		me.standby_group.setTranslation(_getTopLeftTranslation());
		me.standby_text = me.standby_group.createChild("text", "standby_text")
		                                  .setFontSize(FONT_SIZE_BIG, FONT_ASPECT_RATIO)
		                                  .setFont(FONT_MONO_BOLD)
		                                  .setColor(COLOR_RADAR)
		                                  .setAlignment("center-center")
		                                  .setText("SILENCE")
		                                  .setTranslation(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL,
		                                                  PADDING_TOP + 200);
		me.standby_group.hide();
	},

	# When the radar goes into stand-by mode
	# The a-bars and the b-bars should be 0.25 to the left cf. the original in the book, but then there would not be space for the
	# root mode name plus the short name of the radar mode.
	_createRadarModesGroup: func () {
		var y_top_pos = PADDING_TOP + 10;
		me.radar_modes_group = me.root.createChild("group", "radar_range_group");
		me.radar_modes_group.setTranslation(_getTopLeftTranslation());
		me.radar_left_text  = me.radar_modes_group.createChild("text", "radar_left_text")
		                                          .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
		                                          .setFont(FONT_MONO_BOLD)
		                                          .setColor(COLOR_RADAR)
		                                          .setAlignment("left-top")
		                                          .setText("MRF")
		                                          .setTranslation(PADDING_HORIZONTAL + 10, y_top_pos);
		me.radar_a_bars     = me.radar_modes_group.createChild("text", "radar_a_bars")
		                                          .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
		                                          .setFont(FONT_MONO_BOLD)
		                                          .setColor(COLOR_RADAR)
		                                          .setAlignment("center-top")
		                                          .setText("A1")
		                                          .setTranslation(PADDING_HORIZONTAL + 0.375*RADAR_VIEW_HORIZONTAL, y_top_pos);
		me.radar_a_bars.enableUpdate();
		me.radar_b_bars     = me.radar_modes_group.createChild("text", "radar_b_bars")
		                                          .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
		                                          .setFont(FONT_MONO_BOLD)
		                                          .setColor(COLOR_RADAR)
		                                          .setAlignment("right-top")
		                                          .setText("HI")
		                                          .setTranslation(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL - 10, y_top_pos);
		me.radar_b_bars.enableUpdate();
		me.radar_range_text = me.radar_modes_group.createChild("text", "radar_range_text")
		                                          .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
		                                          .setFont(FONT_MONO_BOLD)
		                                          .setColor(COLOR_RADAR)
		                                          .setAlignment("right-top")
		                                          .setText("")
		                                          .setTranslation(SCREEN_WIDTH - PADDING_HORIZONTAL - 10, y_top_pos);
		me.radar_range_text.enableUpdate();
		me.radar_modes_group.hide();
	},

	_updateTargets: func(max_azimuth_rad, max_distance_m, heading_true, is_ppi, radar_mode_root_name) {
		var target_contacts_list = radar_system.apg68Radar.getActiveBleps();
		var i = 0;
		var has_priority = FALSE;
		var relative_heading_rad = 0; # the heading of the target as seen by this aircraft with nose = North
		var screen_pos = nil;
		var target_speed_m_s = 0;

		me.n_contacts = 0;
		me.radar_contacts = [];
		me.radar_contacts_pos = [];
		me.targets_speed_group.removeAllChildren();
		var delta = nil;

		var is_gnd = _is_ground_mode(radar_mode_root_name);

		# walk through all existing targets as per available list
		foreach(var contact; target_contacts_list) {
			append(me.radar_contacts, contact);
			var info = contact.getLastBlep();
			var screen_pos = nil;
			relative_heading_rad = geo.normdeg(contact.getHeading() - heading_true) * D2R;
			if (is_ppi = TRUE) {
				screen_pos = _calcTargetScreenPositionPPIScope(info.getRangeNow(), max_distance_m, info.getAZDeviation()*D2R);
			} else {
				screen_pos = _calcTargetScreenPositionBScope(info.getRangeNow(), max_distance_m, info.getAZDeviation()*D2R, max_azimuth_rad);
			}
			append(me.radar_contacts_pos, screen_pos);

			me.friend_contacts[i].hide(); # currently we do not know the friends
			if (contact.equalsFast(radar_system.apg68Radar.getPriorityTarget())) {
				has_priority = TRUE;
				me.selected_target.setTranslation(screen_pos[0], screen_pos[1]);
				me.selected_target_callsign.updateText(contact.getCallsign());
				me.air_targets[i].hide();
				me.gnd_targets[i].hide();
			} else {
				if (is_gnd == FALSE) {
					me.air_targets[i].setRotation(relative_heading_rad);
					me.air_targets[i].setTranslation(screen_pos[0], screen_pos[1]);
					me.air_targets[i].show();
					me.gnd_targets[i].hide();
				} else {
					me.gnd_targets[i].setTranslation(screen_pos[0], screen_pos[1]);
					me.gnd_targets[i].show();
					me.air_targets[i].hide();
				}
			}

			# Draw a line from the target to indicate the speed - only if faster than 50 kt, ca 25 m/s
			# Based on the pict from the book the selected target does not get a line, here we do
			target_speed_m_s = contact.get_Speed() * KT2MPS;
			if (target_speed_m_s > 25) {
				delta = _calcTargetSpeedIndication(target_speed_m_s, relative_heading_rad);
				me.targets_speeds[i] = me.targets_speed_group.createChild("path")
				                                             .setColor(COLOR_RADAR)
				                                             .moveTo(screen_pos[0] + delta[0], screen_pos[1] - delta[1])
				                                             .lineTo(screen_pos[0] + delta[2], screen_pos[1] - delta[3])
				                                             .setStrokeLineWidth(LINE_WIDTH);
				me.targets_speeds[i].update(); # because targets_speed_group children get deleted in next frame
			}
			i += 1;
		}
		me.n_contacts = i;

		# handle the index positions if the target list was shorter than the reserved elements
		for (var j = i; j < MAX_CONTACTS; j += 1) {
			me.friend_contacts[j].hide();
			me.air_targets[j].hide();
			me.gnd_targets[j].hide();
		}
		me.selected_target.setVisible(has_priority);
		me.selected_target_callsign.setVisible(has_priority);
	},

	_updateRadarTexts: func(radar_mode_root_name, radar_mode_name) {
		# this is fictional based on radar2.nas->radar_mode_toggle(). In the real screen it reads e.g. "MRF"
		me.radar_left_text.setText(radar_mode_root_name~"-"~radar_mode_name);

		# This is fictional based on interpretation of display_system.nas in the F16
		# The azimuth is only to one side - i.e. az=40 means plus/minus 40 -> 80 degrees
		var max_azimuth_deg = radar_system.apg68Radar.getAzimuthRadius();
		var az_text = "A0"; # does not exist
		if (max_azimuth_deg < 20) {
			az_text = "A1";
		} elsif (max_azimuth_deg < 30) {
			az_text = "A2";
		} elsif (max_azimuth_deg < 40) {
			az_text = "A3";
		} elsif (max_azimuth_deg < 50) {
			az_text = "A4";
		} elsif (max_azimuth_deg < 60) {
			az_text = "A5";
		} elsif (max_azimuth_deg < 70) {
			az_text = "A6";
		}
		me.radar_a_bars.setText(az_text);

		me.radar_b_bars.setText(radar_system.apg68Radar.getBars()~"B");

		me.radar_range_text.setText(radar_system.apg68Radar.getRange());
	},

	_updatePPICircle: func(max_azimuth_rad) {
		me.ppi_circle_group.removeAllChildren();
		var circle_x = RADAR_VIEW_VERTICAL * math.sin(max_azimuth_rad);
		var circle_y = RADAR_VIEW_VERTICAL * math.cos(max_azimuth_rad);

		var ppi_circle = me.ppi_circle_group.createChild("path")
		                                    .moveTo(-circle_x, -circle_y)
		                                    .arcSmallCW(RADAR_VIEW_VERTICAL, RADAR_VIEW_VERTICAL, 0, 2*circle_x, 0)
		                                    .setStrokeLineWidth(LINE_WIDTH)
		                                    .setColor(COLOR_RADAR);
		ppi_circle.update();
	},

	# Originally copied from JA37
	_updateCursor: func(max_azimuth_rad, max_distance_m, heading_true, is_ppi, radar_mode_name) {
		if (displays.common.cursor != displays.VTM) {
			me.cursor_group.hide();
			return;
		}
		if (radar_mode_name == "TWS") {
			me.cursor_group.hide();
			return;
		}

		# Retrieve cursor movement from JSBSim
		var cursor_mov = displays.common.getCursorDelta();
		displays.common.resetCursorDelta();
		var click = cursor_mov[2] and !me.cursor_trigger_prev;
		me.cursor_trigger_prev = cursor_mov[2];

		var radar_priority_target = radar_system.apg68Radar.getPriorityTarget();
		if (radar_priority_target != nil) {
			me.cursor_group.hide();
			# clicking unlocks
			if (click) {
				# cursor restarts from current target position
				var info = radar_priority_target.getLastBlep();
				var screen_pos = nil;
				if (info != nil) {
					if (is_ppi = TRUE) {
						screen_pos = _calcTargetScreenPositionPPIScope(info.getRangeNow(), max_distance_m, info.getAZDeviation()*D2R);
					} else {
						screen_pos = _calcTargetScreenPositionBScope(info.getRangeNow(), max_distance_m, info.getAZDeviation()*D2R, max_azimuth_rad);
					}
					me.cursor_pos[0] = math.clamp(screen_pos[0], -RADAR_VIEW_HORIZONTAL/2, RADAR_VIEW_HORIZONTAL/2);
					me.cursor_pos[1] = math.clamp(screen_pos[1], -RADAR_VIEW_VERTICAL/2, RADAR_VIEW_VERTICAL/2);
				}
				radar_system.apg68Radar.undesignate();
			}
			return;
		}

		me.cursor_pos[0] += cursor_mov[0] * RADAR_VIEW_HORIZONTAL * 0.2;
		me.cursor_pos[1] += cursor_mov[1] * RADAR_VIEW_VERTICAL * 0.2;
		me.cursor_pos[0] = math.clamp(me.cursor_pos[0], -RADAR_VIEW_HORIZONTAL/2, RADAR_VIEW_HORIZONTAL/2);
		me.cursor_pos[1] = math.clamp(me.cursor_pos[1], -RADAR_VIEW_VERTICAL/2, RADAR_VIEW_VERTICAL/2);

		me.cursor_group.show();
		me.cursor_group.setTranslation(me.cursor_pos[0], me.cursor_pos[1]);
		me.cursor_stt.setVisible(TRUE);

		if (click) {
			var new_sel = me._findCursorTrack();
			if (new_sel != nil) {
				radar_system.apg68Radar.designate(new_sel);
			}
		}
	},

	_distCursorTrack: func(i) {
		return math.sqrt(
			math.pow(me.cursor_pos[0] - me.radar_contacts_pos[i][0], 2)
			+ math.pow(me.cursor_pos[1] - me.radar_contacts_pos[i][1], 2)
		);
	},

	_findCursorTrack: func() {
		var closest_i = nil;
		var min_dist = 100000;
		for (var i=0; i < me.n_contacts; i+=1) {
			var dist = me._distCursorTrack(i);
			if (dist < min_dist) {
				closest_i = i;
				min_dist = dist;
			}
		}
		if (min_dist < TARGET_WIDTH/2) {
			return me.radar_contacts[closest_i];
		} else {
			return nil;
		}
	},

	update: func() {
		var global_visible = FALSE;
		var radar_voltage = props.globals.getNode("/systems/electrical/outputs/radar").getValue();
		var heading_true = props.globals.getNode("/orientation/heading-deg").getValue();
		var max_azimuth_rad = radar_system.apg68Radar.getAzimuthRadius() * D2R;
		var max_distance_m = radar_system.apg68Radar.getRange() * NM2M;
		var radar_mode_root_name = radar_system.apg68Radar.currentMode.rootName;
		var radar_mode_name = radar_system.apg68Radar.getMode();
		if (radar_voltage != nil and radar_voltage >= 23) {
			global_visible = TRUE;
		}
		me.corners_group.setVisible(global_visible);
		me.screen_mode_group.setVisible(global_visible);
		me.radar_modes_group.setVisible(global_visible);

		var is_ppi = FALSE;
		if (global_visible == TRUE) {
			if (_is_ground_mode(radar_mode_root_name)) {
				is_ppi = TRUE;
				me.ppi_fov_grid_group.setVisible(TRUE);
				me._updatePPICircle(max_azimuth_rad);
				me.rectangular_fov_grid_group.setVisible(FALSE);
			} else {
				me.ppi_fov_grid_group.setVisible(FALSE);
				me.rectangular_fov_grid_group.setVisible(TRUE);
			}
			me._updateRadarTexts(radar_mode_root_name, radar_mode_name);
		} else {
			me.ppi_fov_grid_group.setVisible(FALSE);
			me.rectangular_fov_grid_group.setVisible(FALSE);
		}

		if (global_visible == FALSE) {
			me.standby_group.setVisible(global_visible);
			me.targets_group.setVisible(global_visible);
		#} else if (props.globals.getNode("/instrumentation/radar/radar-standby").getBoolValue()) {
		#	me.standby_group.show();
		#	me.targets_group.hide();
		} else {
			me.standby_group.hide();
			me.targets_group.show();
			me.targets_speed_group.show();
			me._updateTargets(max_azimuth_rad, max_distance_m, heading_true, is_ppi, radar_mode_root_name);
			me._updateCursor(max_azimuth_rad, max_distance_m, heading_true, is_ppi, radar_mode_name); # needs to be after _updateTargets()
		}
	},
};

var _is_ground_mode = func(radar_mode_root_name) {
	if (radar_mode_root_name == 'SEA' or radar_mode_root_name == 'GM' or radar_mode_root_name == 'GMT') {
		return TRUE;
	}
	return FALSE;
};

# Calculates the relative screen position of a target in PPI-scope
# Returns the x/y position on the Canvas
var _calcTargetScreenPositionPPIScope = func(distance_m, max_distance_m, angle_rad) {
	var x_pos = RADAR_VIEW_VERTICAL * math.sin(angle_rad) * distance_m / max_distance_m;
	var y_pos = 0.5 * RADAR_VIEW_VERTICAL - RADAR_VIEW_VERTICAL * math.cos(angle_rad) * distance_m / max_distance_m;
	return [x_pos, y_pos];
};

# Calculates the relative screen position of a target in B-scope
# Returns the x/y position on the Canvas
var _calcTargetScreenPositionBScope = func(distance_m, max_distance_m, angle_rad, max_azimuth_rad) {
	var x_pos = angle_rad / max_azimuth_rad * (0.5 * RADAR_VIEW_HORIZONTAL);
	var y_pos = 0.5 * RADAR_VIEW_VERTICAL - distance_m / max_distance_m * RADAR_VIEW_VERTICAL;
	return [x_pos, y_pos];
};

# Calculates an indication of the speed and direction of a target.
# For each 100 m/s (ca. 200 kt) extra the length increases
var _calcTargetSpeedIndication = func(target_speed_m_s, relative_heading_rad) {
	# the start point
	var dist_away = 0.5 * TARGET_WIDTH;
	var x_start_delta = dist_away * math.sin(relative_heading_rad);
	var y_start_delta = dist_away * math.cos(relative_heading_rad);

	# the end point
	dist_away = dist_away + TARGET_WIDTH + math.floor(target_speed_m_s/100) * 0.5 * TARGET_WIDTH;
	var x_end_delta = dist_away * math.sin(relative_heading_rad);
	var y_end_delta = dist_away * math.cos(relative_heading_rad);
	return [x_start_delta, y_start_delta, x_end_delta, y_end_delta];
};

# assuming a x/y coordinate system with x towards left and y towards up
# calculate a new direct_distance and bearing 1 minute away
# not suitable for B-scope
var _calcTargetOneMinute = func(speed_m_s, relative_heading_rad, direct_distance_m, bearing_rad) {
	var dist_away = speed_m_s * 60;
	var x_new = direct_distance_m * math.sin(bearing_rad) + dist_away * math.sin(relative_heading_rad);
	var y_new = direct_distance_m * math.cos(bearing_rad) + dist_away * math.cos(relative_heading_rad);
	if (y_new == 0) {
		y_new = 0.001;
	}
	var new_angle = 90 - math.atan2(x_new, y_new) * R2D;
	var new_dist = math.sqrt(x_new * x_new + y_new * y_new);
	return [new_dist, new_angle];
};

# the absolute coordinate from top left to screen middle
var _getCenterCoord = func() {
	return [0.5 * SCREEN_WIDTH, 0.5 * SCREEN_HEIGHT];
};

# get the translation from the center of screen coordinates to top left
var _getTopLeftTranslation = func() {
	return [-0.5 * SCREEN_WIDTH, -0.5 * SCREEN_HEIGHT];
};
