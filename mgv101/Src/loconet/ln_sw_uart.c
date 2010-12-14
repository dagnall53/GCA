
/****************************************************************************
    Copyright (C) 2002 Alex Shepherd

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*****************************************************************************

 Title :   LocoNet Software UART Access library
 Author:   Alex Shepherd <kiwi64ajs@sourceforge.net>
 Date:     13-Aug-2002
 Software:  AVR-GCC with AVR-AS
 Target:    any AVR device

 DESCRIPTION
  Basic routines for interfacing to the LocoNet via any output pin and
  either the Analog Comparator pins or the Input Capture pin

  The receiver uses the Timer1 Input Capture Register and Interrupt to detect
  the Start Bit and then the Compare A Register for timing the subsequest
  bit times.

  The Transmitter uses just the Compare A Register for timing all bit times
       
 USAGE
  See the C include ln_sw_uart.h file for a description of each function
       
*****************************************************************************/

#include <avr/io.h>
#include <avr/interrupt.h>
#include <string.h>

#include "ln_sw_uart.h"

#ifdef BOARD_ETHERNET_LOCONET_BUFFER_MGV_101
#define LN_RX_PORT            PINB
#define LN_RX_BIT             PB0

#define LN_SB_SIGNAL          SIG_INPUT_CAPTURE1
#define LN_SB_INT_ENABLE_REG  TIMSK1
#define LN_SB_INT_ENABLE_BIT  ICIE1
#define LN_SB_INT_STATUS_REG  TIFR1
#define LN_SB_INT_STATUS_BIT  ICF1

#define LN_TMR_SIGNAL         SIG_OUTPUT_COMPARE1A
#define LN_TMR_INT_ENABLE_REG TIMSK1
#define LN_TMR_INT_ENABLE_BIT OCIE1A
#define LN_TMR_INT_STATUS_REG TIFR1
#define LN_TMR_INT_STATUS_BIT OCF1A
#define LN_TMR_INP_CAPT_REG   ICR1
#define LN_TMR_OUTP_CAPT_REG  OCR1A
#define LN_TMR_COUNT_REG      TCNT1
#define LN_TMR_CONTROL_REG    TCCR1B

#define LN_TMR_PRESCALER      1

#define LN_TX_PORT            PORTB
#define LN_TX_DDR             DDRB
#define LN_TX_BIT             PB1

#else    // No Board defined (Error)
#    warning "Board not defined"
#endif   // Boardtype

#ifndef LN_SW_UART_SET_TX_LOW                                                  // putting a 1 to the pin to switch on
                                                                               // NPN transistor
#define LN_SW_UART_SET_TX_LOW  sbi(LN_TX_PORT, LN_TX_BIT);                     // to pull down LN line to drive low
                                                                               // level
#endif

#ifndef LN_SW_UART_SET_TX_HIGH                                                 // putting a 0 to the pin to switch off
                                                                               // NPN transistor
#define LN_SW_UART_SET_TX_HIGH cbi(LN_TX_PORT, LN_TX_BIT);                     // master pull up will take care of high
                                                                               // LN level
#endif

#define LN_ST_IDLE            0                                                // net is free for anyone to start
                                                                               // transmission
#define LN_ST_CD_BACKOFF      1                                                // timer interrupt is counting backoff
                                                                               // bits
#define LN_ST_TX_COLLISION    2                                                // just sending break after creating a
                                                                               // collision
#define LN_ST_TX              3                                                // transmitting a packet
#define LN_ST_RX              4                                                // receiving bytes

#define   LN_COLLISION_TICKS 15

// The Start Bit period is a full bit period + half of the next bit period
// so that the bit is sampled in middle of the bit
#define LN_TIMER_RX_START_PERIOD    LN_BIT_PERIOD + (LN_BIT_PERIOD / 2)
#define LN_TIMER_RX_RELOAD_PERIOD   LN_BIT_PERIOD
#define LN_TIMER_TX_RELOAD_PERIOD   LN_BIT_PERIOD

// ATTENTION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// LN_TIMER_TX_RELOAD_ADJUST is a value for an error correction. This is needed for 
// every start of a byte. The first bit is to long. Therefore we need to reduce the 
// reload value of the bittimer.
// The following value depences highly on used compiler, optimizationlevel and hardware.
// Define the value in sysdef.h. This is very project specific.
// For the FREDI hard- and software it is nearly a quarter of a LN_BIT_PERIOD.
// Olaf Funke, 19th October 2007
// ATTENTION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#define LN_TIMER_TX_RELOAD_ADJUST   106                                        // 14,4 us delay for FREDI

