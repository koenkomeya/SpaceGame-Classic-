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
	PutChar('H');
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
		PUTSTRLIT(ANSI_CSI "3J"); //Clear Screen
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

///  Draw an alien at the specified position and direction
/// @param t type of alien
/// @param x x-ccordinate of location
/// @param y y-coordinate of location
/// @param xd x-facing of location
/// @param yd y-facing of location

void drawAlien(alientype_t t, pos_t x, pos_t y, pos_t xd, pos_t yd){
	//TODO Angles and better sprites
	int xt = (x >> 8) + 1;
	int yt = 40 - (y >> 8);
	setCursorPos(xt, yt);
	char alienChar; //@ & % - potential chars
	if      (t == AT_Grunt) alienChar = 'V';
	else if (t == AT_Cruiser) alienChar = 'W';
	else if (t == AT_Battleship) alienChar = '#';
	PutChar(alienChar);
}

//                A
//Player sprite: <H>
/// Draw player at the specified position
/// It is assumed the player is positioned so there will be no clipping
void drawPlayer(pos_t x, pos_t y){
	int xt = (x >> 8) + 1;
	int yt = 40 - (y >> 8);
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
	setCursorPos(xt, yt - 1);
	if (yd < 0){
		xd = -xd;
		yd = -yd;
	}
	if (xd > yd * 2 || xd < -yd * 2) PutChar('-');
	else if ( yd <= 4 * xd) PutChar('/');
	else if (-yd >= 4 * xd) PutChar('\\');
	else                    PutChar('|');
}

void drawLevelScreen(int level);

void drawMainMenu(void);

void drawGameOverScreen(void);

void drawIntroduction1(void);

void drawInstructions(void);
	
void clearScreen(void){
		PUTSTRLIT(ANSI_CSI "3J"); //Clear Screen
}

/// @}
