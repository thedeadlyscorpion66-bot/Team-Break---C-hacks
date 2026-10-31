AXES, TOOLS AND SLASH FX
========================
Pulled out of the Ninja Adventure Asset Pack you already downloaded.

LICENCE (from that pack's own page, verbatim):
  "They are released under the Creative Commons Zero (CC0) license.
   You can use any and all of the assets found in this package in your
   own games, even commercial ones. Attribution is not required but
   appreciated."
CC0 = public domain. Nothing to worry about. Credit pixel-boy anyway.


THE AXES
--------
  axe_woodcutter.png   9 x 14   steel head, wooden handle  <- USE THIS
  axe_big.png         16 x 16   chunkier, orange handle

Use axe_woodcutter.png as the "Axe" Sprite2D on your Woodcutter scene.
It is a proper felling axe and it is sized right next to an 18x26
character. axe_big.png is there if you want him more imposing.

The woodcutter script already rotates whatever sprite you put in that
slot, so this is a straight swap for the axe I drew - nothing in the
code changes.


THE WATERING CAN
----------------
  wateringcan.png     16 x 16

For the ranger's water tool if you get to the fire phase. Same deal:
a Sprite2D child that you rotate or just show while spraying.


SLASH EFFECTS
-------------
  slash_arc.png   228 x 34   6 frames of 38 x 34
  slash_01.png    130 x 32   5 frames of 26 x 32
  slash_03.png    228 x 42   4 frames of 57 x 42

Slice with Vertical = 1 and Horizontal set to the frame count above.

These are the cheapest way to make a swing feel like it connected.
Add an AnimatedSprite2D called "SlashFX" to the woodcutter (or the
player), keep it hidden, and flash it on at the moment of impact:

    @onready var slash: AnimatedSprite2D = $SlashFX

    func _swing_axe():
        slash.rotation = _aim_angle()     # point it where he's facing
        slash.position = _aim_offset()    # out in front of him
        slash.visible = true
        slash.frame = 0
        slash.play("arc")
        await slash.animation_finished
        slash.visible = false

Loop OFF on all of them, Speed around 20 - they are meant to be a
fast flash, not a lingering shape.

slash_03 is the biggest and reads best on a projector during judging.
