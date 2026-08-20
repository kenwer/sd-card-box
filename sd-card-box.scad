/*
Box for carrying (many) SD-Cards

Author: Ken Werner

The model is intended for 3D printing.

This work is licensed under the licensed under the CC BY-SA 4.0 license. The full text of the Creative Commons Attribution-ShareAlike 4.0 International License can be found at: http://creativecommons.org/licenses/by-sa/4.0/
*/

include <BOSL2/std.scad>
include <BOSL2/hinges.scad>

$fn = $preview ? 40 : 220;
nothing = 0.01;

// Layout
num_sd_slots_per_row = 30; // slots per row (cards stacked along the hinge)
num_sd_slot_rows     = 1;  // rows stacked in the depth direction
spacing              = 0.8; // gap between slots

// Card (SD spec + fit)
sd_clearance = 0.28; // slots this much larger than the card so it drops in; 0.3 -> a bit loose
// SD card dimensions are 32.0 x 24.0 x 2.1 mm
sd_depth  = 2.1  + sd_clearance; // card thickness -> spacing direction within a row
sd_width  = 24.0 + sd_clearance; // card width -> spacing direction between rows
sd_height = 32.0 + sd_clearance; // card height -> sticks up out of the slot
card_tilt = 8; // degrees the slots lean toward the hinge

// Shell / lid
wall_thickness      = 1.2; // outer shell and lid thickness
shell_height_offset = 2;   // outer shell stops this far below the inner base so the lid can overlap it
outer_case_rounding = 2.0;
lid_catch_depth = 1.2; // how deep the lid's per-card slots grip the card tip
// Lid snap lock (triangular ridge on the lid clicks into a socket in the base)
lock_height           = 0.4;  // how far the snap-lock ridge stands out (bigger = stiffer click)
lock_socket_clearance = 1.05; // base socket is oversized by this factor so the ridge snaps in

// Hinge
hinge_offset = 3; // horizontal (Y) pin offset behind the shell
// The lid closes on a circular arc about the pin. With the pin at the shell top
// (~10mm below the card tips) that arc slides sideways as it drops, so the lid
// pockets jam against the card corners
hinge_pin_raise = 2; // lifts the pin toward the card tips
hinge_arm       = 1; // leaf extension
hinge_chamfer   = 1.5;

// Engraved text
case_text1  = str(num_sd_slots_per_row * num_sd_slot_rows, " SD-Cards");
case_text2  = "some more text";
text_height = 0.25; // height of engraved text
font_sz     = 8;
font        = "DIN Condensed:style=Bold";


// Computed vars from the parameters above, don't edit

// Bounding-box reach of a tilted SD-Card in each axis. A card tilted by card_tilt no
// longer stands upright in its slot: it sweeps a bigger envelope in the tilt (Y-Z) plane.
card_env_y = sd_width * cos(card_tilt) + sd_height * sin(card_tilt); // Y (rows/depth) reach
card_env_z = sd_width * sin(card_tilt) + sd_height * cos(card_tilt); // Z (height) reach

// Centre-to-centre pitch of the slot grid, gap included
slot_pitch = sd_depth  + spacing; // along the hinge axis (within a row)
row_pitch  = card_env_y + spacing; // across the depth direction (between rows)

// Case shell. case_length is the hinge axis: cards are stacked thin-side (sd_depth) along
// it, so the tight fit lands in the hinge-parallel direction, which the closing arc leaves
// undisturbed. The rows (card width, sd_width) run across the depth direction.
case_height       = card_env_z * 0.75; // 25 % uncovered to be able to pull out cards
case_length       = num_sd_slots_per_row * slot_pitch + spacing;
case_width        = num_sd_slot_rows * row_pitch + spacing;
outer_case_height = case_height - shell_height_offset; // height of the outer shell
lid_height        = card_env_z - outer_case_height + spacing + wall_thickness;

// Lid snap-lock profile (trapezoid shared by the lid ridge and the base socket)
lock_width1 = case_length/3; // wide end of the lock profile
lock_width2 = case_length/4; // narrow end of the lock profile

// Hinge sizing
hinge_length = case_length * 0.9;
hinge_segs   = max(2, round(hinge_length / 7)); // knuckle count, sized for ~7mm long knuckles

// Rotates its children about the card's own centre
module card_tilt_frame() {
  up(card_env_z/2) xrot(-card_tilt) down(sd_height/2) children();
}

// The snap-lock trapezoid: a ridge on the lid clicks into a socket in the base
module lock_ridge(h, scale=1) {
  prismoid(size1=[lock_width1*scale, 1*scale],
           size2=[lock_width2*scale, 0],
           h=h, orient=BACK);
}

// Grid of SD-card-shaped holes, used to cut slots in both the base and the lid
module sd_card_holes(z=0) {
  up(z)
    grid_copies(spacing=[slot_pitch, row_pitch], n=[num_sd_slots_per_row, num_sd_slot_rows])
      card_tilt_frame()
        cuboid([sd_depth, sd_width, sd_height], anchor=BOT);
}

module draw_case_base() {
  // A tilted card's lowest corner lifts this far off the floor. The finger groove uses it
  // to find where the card's centreline crosses the case top.
  tilt_lift_z = sd_width / 2 * sin(card_tilt);

