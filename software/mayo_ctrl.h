#ifndef MAYO_CTRL_H
#define MAYO_CTRL_H

#include "xparameters.h"
#include "xil_io.h"

#define MAYO_ACCEL_BASEADDR      XPAR_MAYO_VERIFY_ACCELERATOR_0_BASEADDR
#define MAYO_CTRL_STATUS_OFFSET  0x00U

#define CTRL_IDLE                0x00000000U
#define CTRL_CALC                0x00000001U
#define STATUS_DONE              0x00000001U

static inline void module_start(u32 ctrl)
{
	Xil_Out32(MAYO_ACCEL_BASEADDR + MAYO_CTRL_STATUS_OFFSET, ctrl);
}

static inline u32 module_status(void)
{
	return Xil_In32(MAYO_ACCEL_BASEADDR + MAYO_CTRL_STATUS_OFFSET);
}

#endif /* MAYO_CTRL_H */
