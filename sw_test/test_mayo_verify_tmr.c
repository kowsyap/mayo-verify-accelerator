#include "xparameters.h"
#include "xil_util.h"
#include "dma_helper.h"
#include "mayo_ctrl.h"
#include "mayo_helper.h"
#include "xtmrctr.h"
#include <string.h>

/******************** Constant Definitions **********************************/

#define POLL_TIMEOUT_COUNTER	1000000U
#define NUMBER_OF_EVENTS	1
#define TMRCTR_DEVICE_ID 0

#define TIMER_FREQ_HZ      XPAR_XTMRCTR_0_CLOCK_FREQUENCY
#define TICKS_TO_US(t)     ((u32)((t) / (TIMER_FREQ_HZ / 1000000U)))
#define TICKS_TO_US_FRAC(t) ((u32)(((t) % (TIMER_FREQ_HZ / 1000000U)) * 1000U / (TIMER_FREQ_HZ / 1000000U)))

#define MAYO_ROUND  1

#include "test_vectors_zybo_r1.h"
#define MAYO_PARAMS   MAYO_R1_2

#ifndef DEBUG
extern void xil_printf(const char *format, ...);
#endif

/************************** Function Prototypes ******************************/
static int VerifyData(const unsigned char *t_expected);

/************************** Variable Definitions *****************************/

static XAxiDma AxiDma;
static XTmrCtr TimerCounter;

/* Buffers derived from KAT header */
static unsigned char epk[MAYO_MAX_epk_bytes];
static unsigned char t_vec[MAYO_MAX_m_bytes];
static unsigned char sig_epk[MAYO_MAX_sig_bytes + MAYO_MAX_epk_bytes];

/***************************** Main Function *********************************/

