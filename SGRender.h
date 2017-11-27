/// Space Game (name not final)
/// @file SGRender.h
/// Contains declarations for rendering functions that can be implemented
///  in different ways.
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/25/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
///----------------------------------------------------------------------------
#ifndef SGRENDER_H
#define SGRENDER_H

/// Includes
#include "SpaceGame.h"
///----------------------------------------------------------------------------
/// @addtogroup Major Functions
/// @{
/// Initializes the renderer
void initRenderer(void); //FIXME implement with #include "UART0CharIO.h" in SGRenderTerminal

/// Draw an alien at the specified position and direction
void drawAlien(pos_t x, pos_t y, pos_t xd, pos_t yd);

//        A
//Player <H>
/// Draw player at the specified position
void drawPlayer(pos_t x, pos_t y);

void drawLevelScreen(void);

void drawMainMenu(void);

void drawGameOverScreen(void);

void drawIntroduction1(void);

void drawInstructions(void);
	
void clearScreen(void);

/// @}
#endif 
