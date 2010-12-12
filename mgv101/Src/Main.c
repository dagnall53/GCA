
/**
 *******************************************************************************************
 * @file 		main.c                                         
 * @ingroup     Main
 * @defgroup	Main Main : Main appliocation of the MGV101 Ethernet Loconet buffer.  
 * @author		Robert Evers                                                      
 *******************************************************************************************
 */

/*
 *******************************************************************************************
 * Standard include files
 *******************************************************************************************
 */
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <util/delay.h>
#include "UserIo.h"
#include "enc28j60.h"
#include "EthLocBuffer.h"
#include "LoconetTxBuffer.h"

#ifndef F_CPU
# 	error F_CPU NOT DEFINED!!!
#endif

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
 * @fn	    	void main(void)		
 * @brief   	Main routine of MGV101 Ethernet Loconet  application.
 * @return		None
 * @attention	
 *******************************************************************************************
 */

int main(void)
{
   /* Set clock speed to "no pre-scaler" */
   CLKPR = (1 << CLKPCE);
   CLKPR = 0;
   _delay_ms(12);

   /* Set run led */
   UserIoInit();
   UserIoSetLed(userIoLed4, userIoLedSetBlink);
   UserIoSetLed(userIoLed5, userIoLedSetBlink);

   EthLocBufferInit();
   LoconetTxBufferInit();

   sei();

   while (1)
   {
      UserIoMain();
      EthLocBufferMain();
      LoconetTxBufferMain();
   }
}
