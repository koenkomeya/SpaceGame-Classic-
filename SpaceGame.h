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
/// Number of rows in the alien grid. Adjust #aliencount_t when modified.
/// @see Alien_Mass
#define ALIEN_ROWS 5
/// Number of columns in the alien grid. Adjust #aliencount_t when modified.
/// @see Alien_Mass
#define ALIEN_COLS 10

///----------------------------------------------------------------------------
/// @addtogroup Typedefs
/// Size of data required to store an alien's type
typedef uint8_t alientype_t;

/// Position type: Fixed point, low byte is fractional component
typedef uint16_t pos_t;

/// Counter type for Aliens. Adjust when #ALIEN_ROWS and #ALIEN_COLS are 
///  changed.
typedef uint8_t aliencount_t;


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
	/// In the form:
	/// Bit 7: Currently attacking?
	/// Bit 6: Currently swooping for attack?
	/// Bit 1: Currently exploding?
	/// Bit 0: Currently alive?
	uint8_t flags1;
	/// Health points of alien
	uint8_t health;
	/// Timer; used to countdown to stage transitions (e.g. Exploding -> Dead)
	uint8_t timer;
} Alien;

// Represents all of the aliens
//  The alien mass is organized in a rectangular grid alike to as in Galaxian.
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
typedef struct GameState_s{
	///Structure for the aliens.
	struct Alien_Mass aliens;
	///Structures for enemy lasers
	laser_count activelasers
	
	laser *laserarray[]
	/// FIXME structure for Player
	///Player's score
	uint16_t score;
	///Amount of lives player has
	uint8_t lives;
} GameState;

#endif