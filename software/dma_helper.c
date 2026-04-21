#include "dma_helper.h"
#include "xil_printf.h"
#include <string.h>

/******************** Shared State *******************************************/

volatile u32 TxDone;
volatile u32 RxDone;
volatile u32 Error;
XAxiDma_Config *DmaConfig;

/******************** Private State ******************************************/

static XAxiDma      *AxiDmaPtr;    /* set in DmaSetup, used by interrupt handlers */
static XAxiDma_BdRing *TxRingPtr;
static XAxiDma_BdRing *RxRingPtr;

/******************** Forward declarations ***********************************/

static int  TxSetup(XAxiDma *AxiDmaInstPtr);
static int  RxSetup(XAxiDma *AxiDmaInstPtr);
static void TxCallBack(XAxiDma_BdRing *TxRingPtr);
static void TxIntrHandler(void *Callback);
static void RxCallBack(XAxiDma_BdRing *RxRingPtr);
static void RxIntrHandler(void *Callback);

/******************** Public Functions ***************************************/

int DmaSetup(XAxiDma *AxiDmaInstPtr)
{
	int Status;

	AxiDmaPtr = AxiDmaInstPtr;

	DmaConfig = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
	if (!DmaConfig) {
		xil_printf("No config found for %d\r\n", XPAR_XAXIDMA_0_BASEADDR);
		return XST_FAILURE;
	}

	XAxiDma_CfgInitialize(AxiDmaInstPtr, DmaConfig);

	if (!XAxiDma_HasSg(AxiDmaInstPtr)) {
		xil_printf("Device configured as Simple mode\r\n");
		return XST_FAILURE;
	}

	Status = TxSetup(AxiDmaInstPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed TX setup\r\n");
		return XST_FAILURE;
	}

	Status = RxSetup(AxiDmaInstPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed RX setup\r\n");
		return XST_FAILURE;
	}

	TxRingPtr = XAxiDma_GetTxRing(AxiDmaInstPtr);
	Status = XSetupInterruptSystem(TxRingPtr, &TxIntrHandler,
	                               DmaConfig->IntrId[0], DmaConfig->IntrParent,
	                               XINTERRUPT_DEFAULT_PRIORITY);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed TX intr setup\r\n");
		return XST_FAILURE;
	}

	Status = XSetupInterruptSystem(RxRingPtr, &RxIntrHandler,
	                               DmaConfig->IntrId[1], DmaConfig->IntrParent,
	                               XINTERRUPT_DEFAULT_PRIORITY);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

int bd_count_for(int total_bytes)
{
	return (total_bytes + MAX_PKT_LEN - 1) / MAX_PKT_LEN;
}