int main(void)
{
	int Status;
	int num_bds;

	xil_printf("\r\n--- Entering main() ---\r\n");
	xil_printf("MAYO Round %d (KAT header mode)\r\n", MAYO_ROUND);

	/* ---- DMA + interrupt setup ---- */
	Status = DmaSetup(&AxiDma);
	if (Status != XST_SUCCESS) {
		xil_printf("DMA setup failed\r\n");
		return XST_FAILURE;
	}

	Status = XTmrCtr_Initialize(&TimerCounter, TMRCTR_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		xil_printf("Timer setup failed\r\n");
		return XST_FAILURE;
	}

	Status = XTmrCtr_SelfTest(&TimerCounter, TMRCTR_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		xil_printf("Timer self test failed\r\n");
		return XST_FAILURE;
	}

	XTmrCtr_SetOptions(&TimerCounter, TMRCTR_DEVICE_ID, XTC_AUTO_RELOAD_OPTION);

	xil_printf("MSG %d B  CPK %d B  SIG %d B\r\n",
	           MSG_LEN, CPK_LEN, SIG_LEN);

	/* ---- Expand CPK and derive T from KAT vectors ---- */
	xil_printf("Expanding CPK -> EPK ...\r\n");

	XTmrCtr_Start(&TimerCounter, TMRCTR_DEVICE_ID);
	mayo_expand_pk(&MAYO_PARAMS, cpk, epk);
	XTmrCtr_Stop(&TimerCounter, TMRCTR_DEVICE_ID);

	u32 val1 = XTmrCtr_GetValue(&TimerCounter, TMRCTR_DEVICE_ID);
	u32 val2, val3, val4;

	xil_printf("EPK[0..15]: ");
	for (int i = 0; i < 16; i++) xil_printf("%02x", epk[i]);
	xil_printf("\r\n");

	XTmrCtr_Reset(&TimerCounter, TMRCTR_DEVICE_ID);

	xil_printf("Deriving T ...\r\n");
	XTmrCtr_Start(&TimerCounter, TMRCTR_DEVICE_ID);
	deriveT(&MAYO_PARAMS, msg, (unsigned long long)MSG_LEN, sig, t_vec);
	XTmrCtr_Stop(&TimerCounter, TMRCTR_DEVICE_ID);

	val2 = XTmrCtr_GetValue(&TimerCounter, TMRCTR_DEVICE_ID);

	xil_printf("T[0..%d]: ", (int)MAYO_PARAMS.m_bytes - 1);
	for (int i = 0; i < (int)MAYO_PARAMS.m_bytes; i++) xil_printf("%02x", t_vec[i]);
	xil_printf("\r\n");

	/* ---- Build combined SIG + EPK buffer ---- */
	size_t sig_len        = MAYO_PARAMS.sig_bytes - MAYO_PARAMS.salt_bytes;
	size_t sig_len_padded = (sig_len + 7 + (MAYO_ROUND-1)*8) & ~(size_t)7;
	memcpy(sig_epk,                sig, sig_len);
	memset(sig_epk + sig_len,      0,      sig_len_padded - sig_len);
	memcpy(sig_epk + sig_len_padded, epk,  MAYO_PARAMS.epk_bytes);

	for (size_t i=0;i<sig_len_padded+MAYO_PARAMS.epk_bytes;i+=8){
		unsigned char tmp;
		tmp = sig_epk[i+0]; sig_epk[i+0]=sig_epk[i+7]; sig_epk[i+7] = tmp;
		tmp = sig_epk[i+1]; sig_epk[i+1]=sig_epk[i+6]; sig_epk[i+6] = tmp;
		tmp = sig_epk[i+2]; sig_epk[i+2]=sig_epk[i+5]; sig_epk[i+5] = tmp;
		tmp = sig_epk[i+3]; sig_epk[i+3]=sig_epk[i+4]; sig_epk[i+4] = tmp;
	}

	/* ---- Start FSM and send SIG+EPK in one transfer ---- */
	module_start(CTRL_CALC);
	xil_printf("\r\n[Phase 1+2] SIG+EPK transfer started\r\n");

	TxDone = 0; Error = 0;
	XTmrCtr_Reset(&TimerCounter, TMRCTR_DEVICE_ID);

	XTmrCtr_Start(&TimerCounter, TMRCTR_DEVICE_ID);
	num_bds = SendData(&AxiDma, sig_epk, sig_len_padded + MAYO_PARAMS.epk_bytes);
	if (num_bds < 0) {
		xil_printf("SendData failed (SIG+EPK)\r\n");
		goto Done;
	}

	Status = Xil_WaitForEventSet(POLL_TIMEOUT_COUNTER, NUMBER_OF_EVENTS, &Error);
	if (Status == XST_SUCCESS) {
		if (!TxDone) {
			xil_printf("DMA error (SIG+EPK)\r\n");
			goto Done;
		}
	}

	Status = Xil_WaitForEvent((UINTPTR)&TxDone, num_bds, num_bds, POLL_TIMEOUT_COUNTER);
	if (Status != XST_SUCCESS) {
		xil_printf("TX timeout (SIG+EPK)\r\n");
		goto Done;
	}
	XTmrCtr_Stop(&TimerCounter, TMRCTR_DEVICE_ID);

	val3 = XTmrCtr_GetValue(&TimerCounter, TMRCTR_DEVICE_ID);
	xil_printf("[Phase 1+2] SIG+EPK DMA done\r\n");

	/* Arm RX only after TX completes — no spurious M_AXIS activity during TX */
	Status = RxPrepare(MAYO_PARAMS.m_bytes);
	if (Status != XST_SUCCESS) {
		xil_printf("RxPrepare failed\r\n");
		goto Done;
	}

	/* ---- Phase 3: QA (FSM triggered automatically after EPK done) ---- */
	xil_printf("\r\n[Phase 3] Waiting for QA output\r\n");

	XTmrCtr_Reset(&TimerCounter, TMRCTR_DEVICE_ID);

	XTmrCtr_Start(&TimerCounter, TMRCTR_DEVICE_ID);
	while (!(module_status() & STATUS_DONE));
	XTmrCtr_Stop(&TimerCounter, TMRCTR_DEVICE_ID);
	
	val4 = XTmrCtr_GetValue(&TimerCounter, TMRCTR_DEVICE_ID);
	xil_printf("[Phase 3] QA done\r\n");

	module_start(CTRL_IDLE);

	VerifyData(t_vec);

	u32 total = val1 + val2 + val3 + val4;
	u64 tot64 = (u64)total;
	u32 us1 = TICKS_TO_US(val1), us2 = TICKS_TO_US(val2);
	u32 us3 = TICKS_TO_US(val3), us4 = TICKS_TO_US(val4);
	u32 usT = TICKS_TO_US(total);

#define PRINT_ROW(label, val, us) \
	xil_printf(label " : "); \
	if ((us) >= 1000) xil_printf("%u.%03u ms", (us)/1000, (us)%1000); \
	else              xil_printf("%u.%03u us", (us), TICKS_TO_US_FRAC(val)); \
	xil_printf("  (%u.%02u%%)\r\n", \
	    (u32)((u64)(val) * 100ULL / tot64), \
	    (u32)((u64)(val) * 10000ULL / tot64 % 100ULL))

	xil_printf("\r\n--- Timing Summary ---\r\n");
	PRINT_ROW("mayo_expand_pk", val1, us1);
	PRINT_ROW("deriveT       ", val2, us2);
	PRINT_ROW("DMA TX        ", val3, us3);
	PRINT_ROW("HW compute    ", val4, us4);
	xil_printf("Total          : ");
	if (usT >= 1000) xil_printf("%u.%03u ms\r\n", usT/1000, usT%1000);
	else             xil_printf("%u.%03u us\r\n", usT, TICKS_TO_US_FRAC(total));

#undef PRINT_ROW

Done:
	XDisconnectInterruptCntrl(DmaConfig->IntrId[0], DmaConfig->IntrParent);
	XDisconnectInterruptCntrl(DmaConfig->IntrId[1], DmaConfig->IntrParent);
	xil_printf("--- Exiting main() ---\r\n");
	return XST_SUCCESS;
}

/************************** VerifyData ****************************************/

static int VerifyData(const unsigned char *t_expected)
{
	unsigned char rx[MAYO_PARAMS.m_bytes];

	RecvData(rx, MAYO_PARAMS.m_bytes);

	for (int i = 0, j = MAYO_PARAMS.m_bytes - 1; i < j; i++, j--) {
		unsigned char tmp = rx[i];
		rx[i] = rx[j];
		rx[j] = tmp;
	}

	int pass = (memcmp(rx, t_expected, MAYO_PARAMS.m_bytes) == 0);
	xil_printf("Result: %s\r\n", pass ? "PASS" : "FAIL");

	if (!pass) {
		xil_printf("  HW : ");
		for (int i = 0; i < (int)MAYO_PARAMS.m_bytes; i++) xil_printf("%02x", rx[i]);
		xil_printf("\r\n  SW : ");
		for (int i = 0; i < (int)MAYO_PARAMS.m_bytes; i++) xil_printf("%02x", t_expected[i]);
		xil_printf("\r\n");
	}

	return pass ? XST_SUCCESS : XST_FAILURE;
}
