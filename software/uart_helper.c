#include "uart_helper.h"
#include "xil_printf.h"

XUartPs_Config *uart_init(XUartPs *inst, u32 base_addr)
{
	XUartPs_Config *cfg = XUartPs_LookupConfig(base_addr);
	XUartPs_CfgInitialize(inst, cfg, cfg->BaseAddress);
	XUartPs_EnableUart(inst);
	return cfg;
}

void uart_send_byte(XUartPs *inst, u8 b)
{
	while (!XUartPs_IsTransmitEmpty(inst)) { }
	XUartPs_Send(inst, &b, 1);
}

void uart_send_str(XUartPs *inst, const char *s)
{
	while (*s)
		uart_send_byte(inst, (u8)(*s++));
}

void uart_recv_buf(XUartPs_Config *cfg, u8 *buf, unsigned int len)
{
	unsigned int i;
	for (i = 0; i < len; i++)
		buf[i] = XUartPs_RecvByte(cfg->BaseAddress);
}

unsigned int uart_recv_field(XUartPs_Config *cfg, u8 *buf, unsigned int buf_max)
{
	u8 hdr[2];
	unsigned int field_len;

	uart_recv_buf(cfg, hdr, 2);
	field_len = ((unsigned int)hdr[0] << 8) | hdr[1];

	if (field_len == 0)
		return 0;  /* sentinel: host signals no more cases */

	if (field_len > buf_max) {
		xil_printf("ERROR: field too large (%u > %u)\r\n", field_len, buf_max);
		return 0;
	}

	uart_recv_buf(cfg, buf, field_len);
	return field_len;
}
