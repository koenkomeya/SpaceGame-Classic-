/// Space Game (name not final)
/// @file SpaceGame.c
/// Header file for main program and game logic
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/24/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
///----------------------------------------------------------------------------
#ifndef SPACEGAME_H
#define SPACEGAME_H

///             Includes
#include <stdbool.h>
#include <stdint.h>

///----------------------------------------------------------------------------
/// @addtogroup Defines
/// @{

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

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Typedefs
/// @{
/// Size of data required to store an alien's type
/// @see AlienType
typedef uint8_t alientype_t;

/// Size of data required to store operation mode
/// @see OperationMode
typedef uint8_t opmode_t;

/// Position type: Fixed point, low byte is fractional component
typedef int16_t pos_t;

/// Counter type for Aliens. Adjust when #ALIEN_ROWS and #ALIEN_COLS are 
///  changed.
typedef uint8_t aliencount_t;

/// Counter type for Weapons/Entity1's. Adjust when #MAX_ENT1S is changed.
typedef uint8_t e1count_t;


/// @}
///----------------------------------------------------------------------------
/// @addtogroup Enums
/// @{
/// Defines types of aliens.
/// Must fit in #alientype_t
/// If an alien type is added, #drawAlien() must be modified.
enum AlienType {
	AT_Grunt = 0,
	AT_Cruiser,
	AT_Battleship,
};

/// Defines modes of operation.
/// Must fit in #opmode_t
/// When updated, update #updateOpState()
enum OperationMode {
	OM_TransitionState = 0,
	OM_Game,
	OM_GameOver,
	OM_MainMenu,
	OM_IntroSequence,
	OM_Credits,
};

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Structs
/// @{

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
	///@see AlienType
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
	pos_t ply_pos_x, ply_pos_y;
	///Player's score
	uint16_t score;
	///Amount of lives player has
	uint8_t lives;
  ///Storage for the E1's pointed to in #GameState.e1s
  Entity1 e1Storage[MAX_E1S];
} GameState;

///Data structure representing a union of every data structure of every
/// independent state.
/// Used to save memory.
typedef union StateUnion_s{
	GameState game;
} StateUnion;

///Data structure for on-chip inputs that are used in this program.
typedef struct Inputs_s{
	/// The current state of the slider.
  int8_t slider;
  /// The current state of the button.
  bool buttonPressed;
} Inputs;

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Variables
/// @{

/// The current mode of operation (Do not update directly)
/// @see updateOpState
extern opmode_t opMode;

/// Contains the data for the current state.
/// @see StateUnion
extern StateUnion state;

/// Contains the current state of the inputs.
/// @see Inputs
extern Inputs inputs;

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Functions
/// @{

///@brief Updates the current operating state. 
void updateOpState(opmode_t);


/// @}
#endif
