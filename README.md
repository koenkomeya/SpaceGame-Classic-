# SpaceGame-Classic-

Overview
========
This is essentially a clone of Space Invaders. The aliens attack akin to Space Invaders and the objective is to shoot down all of the aliens. They fire increasingly difficult barrages of lasers as the level increaeses. This is the version of SpaceGame submitted as my Lab 12 submission for CMPE-250 Assembly Language Programming in lieu of the standard Lab 12. I have since updated the code to bug-fix and add features (Galaga-like enemy swooping); that version will posted on GitHub soon. Made for Keil MKL46Z256 using mixed ARM Assembly/C. The LCD display code does not work in this version, but the score (which would normally be displayed on the LCD) is also displayed on-screen and the game as a whole is fully functional regardless. To play, use a terminal emulator (e.g. PuTTY) and connect to the port which the microcontroller is connected to with a baud rate of 96000. To move, hold the on-chip touch slider in direction you want to move. To fire, use either on-chip pushbutton.



Gameplay
========
The object of the game is to obtain the highest score. The score is based on how many enemies are shot down. In order for a enemy to be shot down, a laser, fired by the player using either on-chip pushbutton, must hit the enemy. Each type of enemy has a different point value.

Grunt - 'V' - 1 point
Cruiser - 'W'- 2 points
Battleship - '#' - 4 points

Periodically, the enemies will fire a barrage of lasers. As the round number increases, the enemies will gain more health and fire more lasers. If a laser collides with your ship, your ship blows up and you lose a life. You have 3 lives to amass the highest score possible. 
