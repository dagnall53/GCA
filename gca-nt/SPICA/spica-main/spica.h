/*
 Rocrail - Model Railroad Software

 Copyright (C) 2002-2012 Rob Versluis, Rocrail.net

 Without an official permission commercial use is not permitted.
 Forking this project is not permitted.

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/


#ifndef __SPICA_H
#define __SPICA_H

#include <p18f2585.h>

#define byte unsigned char

#define FIXED_CAN_ID 0x72
#define DEFAULT_NN 	0xFFFE
#define MAJOR_VER 	1
#define MINOR_VER 	0	// Minor version character

#define NV_NUM		0	// Number of node variables
#define EVT_NUM		0	// Number of event variables
#define EVperEVT	0	// Event variables per event


extern near unsigned char Latcount;
extern near unsigned char ledBUStimer;
extern near unsigned char Wait4NN;
extern near unsigned char isLearning;



#endif
