//
// CANCMD Programmer/Command Station (C) 2009 SPROG DCC
//	web:	http://www.sprog-dcc.co.uk
//	e-mail:	sprog@sprog-dcc.co.uk
//
//   Mod by Mike B for PORTC,6 up at start of ISR and down at end.
//	Pete Brownlow	27/6/11 - Change heartbeat to half second so can use for beep control and transmit timeouts as well
//							  Output bridge enable turned off during overload retry wait and when
//							  service programming track is turned off

#include "project.h"

//
// DCC bit state machine macros
//
#define FIRST_EDGE 0
#define SECOND_EDGE_BIT1 1
#define SECOND_MIDPOINT_BIT0 2
#define SECOND_EDGE_BIT0 3
#define FIRST_MIDPOINT_BIT0 4
#define SECOND_IDLE 5
#define FIRST_IDLE 6
#define SECOND_PRE 7
#define FIRST_PRE 8
#define SECOND_MID_START 9
#define SECOND_START 10
#define FIRST_MID_START 11
#define FIRST_START 12

//
// ADC state machine macros
//
#define AD_RESET 0
#define ACQ_AN0 1
#define CONV_AN0 2
#define ACQ_AN4 3
#define CONV_AN4 4

#pragma udata ISR_VARS

unsigned short an0;
unsigned short retry_delay;
unsigned short ave;
unsigned short sum;

#pragma udata access VARS

unsigned near char bit_flag_s;
unsigned near char bit_flag_m;
unsigned near char next_byte_s;
unsigned near char pre_cnt_s;
unsigned near char byte_cnt_s;
unsigned near char next_byte_m;
unsigned near char pre_cnt_m;
unsigned near char byte_cnt_m;

unsigned near char dcc_pre_s;
unsigned near char dcc_bits_s;
unsigned near char dcc_bits_m;
unsigned near char dcc_bytes_s;
unsigned near char dcc_bytes_m;

near unsigned char dcc_idx_s;
near unsigned char dcc_idx_m;

near unsigned short long slot_timer;

near unsigned char awd_count;

#define dcc_pre_m   14

//
// toggle_dcc()
//
// Called from ISR to toggle the internal DCC value.
//
#define toggle_dcc_s() op_flags.op_bit_s=!op_flags.op_bit_s
#define toggle_dcc_m() op_flags.op_bit_m=!op_flags.op_bit_m

#pragma code APP

