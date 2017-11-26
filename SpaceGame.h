/// Space Game (name not final)
/// @file SpaceGame.c
/// Header file for main program and game logic
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/24/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
///----------------------------------------------------------------------------
#ifndef SPACEGAME_H
#define SPACEGAME_H

/// @addtogroup Defines

/// Number of lives player should start with
#define STARTING_LIVES 2


/// Number of rows in the alien grid. Adjust #aliencount_t when modified.
/// @see Alien_Mass
#define ALIEN_ROWS 5
/// Number of columns in the alien grid. Adjust #aliencount_t when modified.
/// @see Alien_Mass
#define ALIEN_COLS 10
/// Number of Weapons/Entity1's that can be present at once in the game.
/// @see GameState
#define MAX_E1S 80

///----------------------------------------------------------------------------
/// @addtogroup Typedefs
/// Size of data required to store an alien's type
typedef uint8_t alientype_t;

/// Position type: Fixed point, low byte is fractional component
typedef uint16_t pos_t;

/// Counter type for Aliens. Adjust when #ALIEN_ROWS and #ALIEN_COLS are 
///  changed.
typedef uint8_t aliencount_t;

/// Counter type for Weapons/Entity1's. Adjust when #MAX_ENT1S is changed.
typedef uint8_t e1count_t;


///----------------------------------------------------------------------------
/// @addtogroup Enums
/// Defines types of aliens.
/// Must fit in alientype_t
enum AlienType {
	Grunt = 0,
	Cruiser,
	Battleship,
};

///----------------------------------------------------------------------------
/// @addtogroup Structs

///Data structure for weapons of both sides.
///Currently represents a laser.
typedef struct Entity1_s{
	///X Position 
	pos_t xPos; 
	///Y Position 
	pos_t yPos;
	///X Velocity 
	pos_t xVel; 
	///Y Velocity 
	pos_t yVel;
	///Flags - In the form:
	/// Bit 7: 1 if on player's side, otherwise 0.
	uint8_t flags1;
	
} Entity1;

#define E1_F1_SIDE_MASK 0x80

///Data structure for an alien.
typedef struct Alien_s{
	///X Position when attacking
	pos_t xPos; 
	///Y Position when attacking
	pos_t yPos;
	///X Velocity when attacking
	pos_t xVel; 
	///Y Velocity when attacking
	pos_t yVel;
	///Alien's type
	alientype_t type;
	/// Flags - In the form:
	/// Bit 7: Currently attacking?
	/// Bit 6: Currently swooping for attack?
	/// Bit 1: Currently exploding?
	/// Bit 0: Currently alive? (Checked to see if alien should be updated/rendered)
	uint8_t flags1;
	/// Health points of alien
	uint8_t health;
	/// Timer; used to countdown to stage transitions (e.g. Exploding -> Dead)
	uint8_t timer;
} Alien;

#define AL_F1_ATTACK_MASK 0x80
#define AL_F1_SWOOP_MASK  0x40
#define AL_F1_DYING_MASK  0x02
#define AL_F1_ALIVE_MASK  0x01

// Represents all of the aliens
//  The #Alien mass is organized in a rectangular grid alike to as in Galaxian.
//  Each entry of the alien mass is represent
struct Alien_Mass{
	///X Position of top left unit of alien mass
	pos_t massXPos; 
	///Y Position of top left unit of alien mass
	pos_t massYPos;
	///The array of the aliens
	Alien alienArray[ALIEN_ROWS * ALIEN_COLS];
	///Time until alien attack in ticks
	uint16_t etaAlienAttack;
};


///Data structure containing all of the necessary information to contain the
/// state of an active game.
///If modified, #startGame() must be modified to handle the changes.
typedef struct GameState_s{
	///Structure for the aliens.
	struct Alien_Mass aliens;
	///Data for weapons/Entity1's
	e1count_t activeE1s;
	///Array of pointers to E1's such that the first #GameState.activeE1s entries
	/// point to active E1's and the remainder point to inactive E1's.
	Entity1 *e1s[MAX_E1S];
	/// FIXME structure for Player
	///Player's score
	uint16_t score;
	///Amount of lives player has
	uint8_t lives;
} GameState;

///----------------------------------------------------------------------------
/// @addtogroup Variables

#endif