#ifndef DMA_HELPER_H
#define DMA_HELPER_H

#include "xaxidma.h"
#include "xparameters.h"
#include "xil_exception.h"
#include "xinterrupt_wrap.h"
#include "xil_util.h"

/******************** Memory Map *********************************************/

#define MEM_BASE_ADDR       0x01000000

#define RX_BD_SPACE_BASE    (MEM_BASE_ADDR)
#define RX_BD_SPACE_HIGH    (MEM_BASE_ADDR + 0x0000FFFF)
#define TX_BD_SPACE_BASE    (MEM_BASE_ADDR + 0x00010000)
#define TX_BD_SPACE_HIGH    (MEM_BASE_ADDR + 0x0001FFFF)
#define TX_BUFFER_BASE      (MEM_BASE_ADDR + 0x00100000)
#define RX_BUFFER_BASE      (MEM_BASE_ADDR + 0x00300000)
#define RX_BUFFER_HIGH      (MEM_BASE_ADDR + 0x004FFFFF)

#define MAX_PKT_LEN         256
#define RESET_TIMEOUT_COUNTER   10000
#define COALESCING_COUNT    1
#define DELAY_TIMER_COUNT   100

/******************** Shared State (defined in dma_helper.c) *****************/

extern volatile u32 TxDone;
extern volatile u32 RxDone;
extern volatile u32 Error;
extern XAxiDma_Config *DmaConfig;   /* needed by caller for interrupt teardown */

/******************** Public API *********************************************/

/*
 * Full DMA initialisation: lookup config, init instance, call TxSetup +
 * RxSetup, wire TX and RX interrupts.
 * Must be called once before SendData / RxPrepare.
 */
int  DmaSetup(XAxiDma *AxiDmaInstPtr);

/*
 * Arm the RX ring with `total_bytes` worth of buffer descriptors.
 * Call this before triggering the QA phase each iteration.
 */
int  RxPrepare(int total_bytes);

/*
 * Copy `data` (total_bytes) to the TX buffer and submit to DMA.
 * Returns number of BDs submitted, or -1 on error.
 */
int  SendData(XAxiDma *AxiDmaInstPtr, const void *data, int total_bytes);

/*
 * Invalidate D-cache for the RX buffer then copy total_bytes into out.
 * Call this after the QA phase completes to retrieve the hardware result.
 */
int  RecvData(void *out, int total_bytes);

/*
 * Calculate how many BDs are needed to transfer total_bytes
 * given MAX_PKT_LEN per BD.
 */
int  bd_count_for(int total_bytes);

#endif /* DMA_HELPER_H */
