
/**
 *******************************************************************************************
 * @file       Serial.c
 * @ingroup    Serial
 * @author		Robert Evers                                                      
 *******************************************************************************************
 */

/*
 *******************************************************************************************
 * Standard include files
 *******************************************************************************************
 */
#include <avr/io.h>
#include <inttypes.h>
#include "Serial.h"

/*
 *******************************************************************************************
 * Macro definitions
 *******************************************************************************************
 */

/*
 *******************************************************************************************
 * Types
 *******************************************************************************************
  */

/*
 *******************************************************************************************
 * Variables
 *******************************************************************************************
 */

/*
 *******************************************************************************************
 * Prototypes
 *******************************************************************************************
 */

/*
 *******************************************************************************************
 * Routines implementation
 *******************************************************************************************
 */

/**
 *******************************************************************************************
 * @fn	    	void SerialInit(void)
 * @brief   	Init  serial port for transmit at 19200 baud at 8<hz clock.
 * @return		None
 * @attention	
 *******************************************************************************************
 */

void SerialInit(void)
{
   UCSR0A = 0;
   UCSR0B = 0;
   UCSR0C = 0;
   UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
   UBRR0H = 0;
   UBRR0L = 25;
   UCSR0B |= (1 << TXEN0);
}

/**
 *******************************************************************************************
 * @fn         void SerialTransmit(char *Data)
 * @brief      Transmt a string on the serial port.
 * @param      Data Pointer to null terminated string with data.
 * @return     None
 * @attention
 *******************************************************************************************
 */
void SerialTransmit(char *Data)
{
   while (*Data)
   {
      while (!(UCSR0A & (1 << UDRE0)));
      UDR0 = *Data;
      Data++;
   }
}
