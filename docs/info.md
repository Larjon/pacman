<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

his project implements a simple Pac-Man-style game in pure Verilog for the Tiny Tapeout / VGA Playground environment.

The design generates a real-time VGA video signal at 640×480 resolution and renders the game directly from combinational logic, without using a framebuffer. The game board is based on a 16×16 tile map, where each tile is 16×16 pixels. Walls, dots, Pac-Man, the ghost, and the score bar are all drawn on the fly from the current pixel position.

Game logic is updated once per frame using a frame tick generated at the beginning of the screen refresh. Pac-Man moves on the grid in four directions and cannot pass through walls. Dots are stored as bitmasks and are cleared when collected. A single ghost moves through the maze using a very simple low-cost movement rule: it continues in its current direction when possible, and when blocked it selects the first available direction from a fixed priority order.

The project was designed to stay friendly to Tiny Tapeout constraints, so it avoids multipliers, dividers, frame memory, and other expensive structures. The implementation mainly uses add, subtract, shift, compare, and case-based lookup logic.

## How to test

Load the design in Tiny Tapeout / VGA Playground and connect the VGA output.

Controls:

ui[4] — move left

ui[5] — move right

ui[0] — move up

ui[1] — move down

ui[2] — restart game

Gameplay:

Move Pac-Man through the maze
Collect all dots to win
Avoid the ghost
If Pac-Man collides with the ghost, the game ends
Press restart to reset the board, score, and positions

Visual feedback:

Yellow character: Pac-Man
Magenta character: ghost
White dots: collectible pellets
Red bar: game over
Green bar: win
Yellow bar near the top: score indicator

## External hardware

External hardware used:
VGA output / VGA monitor
Tiny Tapeout VGA PMOD interface
No additional external hardware is required.
