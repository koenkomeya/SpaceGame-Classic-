/// Space Game (name not final)
/// @file LCDDriver.h
/// Interface to the driver for the LCD.
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/27/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
///---------------------------------------------------------------------------
#ifndef LCDDRIVER_H
#define LCDDRIVER_H
///----------------------------------------------------------------------------
/// @addtogroup Major Functions
/// @{

/// Enables the LCD display
void EnableLCD(void);

/// Disables the LCD display
void DisableLCD(void);

/// Writes a number in decimal to the LCD display.
void WriteLCDDec(int num);

/// @}
#endif