#ifndef LN_TIMER_TX_RELOAD_ADJUST
#define LN_TIMER_TX_RELOAD_ADJUST   0
#error detect value by oszilloscope
#endif

// ATTENTION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//#define COLLISION_MONITOR
#ifdef COLLISION_MONITOR
#define COLLISION_MONITOR_PORT PORTB
#define COLLISION_MONITOR_DDR DDRB
#define COLLISION_MONITOR_BIT PB4
#endif

//#define STARTBIT_MONITOR
#ifdef STARTBIT_MONITOR
#define STARTBIT_MONITOR_PORT PORTB
#define STARTBIT_MONITOR_DDR DDRB
#define STARTBIT_MONITOR_BIT PB4
#endif

volatile byte                           lnState;
volatile byte                           lnBitCount;
volatile byte                           lnCurrentByte;
volatile word                           lnCompareTarget;

LnBuf                                  *lnRxBuffer;
volatile lnMsg                         *volatile lnTxData;
volatile byte                           lnTxIndex;
volatile byte                           lnTxLength;
volatile byte                           lnTxSuccess;

/**************************************************************************
*
* Start Bit Interrupt Routine
*
* DESCRIPTION
* This routine is executed when a falling edge on the incoming serial
* signal is detected. It disables further interrupts and enables
* timer interrupts (bit-timer) because the UART must now receive the
* incoming data.
*
**************************************************************************/

ISR(LN_SB_SIGNAL)
{
   // Disable the Input Comparator Interrupt
   cbi(LN_SB_INT_ENABLE_REG, LN_SB_INT_ENABLE_BIT);

   // Get the Current Timer1 Count and Add the offset for the Compare target
   lnCompareTarget = LN_TMR_INP_CAPT_REG + LN_TIMER_RX_START_PERIOD;
   LN_TMR_OUTP_CAPT_REG = lnCompareTarget;

   // Clear the current Compare interrupt status bit and enable the Compare interrupt
   sbi(LN_TMR_INT_STATUS_REG, LN_TMR_INT_STATUS_BIT);
   sbi(LN_TMR_INT_ENABLE_REG, LN_TMR_INT_ENABLE_BIT);

   // Set the State to indicate that we have begun to Receive
   lnState = LN_ST_RX;

   // Reset the bit counter so that on first increment it is on 0
   lnBitCount = 0;
}

/**************************************************************************
*
* Timer Tick Interrupt
*
* DESCRIPTION
* This routine coordinates the transmition and reception of bits. This
* routine is automatically executed at a rate equal to the baud-rate. When
* transmitting, this routine shifts the bits and sends it. When receiving,
* it samples the bit and shifts it into the buffer.
*
**************************************************************************/

