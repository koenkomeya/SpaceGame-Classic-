/// Space Game (name not final)
/// @file SpaceGame.c
/// Center of all game logic. Contains main program
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/24/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
//-----------------------------------------------------------------------------
/// @addtogroup Pragmas
/// @{
//Make it possible to use anonymous unions
#pragma anon_unions

/// @}
///----------------------------------------------------------------------------
///             Imports
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "MKL46Z4.h"
#include "SpaceGame.h"
#include "SGRender.h"

///----------------------------------------------------------------------------
/// @addtogroup Variables
/// @{
laser laserStorage[];

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Major Functions
/// Entry point to the game
int main(){
	initRenderer();
	//TODO Also Timer
}

void renderGame();

/// Responsible for rendering the game to somewhere.
void render(){
	renderGame();
}

void tickAliens();

/// Called every 1/60'th of a second to update stuff.
void tick(){
	tickAliens();
	
	render();
}

/// @}
/// @addtogroup Minor Functions
/// Updates all the aliens
void tickAliens(){
	for (aliencount_t r = 0; r < ALIEN_ROWS; r++){
		for (aliencount_t c = 0; c < ALIEN_COLS; c++){
			// Each alien
		}
	}
}

/// Renders ever
void renderGame(){
	
}


/// @}
/// @}