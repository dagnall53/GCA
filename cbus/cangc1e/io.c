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



#include <p18cxxx.h>
#include <stdio.h>

#include "project.h"
#include "canbus.h"
#include "utils.h"
#include "cbusdefs.h"
#include "cangc1e.h"
#include "io.h"

void setupIO(byte clr) {
  int idx = 0;

  // all digital I/O
  ADCON0 = 0x00;
  ADCON1 = 0x0F;

  TRISCbits.TRISC0 = 0; /* LED1 */
  TRISCbits.TRISC1 = 0; /* LED2 */
  TRISCbits.TRISC2 = 0; /* LED3 */
  TRISAbits.TRISA0 = 1; /* SW */
  TRISCbits.TRISC6 = 1; /* JP2 */

  // Enable internal pull-ups.
  INTCON2bits.RBPU = 0;

  LED1 = LED_OFF;
  LED2 = LED_OFF;
  LED3 = LED_OFF;


  // following presets are written to eeprom if the flim switch is preshed at boot


}

void writeOutput(int idx, unsigned char val) {
}

unsigned char readInput(int idx) {
  unsigned char val = 0;
  return !val;
}

// Called every 3ms.

void doLEDTimers(void) {
  if (led1timer > 0) {
    led1timer--;
    if (led1timer == 0) {
      LED1 = LED_OFF;
    }
  }

  if (led2timer > 0) {
    led2timer--;
    if (led2timer == 0) {
      LED2 = LED_OFF;
    }
  }

  if (led3timer > 0) {
    led3timer--;
    if (led3timer == 0) {
      LED3 = LED_ON;
    }
  }

  if (Wait4NN) {
    return;
  }
}

void doIOTimers(void) {
  int i = 0;
}

void doTimedOff(int i) {
}

unsigned char checkFlimSwitch(void) {
  unsigned char val = SW;
  return !val;
}

unsigned char checkInput(unsigned char idx) {
  unsigned char ok = 1;
  return ok;
}

void saveOutputStates(void) {
  int idx = 0;
  byte o1 = 0;
  byte o2 = 0;

  //eeWrite(EE_PORTSTAT + 1, o2);


}



static unsigned char __LED3 = 0;

void doLEDs(void) {
  if (Wait4NN || isLearning) {
    LED3 = __LED3;
    __LED3 ^= 1;
    led3timer = 20;
  }
}

void setOutput(ushort nn, ushort addr, byte on) {
}
