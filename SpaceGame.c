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
#include <string.h>

#include "MKL46Z4.h"
#include "SpaceGame.h"
#include "SGRender.h"

///----------------------------------------------------------------------------
/// @addtogroup Variables
/// @{

///Storage for the E1's pointed to in #GameState.e1s
Entity1 e1Storage[MAX_E1S];

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Major Functions

/// Assembly Subroutine to enable updates
void EnableClock();

/// Initializes game structures
void startGame(){
	//TODO finish initialize structures
	GameState *gs; //FIXME set to location of the GameState
	//Initialize E1 container
	gs->activeE1s = 0;
	for (e1count_t i = 0; i < MAX_E1S; i++){
		gs->e1s[i] = &e1Storage[i]; 
	}
	//Initialize Aliens
	memset(&(gs->aliens), 0, sizeof(struct Alien_Mass));
	//TODO actually initialize each alien in the grid.
	//TODO set gs->aliens.etaAlienAttack to something.
	//Initialize Miscellaneous
	gs->lives = STARTING_LIVES;
	gs->score = 0;
}

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