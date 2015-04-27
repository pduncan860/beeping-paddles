# Report: Beeping Paddles #

<pre>
Jack Hall, Reuben Smith<br>
ECE 287 C, Miami University<br>
Fall Semester, 2011<br>
</pre>

## Description ##

Beeping Paddles is a loving recreation of Atari's classic game, PONG. Named for the fact that the paddles beep when the ball hits them, our project employs all of the skills learned in ECE 287 and an understanding of the hardware on Altera's DE2 gained from self-driven research.

## Modules ##

The Beeping Paddles system is composed of three fundamental modules that are utilized in the game logic of the top-level module. The three modules are Audio, Controller Input, and Video. Each of these modules is configured to provide input or produce an output based on the state of the game logic.

The first of these modules, Audio, is used in scenarios where the game logic requires output of some audio tone. The audio module is sent a specific frequency, length of playtime, and valid signal at the appropriate points in game logic (ball collisions with various objects).

The second of these modules, Controller Input, is the module that handles data input from the players. This module polls for the state of the players’ SNES controllers and stores the states of the latest poll to registers which are checked by the game logic to determine various factors of gameplay including velocity and position of both the paddles and the ball.

The final module, Video, is an independent process that stores a frame of image data in an internal memory buffer and constantly draws it to the screen. As the game state is updated by the system module, the data is turned into image data at the appropriate time and plotted to the frame buffer.

### System Module ###

The top-level module is used to tie together the audio, video, and input modules and signals them as the game's state data is generated. System states move between plotting the various visual regions and checking whether the game state has reached a stopping point.

Game logic is handled outside of a state machine in two primary logic processes: paddle logic and ball logic, both of which are ran at 60 Hz. The paddle logic checks for the button state of each of the player's controllers and calculates the speed for their respective paddles based on input. Ball logic updates the ball's physical state, performing collision detection and scoring. The state generated from these processes is used in the system rendering states to display the game on screen. The sound module is signaled based on inputs from ball logic's collision checks.

### Audio Module ###

The audio module for Beeping Paddles was developed around John Loomis’ third audio project, implementing a sine lookup table for varying frequencies of output at constant amplitude. The module produces tones of specific frequency for set increments of an eighth of a second, of which both parameters are determined by registers in the top-level module. This audio module requires a valid signal to initiate the tone output and is triggered by several cases of ball collision in the top-level module.
John Loomis’ base code can be found [here](http://johnloomis.org/digitallab/audio/audio3/audio3.html).


### Input Module ###

The input of the Beeping Paddles system was handled by a polling module which interacted with Nintendo SNES controllers via GPIO connections. The SNES controller transmits its state data in a serialized manner based on a very specific protocol. Every 16.67 ms, or at a rate of 60 Hz, the DE2 sends a 12 µs latch signal to the latch pin. This latch signal tells the controller to latch the current states of all buttons. Then, 6 µs later, the DE2 sends 16 high pulses on the Pulse/clock pin, each 6 µs long with 6 µs low in between (or a 12 µs, 50% duty, cycle). The data is fed in the following order: B, Y, Select, Start, Up, Down, Left, Right, A, X, Left bumper, Right Bumper. This data from the controller is stored to register until the next update is cued by the 60 Hz polling clock. The following timing diagram shows the first 5 buttons in the polling cycle of the SNES controller:

![http://farm8.staticflickr.com/7155/6468646417_7605c636ed.jpg](http://farm8.staticflickr.com/7155/6468646417_7605c636ed.jpg)

This interface was very intuitive for game play and leaves many doors open for further improvement of the game. The basic structure of the finite state machine was adapted from the following [link](http://web.mit.edu/6.111/www/s2004/PROJECTS/2/nes.htm).

### Video Module ###

Our original designs involved developing a VGA module and memory module that would communicate with each other, creating a framebuffer device and allow us to display a 640x480 image at 60 Hz to the monitor. Both of these modules were developed and worked well by themselves, but timing issues in getting the two to communicate persisted so far into the project that both were dropped in favor of using the [VGA module](http://www.eecg.utoronto.ca/~jayar/ece241_06F/vga/) developed by the University of Toronto. Their product worked admirably and with sufficient performance for our needs, but it did limit us to a 320x240 image resolution and does not provide frame double buffering.

## Result ##

From an academic standpoint, the project was successful at teaching us more about system design and forced us to be innovative in development. Additionally, the hardware used in this project required us to go beyond the knowledge provided in class by researching VGA signals, audio output, communication with an SNES controller, and even the unused memory module taught us how to work with the DE2's SRAM chip. The knowledge of all of these things was gained from reading device data sheets and from understanding other systems developed by third-party authors, just as would be required of us professionally.

While the game differs in implementation from our proposal, there are bugs remaining, and there are more than a few poor design decisions in how game logic is performed, the resulting product does function at a playable level and seemed to be something of a little hit when demonstrated.

Included below are some videos from later build stages in the project.

<a href='http://www.youtube.com/watch?feature=player_embedded&v=tSXddswz4NI' target='_blank'><img src='http://img.youtube.com/vi/tSXddswz4NI/0.jpg' width='425' height=344 /></a>
<a href='http://www.youtube.com/watch?feature=player_embedded&v=H7dFf2XpHOQ' target='_blank'><img src='http://img.youtube.com/vi/H7dFf2XpHOQ/0.jpg' width='425' height=344 /></a>