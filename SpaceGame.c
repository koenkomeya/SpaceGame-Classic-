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
#include <stdlib.h>
#include <string.h>

#include "LCDDriver.h"
#include "MKL46Z4.h"
#include "SpaceGame.h"
#include "SGRender.h"
#include "TouchDriver.h"

///----------------------------------------------------------------------------
/// @addtogroup Variables
/// @{

/// The current mode of operation.
/// @see OperationMode
opmode_t opMode;

/// The current mode's delegate for ticking
void (*mode_tick)();

/// The current mode's delegate for rendering
void (*mode_render)();

/// The current mode's delegate for any after-tick processes
void (*mode_posttick)();

/// Contains the data for the current state.
/// @see StateUnion
StateUnion state;

/// Contains the current state of the inputs.
/// @see Inputs
Inputs inputs;


/// Contains data common to at least most states.
/// @see SharedData
SharedData data;

///Seed for #rand()
int rand_seed;

//Current tick number
int cTick = 0;

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Functions
/// @{
/// @addtogroup Major Functions
/// @{

/// Assembly Subroutine to enable periodic ticks
void EnableClock(void);
/// Assembly Subroutine to enable state recording for buttons.
void EnableButtonDriver(void);
/// Assembly Subroutine to wait until the next timed tick.
void WaitForTick(void);

/// Does nothing; used as a dummy function.
void noop(){}
	
/// Prepares game to progress to next level.
void nextLevel(){//Initialize E1 container
	int level = data.level++;
	//TODO finish initialize structures
	GameState *gs = &(state.game);
	gs->activeE1s = 0;
	for (e1count_t i = 0; i < MAX_E1S; i++){
		gs->e1s[i] = &(gs->e1Storage[i]); 
	}
	//Initialize Aliens
	memset(&(gs->aliens), 0, sizeof(struct Alien_Mass));
	gs->aliens.massXPos = ALIEN_MASS_START_X;
	gs->aliens.massYPos = ALIEN_MASS_START_Y;
	{
		aliencount_t r = 0;
		int rc = r * ALIEN_COLS;
		for (aliencount_t c = 0; c < ALIEN_COLS; c++){
			Alien *a = &(gs->aliens.alienArray[rc+c]);
			a->type = AT_Battleship;
			a->health = 3 + (level >> 3);
			a->flags1 = AL_F1_ALIVE_MASK;
		}
	}
	for (aliencount_t r = 1; r < 3; r++){
		int rc = r * ALIEN_COLS;
		for (aliencount_t c = 0; c < ALIEN_COLS; c++){
			Alien *a = &(gs->aliens.alienArray[rc+c]);
			a->type = AT_Cruiser;
			a->health = 1 + ((level+8) >> 4);
			a->flags1 = AL_F1_ALIVE_MASK;
		}
	}
	if (level != 0){
		for (aliencount_t r = 3; r < ALIEN_ROWS; r++){
			int rc = r * ALIEN_COLS;
			for (aliencount_t c = 0; c < ALIEN_COLS; c++){
				Alien *a = &(gs->aliens.alienArray[rc+c]);
				a->type = AT_Grunt;
				if (level < 8) a->health = 1;
				else a->health = ((level+24) >> 5);
				a->flags1 = AL_F1_ALIVE_MASK;
			}
		}
	} else {
		for (aliencount_t r = 3; r < ALIEN_ROWS; r++){
			int rc = r * ALIEN_COLS;
			for (aliencount_t c = 0; c < ALIEN_COLS; c++){
				Alien *a = &(gs->aliens.alienArray[rc+c]);
				a->flags1 = 0;
			}
		}
	}
	gs->aliens.etaAlienAttack = 250;
	gs->aliens.alienAttackTime = 3000 / (data.level + 2);
	//Initialize Miscellaneous
	gs->player.xPos = STARTING_X;
	gs->player.yPos = STARTING_Y;
	gs->player.dying = 0;
	gs->player.cooldown = 50;
	drawLevelScreen(data.level, gs->player.lives, data.score);
	for (int i = 0; i < 150; i++) WaitForTick();
	clearScreen();
}
/// Initializes game structures
void startGame(){
	updateOpState(OM_Game);
	data.level = 0;
	GameState *gs = &(state.game);
	data.score = 0;
	gs->player.lives = STARTING_LIVES;
	nextLevel();
}


/// Called every 1/50'th of a second to update stuff.
void tick(){
	mode_tick();
	mode_render();
	mode_posttick();
}

