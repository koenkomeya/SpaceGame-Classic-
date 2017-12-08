/// Space Game (name not final)
/// @file SGRenderUART0Term.c
/// Responsible for the terminal backend for rendering. TODO make the output buffered and modify SGRender interface for this chg
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/30/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
//-----------------------------------------------------------------------------
///             Imports
#include <string.h>

#include "SGRender.h"
#include "SpaceGame.h"
#include "UART0CharIO.h"
///----------------------------------------------------------------------------
/// @addtogroup Defines
/// @{

/// Escape character 0x1B (ESC)
#define ESCAPE_CHAR '\x1B'
/// Escape character 0x1B (ESC) as string
#define ESCAPE_STR "\x1B"

/// ANSI CSI Sequence start
#define ANSI_CSI ESCAPE_STR "["

/// Terminal Width
#define TERM_WIDTH 80
/// Terminal Width minus 1
#define TWM1 79
/// Terminal Height
#define TERM_HEIGHT 40
/// Terminal Height minus 1
#define THM1 39

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Functional Macros
/// @{
/// Helper functional macro to #STRINGIFY
/// Don't use.
#define STRINGIFY_HELP(x) #x

///Stringifies x.
///@param x token to stringify
#define STRINGIFY(x) STRINGIFY_HELP(x)
/// @}
///----------------------------------------------------------------------------
/// @addtogroup Functions
/// @{

/// Moves the terminal cursor to the specified location.
/// @param xc the x position of the terminal.
/// @param yc the y position of the terminal. (0 is top)
static void setCursorPos(int xc, int yc){
	PutChar(ESCAPE_CHAR);
	PutChar('[');
	PutNumU(yc);
	PutChar(';');
	PutNumU(xc);
	PutChar('f');
}

/// Initializes the renderer.
/// @pre Requires Button to be functional.
void initRenderer(void){
	Init_UART0_IRQ();
	while (0){
		PUTSTRLIT(ANSI_CSI "3J"); //Clear Screen
		PUTSTRLIT(ANSI_CSI "H");  //Position cursor at top left.
		PUTSTRLIT(ANSI_CSI STRINGIFY(TWM1) "C");  //Move TWM1 right
		PUTSTRLIT(ANSI_CSI STRINGIFY(THM1) "B");  //Move THM1 down
		PUTSTRLIT(ANSI_CSI "6n"); //Request cursor position
		PUTSTRLIT(ANSI_CSI "H");  //Position cursor at top left.
		PUTSTRLIT("If this message does not disappear shortly, this terminal " \
		          "does not support ANSI escape sequences. PuTTY is an example " \
		          "of a terminal that supports ANSI escape sequences.");
		char curbuf[16];          //Read cursor position
		GETSTRLIN(curbuf);        
		clearScreen(); //Clear Screen
		PUTSTRLIT(ANSI_CSI "H");  //Position cursor at top left.
		if (strcmp(curbuf, ANSI_CSI STRINGIFY(TERM_WIDTH) ";" \
			         STRINGIFY(TERM_HEIGHT) "R") != 0){
			PUTSTRLIT("Please resize your terminal window to be 80x40 then press " \
								"either button.");
			while (!CheckAndClearPress()); //Wait for button press
			continue;
		}
		//TODO Check for too large screens
	}
	
}

static inline char returnAngled(pos_t xd, pos_t yd, char up, char down, char left, char right){
	if (yd > 0){
		if (xd > 0){
			if (xd > yd)  return right;
			else          return up;
		} else {
			if (-xd > yd) return left;
			else          return up;
		}
	} else {
		if (xd > 0){
			if (xd > -yd) return right;
			else          return down;
		} else {
			if (xd < yd)  return left;
			else          return down;
		}
	}
}

