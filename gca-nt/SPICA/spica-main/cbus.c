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


#include <string.h>
#include "spica.h"
#include "cbus.h"
#include "cbusdefs.h"
#include "io.h"


ram CANMsg CANMsgs[CANMSG_QSIZE];
ram CANMsg canmsg;

#pragma romdata EEPROM
// Ensure newly programmed part is in virgin state
rom unsigned char status = 0;
rom unsigned short nodeID = 0;

#pragma code APP

/*
 * Common CBUS CAN setup
 */
void cbusSetup(void) {
  int i = 0;
  CANCON = 0b10000000; // CAN to config mode
  while (CANSTATbits.OPMODE2 == 0)
    // Wait for config mode
    ;
  // Want ECAN mode 2 with FIFO
  ECANCON = 0b10110000; // FIFOWM = 1 (one entry)
  // EWIN default
  BSEL0 = 0; // All buffers to receive so
  // FIFO is 8 deep
  RXB0CON = 0b00000000; // receive valid messages

/*
  In PICs ist 125Kbps mit folgender Einstellung bereitzustellen:

16MHz:
-------------
BRGCON1: 0x03
BRGCON2: 0xDE
BRGCON3: 0x03
*/
  /*
   * Baud rate setting.
   * Sync segment is fixed at 1 Tq
   * Total bit time is Sync + prop + phase 1 + phase 2
   * or 16 * Tq in our case
   * So, for 125kbits/s, bit time = 8us, we need Tq = 500ns
   * Fosc is 32MHz (8MHz + PLL), Tosc is 31.25ns, so we need 1:16 prescaler
   */

  // prescaler Tq = 16/Fosc
  BRGCON1 = 0b00000111; // 8MHz resonator
  //BRGCON1 = 0b00000011; // 4MHz resonator
  // freely programmable, sample once, phase 1 = 4xTq, prop time = 7xTq
  BRGCON2 = 0b10011110;
  // Wake-up enabled, wake-up filter not used, phase 2 = 4xTq
  BRGCON3 = 0b00000011;
  // TX drives Vdd when recessive, CAN capture to CCP1 disabled
  CIOCON = 0b00100000;

  RXFCON0 = 1; // Only filter 0 enabled
  RXFCON1 = 0;
  SDFLC = 0;

  // Setup masks so all filter bits are ignored apart from EXIDEN
  RXM0SIDH = 0;
  RXM0SIDL = 0x08;
  RXM0EIDH = 0;
  RXM0EIDL = 0;
  RXM1SIDH = 0;
  RXM1SIDL = 0x08;
  RXM1EIDH = 0;
  RXM1EIDL = 0;

  // Set filter 0 for standard ID only to reject bootloader messages
  RXF0SIDL = 0x80;

  // Link all filters to RXB0 - maybe only neccessary to link 1
  RXFBCON0 = 0;
  RXFBCON1 = 0;
  RXFBCON2 = 0;
  RXFBCON3 = 0;
  RXFBCON4 = 0;
  RXFBCON5 = 0;
  RXFBCON6 = 0;
  RXFBCON7 = 0;

  // Link all filters to mask 0
  MSEL0 = 0;
  MSEL1 = 0;
  MSEL2 = 0;
  MSEL3 = 0;

  BIE0  = 0; // No Rx buffer interrupts - assume FIFOWM will interrupt
  TXBIE = 0; // No Tx buffer interrupts

  // Clear RXFUL bits
  RXB0CON = 0;
  RXB1CON = 0;
  B0CON = 0;
  B1CON = 0;
  B2CON = 0;
  B3CON = 0;
  B4CON = 0;
  B5CON = 0;

  CANCON = 0; // Out of CAN setup mode

  for( i = 0; i < CANMSG_QSIZE; i++ ) {
    CANMsgs[i].status = CANMSG_FREE;
  }
}

#pragma udata access VARS_CAN
// Transmit buffers
near unsigned char Tx1[14];


#pragma udata
ecan_rx_buffer * rx_ptr;


//#pragma code CAN

//
// ecan_fifo_empty()
//
// Check if ECAN FIFO has a valid receive buffer available and
// preload the pointer to it
//

unsigned char fifoEmpty(void) {
  switch (CANCON & 0b00000111) {
    case 0:
      rx_ptr = (ecan_rx_buffer *) & RXB0CON;
      break;

    case 1:
      rx_ptr = (ecan_rx_buffer *) & RXB1CON;
      break;

    default:
      // Remaining buffers are 16 bytes long starting at
      // pointer value 2
      rx_ptr = (ecan_rx_buffer *) (&B0CON + (((CANCON - 2) & 0b00000111) << 4));
      break;

  }

  if (rx_ptr->con & 0x80) {
    // current buffer is not empty
    return 0;
  } else {
    return 1;
  }
}


byte canQueue(CANMsg* msg) {
  int i = 0;
  int n = 0;
  for( i = 0; i < CANMSG_QSIZE; i++ ) {
    if( CANMsgs[i].status == CANMSG_FREE ) {
      memcpy(&CANMsgs[i], (const void*)msg, sizeof(CANMsg));
      CANMsgs[i].status = CANMSG_OPEN;
      //LED2 = PORT_OFF;
      return 1;
    }
  }
  //LED2 = PORT_ON;
  return 0;
}



void canTxQ(CANMsg* msg) {
	unsigned char tx_idx;
	unsigned char *ptr_fsr1;
	unsigned char i;

  Tx1[dlc] = msg->len + 1;	// data length + opc
	Tx1[sidh] &= 0b00001111;	// clear old priority
	Tx1[sidh] |= 0b10110000;	// low priority
  Tx1[d0] = msg->opc;
  Tx1[d1] = msg->d[0];
  Tx1[d2] = msg->d[1];
  Tx1[d3] = msg->d[2];
  Tx1[d4] = msg->d[3];
  Tx1[d5] = msg->d[4];
  Tx1[d6] = msg->d[5];
  Tx1[d7] = msg->d[6];
	Latcount = 10;

  LED4_BUS = PORT_ON;
  ledBUStimer = 20;

  tx_idx = 0;
  ptr_fsr1 = &TXB1CON;
  for( i = 0; i < 14; i++ ) {
    *(ptr_fsr1++) = Tx1[tx_idx++];
  }

  TXB1CONbits.TXREQ = 1;
}


void canSendQ(void) {
  if( TXB1CONbits.TXREQ == 0 ) {
    int i;
    for( i = 0; i < CANMSG_QSIZE; i++ ) {
      if( CANMsgs[i].status == CANMSG_PENDING )
        CANMsgs[i].status = CANMSG_FREE;
    }
    for( i = 0; i < CANMSG_QSIZE; i++ ) {
      if( CANMsgs[i].status == CANMSG_OPEN ) {
        CANMsgs[i].status = CANMSG_PENDING;
        canTxQ(&CANMsgs[i]);
        break;
      }
    }
  }
}