void prepReadInputs(void);
/// Entry point to the game
int main(){
	srand(rand_seed);
	//Initialize variables/state.
	opMode = OM_TransitionState; //Have to do this first to ensure some routine
	                             //doesn't get called for deinitialization.
	updateOpState(OM_TransitionState);
	memset(&data, 0, sizeof(SharedData));
	//Enable Peripherals
	EnableButtonDriver();
	EnableTSI();
	prepReadInputs();
	initRenderer();
	EnableClock();
	startGame();
	//Do tick loop: Tick every 0.02s interval
	while (1){
		WaitForTick();
		tick();
  }
}

void tickGame(void);
void renderGame(void);
void postGame(void);
/// Updates the operation mode safely, updating #mode_tick and #mode_render in the process
/// @see OperationMode
void updateOpState(opmode_t newState){
	__asm("CPSID I");
	switch (opMode){ //Deinitialization Procedure
		case OM_Game:
			DisableLCD();
		break;
		case OM_GameOver:
		break;
		case OM_MainMenu:
		break;
		case OM_IntroSequence:
		break;
		case OM_Credits:
		break;
	}
	opMode = newState;
	switch (opMode){ //Initialization Procedure
		case OM_TransitionState:
			mode_tick = noop;
		  mode_render = noop;
			mode_posttick = noop;
		break;
		case OM_Game:
			mode_tick = tickGame;
		  mode_render = renderGame;
			mode_posttick = postGame;
		  EnableLCD();
		break;
		case OM_GameOver:
			mode_tick = noop;
		  mode_render = noop;
			mode_posttick = noop;
		break;
		case OM_MainMenu:
			mode_tick = noop;
		  mode_render = noop;
			mode_posttick = noop;
		break;
		case OM_IntroSequence:
			mode_tick = noop;
		  mode_render = noop;
			mode_posttick = noop;
		break;
		case OM_Credits:
			mode_tick = noop;
		  mode_render = noop;
			mode_posttick = noop;
		break;
	}
	__asm("CPSIE I");
}

///@brief generate pseudo-random number
//int rand(){
//rand_seed
//}
/// @}
/// @addtogroup Minor Functions
/// @{

/// Does any end of tick preparation to quickly read inputs the next ticks,
void prepReadInputs(void){
	ScanTSI();
}

/// Reads all input sources for this game.
void readInputs(void){
	inputs.buttonPressed = CheckAndClearPress();
	inputs.slider = ReadTSIScaled();
}

void tickPlayer(void);
void tickAliens(void);
void tickE1s(void);
/// Ticks everything in a game session.
void tickGame(){
	readInputs();
	tickPlayer();
	tickAliens();
	tickE1s();
	struct PlayerGameData *p = &(state.game.player);
	if (p->dying == 1 && p->cooldown <= 0){
		if (--(p->lives) == 0){
			updateOpState(OM_GameOver);
			drawGameOverScreen(data.score);
			while (1); //Lock here because we can't gracefuly change state like this.
		} else {
			data.level--;
			nextLevel();
		}
	}
	WriteLCDDec(data.score);
	cTick++;
	struct Alien_Mass *am = &(state.game.aliens);
	for (aliencount_t i = 0; i < (ALIEN_ROWS * ALIEN_COLS); i++){
		if (am->alienArray[i].flags1 & AL_F1_ALIVE_MASK) return;
	}
	nextLevel();
}

/// Renders everything in a game session.
void renderGame(){
	if (cTick & 3) return;
	if (cTick & 4){
		clearScreen();
		GameState *gs = &(state.game);
		//Draw Player
		if (!(gs->player.dying)) drawPlayer(gs->player.xPos, gs->player.yPos);
		//Render each E1.
		int gsae1s = gs->activeE1s;
		for (e1count_t i = 0; i < gsae1s; i++){
			Entity1 *e1 = gs->e1s[i];
			drawE1(e1->flags1, e1->xPos, e1->yPos, e1->xVel, e1->yVel);
		}
		//Render each alien.
		for (aliencount_t r = 0; r < ALIEN_ROWS; r++){
			int rc = r * ALIEN_COLS;
			for (aliencount_t c = 0; c < ALIEN_COLS; c++){
				Alien *a = &(gs->aliens.alienArray[rc+c]);
				drawAlien(a, gs->aliens.massXPos + c * ALIEN_MASS_SPREAD_X, 
									gs->aliens.massYPos - r * ALIEN_MASS_SPREAD_Y);
			}
		}
	} else {
		clearScreen();
		GameState *gs = &(state.game);
		//Render each alien.
		for (aliencount_t r = ALIEN_ROWS - 1; r < ALIEN_ROWS; r--){
			int rc = r * ALIEN_COLS;
			for (aliencount_t c = ALIEN_COLS - 1; c < ALIEN_COLS; c--){
				Alien *a = &(gs->aliens.alienArray[rc+c]);
				drawAlien(a, gs->aliens.massXPos + c * ALIEN_MASS_SPREAD_X, 
									gs->aliens.massYPos - r * ALIEN_MASS_SPREAD_Y);
			}
		}
		//Render each E1.
		int gsae1s = gs->activeE1s;
		for (e1count_t i = gsae1s - 1; i < gsae1s; i--){
			Entity1 *e1 = gs->e1s[i];
			drawE1(e1->flags1, e1->xPos, e1->yPos, e1->xVel, e1->yVel);
		}
		//Draw Player
		if (!(gs->player.dying)) drawPlayer(gs->player.xPos, gs->player.yPos);
	}
	drawScore(data.score);
	flushScreen();
}