  diff(){
    // Inner base case
    cuboid([case_length, case_width, case_height], anchor=BOT);

    // Cut holes for the SD cards, tilted toward the hinge so the card stands at
    // the same angle the lid needs when it swings shut on its arc
    tag("remove") sd_card_holes(spacing);

    // Cut a groove across each row so the cards are easy to grab and pull out.
    tag("remove")
      ycopies(spacing=row_pitch, n=num_sd_slot_rows)
        card_tilt_frame()
          up((case_height - tilt_lift_z) / cos(card_tilt))
            xcyl(l=case_length - 2*spacing, d=sd_width - 2*spacing);

    // Lid lock socket (oversized copy of the ridge so it snaps in 0.1 deeper than the ridge so the tip seats without bottoming out)
    tag("remove") fwd(case_width/2) up(case_height-1.0)
      lock_ridge(h=lock_height+0.1, scale=lock_socket_clearance);


    // Outer base case (shell with rounding)
    rect_tube(isize=[case_length, case_width], wall=wall_thickness, h=outer_case_height, rounding=outer_case_rounding, anchor=BOT)
    // Add hinge (pin raised toward the card tips so the lid closes without binding)
    position(TOP+BACK) up(hinge_pin_raise) orient(anchor=BACK)
        knuckle_hinge(length=hinge_length, segs=hinge_segs, offset=hinge_offset, arm_height=hinge_arm, round_bot=1.0, teardrop=true, pin_diam=2, in_place=false);

    // If the height base of the case is low, the hinge might stick out at the bottom, so we cut that
    tag("remove") back(case_width/2) down(nothing) cuboid([case_length, 10, 5], anchor=TOP);

    // Bevel the top corners of the raised hinge mount so the closing lid clears them on its arc
    if (hinge_chamfer > 0) {
      tag("remove")
        back(case_width/2+wall_thickness/2) up(outer_case_height+nothing)
          prismoid(size1=[case_length+nothing, wall_thickness],
                    size2=[case_length+nothing, wall_thickness + hinge_offset/2], // TODO: currently only works with hinge_offset=3
                    shift=[0, 0.25], h=hinge_pin_raise+nothing, anchor=BOT);
    }
  }
}

module draw_case_top() {
  difference(){
    draw_case_lid();
    down(nothing)
      color("Grey", 1) xflip() engrave_text();
  }
}

module draw_case_lid() {
  lid_clearance=0.1;
  // Outer shell of the lid
  rect_tube(isize=[case_length+2*lid_clearance, case_width+2*lid_clearance], wall=wall_thickness-lid_clearance, h=lid_height, rounding=outer_case_rounding, ichamfer=0, anchor=BOT)
  position(TOP+BACK) down(hinge_pin_raise) orient(anchor=BACK)
    // Add hinge
    knuckle_hinge(length=hinge_length, segs=hinge_segs, offset=hinge_offset, arm_height=hinge_arm, round_bot=0.25, teardrop=true, pin_diam=2, inner=true, in_place=false);

  // Fill gap created by the rect_tube with lid_clearance above
  rect_tube(isize=[case_length, case_width], wall=wall_thickness, h=card_env_z-case_height, rounding=outer_case_rounding, ichamfer=0, anchor=BOT);

  // SD card slots for the lid. Besides the snug slots (sd_card_holes), each row gets a
  // loose trough that wraps the card tips so they can follow the hinge's arc without
  // binding as the lid swings shut.
  lid_pocket_height = card_env_z-outer_case_height - wall_thickness - lid_catch_depth;
  trough_len   = case_length - 2*spacing;  // full row length, along the hinge axis
  trough_w     = sd_width + 2*spacing;      // loose fit around the card width
  trough_h     = lid_pocket_height + card_env_z*sin(card_tilt); // height it rises in the tilted frame
  // Over that rise the hinge-side wall must lean out by a further card_tilt to clear the
  // swinging tip: widen the top by trough_flare and shift half of it, so only the
  // hinge-side wall leans (by card_tilt) while the far wall stays vertical.
  trough_flare = trough_h * tan(card_tilt);

  difference(){
    cuboid([case_length, case_width, card_env_z-outer_case_height], anchor=BOT);

    // The lid folds 180° about the hinge to close
    yflip() {
      up(wall_thickness)
        sd_card_holes(0);

      ycopies(spacing=row_pitch, n=num_sd_slot_rows)
        up(wall_thickness) card_tilt_frame()
          up(lid_catch_depth)
            prismoid(size1=[trough_len, trough_w],
                     size2=[trough_len, trough_w + trough_flare],
                     shift=[0, trough_flare/2], h=trough_h, anchor=BOT);
    }
  }
  // In case you don't want the slots above, we need a wall
  //cuboid([case_length, case_width, wall_thickness], anchor=BOT);

  // Lid lock ridge
  fwd(case_width/2+lid_clearance) up(lid_height-1.0)
    lock_ridge(h=lock_height);

  // Lid opener handle
  fwd(case_width/2+wall_thickness) up(1.0)
    prismoid(size1=[lock_width1,2], size2=[lock_width2,1], shift=[0,-0.5], h=1.5, orient=FRONT);
}

module engrave_text() {
  for (line = [[case_text1, font_sz*0.8], [case_text2, -font_sz*0.8]])
    back(line[1])
    linear_extrude(text_height)
      text(line[0], size=font_sz, halign="center", valign="center", font);
}

//back_half()
draw_case_base();


back(case_width+8) zrot(180)
  //back_half()
  draw_case_top(); // with engraved text
  //draw_case_lid(); // without engraved text