///  Draw an alien
/// @param a Alien to draw
/// @param x x-ccordinate of cluster location
/// @param y y-coordinate of clusterlocation
void drawAlien(Alien *a, pos_t x, pos_t y){
	uint8_t f1 = a->flags1;
	if (!(f1 & AL_F1_ALIVE_MASK)) return;
	//TODO better sprites
	uint8_t t = a->type;
	
	if (f1 & (AL_F1_ATTACK_MASK | AL_F1_SWOOP_MASK)) { //Swooping or attacking
		int xt = (a->xPos >> 8) + 1;
		int yt = 40 - (a->yPos >> 8);
		setCursorPos(xt, yt);
		if (f1 & AL_F1_DYING_MASK){ //Exploding?
      PUTSTRLIT(ANSI_CSI "37m"); 
			PutChar('X');
			return;
		}
    PUTSTRLIT(ANSI_CSI "31m"); 
		char alienChar; //@ & % - potential chars
		if      (t == AT_Grunt) alienChar = returnAngled(a->xPos, a->yPos, 'A', 'V', '<', '>');
		else if (t == AT_Cruiser) alienChar = returnAngled(a->xPos, a->yPos, 'M', 'W', 'E', '3');
		else if (t == AT_Battleship) alienChar = '#';
	  PutChar(alienChar);
	} else {
		int xt = (x >> 8) + 1;
		int yt = 40 - (y >> 8);
		setCursorPos(xt, yt);
		if (f1 & AL_F1_DYING_MASK){ //Exploding?
      PUTSTRLIT(ANSI_CSI "37m"); 
			PutChar('X');
			return;
		}
    PUTSTRLIT(ANSI_CSI "31m"); 
		char alienChar; //@ & % - potential chars
		if      (t == AT_Grunt) alienChar = 'V';
		else if (t == AT_Cruiser) alienChar = 'W';
		else if (t == AT_Battleship) alienChar = '#';
	  PutChar(alienChar);
	}
}

//                A
//Player sprite: <H>
/// Draw player at the specified position
/// It is assumed the player is positioned so there will be no clipping
void drawPlayer(pos_t x, pos_t y){
	int xt = (x >> 8) + 1;
	int yt = 40 - ((y - 0x80) >> 8);
	PUTSTRLIT(ANSI_CSI "34m"); 
	setCursorPos(xt, yt - 1);
	PutChar('A');
	setCursorPos(xt - 1, yt);
	PutChar('<');
	PutChar('H');
	PutChar('>');
}

/// @brief Draw an E1 at the specified position and direction
void drawE1(int8_t e1flags1, pos_t x, pos_t y, pos_t xd, pos_t yd){
	int xt = (x >> 8) + 1;
	int yt = 40 - (y >> 8);
	if (e1flags1 & E1_F1_SIDE_MASK) 
	  PUTSTRLIT(ANSI_CSI "1;36m"); 
	else 
	  PUTSTRLIT(ANSI_CSI "1;33m"); 
	setCursorPos(xt, yt);
	if (yd < 0){
		xd = -xd;
		yd = -yd;
	}
	if (xd > yd * 2 || xd < -yd * 2) PutChar('-');
	else if ( yd <= 4 * xd) PutChar('/');
	else if (-yd >= 4 * xd) PutChar('\\');
	else                    PutChar('|');
}

void drawLevelScreen(int level, int lives, int score){
	clearScreen();
	PUTSTRLIT(ANSI_CSI "0m"); 
	setCursorPos(34, 15);
	PUTSTRLIT("LEVEL");
	setCursorPos(44, 15);
	PutNumU(level);
	setCursorPos(32, 16);
	PUTSTRLIT("------------------");
	setCursorPos(50, 38);
	PUTSTRLIT("Lives");
	setCursorPos(57, 38);
	PutNumU(lives);
	setCursorPos(50, 39);
	PUTSTRLIT("Score");
	setCursorPos(57, 39);
	PutNumU(score);
}

void drawMainMenu(void);

void drawGameOverScreen(int score){
	clearScreen();
	setCursorPos(36, 15);
	PUTSTRLIT(ANSI_CSI "31m"); 
	PUTSTRLIT("GAME  OVER");
	setCursorPos(36, 15);
	setCursorPos(35, 39);
	PUTSTRLIT(ANSI_CSI "0m"); 
	PUTSTRLIT("Score");
	setCursorPos(42, 39);
	PutNumU(score);
}

void drawIntroduction1(void);

void drawInstructions(void);
	
void clearScreen(void){
		PUTSTRLIT(ANSI_CSI "2J"); //Clear Screen
}

void flushScreen(void){
	__asm("CPSID I");
	Flush();
	__asm("CPSIE I");
}

void drawScore(int score){
	setCursorPos(68, 40);
	PUTSTRLIT(ANSI_CSI "0m"); 
	PUTSTRLIT("Score");
	setCursorPos(74, 40);
	PutNumU(score);
}

/// @}
