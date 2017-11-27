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

/// The current mode of operation.
/// @see OperationMode
opmode_t opMode;

/// The current mode's delegate for ticking
void (*mode_tick)();

/// The current mode's delegate for rendering
void (*mode_render)();

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Functions
/// @{
/// @addtogroup Major Functions
/// @{

/// Assembly Subroutine to enable updates
void EnableClock(void);
void WaitForTick(void);

/// Does nothing; used as a dummy function.
void noop(){}
	
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


/// Called every 1/50'th of a second to update stuff.
void tick(){
	mode_tick();
	mode_render();
}


/// Entry point to the game
int main(){
	updateOpState(OM_TransitionState);
	initRenderer();
	EnableClock();
	//TODO initialize GameState
	//Do tick loop: Tick every 0.02s interval
	while (1){
		WaitForTick();
		tick();
  }
}

void tickGame(void);
void renderGame(void);
/// Updates the operation mode safely, updating #mode_tick and #mode_render in the process
/// @see OperationMode
void updateOpState(opmode_t newState){
	opMode = newState;
	switch (opMode){
		case OM_TransitionState:
			mode_tick = noop;
		  mode_render = noop;
		break;
		case OM_Game:
			mode_tick = tickGame;
		  mode_render = renderGame;
		break;
		case OM_GameOver:
			mode_tick = noop;
		  mode_render = noop;
		break;
		case OM_MainMenu:
			mode_tick = noop;
		  mode_render = noop;
		break;
		case OM_IntroSequence:
			mode_tick = noop;
		  mode_render = noop;
		break;
		case OM_Credits:
			mode_tick = noop;
		  mode_render = noop;
		break;
	}
}


/// @}
/// @addtogroup Minor Functions
/// @{

void tickAliens(void);
/// Ticks everything in a game session.
void tickGame(){
	
}

/// Renders everything in a game session.
void renderGame(){
	
}


/// @}

/// @addtogroup Sub-Minor Functions
/// @{
/// Updates all the aliens
void tickAliens(){
	for (aliencount_t r = 0; r < ALIEN_ROWS; r++){
		for (aliencount_t c = 0; c < ALIEN_COLS; c++){
			// Each alien
		}
	}
}


/// @}
/// @}
