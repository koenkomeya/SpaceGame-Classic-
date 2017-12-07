/// Space Game (name not final)
/// @file TouchDriver.h
/// Interface to the Touch Sensing Input Module
/// @author Koen Komeya <kxk2610@rit.edu>
/// @date 11/26/2017 ~
/// [Final project for CMPE-250 (Section 4: Thursday 11 AM - 1 PM)]
///----------------------------------------------------------------------------
#ifndef TOUCHDRIVER_H
#define TOUCHDRIVER_H
///----------------------------------------------------------------------------
/// @addtogroup Major Functions
/// @{

/// Enables the Touch Sensing Input module.
void EnableTSI(void);

/// Disables the Touch Sensing Input module.
void DisableTSI(void);

/// ScanTSI causes the TSI to do a scan on the touch sensor.
/// Recommended to be called at the end of a tick.
void ScanTSI(void);

/// Returns where the TSI is being pressed, scaled from the values
///  -128 (held on the left) to 127 (held to the right).
/// If it is not currently being pressed, returns 0.
/// ScanTSI must be called before this is called.
int ReadTSIScaled(void);
/// @}
#endif
