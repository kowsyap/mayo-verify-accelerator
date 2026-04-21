#ifndef UART_HELPER_H
#define UART_HELPER_H

#include "xuartps_hw.h"
#include "xuartps.h"

/*
 * Initialise the XUartPs instance.
 * Must be called once before any other uart_* function.
 * Returns the XUartPs_Config pointer needed by uart_recv_field / uart_recv_buf.
 */
XUartPs_Config *uart_init(XUartPs *inst, u32 base_addr);

/* Send a single byte (polls TX-empty before writing). */
void uart_send_byte(XUartPs *inst, u8 b);

/* Send a null-terminated string. */
void uart_send_str(XUartPs *inst, const char *s);

/*
 * Receive exactly `len` bytes into buf (blocking).
 */
void uart_recv_buf(XUartPs_Config *cfg, u8 *buf, unsigned int len);

/*
 * Receive a length-prefixed field: [2-byte big-endian length][payload].
 * Returns number of bytes received.
 * Returns 0 if the host sends a zero-length header (end-of-cases sentinel)
 * or if the field exceeds buf_max.
 */
unsigned int uart_recv_field(XUartPs_Config *cfg, u8 *buf, unsigned int buf_max);

#endif /* UART_HELPER_H */
