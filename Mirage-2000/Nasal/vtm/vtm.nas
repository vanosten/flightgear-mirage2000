# VTM - Visualisation Tête Moyenne
# aka. écran radar
# The display just below the HUD and the Visualisation Tête Bas (VTB): head level display.
# Basically it is a bit like the Fire Control Radar in the F-16: https://github.com/NikolaiVChr/f16/wiki/FCR
#
# Measurements from ac-model 2000-5: 
#  * height (y) = top: -0.075 bottom: -0.159 = 84 mm, middle = -0.117
#  * width (z)  = left: 0.060 right: -0.060 = 120 mm, middle = 0.0
#  * depth (x) -3.305 (bottom of front), -3.268 (top of front)
# 
# From measurements of cockpit pictures it looks like the screen width/height is ca. 75% of an MFD.
#
# We go with height = 0.09, middle = -0.115; and width = 0.12 -> results in a 4:3 screen
# We go with a 768/1024 resolution -> 4:3
#
# The main visual source for the VTM is the picture on page 71 in the following book:
# Alexandre Paringaux, Mirage 2000-5; Groupe de chasse 1/2 Cigognes. Zéphyr.
# 


print("*** LOADING vtm.nas ... ***");

# It is basically a black and green screen.
var COLOR_BACKGROUND = [0,0.02,0]; # almost black with a bit of green
var COLOR_FOREGROUND = [0.75,1,0]; # between yellow and green
var COLOR_RADAR = [0,1,0]; # green

var SCREEN_WIDTH = 1024;
var SCREEN_HEIGHT = 768;

# The main dimensions and corners of the screen. 
# x=0, y=0 is in the top left corner; x increases towards right; y increases downwards
# There is a small padding around the drawable screen area, because the pilot moves the head etc.
var PADDING_TOP = 34; 
var PADDING_BOTTOM = 54; 
var PADDING_HORIZONTAL = 47; 

# The radar view is where radar stuff gets displayed - between the 4 corners
var RADAR_VIEW_VERTICAL = SCREEN_HEIGHT - PADDING_TOP - PADDING_BOTTOM; # 768 - 34 - 54 = 680 left
var RADAR_VIEW_HORIZONTAL = SCREEN_WIDTH - 2 * PADDING_HORIZONTAL; # 1024 - 2*47 = 930 left

var CORNER_LINE_LENGTH = 75;
var LINE_WIDTH = 2;
var GRID_TICK_LENGTH = 10;

var FONT_SIZE = 24;
var FONT_SIZE_BIG = 48;
var FONT_ASPECT_RATIO = 1;
var FONT_MONO_REGULAR = "LiberationFonts/LiberationMono-Regular.ttf";
var FONT_MONO_BOLD = "LiberationFonts/LiberationMono-Bold.ttf";

var MAX_TARGETS = 28;
var TARGET_WIDTH = 30;