int RxPrepare(int total_bytes)
{
	XAxiDma_Bd *BdPtr;
	XAxiDma_Bd *BdCurPtr;
	int num_bds;
	UINTPTR RxBufferPtr;
	int Status;
	int Index;

	num_bds = bd_count_for(total_bytes);

	Xil_DCacheInvalidateRange(RX_BUFFER_BASE, total_bytes);

	Status = XAxiDma_BdRingAlloc(RxRingPtr, num_bds, &BdPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("RxPrepare: bd alloc failed\r\n");
		return XST_FAILURE;
	}

	BdCurPtr = BdPtr;
	RxBufferPtr = RX_BUFFER_BASE;
	for (Index = 0; Index < num_bds; Index++) {
		int len = (Index == num_bds - 1 && total_bytes % MAX_PKT_LEN != 0)
		          ? total_bytes % MAX_PKT_LEN
		          : MAX_PKT_LEN;

		Status = XAxiDma_BdSetBufAddr(BdCurPtr, RxBufferPtr);
		if (Status != XST_SUCCESS) {
			xil_printf("RxPrepare: set buf addr failed\r\n");
			return XST_FAILURE;
		}
		Status = XAxiDma_BdSetLength(BdCurPtr, len, RxRingPtr->MaxTransferLen);
		if (Status != XST_SUCCESS) {
			xil_printf("RxPrepare: set length failed\r\n");
			return XST_FAILURE;
		}
		XAxiDma_BdSetCtrl(BdCurPtr, 0);
		XAxiDma_BdSetId(BdCurPtr, RxBufferPtr);
		RxBufferPtr += len;
		BdCurPtr = (XAxiDma_Bd *)XAxiDma_BdRingNext(RxRingPtr, BdCurPtr);
	}

	Status = XAxiDma_BdRingToHw(RxRingPtr, num_bds, BdPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("RxPrepare: ToHw failed\r\n");
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

int SendData(XAxiDma *AxiDmaInstPtr, const void *data, int total_bytes)
{
	XAxiDma_BdRing *TxRing = XAxiDma_GetTxRing(AxiDmaInstPtr);
	XAxiDma_Bd *BdPtr, *BdCurPtr;
	int Status;
	int Index;
	int num_bds = bd_count_for(total_bytes);
	UINTPTR BufferAddr = TX_BUFFER_BASE;

	memcpy((void *)TX_BUFFER_BASE, data, total_bytes);
	Xil_DCacheFlushRange(TX_BUFFER_BASE, total_bytes);

	Status = XAxiDma_BdRingAlloc(TxRing, num_bds, &BdPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("SendData: bd alloc failed\r\n");
		return -1;
	}

	BdCurPtr = BdPtr;
	for (Index = 0; Index < num_bds; Index++) {
		int len = (Index == num_bds - 1 && total_bytes % MAX_PKT_LEN != 0)
		          ? total_bytes % MAX_PKT_LEN
		          : MAX_PKT_LEN;
		u32 CrBits = 0;

		Status = XAxiDma_BdSetBufAddr(BdCurPtr, BufferAddr);
		if (Status != XST_SUCCESS) {
			xil_printf("SendData: set buf addr failed\r\n");
			return -1;
		}
		Status = XAxiDma_BdSetLength(BdCurPtr, len, TxRing->MaxTransferLen);
		if (Status != XST_SUCCESS) {
			xil_printf("SendData: set length failed\r\n");
			return -1;
		}

		if (Index == 0)
			CrBits |= XAXIDMA_BD_CTRL_TXSOF_MASK;
		if (Index == num_bds - 1)
			CrBits |= XAXIDMA_BD_CTRL_TXEOF_MASK;

		XAxiDma_BdSetCtrl(BdCurPtr, CrBits);
		XAxiDma_BdSetId(BdCurPtr, BufferAddr);

		BufferAddr += len;
		BdCurPtr = (XAxiDma_Bd *)XAxiDma_BdRingNext(TxRing, BdCurPtr);
	}

	Status = XAxiDma_BdRingToHw(TxRing, num_bds, BdPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("SendData: ToHw failed\r\n");
		return -1;
	}

	return num_bds;
}

int RecvData(void *out, int total_bytes)
{
	Xil_DCacheInvalidateRange(RX_BUFFER_BASE, total_bytes);
	memcpy(out, (void *)RX_BUFFER_BASE, total_bytes);
	return XST_SUCCESS;
}

/******************** Private: Ring Setup ************************************/

static int TxSetup(XAxiDma *AxiDmaInstPtr)
{
	XAxiDma_BdRing *TxRing = XAxiDma_GetTxRing(AxiDmaInstPtr);
	XAxiDma_Bd BdTemplate;
	int Status;
	u32 BdCount;

	XAxiDma_BdRingIntDisable(TxRing, XAXIDMA_IRQ_ALL_MASK);

	BdCount = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT,
	                                 (UINTPTR)TX_BD_SPACE_HIGH - (UINTPTR)TX_BD_SPACE_BASE + 1);

	Status = XAxiDma_BdRingCreate(TxRing, TX_BD_SPACE_BASE, TX_BD_SPACE_BASE,
	                              XAXIDMA_BD_MINIMUM_ALIGNMENT, BdCount);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed create TX BD ring\r\n");
		return XST_FAILURE;
	}

	XAxiDma_BdClear(&BdTemplate);
	Status = XAxiDma_BdRingClone(TxRing, &BdTemplate);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed clone TX BDs\r\n");
		return XST_FAILURE;
	}

	Status = XAxiDma_BdRingSetCoalesce(TxRing, COALESCING_COUNT, DELAY_TIMER_COUNT);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed set TX coalescing\r\n");
		return XST_FAILURE;
	}

	XAxiDma_BdRingIntEnable(TxRing, XAXIDMA_IRQ_ALL_MASK);

	Status = XAxiDma_BdRingStart(TxRing);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed TX bd start\r\n");
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

