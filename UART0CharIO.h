///@file UART0CharIO.h
///Supplies an interface to functions defined in the corresponding assembly
/// file, UART0CharIO.s. This interface implements a driver to the UART0.
///This module is responsible for communicating with an external text terminal,
/// communicating with it via the OpenSDA port on the KL46. The internal
/// implementation is done via using the UART module of the chip, which OpenSDA
/// is already set up to.
///@author Koen Komeya <kxk2610@rit.edu>
///@date 11/24/2017 ~
///----------------------------------------------------------------------------
#ifndef UART0CHARIO_H
#define UART0CHARIO_H

/// Includes
#include <stdint.h>
///----------------------------------------------------------------------------
/// @addtogroup Major Functions
/// @{
/**
 * Initializes this module. (See the assembly code for more info.)
 */
void Init_UART0_IRQ (void);

/**
 * Reads a character from the stream
 * @return the next character from the terminal
 */
char GetChar (void);

/**
 * Reads a carriage-return-terminated string as a NUL-terminated string.
 * @param strbuf the string buffer to read data into
 * @param cap the size of the string buffer
 */
void GetStringSB (char *strbuf, int cap);

/**
 * Writes a character to stream
 * @param c character to write
 */
void PutChar (char c);

/** 
 * Writes an optionally NUL-terminated string. (If not NUL-terminated within
 *  len bytes, will only write len bytes)
 * @param str the string to write
 * @param len the maximum amount of bytes to write
 */
void PutStringSB (char *str, int len);

/**
 * Writes an unsigned 32-bit number in its decimal representation.
 * @param num number to write
 */
void PutNumU (uint32_t num);

/**
 * Writes an unsigned 8-bit number in its decimal representation.
 * @param num number to write
 */
void PutNumUB (uint8_t num);

/**
 * Writes an unsigned 32-bit number in its hexadecimal representation.
 * @param num number to write in hex
 */
void PutNumHex (uint32_t num);

/**
 * Flushes the output. (Interrupts need to be disabled.)
 */
void Flush (void);

/// @}
///----------------------------------------------------------------------------
/// @addtogroup Functional Macros
/// @{
/// #define PUTSTRLIT(sa)
/// Prints out a string array or string literal.
/// @param sa string array to print; MUST BE A CHAR ARRAY OR STRING LITERAL.
#define PUTSTRLIT(sa) PutStringSB(sa, sizeof(sa))
/// #define GETSTRLIN(sa)
/// Reads a line into buffer.
/// @param sa char buffer to write to; MUST BE A CHAR BUFFER.
#define GETSTRLIN(sa) GetStringSB(sa, sizeof(sa))

/// @}
#endif