//
// Interrupt Service Routine
//
// TMR0 generates a heartbeat every 58uS to generate timing for the DCC bit
// stream. If no DCC packet to be transmitted then preamble is generated.
//
// One bit half cycle is 58usec. Zero bit half cycle is 116usec.
//
// A/D readings are stored in RAM.
//
#pragma interrupt isr_high
void isr_high(void) {
    // 13 clocks to get here after interrupt
	ISR_PIN = 1;		// flag start of ISR
    INTCONbits.T0IF = 0;
    TMR0L = tmr0_reload;

    //
    // TMR0 is enabled all the time and we send a continuous preamble
    // as required for booster operation. The power may, however, be off
    // resulting in no actual DCC ooutput
    //
    // Outputs are toggled here to set the output to the state
    // determined during the previous interrupt. This ensures the output
    // always toggles at the same time relative to the interrupt, regardless
    // of the route taken through the switch() statement for bit generation.
    //
    // This hardware does not use MOSFETs and does not need shoot-through
    // protection delay
    //

    if (SWAP_OP == 1) {
        // J7 is out
        // On-board booster is service mode output
        if (op_flags.op_pwr_s) {
			DCC_EN = 1;
            if (op_flags.op_bit_s) {
                DCC_NEG = 0;
                DCC_POS = 1;
            } else {
                DCC_POS = 0;
                DCC_NEG = 1;
            }
        } else {
			DCC_EN = 0;
            DCC_POS = 0;
            DCC_NEG = 0;
        }
        // Main track output is main track output
        if (op_flags.op_pwr_m) {
            DCC_OUT = op_flags.op_bit_m;
        }
    } else {
        // J7 is in
        // On board booster is main track output
        if (op_flags.op_pwr_m) {
			DCC_EN = 1;
            if (op_flags.op_bit_m) {
                DCC_NEG = 0;
                DCC_POS = 1;
            } else {
                DCC_POS = 0;
                DCC_NEG = 1;
            }
        } else {
			DCC_EN = 0;
            DCC_POS = 0;
            DCC_NEG = 0;
        }
        // Main track output is service mode packets
        if (op_flags.op_pwr_s) {
            DCC_OUT = op_flags.op_bit_s;
        }
    }

    // Power LEDs
    if (SWAP_OP == 1) {
        // J7 is out
        // On-board booster is service mode output
        // LED1 flashes during programming
        if (op_flags.op_pwr_s) {
            LED1 = 1;
        } else {
            LED1 = 0;
        }
    } else {
        // J7 is in
        // On board booster is main track output
        // LED2 normall on, off during overload
        if (op_flags.op_pwr_m) {
            LED1 = 1;
        } else {
            LED1 = 0;
        }
   }
    
    LED2 = 1;

    // AWD drive signal
    if (retry_delay > 0) {
        AWD = 1;
    } else {
        AWD = op_flags.beeping;
    }

    
    // In case mode is changed on the fly, we don't check for ack
    // when on board booster is main track output
    if (SWAP_OP == 0) {
        dcc_flags.dcc_check_ack = 0;
       // ACK_PIN = 0;
    }

    //
    // Slot timeout and other timers - every half second
    //
    if (--slot_timer == 0) {
        slot_timer = ((short long)500000)/58;
        op_flags.slot_timer = 1;

		if (can_transmit_timeout != 0) {
			--can_transmit_timeout;
		}
    }


    // Determine next service mode track DCC output bit
    switch(bit_flag_s) {
        case FIRST_EDGE:
            toggle_dcc_s();
            // test for a 1 or 0 to transmit
            bit_flag_s = ((next_byte_s & 0x80) == 0x80) ? SECOND_EDGE_BIT1 : FIRST_MIDPOINT_BIT0;
            break;

        case SECOND_EDGE_BIT1:
            toggle_dcc_s();
            // fall through to next_bit

        case SECOND_MIDPOINT_BIT0:
            bit_flag_s = FIRST_EDGE;			// likely to be first edge next
            next_byte_s = next_byte_s << 1;		// Rotate DCC data byte for next bit
            dcc_bits_s--;
            if (dcc_bits_s != 0) {
                break;
            }
            dcc_idx_s++;		                    // all bits done so point to next byte
            next_byte_s = dcc_buff_s[dcc_idx_s];
            dcc_bits_s = 8;		                // reload bit counter
            byte_cnt_s--;
            if (byte_cnt_s == 0) {
                dcc_buff_s[6]--;                  // no more bytes, more packets?
                if ((dcc_buff_s[6] == 0)
                    || ((dcc_flags.dcc_rec_time == 0) && (dcc_flags.dcc_ack == 1))) {
                    bit_flag_s = FIRST_IDLE;		// no more packets or ack received
                                                    // and not recovery time
                    dcc_flags.dcc_rdy_s = 1;		// buffer free
                } else {
                    bit_flag_s = FIRST_PRE;       // do another packet
                    dcc_idx_s = 0;			    // reset pointer
                    next_byte_s = dcc_buff_s[dcc_idx_s];
                    pre_cnt_s = dcc_pre_s;
                    byte_cnt_s = dcc_bytes_s;
                    dcc_bits_s = 8;               // and bit count
                }
            } else {
                bit_flag_s = FIRST_START;		    // start another byte
            }
            break;

        case SECOND_EDGE_BIT0:
            toggle_dcc_s();
            bit_flag_s = SECOND_MIDPOINT_BIT0;
            break;

        case FIRST_MIDPOINT_BIT0:
            bit_flag_s = SECOND_EDGE_BIT0;
            break;

        case SECOND_IDLE:
            toggle_dcc_s();
            bit_flag_s = FIRST_IDLE;
            // test for new packet
            if (dcc_flags.dcc_rdy_s == 0) {
                bit_flag_s = FIRST_PRE;
                dcc_idx_s = 0;			    // set up pointer
                next_byte_s = dcc_buff_s[dcc_idx_s];
                pre_cnt_s = dcc_pre_s;
                byte_cnt_s = dcc_bytes_s;
                dcc_bits_s = 8;
            }
            break;

        case FIRST_IDLE:
            toggle_dcc_s();
            bit_flag_s = SECOND_IDLE;
            break;

        case SECOND_PRE:
            toggle_dcc_s();
            // check if ready for start bit
            pre_cnt_s--;
            if (pre_cnt_s == 0) {
                bit_flag_s = FIRST_START;
            } else {
                bit_flag_s = FIRST_PRE;
            }
            break;

        case FIRST_PRE:
            // Could keep track of how many preamble bits have been sent with power on
            // but for now we assume we are starting from scratch
            toggle_dcc_s();
            bit_flag_s = SECOND_PRE;
            break;

        case SECOND_MID_START:
            bit_flag_s = FIRST_EDGE;
            break;

        case SECOND_START:
            toggle_dcc_s();
            bit_flag_s = SECOND_MID_START;
            break;

        case FIRST_MID_START:
            bit_flag_s = SECOND_START;
            break;

        case FIRST_START:
        default:
            toggle_dcc_s();
            bit_flag_s = FIRST_MID_START;
            break;
    }

    //
    // Determine next main track DCC output bit
    //
    switch(bit_flag_m) {
        case FIRST_EDGE:
            toggle_dcc_m();
            // test for a 1 or 0 to transmit
            bit_flag_m = ((next_byte_m & 0x80) == 0x80) ? SECOND_EDGE_BIT1 : FIRST_MIDPOINT_BIT0;
            break;

        case SECOND_EDGE_BIT1:
            toggle_dcc_m();
            // fall through to next_bit

        case SECOND_MIDPOINT_BIT0:
            bit_flag_m = FIRST_EDGE;			// likely to be first edge next
            next_byte_m = next_byte_m << 1;		// Rotate DCC data byte for next bit
            dcc_bits_m--;
            if (dcc_bits_m != 0) {
                break;
            }
			
			if (dcc_idx_m == 0) {
              DCC_PKT_PIN = 1;					// Spare output pin for sync scope on start of packet
   			}
			         
            dcc_idx_m++;		                    // all bits done so point to next byte
            next_byte_m = dcc_buff_m[dcc_idx_m];
            dcc_bits_m = 8;		                // reload bit counter
            byte_cnt_m--;
            if (byte_cnt_m == 0) {
				DCC_PKT_PIN = 0;
                dcc_buff_m[6]--;                  // no more bytes, more packets?
                if ((dcc_buff_m[6] == 0)) {
                    bit_flag_m = FIRST_IDLE;		// no more packets
                    dcc_flags.dcc_rdy_m = 1;		// buffer free
                } else {
                    bit_flag_m = FIRST_PRE;       // do another packet
                    dcc_idx_m = 0;			    // reset pointer
                    next_byte_m = dcc_buff_m[dcc_idx_m];
                    pre_cnt_m = dcc_pre_m;
                    byte_cnt_m = dcc_bytes_m;
                    dcc_bits_m = 8;               // and bit count
                }
            } else {
                bit_flag_m = FIRST_START;		    // start another byte
            }
            break;

        case SECOND_EDGE_BIT0:
            toggle_dcc_m();
            bit_flag_m = SECOND_MIDPOINT_BIT0;
            break;

        case FIRST_MIDPOINT_BIT0:
            bit_flag_m = SECOND_EDGE_BIT0;
            break;

        case SECOND_IDLE:
            toggle_dcc_m();
            bit_flag_m = FIRST_IDLE;
            // test for new packet
            if (dcc_flags.dcc_rdy_m == 0) {
                bit_flag_m = FIRST_PRE;
                dcc_idx_m = 0;			    // set up pointer
                next_byte_m = dcc_buff_m[dcc_idx_m];
                pre_cnt_m = dcc_pre_m;
                byte_cnt_m = dcc_bytes_m;
                dcc_bits_m = 8;
            }
            break;

        case FIRST_IDLE:
            toggle_dcc_m();
            bit_flag_m = SECOND_IDLE;
            break;

        case SECOND_PRE:
            toggle_dcc_m();
            // check if ready for start bit
            pre_cnt_m--;
            if (pre_cnt_m == 0) {
                bit_flag_m = FIRST_START;
            } else {
                bit_flag_m = FIRST_PRE;
            }
            break;

        case FIRST_PRE:
            // Could keep track of how many preamble bits have been sent with power on
            // but for now we assume we are starting from scratch
            toggle_dcc_m();
            bit_flag_m = SECOND_PRE;
            break;

        case SECOND_MID_START:
            bit_flag_m = FIRST_EDGE;
            break;

        case SECOND_START:
            toggle_dcc_m();
            bit_flag_m = SECOND_MID_START;
            break;

        case FIRST_MID_START:
            bit_flag_m = SECOND_START;
            break;

        case FIRST_START:
        default:
            toggle_dcc_m();
            bit_flag_m = FIRST_MID_START;
            break;
    }

    //
    // service_ad
    //
    // Acquisition time is within one DCC half bit period (58us).
    //
    // Conversion time is 11 * Tad. Tad is Tosc*64 or 2.66us at 24MHz. So,
    // conversion time is also within one DCC half bit period.
    //
    // one state covers aquisition time, a second state the conversion time.
    // Historic code converts two channels even though we only use the value
    // from the current shunt) so
    // the sample period for each channel is 58us *2 *2 = 232us.
    //
    // Current sense samples on channel 4 are averaged over four sample
    // periods.
    //
    // If a potential overload condition is sensed, a timer is started to
    // check gain after 130 cycles or approx 30ms. If the overload is still present
    // in programming mode then DCC_FLAGS, DCC_OVERLOAD is set.
    //
    switch(ad_state) {
        case AD_RESET:		// 0
            ad_state = ACQ_AN0;
            break;

        case ACQ_AN0:
            ad_state = CONV_AN0;
            ADCON0bits.GO = 1;
            break;

        case CONV_AN0:
            if (ADCON0bits.GO == 0) {
                an0 = ((unsigned int)ADRESH<<8) | ADRESL;
                // Averaging function used for current sense is
                // S(t) = S(t-1) - [S(t-1)/N] + VIN
                // A(t) = S(t)/N
                //
                // where S is an accumulator, N is the length of the filter (i.e.,
                // the number of samples included in the rolling average), and A is
                // the result of the averaging function.
                // The time constant of the averaging equation is given by t = N/FS,
                // where N is again the length of the filter and FS is the sampling
                // frequency.
                //
                // Re-arranged for N=4:
                // S(t) = S(t-1) - A(t-1) + Vin
                // A(t) = S(t)/4
                sum = sum - ave;            // S(t) = S(t-1) - A(t-1)
                sum = sum + an0;            // S(t) = S(t-1) - A(t-1) + Vin
                ave = sum>>2;               // A(t) = S(t)/4
                ADCON0 = 0b00000001;		// select channel 0
                ad_state = ACQ_AN4;

                // Are we waiting for retry delay?
                if (retry_delay == 0) {
                    // No, have we had a potential overload?
                    if (ovld_delay == 0) {
                        // No, do normal checks
                        if (dcc_flags.dcc_check_ack == 1) {
                            // has current increased, denoting ACK?
                            if (ave >= (short)(iccq + I_ACK_DIFF)) {
                                dcc_flags.dcc_ack = 1;
							//	ACK_PIN = 1;
                            }
                        } else {
                            // check for dead short immediately
                            // current is limited by LM317
                            if ((short)I_LIMIT > an0) {
                                // not dead short, look for overload
                                if ((dcc_flags.dcc_check_ovld == 1)
                                    || (SWAP_OP == 0)) {         // low power booster mode
                                    if (ave >= (short)imax) {
                                        ovld_delay = 130;         // 130*232us = 30160us delay
                                    }
                                }
                            } else {
                                // Dead short - shutdown immediately
								OVERLOAD_PIN = 1;
                                if (SWAP_OP == 1) {
                                    // programming mode so react immediately
                                    op_flags.op_pwr_s = 0;
                                    dcc_flags.dcc_overload = 1;
                                    dcc_flags.dcc_check_ovld = 0;
                                } else {
                                    // low power booster mode start retry delay
                                    op_flags.op_pwr_m = 0;
                                    retry_delay = 9 * 256;          // 9 * 256 * 232us ~ 535ms
                                }
                            }
                        }
                    } else {
                        // countdown overload delay
                        ovld_delay--;
                        if (ovld_delay == 0) {
                            // Check again
                            if (ave >= (short)imax) {
                                // still overload so power off
								OVERLOAD_PIN = 1;				// Set spare output pin for scope monitoring
                                if (SWAP_OP == 1) {
                                    // programming mode so react immediately
                                    op_flags.op_pwr_s = 0;
                                    dcc_flags.dcc_overload = 1;
                                    dcc_flags.dcc_check_ovld = 0;
                                } else {
                                    // low power booster mode restart retry delay
                                    op_flags.op_pwr_m = 0;
                                    retry_delay = 9 * 256;          // 9 * 256 * 232us ~ 535ms
                                }
                            }
                        }
                    }
                } else {
                    // countdown retry delay
                    retry_delay--;
                    if (retry_delay == 0) {
                       // Request power on again
                       dcc_flags.dcc_retry = 1;
					   OVERLOAD_PIN = 0;	
                    }
                }
            }
            break;

        case ACQ_AN4:
            ad_state = CONV_AN4;
            break;

        case CONV_AN4:
            ad_state = ACQ_AN0;
            break;

        default:
            break;
    }

	ISR_PIN = 0;   // end of ISR
}