ISR(LN_TMR_SIGNAL)                                                             /* signal handler for timer0 overflow */
{
   // Advance the Compare Target
   lnCompareTarget += LN_TIMER_RX_RELOAD_PERIOD;
   LN_TMR_OUTP_CAPT_REG = lnCompareTarget;

   // Increment bit_counter
   lnBitCount++;

   // Are we in the RX State
   if (lnState == LN_ST_RX)
   {
      // Are we in the Stop Bits phase
      if (lnBitCount < 9)
      {
         lnCurrentByte >>= 1;
         if (bit_is_set(LN_RX_PORT, LN_RX_BIT))
         {
            lnCurrentByte |= 0x80;
         }
         return;
      }

      // Clear the Start Bit Interrupt Status Flag and Enable ready to 
      // detect the next Start Bit
      sbi(LN_SB_INT_STATUS_REG, LN_SB_INT_STATUS_BIT);
      sbi(LN_SB_INT_ENABLE_REG, LN_SB_INT_ENABLE_BIT);

      // If the Stop bit is not Set then we have a Framing Error
      if (bit_is_clear(LN_RX_PORT, LN_RX_BIT))
      {
         lnRxBuffer->Stats.RxErrors++;
         addByteLnBuf(lnRxBuffer, lnCurrentByte);
      }
      else
      {
         // Put the received byte in the buffer
         addByteLnBuf(lnRxBuffer, lnCurrentByte);
      }

      lnBitCount = 0;
      lnState = LN_ST_CD_BACKOFF;
   }

   // Are we in the TX State
   else if (lnState == LN_ST_TX)
   {
      // To get to this point we have already begun the TX cycle so we need to 
      // first check for a Collision. For now we will simply check that TX and RX
      // ARE NOT THE SAME as our circuit requires the TX signal to be INVERTED
      // If they are THE SAME then we have a Collision

#     ifdef LN_SW_UART_TX_NON_INVERTED
      if (((LN_TX_PORT >> LN_TX_BIT) & 0x01) != ((LN_RX_PORT >> LN_RX_BIT) & 0x01))
#     else
      if (((LN_TX_PORT >> LN_TX_BIT) & 0x01) == ((LN_RX_PORT >> LN_RX_BIT) & 0x01))
#     endif
      {
         lnBitCount = 0;
         lnState = LN_ST_TX_COLLISION;
      }
      // Send each Bit
      else if (lnBitCount < 9)
      {
         if (lnCurrentByte & 0x01)
            LN_SW_UART_SET_TX_HIGH
            else
            LN_SW_UART_SET_TX_LOW lnCurrentByte >>= 1;
      }
      // When the Data Bits are done, generate stop-bit
      else if (lnBitCount == 9)
      {
      	LN_SW_UART_SET_TX_HIGH
      }
      // Any more bytes in buffer
      else
      {
         if (++lnTxIndex < lnTxLength)
         {
            // Setup for the next byte
            lnBitCount = 0;
            lnCurrentByte = lnTxData->data[lnTxIndex];

            // Begin the Start Bit
            LN_SW_UART_SET_TX_LOW
               // Get the Current Timer1 Count and Add the offset for the Compare target
               // added adjustment value for bugfix (Olaf Funke)
               lnCompareTarget = LN_TMR_COUNT_REG + LN_TIMER_TX_RELOAD_PERIOD - LN_TIMER_TX_RELOAD_ADJUST;
            LN_TMR_OUTP_CAPT_REG = lnCompareTarget;
         }
         else
         {
            // Successfully Sent all bytes in the buffer
            // so set the Packet Status to Done
            lnTxSuccess = 1;

            // Begin CD Backoff state
            lnBitCount = 0;
            lnState = LN_ST_CD_BACKOFF;
         }
      }
   }

   // Note we may have got here from a failed TX cycle, if so BitCount will be 0
   if (lnState == LN_ST_TX_COLLISION)
   {
      if (lnBitCount == 0)
      {
         // Pull the TX Line low to indicate Collision
         LN_SW_UART_SET_TX_LOW
#        ifdef COLLISION_MONITOR
         cbi(COLLISION_MONITOR_PORT, COLLISION_MONITOR_BIT);
#        endif
      }
      else if (lnBitCount >= LN_COLLISION_TICKS)
      {
         // Release the TX Line
         LN_SW_UART_SET_TX_HIGH
#        ifdef COLLISION_MONITOR
         sbi(COLLISION_MONITOR_PORT, COLLISION_MONITOR_BIT);
#        endif

         lnBitCount = 0;
         lnState = LN_ST_CD_BACKOFF;

         lnRxBuffer->Stats.Collisions++;
      }
   }

   if (lnState == LN_ST_CD_BACKOFF)
   {
      if (lnBitCount == 0)
      {
         // Even though we are waiting, other nodes may try and transmit early
         // so Clear the Start Bit Interrupt Status Flag and Enable ready to 
         // detect the next Start Bit
         sbi(LN_SB_INT_STATUS_REG, LN_SB_INT_STATUS_BIT);
         sbi(LN_SB_INT_ENABLE_REG, LN_SB_INT_ENABLE_BIT);
      }
      else if (lnBitCount >= LN_BACKOFF_MAX)
      {
         // declare network to free after maximum 
         // backoff delay
         lnState = LN_ST_IDLE;
         cbi(LN_TMR_INT_ENABLE_REG, LN_TMR_INT_ENABLE_BIT);
      }
   }
}

void initLocoNetHardware(LnBuf * RxBuffer)
{
#  ifdef COLLISION_MONITOR
   sbi(COLLISION_MONITOR_DDR, COLLISION_MONITOR_BIT);
   sbi(COLLISION_MONITOR_PORT, COLLISION_MONITOR_BIT);
#  endif
#  ifdef STARTBIT_MONITOR
   sbi(STARTBIT_MONITOR_DDR, STARTBIT_MONITOR_BIT);
   sbi(STARTBIT_MONITOR_PORT, STARTBIT_MONITOR_BIT);
#  endif

   initLnBuf(RxBuffer);
   lnRxBuffer = RxBuffer;

   // Set the TX line to Inactive
   LN_SW_UART_SET_TX_HIGH;
   sbi(LN_TX_DDR, LN_TX_BIT);

   lnState = LN_ST_IDLE;

   // Clear StartBit Interrupt flag
   sbi(LN_SB_INT_STATUS_REG, LN_SB_INT_STATUS_BIT);

   // Enable StartBit Interrupt
   sbi(LN_SB_INT_ENABLE_REG, LN_SB_INT_ENABLE_BIT);

   // Set Timer Clock Source 
   LN_TMR_CONTROL_REG = (LN_TMR_CONTROL_REG & 0xF8) | LN_TMR_PRESCALER;
}