/// Does post-tick processes
void postGame(void){
	prepReadInputs();
}

/// Allocates an E1 and returns short-term index or -1
int allocE1(void){
	GameState *gs = &(state.game);
	int index = gs->activeE1s;
	if (index == MAX_E1S) return -1;
	gs->activeE1s++;
	return index;
}
/// Frees E1 by short term index.
/// If iterating, repeat access of this index to get a diffferent E1.
void freeE1(int index){
	GameState *gs = &(state.game);
	gs->activeE1s--;
	Entity1 *temp = gs->e1s[gs->activeE1s];
	gs->e1s[gs->activeE1s] = gs->e1s[index];
	gs->e1s[index] = temp;
}


/// @}

/// @addtogroup Sub-Minor Functions
/// @{

/// Player loses life
void playerDie(){
	GameState *gs = &(state.game);
	gs->player.dying = 1;
	gs->player.cooldown = 90;
}

/// Updates player
void tickPlayer(){
	GameState *gs = &(state.game);
	if (gs->player.cooldown == 0){
		if (inputs.buttonPressed){
			int e = allocE1();
			if (e != -1){
				Entity1 *e1 = gs->e1s[e];
				e1->xPos = gs->player.xPos;
				e1->yPos = gs->player.yPos + 0x100;
				e1->yVel = 12;
				e1->xVel = 0;
				e1->flags1 = E1_F1_SIDE_MASK;
				gs->player.cooldown = PLAYER_GUN_COOLDOWN;
			}
		}
	} else gs->player.cooldown -= 1;
	if (gs->player.dying) return;
	//Movement
	gs->player.xPos += (inputs.slider / 4);
	if (gs->player.xPos < 0x0200) gs->player.xPos = 0x0200;
	if (gs->player.xPos >= 0x4800) gs->player.xPos = 0x47FF;
	//Collide check -> Game Over
	// TODO alien collision
	for (e1count_t i = 0; i < gs->activeE1s; i++){
		Entity1 *e1 = gs->e1s[i];
		if (!(e1->flags1 & E1_F1_SIDE_MASK)){
			int dx = e1->xPos - gs->player.xPos;
			if (dx < 0) dx = -dx;
			if (dx < E1_RADIUS + PLAYER_RADIUS){
				int dy = e1->yPos - gs->player.yPos;
				if (dy < 0) dy = -dy;
				if (dy < E1_RADIUS + PLAYER_RADIUS){
					freeE1(i);
					playerDie();
					return;
				}
			}
		}
	}
}
/// Updates all the aliens
void tickAliens(){
	GameState *gs = &(state.game);
	struct Alien_Mass *am = &(state.game.aliens);
	if (am->massXPos & 1){ //Move around mass
		if (am->massXPos > (0x4900 - ALIEN_MASS_WIDTH)){
			am->massXPos--;
		}
		am->massXPos += 0x2;
	} else {
		if (am->massXPos < 0x100){
			am->massXPos++;
		}
		am->massXPos -= 0x2;
	}
	am->etaAlienAttack -= 1;
	int level = data.level;
	if (am->etaAlienAttack == 0){
		am->etaAlienAttack = am->alienAttackTime;
		for (int i = 0; i < 3; i++){
			int col = rand() % ALIEN_COLS;
			int row = ALIEN_ROWS - 1;
			Alien *a = &(am->alienArray[row * ALIEN_COLS + col]);
			while (row >= 0 && (a->flags1 & 1) == 0){
				row--;
				a = &(am->alienArray[row * ALIEN_COLS + col]);
			}
			if (row == -1) continue;
			//a->flags1 |= AL_F1_SWOOP_MASK; //TODO trigger and set location.
			// Spawn 1-3 E1s
			alientype_t type = a->type;
			if ((rand() & 0x7) == 1 && type != AT_Grunt && level > 3){
				int e = allocE1();
				if (e == -1) break;
				Entity1 *e1 = gs->e1s[e];
				e1->xPos = a->xPos;
				e1->yPos = a->yPos;
				e1->yVel = -12;
				e1->xVel = (rand() & 0x0F) - 0x08;
				e1->flags1 = 0;
			}
			int e = allocE1();
			if (e == -1) break;
			Entity1 *e1 = gs->e1s[e];
			e1->xPos = a->xPos;
			e1->yPos = a->yPos;
			e1->yVel = -12;
			e1->xVel = (rand() & 0x03) - 0x02;
			e1->flags1 = 0;
			if ((rand() & 0x7) > 2 && type != AT_Grunt && level > 1){
				e = allocE1();
				if (e == -1) break;
				Entity1 *e1 = gs->e1s[e];
				e1->xPos = a->xPos;
				e1->yPos = a->yPos;
				e1->yVel = -12;
				e1->xVel = (rand() & 0x07) - 0x04;
				e1->flags1 = 0;
			}
			if (type == AT_Battleship){
				if ((rand() & 0x3) == 1 && type == AT_Battleship){
					int e = allocE1();
					if (e == -1) break;
					Entity1 *e1 = gs->e1s[e];
					e1->xPos = a->xPos;
					e1->yPos = a->yPos;
					e1->yVel = -12;
					e1->xVel = (rand() & 0x1F) - 0x10;
					e1->flags1 = 0;
				}
				int barrage;
        if (level < 8) barrage = (rand() & level);
        else barrage = 4 + (rand() & 0x7);
				for (int i = 0; i < barrage; i++){
					int e = allocE1();
					if (e == -1) break;
					Entity1 *e1 = gs->e1s[e];
					e1->xPos = a->xPos;
					e1->yPos = a->yPos;
					e1->yVel = -12;
					e1->xVel = (rand() & 0x0F) - 0x08;
					e1->flags1 = 0;
				}
			}
		}
	}
	for (aliencount_t r = 0; r < ALIEN_ROWS; r++){
		int rc = r * ALIEN_COLS;
		for (aliencount_t c = 0; c < ALIEN_COLS; c++){
			Alien *a = &(am->alienArray[rc+c]);
			if (!(a->flags1 & AL_F1_ALIVE_MASK)) continue;
			if (a->flags1 & AL_F1_DYING_MASK){
				if (--(a->timer) <= 0){
					a->flags1 &= ~AL_F1_ALIVE_MASK;
				}
				continue;
			}
			if (a->flags1 & (AL_F1_ATTACK_MASK | AL_F1_SWOOP_MASK)) {
				//Velocity calc
				a->xPos += a->xVel;
				a->yPos += a->yVel;
			} else {
				a->xPos = am->massXPos + c * ALIEN_MASS_SPREAD_X;
				a->yPos = am->massYPos - r * ALIEN_MASS_SPREAD_Y;
			}
			for (e1count_t i = 0; i < gs->activeE1s; i++){
			  //Collision check
		    Entity1 *e1 = gs->e1s[i];
				if (e1->flags1 & E1_F1_SIDE_MASK){
					int dx = e1->xPos - a->xPos;
					if (dx < 0) dx = -dx;
					if (dx < E1_RADIUS + ENEMY_RADIUS){
						int dy = e1->yPos - a->yPos;
						if (dy < 0) dy = -dy;
						if (dy < E1_RADIUS + ENEMY_RADIUS){
							freeE1(i);
							a->health--;
							if (a->health <= 0){
								a->timer = 20;
								a->flags1 |= AL_F1_DYING_MASK;
								if (a->type == AT_Battleship) data.score += 4;
								if (a->type == AT_Cruiser) data.score += 2;
								if (a->type == AT_Grunt) data.score += 1;
							}
						}
					}
				}
			}
		}
	}
}

/// Updates E1s
void tickE1s(){
	GameState *gs = &(state.game);
	for (e1count_t i = 0; i < gs->activeE1s; i++){
		Entity1 *e1 = gs->e1s[i];
		register int x = e1->xPos;
		x += e1->xVel;
		e1->xPos = x;
		register int y = e1->yPos;
		y += e1->yVel;
		e1->yPos = y;
		if (x < 0) goto e1die;
		if (x >= 0x5000) goto e1die; //TODO get rid of hard-coded vals
		if (y < 0) goto e1die;
		if (y >= 0x2800) goto e1die; //TODO get rid of hard-coded vals
		continue;
		e1die:
		freeE1(i);
		i--;
	}
}


/// @}
/// @}
