/// Space Game (name not final)
/// @file SGRender.h
/// Contains declarations for rendering functions that can be implemented
///  in different ways.
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/25/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
///----------------------------------------------------------------------------
/// E X P L A N A T I O N
///- - - - - - - - - - - -
///The screen starts at (0,40) in the upper left hand corner and goes to 
/// (80,0) in the lower right hand corner.
///----------------------------------------------------------------------------
#ifndef SGRENDER_H
#define SGRENDER_H

/// Includes
#include "SpaceGame.h"
///----------------------------------------------------------------------------
/// @addtogroup Defines
/// @{

/// X Max of screen
#define SCREEN_WIDTH 80

/// Y Max of screen
#define SCREEN_HEIGHT 40

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Major Functions
/// @{
/// @brief Initializes the renderer.
void initRenderer(void);

/// @brief Draw an alien; the specified location is if it is not swooping
void drawAlien(Alien *a, pos_t x, pos_t y);

/// @brief Draw player at the specified position
void drawPlayer(pos_t x, pos_t y);

/// @brief Draw an E1 at the specified position and direction
void drawE1(int8_t e1flags1, pos_t x, pos_t y, pos_t xd, pos_t yd);

void drawLevelScreen(int level, int lives, int score);

void drawMainMenu(void);

void drawGameOverScreen(int score);

void drawIntroduction1(void);

void drawInstructions(void);
	
void clearScreen(void);
	
void flushScreen(void);

void drawScore(int score);

/// @}
#endif 
