FOREST GUARDIAN - AUDIO
=======================
All from the Ninja Adventure Asset Pack. CC0 - that pack's own wording:

  "They are released under the Creative Commons Zero (CC0) license.
   You can use any and all of the assets found in this package in your
   own games, even commercial ones. Attribution is not required but
   appreciated."


MUSIC
-----
  music_title.ogg     "Adventure Begin"  - the menu
  music_game.ogg      "Dark Forest"      - gameplay. THE one.
  music_intense.ogg   "Tension"          - optional, later waves
  music_calm.ogg      "Clearing"         - optional, gentler


SOUND EFFECTS
-------------
  sfx_sword_swing.wav   your sword cutting air
  sfx_sword_hit.wav     your sword landing on a logger
  sfx_axe_swing.wav     the logger's axe
  sfx_tree_chop.wav     axe biting into a tree
  sfx_tree_fall.wav     the tree coming down
  sfx_tree_grow.wav     a tree regrowing
  sfx_player_hurt.wav   you taking a hit
  sfx_logger_die.wav    a logger going down
  sfx_click.wav         menu buttons
  jingle_gameover.wav   death screen


=========================================================
STEP 1 - TICK LOOP ON THE MUSIC
=========================================================
Music does NOT loop by default. Yours plays once, stops, and leaves
the rest of the run silent.

For EACH .ogg file:

  1. Click the file in the FileSystem panel (bottom left)
  2. Look at the TOP LEFT of the editor - there are two tabs there,
     "Scene" and "Import". Click IMPORT.
  3. A list of settings appears. Tick  Loop
  4. Click the  Reimport  button at the bottom of that list

The Import tab only shows settings when a FILE is selected in
FileSystem. If it looks empty, you have a node selected instead.

Do NOT tick Loop on the .wav effects, or every sword swing rings
forever.


=========================================================
STEP 2 - MUSIC (two nodes, no code)
=========================================================
title.tscn:
  Select root -> Ctrl+A -> AudioStreamPlayer
  Drag music_title.ogg into its Stream slot
  Tick Autoplay
  Volume dB: -8

main.tscn:
  Same, with music_game.ogg


=========================================================
STEP 3 - SOUND EFFECTS (one line each)
=========================================================
Put sfx.gd in your Scripts folder. Nothing to attach.

IF YOUR AUDIO IS NOT IN res://Assets/ , open sfx.gd and change the
DIR line at the top to wherever you put it.

Then add these single lines:


--- player.gd ---------------------------------------------------------

In _start_attack(), straight after  anim.play(...) :

	Sfx.play(self, "sfx_sword_swing.wav")


In _damage_in_cone(), inside the  if connected:  block at the end,
next to the GameFeel.hitstop line:

	Sfx.play(self, "sfx_sword_hit.wav")


In take_damage(), just after  _hurt_flash() :

	Sfx.play(self, "sfx_player_hurt.wav")


--- woodcutter.gd -----------------------------------------------------

In _swing_axe(), after  _swinging = true :

	Sfx.play(self, "sfx_axe_swing.wav", -6.0)


In _die(), as the first line after  state = State.DEAD :

	Sfx.play(self, "sfx_logger_die.wav")


--- forest_tree.gd ----------------------------------------------------

In hit(), just after  _knock() :

	Sfx.play(self, "sfx_tree_chop.wav")


In _fell(), after  tree_lost.emit(self) :

	Sfx.play(self, "sfx_tree_fall.wav")


--- game_manager.gd ---------------------------------------------------

In _respawn_trees(), inside  if grown > 0: :

	Sfx.play(self, "sfx_tree_grow.wav", -8.0)


--- hud.gd ------------------------------------------------------------

In _on_game_over(), as the first line:

	Sfx.play(self, "jingle_gameover.wav", -2.0)


=========================================================
VOLUME
=========================================================
The second argument to Sfx.play is a dB offset for that one sound.
Negative is quieter. The axe is at -6 because the logger swings
constantly and it gets tiring at full volume.

To change ALL effects at once, edit  volume_db  at the top of sfx.gd.
Default is -4.

Music at 0 dB drowns everything - keep it around -8.


=========================================================
WHY THE PITCH WOBBLES
=========================================================
Sfx.play randomises pitch by 10% every time. Without it, a sound
repeated quickly - chopping a tree four times - turns into an
obviously looping machine noise.

It is one line of code and it is the main thing separating audio that
sounds designed from audio that sounds copy-pasted. Worth mentioning
in judging.
