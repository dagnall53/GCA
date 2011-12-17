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

#include "cbus.h"
#include "utils.h"
#include "cbusdefs.h"
#include "cangc6.h"
#include "io.h"

static byte pos_bcd[] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};
static byte neg_bcd[] = {0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90};

static byte pos_wd[] = {0x00, 0x01, 0x20, 0x02, 0x10, 0x40, 0x04, 0x08};
static byte neg_wd[] = {0xFF, 0xFE, 0xDF, 0xFD, 0xEF, 0xBF, 0xFB, 0xF7};


static byte pos_Dash = 0x40;
static byte neg_Dash = 0xBF;

static byte pos_H = 0x76;
static byte pos_E = 0x79;
static byte pos_L = 0x38;
static byte pos_P = 0x73;

static byte neg_H = 0x89;
static byte neg_E = 0x86;
static byte neg_L = 0xC7;
static byte neg_P = 0x8C;

static int showdate_timer = 0;

void setupIO(byte clr) {
  int idx = 0;

  // all digital I/O
  ADCON0 = 0x00;
  ADCON1 = 0x0F;

  TRISCbits.TRISC0 = 1; /* T1S */
  TRISCbits.TRISC1 = 1; /* T1R */
  TRISCbits.TRISC2 = 1; /* T2S */
  TRISCbits.TRISC3 = 1; /* T2R */
  TRISCbits.TRISC4 = 1; /* T3S */
  TRISCbits.TRISC5 = 1; /* T3R */
  TRISCbits.TRISC6 = 1; /* T4S */
  TRISCbits.TRISC7 = 1; /* T4R */

  TRISAbits.TRISA1 = 1; /* SW */
  TRISAbits.TRISA2 = 0; /* GCA137 */
  TRISAbits.TRISA3 = 0; /* LED1 */
  TRISAbits.TRISA4 = 0; /* LED2 */
  TRISAbits.TRISA5 = 0; /* LED3 */

  TRISBbits.TRISB0 = 0; /* SERVO1 */
  TRISBbits.TRISB1 = 0; /* SERVO2 */
  TRISBbits.TRISB4 = 0; /* SERVO3 */
  TRISBbits.TRISB5 = 0; /* SERVO4 */

  GCA137 = PORT_OFF;
  LED1   = PORT_OFF;
  LED2   = PORT_OFF;
  LED3   = PORT_OFF;
  SERVO1 = PORT_OFF;
  SERVO2 = PORT_OFF;
  SERVO3 = PORT_OFF;
  SERVO4 = PORT_OFF;

  for( idx = 0; idx < 4; idx++ ) {
    Servo[idx].config   = eeRead(EE_SERVO_CONFIG + idx);
    Servo[idx].left     = eeRead(EE_SERVO_LEFT + idx);
    Servo[idx].right    = eeRead(EE_SERVO_RIGHT + idx);
    Servo[idx].speed    = eeRead(EE_SERVO_SPEED + idx);
    Servo[idx].position = eeRead(EE_SERVO_POSITION + idx);
    Servo[idx].fbnn     = eeReadShort(EE_SERVO_FBNN + 2 * idx);
    Servo[idx].fbevent  = eeReadShort(EE_SERVO_FBEVENT + 2 * idx);
    Servo[idx].swnn     = eeReadShort(EE_SERVO_SWNN + 2 * idx);
    Servo[idx].swevent  = eeReadShort(EE_SERVO_SWEVENT + 2 * idx);
  }

}


void writeOutput(int idx, unsigned char val) {
}

unsigned char readInput(int idx) {
  unsigned char val = 0;
  return !val;
}


// Called every 3ms.
void doLEDTimers(void) {
  if( led1timer > 0 ) {
    led1timer--;
    if( led1timer == 0 ) {
      LED1 = 0;
    }
  }

}

void doIOTimers(void) {
}

void doTimedOff(int i) {
}


unsigned char checkFlimSwitch(void) {
  unsigned char val = SW;
  return !val;
}

unsigned char checkInput(unsigned char idx, unsigned char sod) {
  unsigned char ok = 1;
  if( sod ) {
    canmsg.opc = Servo[idx].position ? OPC_ASON:OPC_ASOF;
    if( canmsg.opc > 0 ) {
      canmsg.d[0] = (NN_temp / 256) & 0xFF;
      canmsg.d[1] = (NN_temp % 256) & 0xFF;
      canmsg.d[2] = (Servo[idx].fbevent / 256) & 0xFF;
      canmsg.d[3] = (Servo[idx].fbevent % 256) & 0xFF;
      canmsg.len = 4; // data bytes
    }
    ok = canQueue(&canmsg);
  }
  return ok;
}



void saveOutputStates(void) {
  int idx = 0;  
  for( idx = 0; idx < 4; idx++ ) {
    eeWrite(EE_SERVO_POSITION + idx, Servo[idx].position);
  }

}



void restoreOutputStates(void) {
  int idx = 0;

}



void doLEDs(void) {
}

byte getPortStates(int group) {
}


void setOutput(ushort nn, ushort addr, byte on) {
  int i = 0;
}