LN_STATUS sendLocoNetPacketTry(lnMsg * TxData, unsigned char ucPrioDelay)
{
   byte                                    CheckSum;
   byte                                    CheckLength;

   lnTxLength = getLnMsgSize(TxData);

   // First calculate the checksum as it may not have been done
   CheckLength = lnTxLength - 1;
   CheckSum = 0xFF;

   for (lnTxIndex = 0; lnTxIndex < CheckLength; lnTxIndex++)
      CheckSum ^= TxData->data[lnTxIndex];

   TxData->data[CheckLength] = CheckSum;

   // clip maximum prio delay
   if (ucPrioDelay > LN_BACKOFF_MAX)
      ucPrioDelay = LN_BACKOFF_MAX;

   // if priority delay was waited now, declare net as free for this try
   // disabling interrupt to avoid
   cli();
   // confusion by ISR changing lnState
   // while we want to do it
   if (lnState == LN_ST_CD_BACKOFF)
   {
      // Likely we don't want to wait as long as the timer ISR waits its maximum
      if (lnBitCount >= ucPrioDelay)
      {
         lnState = LN_ST_IDLE;
         cbi(LN_TMR_INT_ENABLE_REG, LN_TMR_INT_ENABLE_BIT);
      }
   }
   sei();
   // a delayed start bit interrupt will happen now,
   // a delayed timer interrupt was stalled

   // If the Network is not Idle, don't start the packet
   if (lnState == LN_ST_CD_BACKOFF)
   {
      // in carrier detect timer?
      if (lnBitCount < LN_CARRIER_TICKS)
      {
         return LN_CD_BACKOFF;
      }
      else
      {
         return LN_PRIO_BACKOFF;
      }
   }

   if (lnState != LN_ST_IDLE)
   {
      // neither idle nor backoff -> busy
      return LN_NETWORK_BUSY;
   }

   // We need to do this with interrupts off.
   // The last time we check for free net until sending our start bit
   // must be as short as possible, not interrupted.
   cli();
   // Before we do anything else - Disable StartBit Interrupt
   cbi(LN_SB_INT_ENABLE_REG, LN_SB_INT_ENABLE_BIT);
   if (bit_is_set(LN_SB_INT_STATUS_REG, LN_SB_INT_STATUS_BIT))
   {
      // first we disabled it, than before sending the start bit, we found out
      // that somebody was faster by examining the start bit interrupt request flag
      // receive now what our rival is sending
      sbi(LN_SB_INT_ENABLE_REG, LN_SB_INT_ENABLE_BIT);
      sei();
      return LN_NETWORK_BUSY;
   }

   LN_SW_UART_SET_TX_LOW
      // Begin the Start Bit
      // Get the Current Timer1 Count and Add the offset for the Compare target
      // added adjustment value for bugfix (Olaf Funke)
      lnCompareTarget = LN_TMR_COUNT_REG + LN_TIMER_TX_RELOAD_PERIOD - LN_TIMER_TX_RELOAD_ADJUST;
   LN_TMR_OUTP_CAPT_REG = lnCompareTarget;

   sei();

   lnTxData = TxData;
   lnTxIndex = 0;
   lnTxSuccess = 0;

   // Load the first Byte
   lnCurrentByte = TxData->data[0];

   // Set the State to Transmit
   lnState = LN_ST_TX;

   // Reset the bit counter
   lnBitCount = 0;

   // Clear the current Compare interrupt status bit and enable the Compare interrupt
   sbi(LN_TMR_INT_STATUS_REG, LN_TMR_INT_STATUS_BIT);
   sbi(LN_TMR_INT_ENABLE_REG, LN_TMR_INT_ENABLE_BIT);

   // now busy waiting until the interrupts did the rest
   while (lnState == LN_ST_TX)
   {
   }

   if (lnTxSuccess)
   {
      lnRxBuffer->Stats.TxPackets++;
      return LN_DONE;
   }

   if (lnState == LN_ST_TX_COLLISION)
   {
      return LN_COLLISION;
   }

   // everything else is an error
   return LN_UNKNOWN_ERROR;
}
