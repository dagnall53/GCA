/*
 Copyright (C) MERG CBUS

 Rocrail - Model Railroad Software

 Copyright (C) Rob Versluis <r.j.versluis@rocrail.net>

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 3
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/


#include "project.h"
#include "isr.h"
#include "cangc7.h"
#include "io.h"

#pragma udata access VARS
near unsigned short led500ms_timer;
near unsigned short io_timer;
near unsigned short led_timer;
near unsigned short dim_timer;

#pragma code APP

//
// Interrupt Service Routine
//
// TMR0 generates a heartbeat every 250uS.
//
#pragma interrupt isr_high
void isr_high(void) {
    INTCONbits.T0IF = 0;
    TMR0L = tmr0_reload;


    //
    // I/O timeout - 3ms
    //
    if (dim_timer > 0 && --dim_timer == 0) {
      byte dispOFF = pos_display ? DISPLAY_OFF:DISPLAY_ON;
      DIS1 = dispOFF;
      DIS2 = dispOFF;
      DIS3 = dispOFF;
      DIS4 = dispOFF;
      DIS5 = dispOFF;
      DIS6 = dispOFF;
    }

    //
    // I/O timeout - 3ms
    //
    if (--led_timer == 0) {
      led_timer = 12;
      doLEDTimers();
      dim_timer = NV1 & CFG_DISPDIM;
      if( dim_timer == 0 )
        dim_timer++;
    }

    //
    // I/O timeout - 50ms
    //
    if (--io_timer == 0) {
      io_timer = 200;
      doIOTimers();

      if (can_transmit_timeout != 0) {
        --can_transmit_timeout;
      }
    }

    //
    // Timer 500ms
    //
    if (--led500ms_timer == 0) {
        led500ms_timer = 2000;
        doLEDs();
    }

}


//
// Low priority interrupt. Used for CAN receive.
//
#pragma interruptlow isr_low
void isr_low(void) {
  //LED2 = 1;

  if (PIR3bits.ERRIF == 1) {

    if (TXB1CONbits.TXLARB) { // lost arbitration
      if (Latcount == 0) { // already tried higher priority
        can_transmit_failed = 1;
        TXB1CONbits.TXREQ = 0;
      } else if (--Latcount == 0) { // Allow tries at lower level priority first
        TXB1CONbits.TXREQ = 0;
        Tx1[sidh] &= 0b00111111; // change priority
        TXB1CONbits.TXREQ = 1; // try again
      }
    }

    if (TXB1CONbits.TXERR) { // bus error
      can_transmit_failed = 1;
      TXB1CONbits.TXREQ = 0;
    }

  }

  PIR3 = 0; // clear interrupts
}