static int RxSetup(XAxiDma *AxiDmaInstPtr)
{
	XAxiDma_Bd BdTemplate;
	int Status;
	int BdCount;

	RxRingPtr = XAxiDma_GetRxRing(AxiDmaInstPtr);

	XAxiDma_BdRingIntDisable(RxRingPtr, XAXIDMA_IRQ_ALL_MASK);

	BdCount = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT,
	                                 RX_BD_SPACE_HIGH - RX_BD_SPACE_BASE + 1);

	Status = XAxiDma_BdRingCreate(RxRingPtr, RX_BD_SPACE_BASE, RX_BD_SPACE_BASE,
	                              XAXIDMA_BD_MINIMUM_ALIGNMENT, BdCount);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx bd create failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	XAxiDma_BdClear(&BdTemplate);
	Status = XAxiDma_BdRingClone(RxRingPtr, &BdTemplate);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx bd clone failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	Status = XAxiDma_BdRingSetCoalesce(RxRingPtr, COALESCING_COUNT, DELAY_TIMER_COUNT);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx set coalesce failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	XAxiDma_BdRingIntEnable(RxRingPtr, XAXIDMA_IRQ_ALL_MASK);

	Status = XAxiDma_BdRingStart(RxRingPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx start BD ring failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

/******************** Interrupt Handlers *************************************/

static void TxCallBack(XAxiDma_BdRing *TxRingPtr)
{
	int BdCount;
	u32 BdSts;
	XAxiDma_Bd *BdPtr;
	XAxiDma_Bd *BdCurPtr;
	int Status;
	int Index;

	BdCount = XAxiDma_BdRingFromHw(TxRingPtr, XAXIDMA_ALL_BDS, &BdPtr);

	BdCurPtr = BdPtr;
	for (Index = 0; Index < BdCount; Index++) {
		BdSts = XAxiDma_BdGetSts(BdCurPtr);
		if ((BdSts & XAXIDMA_BD_STS_ALL_ERR_MASK) ||
		    (!(BdSts & XAXIDMA_BD_STS_COMPLETE_MASK))) {
			Error = 1;
			break;
		}
		BdCurPtr = (XAxiDma_Bd *)XAxiDma_BdRingNext(TxRingPtr, BdCurPtr);
	}

	Status = XAxiDma_BdRingFree(TxRingPtr, BdCount, BdPtr);
	if (Status != XST_SUCCESS)
		Error = 1;

	if (!Error)
		TxDone += BdCount;
}

static void TxIntrHandler(void *Callback)
{
	XAxiDma_BdRing *TxRingPtr = (XAxiDma_BdRing *)Callback;
	u32 IrqStatus;
	int TimeOut;

	IrqStatus = XAxiDma_BdRingGetIrq(TxRingPtr);
	XAxiDma_BdRingAckIrq(TxRingPtr, IrqStatus);

	if (!(IrqStatus & XAXIDMA_IRQ_ALL_MASK))
		return;

	if (IrqStatus & XAXIDMA_IRQ_ERROR_MASK) {
		XAxiDma_BdRingDumpRegs(TxRingPtr);
		Error = 1;
		XAxiDma_Reset(AxiDmaPtr);
		TimeOut = RESET_TIMEOUT_COUNTER;
		while (TimeOut) {
			if (XAxiDma_ResetIsDone(AxiDmaPtr)) break;
			TimeOut -= 1;
		}
		return;
	}

	if (IrqStatus & (XAXIDMA_IRQ_DELAY_MASK | XAXIDMA_IRQ_IOC_MASK))
		TxCallBack(TxRingPtr);
}

static void RxCallBack(XAxiDma_BdRing *RxRingPtr)
{
	int BdCount;
	XAxiDma_Bd *BdPtr;
	XAxiDma_Bd *BdCurPtr;
	u32 BdSts;
	int Index;

	BdCount = XAxiDma_BdRingFromHw(RxRingPtr, XAXIDMA_ALL_BDS, &BdPtr);

	BdCurPtr = BdPtr;
	for (Index = 0; Index < BdCount; Index++) {
		BdSts = XAxiDma_BdGetSts(BdCurPtr);
		if ((BdSts & XAXIDMA_BD_STS_ALL_ERR_MASK) ||
		    (!(BdSts & XAXIDMA_BD_STS_COMPLETE_MASK))) {
			Error = 1;
			break;
		}
		BdCurPtr = (XAxiDma_Bd *)XAxiDma_BdRingNext(RxRingPtr, BdCurPtr);
		RxDone += 1;
	}

	XAxiDma_BdRingFree(RxRingPtr, BdCount, BdPtr);
}

static void RxIntrHandler(void *Callback)
{
	XAxiDma_BdRing *RxRingPtr = (XAxiDma_BdRing *)Callback;
	u32 IrqStatus;
	int TimeOut;

	IrqStatus = XAxiDma_BdRingGetIrq(RxRingPtr);
	XAxiDma_BdRingAckIrq(RxRingPtr, IrqStatus);

	if (!(IrqStatus & XAXIDMA_IRQ_ALL_MASK))
		return;

	if (IrqStatus & XAXIDMA_IRQ_ERROR_MASK) {
		XAxiDma_BdRingDumpRegs(RxRingPtr);
		Error = 1;
		XAxiDma_Reset(AxiDmaPtr);
		TimeOut = RESET_TIMEOUT_COUNTER;
		while (TimeOut) {
			if (XAxiDma_ResetIsDone(AxiDmaPtr)) break;
			TimeOut -= 1;
		}
		return;
	}

	if (IrqStatus & (XAXIDMA_IRQ_DELAY_MASK | XAXIDMA_IRQ_IOC_MASK))
		RxCallBack(RxRingPtr);
}