var VTM = {
  new: func() {
    var vtm_obj = {parents: [VTM]};
    vtm_obj.vtm_canvas = canvas.new({
      "name": "vtm_canvas",
      "size": [SCREEN_WIDTH, SCREEN_HEIGHT],
      "view": [SCREEN_WIDTH, SCREEN_HEIGHT],
      "mipmapping": 1
    });

    vtm_obj.vtm_canvas.addPlacement({"node": "vtm_ac_object"});
    vtm_obj.vtm_canvas.setColorBackground(COLOR_BACKGROUND);

    vtm_obj.root = vtm_obj.vtm_canvas.createGroup("root");
    vtm_obj.root.setTranslation(_get_center_coord());

    vtm_obj._create_visible_corners();
    vtm_obj._create_screen_mode_group();
    vtm_obj._create_rectangular_field_of_view_grid();
    vtm_obj._create_targets();
    vtm_obj._create_standby_text();
    vtm_obj._create_radar_modes_group();

    return vtm_obj;
  },

  # The 4 visible corners at the edges of the main screen estate
  _create_visible_corners: func() {
    me.corners_group = me.root.createChild("group", "corners_group");
    me.corners_group.setTranslation(_get_top_left_translation());
    me.left_upper_corner      = me.corners_group.createChild("path", "left_upper_corner")
                                .setColor(COLOR_FOREGROUND)
                                .moveTo(PADDING_HORIZONTAL + CORNER_LINE_LENGTH,
                                        PADDING_TOP)
                                .horizTo(PADDING_HORIZONTAL)
                                .vertTo(PADDING_TOP + CORNER_LINE_LENGTH)
                                .setStrokeLineWidth(LINE_WIDTH);
    me.right_upper_corner      = me.corners_group.createChild("path", "right_upper_corner")
                                 .setColor(COLOR_FOREGROUND)
                                 .moveTo(SCREEN_WIDTH - PADDING_HORIZONTAL - CORNER_LINE_LENGTH,
                                         PADDING_TOP)
                                 .horizTo(SCREEN_WIDTH - PADDING_HORIZONTAL)
                                 .vertTo(PADDING_TOP + CORNER_LINE_LENGTH)
                                 .setStrokeLineWidth(LINE_WIDTH);
    me.left_lower_corner       = me.corners_group.createChild("path", "left_lower_corner")
                                 .setColor(COLOR_FOREGROUND)
                                 .moveTo(PADDING_HORIZONTAL + CORNER_LINE_LENGTH,
                                         SCREEN_HEIGHT - PADDING_BOTTOM)
                                 .horizTo(PADDING_HORIZONTAL)
                                 .vertTo(SCREEN_HEIGHT - PADDING_BOTTOM - CORNER_LINE_LENGTH)
                                 .setStrokeLineWidth(LINE_WIDTH);
    me.right_lower_corner      = me.corners_group.createChild("path", "right_lower_corner")
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
  _create_screen_mode_group: func() {
    me.screen_mode_group = me.root.createChild("group", "screen_mode_group");
    me.screen_mode_group.setTranslation(_get_top_left_translation());
    me.screen_mode_rdr      = me.screen_mode_group.createChild("text", "screen_mode_rdr")
                              .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
                              .setFont(FONT_MONO_REGULAR)
                              .setColor(COLOR_FOREGROUND)
                              .setAlignment("left-top")
                              .setText("RDR")
                              .setTranslation(PADDING_HORIZONTAL + 0.5*0.25*RADAR_VIEW_HORIZONTAL,
                                              SCREEN_HEIGHT - PADDING_BOTTOM + 5);
    me.screen_mode_ldp      = me.screen_mode_group.createChild("text", "screen_mode_ldp")
                              .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
                              .setFont(FONT_MONO_REGULAR)
                              .setColor(COLOR_FOREGROUND)
                              .setAlignment("left-top")
                              .setText("LDP")
                              .setTranslation(PADDING_HORIZONTAL + 1.5*0.25*RADAR_VIEW_HORIZONTAL,
                                              SCREEN_HEIGHT - PADDING_BOTTOM + 5);
    me.screen_mode_rdr_box  = me.screen_mode_group.createChild("path", "screen_mode_rdr_box")
                              .setColor(COLOR_FOREGROUND)
                              .rect(PADDING_HORIZONTAL + 0.4*0.25*RADAR_VIEW_HORIZONTAL,
                                    SCREEN_HEIGHT - PADDING_BOTTOM + 1,
                                    0.5*0.25*RADAR_VIEW_HORIZONTAL, 30)
                              .setStrokeLineWidth(LINE_WIDTH);
    me.screen_mode_ldp_box  = me.screen_mode_group.createChild("path", "screen_mode_ldp_box")
                              .setColor(COLOR_FOREGROUND)
                              .rect(PADDING_HORIZONTAL + 1.4*0.25*RADAR_VIEW_HORIZONTAL,
                                    SCREEN_HEIGHT - PADDING_BOTTOM + 1,
                                    0.5*0.25*RADAR_VIEW_HORIZONTAL, 30)
                              .setStrokeLineWidth(LINE_WIDTH);
    me.screen_mode_ldp_box.hide();
    me.screen_mode_group.hide();
  },

  # Create the stippled grid for B-scope
  _create_rectangular_field_of_view_grid: func() {
    me.rectangular_fov_grid_group = me.root.createChild("group", "rectangular_fov_grid");
    me.rectangular_fov_grid_group.setTranslation(_get_top_left_translation());
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
                                    PADDING_TOP + 4*spacing + 3*2*GRID_TICK_LENGTH)
                            .vert(2*GRID_TICK_LENGTH)
                            # 
                            .moveTo(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL, 
                                    PADDING_TOP + spacing)
                            .vert(2*GRID_TICK_LENGTH)
                            .moveTo(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL, 
                                    PADDING_TOP + 2*spacing + 2*GRID_TICK_LENGTH)
                            .vert(2*GRID_TICK_LENGTH)
                            .moveTo(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL, 
                                    PADDING_TOP + 3*spacing + 2*2*GRID_TICK_LENGTH)
                            .vert(2*GRID_TICK_LENGTH)
                            .moveTo(PADDING_HORIZONTAL + 0.5*RADAR_VIEW_HORIZONTAL, 
                                    PADDING_TOP + 4*spacing + 3*2*GRID_TICK_LENGTH)
                            .vert(2*GRID_TICK_LENGTH)
                            # 
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
                                    PADDING_TOP + 4*spacing + 3*2*GRID_TICK_LENGTH)
                            .vert(2*GRID_TICK_LENGTH)
                            .setStrokeLineWidth(LINE_WIDTH);
    me.rectangular_fov_grid_group.hide();
  },

  # 3 types of targets: selected target, friend targets, foe targets.
  # The selected target (max 1) is a cross.
  # The friendly targets (given the IFF) are drawn as a filled circle.
  # Foe targets are drawn as open squares - with the opening being on the back side of the target
  _create_targets: func() {
    me.targets_group = me.root.createChild("group", "targets_group");
    me.selected_target = me.targets_group.createChild("path", "selected_target")
                         .setColor(COLOR_RADAR)
                         .moveTo(-0.5 * TARGET_WIDTH, 0)
                         .horiz(TARGET_WIDTH)
                         .moveTo(0, -0.5 * TARGET_WIDTH)
                         .vert(TARGET_WIDTH)
                         .setStrokeLineWidth(2*LINE_WIDTH);

    me.selected_target_callsign = me.targets_group.createChild("text", "selected_target_callsign")
                                  .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
                                  .setFont(FONT_MONO_REGULAR)
                                  .setColor(COLOR_RADAR)
                                  .setAlignment("right-top")
                                  .setText("")
                                  .setTranslation(0.5 * RADAR_VIEW_HORIZONTAL - 5,
                                                  0.5 * RADAR_VIEW_VERTICAL + 5);
    me.selected_target_callsign.enableUpdate();

    me.friend_targets = setsize([],MAX_TARGETS);
    for (var i = 0; i<MAX_TARGETS; i += 1) {
      me.friend_targets[i] = me.targets_group.createChild("path")
                             .setColor(COLOR_RADAR)
                             .circle(0.5 * TARGET_WIDTH, 0, 0)
                             .setStrokeLineWidth(2*LINE_WIDTH);
    }

    me.foe_targets = setsize([],MAX_TARGETS);
    for (var i = 0; i<MAX_TARGETS; i += 1) {
      me.foe_targets[i]    = me.targets_group.createChild("path")
                             .setColor(COLOR_RADAR)
                             .moveTo(-0.5 * TARGET_WIDTH, -0.5 * TARGET_WIDTH)
                             .vert(TARGET_WIDTH)
                             .moveTo(-0.5 * TARGET_WIDTH, -0.5 * TARGET_WIDTH)
                             .horiz(TARGET_WIDTH)
                             .vert(TARGET_WIDTH)
                             .setStrokeLineWidth(LINE_WIDTH);
    }
    me.targets_group.hide();
  },

  # When the radar goes into stand-by mode
  _create_standby_text: func () {
    me.standby_group = me.root.createChild("group", "standby_group");
    me.standby_group.setTranslation(_get_top_left_translation());
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
  _create_radar_modes_group: func () {
    var y_top_pos = PADDING_TOP + 10;
    me.radar_modes_group = me.root.createChild("group", "radar_range_group");
    me.radar_modes_group.setTranslation(_get_top_left_translation());
    me.radar_left_text   = me.radar_modes_group.createChild("text", "radar_left_text")
                           .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
                           .setFont(FONT_MONO_REGULAR)
                           .setColor(COLOR_RADAR)
                           .setAlignment("left-top")
                           .setText("MRF")
                           .setTranslation(PADDING_HORIZONTAL + 10, y_top_pos);
    me.radar_a_bars      = me.radar_modes_group.createChild("text", "radar_a_bars")
                           .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
                           .setFont(FONT_MONO_REGULAR)
                           .setColor(COLOR_RADAR)
                           .setAlignment("center-top")
                           .setText("A1")
                           .setTranslation(PADDING_HORIZONTAL + 0.125*RADAR_VIEW_HORIZONTAL, y_top_pos);
    me.radar_a_bars.enableUpdate();
    me.radar_b_bars      = me.radar_modes_group.createChild("text", "radar_b_bars")
                           .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
                           .setFont(FONT_MONO_REGULAR)
                           .setColor(COLOR_RADAR)
                           .setAlignment("right-top")
                           .setText("HI")
                           .setTranslation(PADDING_HORIZONTAL + 0.25*RADAR_VIEW_HORIZONTAL - 10, y_top_pos);
    me.radar_b_bars.enableUpdate();
    me.radar_range_text  = me.radar_modes_group.createChild("text", "radar_range_text")
                           .setFontSize(FONT_SIZE, FONT_ASPECT_RATIO)
                           .setFont(FONT_MONO_REGULAR)
                           .setColor(COLOR_RADAR)
                           .setAlignment("right-top")
                           .setText("")
                           .setTranslation(SCREEN_WIDTH - PADDING_HORIZONTAL - 10, y_top_pos);
    me.radar_range_text.enableUpdate();
    me.radar_modes_group.hide();
  },

  _update_targets: func(heading_true) {
    var target_contacts_list = mirage2000.myRadar3.ContactsList;
    var selected_target = mirage2000.myRadar3.Target_Index;
    var i = 0;
    var has_painted = 0;
    var this_aircraft_position = geo.aircraft_position();
    var target_position = nil;
    var direct_distance = 0;
    var bearing = 0; # from this aircraft to the target
    var relative_heading = 0; # the heading of the target as seen by this aircraft with nose = North
    var screen_pos = nil;
    var max_distance = mirage2000.myRadar3.get_radar_distance() * NM2M;
    var max_angle = mirage2000.myRadar3.az_fld / 2;

    # walk through all existing targets as per available list
    foreach(var c; target_contacts_list) {
      target_position = c.get_Coord();
      direct_distance = this_aircraft_position.direct_distance_to(target_position);
      bearing = geo.normdeg180(this_aircraft_position.course_to(target_position) - heading_true);
      relative_heading = geo.normdeg(c.get_heading() - heading_true);
      screen_pos = _calc_target_screen_position_b_scope(direct_distance, max_distance, bearing, max_angle);

      me.friend_targets[i].hide(); # currently we do not know the friends
      if (selected_target == i) {
        has_painted = 1;
        me.selected_target.setTranslation(screen_pos[0], screen_pos[1]);
        me.selected_target_callsign.updateText(c.get_Callsign());
        me.foe_targets[i].hide();
      } else {
        me.foe_targets[i].setRotation(relative_heading * D2R);
        me.foe_targets[i].setTranslation(screen_pos[0], screen_pos[1]);
        me.foe_targets[i].show();
      }
      i += 1;
    }
    # handle the index positions if the target list was shorter than the reserved elements
    for (var j = i; j < MAX_TARGETS; j += 1) {
      me.friend_targets[j].hide();
      me.foe_targets[j].hide();
    }
    me.selected_target.setVisible(has_painted);
    me.selected_target_callsign.setVisible(has_painted);
  },

  _update_radar_texts: func() {
    # this is fictional based on radar2.nas->radar_mode_toggle(). In the real screen it reads e.g. "MRF"
    var tws_auto = props.globals.getNode("/instrumentation/radar/mode/tws-auto").getBoolValue();
    var radar_mode = "RWS";
    if (tws_auto) {
      radar_mode = "TWS";
    }
    me.radar_left_text.setText(radar_mode);

    # this is fictional based on interpretation of https://github.com/NikolaiVChr/f16/wiki/FCR
    var az_text = "A1";
    if (mirage2000.myRadar3.az_fld >= 49.9 and mirage2000.myRadar3.az_fld < 59.9) {
      az_text = "A2";
    } else if (mirage2000.myRadar3.az_fld >= 59.9 and mirage2000.myRadar3.az_fld < 119.9) {
      az_text = "A3";
    } else if (mirage2000.myRadar3.az_fld >= 119.9) {
      az_text = "A4";
    }
    me.radar_a_bars.setText(az_text);

    # right now there is no information about the b_bars

    me.radar_range_text.setText(mirage2000.myRadar3.get_radar_distance());
  },

  update: func() {
    var global_visible = 0;
    var radar_voltage = props.globals.getNode("/systems/electrical/outputs/radar").getValue();
    var heading_true = props.globals.getNode("/orientation/heading-deg").getValue();
    if (radar_voltage != nil and radar_voltage >= 23) {
        global_visible = 1;
    }
    global_visible = 1; # FIXME
    me.corners_group.setVisible(global_visible);
    me.screen_mode_group.setVisible(global_visible);
    me.rectangular_fov_grid_group.setVisible(global_visible);
    me.radar_modes_group.setVisible(global_visible);

    if (global_visible == 0) {
      me.standby_group.setVisible(global_visible);
      me.targets_group.setVisible(global_visible);
    #} else if (props.globals.getNode("/instrumentation/radar/radar-standby").getBoolValue()) {
    #  me.standby_group.show();
    #  me.targets_group.hide();
    } else {
      me.standby_group.hide();
      me.targets_group.show();
      me._update_targets(heading_true);
      me._update_radar_texts();
    }
  },
};


# Calculates the relative screen position of a target in B-scope
# Returns the x/y position on the Canvas
var _calc_target_screen_position_b_scope = func(distance, max_distance, angle, max_angle) {
  var x_pos = angle / max_angle * 0.5 * RADAR_VIEW_HORIZONTAL;
  var y_pos = 0.5 * RADAR_VIEW_VERTICAL - distance / max_distance * RADAR_VIEW_VERTICAL;
  return [x_pos, y_pos];
};

# the absolute coordinate from top left to screen middle
var _get_center_coord = func() {
  return [0.5 * SCREEN_WIDTH, 0.5 * SCREEN_HEIGHT];
};

# get the transaltion from the center of screen coordinates to top left
var _get_top_left_translation = func() {
  return [-0.5 * SCREEN_WIDTH, -0.5 * SCREEN_HEIGHT];
};
