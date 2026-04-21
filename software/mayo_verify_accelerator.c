#include "xparameters.h"
#include "xil_util.h"
#include "dma_helper.h"
#include "uart_helper.h"
#include "mayo_ctrl.h"
#include "mayo_helper.h"
#include <string.h>

/******************** Constant Definitions **********************************/

#define POLL_TIMEOUT_COUNTER	1000000U
#define NUMBER_OF_EVENTS	1

/* ---- Round selection ---- */
#define MAYO_ROUND  1

#if MAYO_ROUND == 1
  #define MAYO_PARAMS   MAYO_R1_2
#else
  #define MAYO_PARAMS   MAYO_R2_2
#endif

#define MSG_BUF_MAX  4096

#define UART_PASS    0x01
#define UART_FAIL    0x00

/************************** Function Prototypes ******************************/
static int VerifyData(const unsigned char *t_expected);

/************************** Variable Definitions *****************************/

static XAxiDma        AxiDma;
static XUartPs        myUart;
static XUartPs_Config *myUartConfig;

/* Static data buffers in cached DDR */
static unsigned char cpk[MAYO_MAX_cpk_bytes];
static unsigned char epk[MAYO_MAX_epk_bytes];
static unsigned char sig_buf[MAYO_MAX_sig_bytes];
static unsigned char msg_buf[MSG_BUF_MAX];
static unsigned char t_vec[MAYO_MAX_m_bytes];
static unsigned char sig_epk[MAYO_MAX_sig_bytes + MAYO_MAX_epk_bytes];

/***************************** Main Function *********************************/

int main(void)
{
	int Status;
	int msg_len;
	unsigned int cpk_len, sig_ln;
	int num_bds;

	/* ---- UART init ---- */
	myUartConfig = uart_init(&myUart, XPAR_UART1_BASEADDR);

	/* ---- DMA + interrupt setup ---- */
	Status = DmaSetup(&AxiDma);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/* ---- Outer loop: re-sync each time Python reconnects ---- */
	while (1) {

		/* ---- Sync: wait for Python ready byte, then send sync ---- */
		XUartPs_RecvByte(myUartConfig->BaseAddress);
		uart_send_str(&myUart, "UART Synchronized\n");

		/* ---- Test case loop: receive until host sends zero-length MSG ---- */
		while (1) {

			/* Receive MSG */
			msg_len = (int)uart_recv_field(myUartConfig, msg_buf, sizeof(msg_buf));
			if (msg_len == 0) {
				break;
			}

			/* Receive CPK */
			cpk_len = uart_recv_field(myUartConfig, cpk, sizeof(cpk));
			if (cpk_len == 0) {
				uart_send_byte(&myUart, UART_FAIL);
				break;
			}

			/* Receive SIG */
			sig_ln = uart_recv_field(myUartConfig, sig_buf, sizeof(sig_buf));
			if (sig_ln == 0) {
				uart_send_byte(&myUart, UART_FAIL);
				break;
			}

			/* ---- Expand CPK and derive T ---- */
			mayo_expand_pk(&MAYO_PARAMS, cpk, epk);
			deriveT(&MAYO_PARAMS, msg_buf, (unsigned long long)msg_len, sig_buf, t_vec);

			size_t sig_len        = MAYO_PARAMS.sig_bytes - MAYO_PARAMS.salt_bytes;
			size_t sig_len_padded = (sig_len + 15) & ~(size_t)7;
			memcpy(sig_epk,                sig_buf, sig_len);
			memset(sig_epk + sig_len,      0,      sig_len_padded - sig_len);
			memcpy(sig_epk + sig_len_padded, epk,  MAYO_PARAMS.epk_bytes);

			for (size_t i=0;i<sig_len_padded+MAYO_PARAMS.epk_bytes;i+=8){
				unsigned char tmp;
				tmp = sig_epk[i+0]; sig_epk[i+0]=sig_epk[i+7]; sig_epk[i+7] = tmp;
				tmp = sig_epk[i+1]; sig_epk[i+1]=sig_epk[i+6]; sig_epk[i+6] = tmp;
				tmp = sig_epk[i+2]; sig_epk[i+2]=sig_epk[i+5]; sig_epk[i+5] = tmp;
				tmp = sig_epk[i+3]; sig_epk[i+3]=sig_epk[i+4]; sig_epk[i+4] = tmp;
			}

			/* ---- Phase 1: SIG, EPK DECODE ---- */
			module_start(CTRL_CALC);

			TxDone = 0; Error = 0;
			num_bds = SendData(&AxiDma, sig_epk, sig_len_padded + MAYO_PARAMS.epk_bytes);
			if (num_bds < 0) {
				uart_send_byte(&myUart, UART_FAIL);
				goto Done;
			}

			Status = Xil_WaitForEventSet(POLL_TIMEOUT_COUNTER, NUMBER_OF_EVENTS, &Error);
			if (Status == XST_SUCCESS) {
				if (!TxDone) {
					uart_send_byte(&myUart, UART_FAIL);
					goto Done;
				}
			}

			Status = Xil_WaitForEvent((UINTPTR)&TxDone, num_bds, num_bds, POLL_TIMEOUT_COUNTER);
			if (Status != XST_SUCCESS) {
				uart_send_byte(&myUart, UART_FAIL);
				goto Done;
			}

			Status = RxPrepare(MAYO_PARAMS.m_bytes);
			if (Status != XST_SUCCESS) {
				xil_printf("RxPrepare failed\r\n");
				goto Done;
			}

			while (!(module_status() & STATUS_DONE));

			module_start(CTRL_IDLE);

			Status = VerifyData(t_vec);
			uart_send_byte(&myUart, (Status == XST_SUCCESS) ? UART_PASS : UART_FAIL);
		}
	}

Done:
	XDisconnectInterruptCntrl(DmaConfig->IntrId[0], DmaConfig->IntrParent);
	XDisconnectInterruptCntrl(DmaConfig->IntrId[1], DmaConfig->IntrParent);
	return XST_SUCCESS;
}

/************************** VerifyData ****************************************/

static int VerifyData(const unsigned char *t_expected)
{
	unsigned char rx[MAYO_PARAMS.m_bytes];

	RecvData(rx, MAYO_PARAMS.m_bytes);

	/* HW outputs y in reversed byte order — reverse in-place before comparing */
	for (int i = 0, j = MAYO_PARAMS.m_bytes - 1; i < j; i++, j--) {
		unsigned char tmp = rx[i];
		rx[i] = rx[j];
		rx[j] = tmp;
	}

	int pass = (memcmp(rx, t_expected, MAYO_PARAMS.m_bytes) == 0);
	return pass ? XST_SUCCESS : XST_FAILURE;
}
