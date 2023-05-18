/*******************************************************************************
** File: 
**  arducam_app.h
**
** Purpose:
**   This file is main header file for the Arducam application.
**
*******************************************************************************/
#ifndef _ARDUCAM_APP_H_
#define _ARDUCAM_APP_H_

/*
** Required header files.
*/
#include "arducam_app_msg.h"
#include "arducam_app_events.h"
#include "cfe_sb.h"
#include "cfe_evs.h"

/***********************************************************************/
#define ARDUCAM_PIPE_DEPTH 32 /* Depth of the Command Pipe for Application */

/************************************************************************
** Type Definitions
*************************************************************************/

/*
 * Buffer to hold telemetry data prior to sending
 * Defined as a union to ensure proper alignment for a CFE_SB_Msg_t type
 */
typedef union
{
    CFE_SB_Msg_t   MsgHdr;
    ARDUCAM_HkTlm_t HkTlm;
} ARDUCAM_HkBuffer_t;

/*
** Global Data
*/
typedef struct
{
    /*
    ** Housekeeping telemetry packet...
    */
    ARDUCAM_HkBuffer_t HkBuf;

    /*
    ** Operational data (not reported in housekeeping)...
    */
    CFE_SB_PipeId_t CommandPipe;
    CFE_SB_MsgPtr_t MsgPtr;
    uint32 RunStatus;           /* App run status for controlling the application state */
    CAM_NoArgsCmd_t EoE;        /* End of Experiment Packet */
    CAM_Exp_tlm_t	Exp_Pkt;    /* Experiment Packet */

    /*
    ** Initialization data (not reported in housekeeping)...
    */
    char   PipeName[16];
    uint16 PipeDepth;

    /*
    ** Child data
    */
    uint32   ChildTaskID;		/* Task ID provided by CFS on initialization */
    uint32   data_mutex;         
    uint32   sem_id;            /* Semaphore ID */
    uint32   Exp;
    uint32   State; 				
    uint32   Size;				/* Resolution of picture */	


    CFE_EVS_BinFilter_t EventFilters[ARDUCAM_EVENT_COUNTS];

} ARDUCAM_AppData_t;

/*
** Exported Data
*/
extern ARDUCAM_AppData_t ARDUCAM_AppData; 


/****************************************************************************/
/*
** Function prototypes.
**
** Note: Except for the entry point (ARDUCAM_AppMain), these
**       functions are not called from any other source module.
*/
void  ARDUCAM_AppMain(void);

int32 ARDUCAM_AppInit(void);
void  ARDUCAM_ProcessCommandPacket(void);
void  CAM_ProcessCommandPacket(void);
void  CAM_ProcessGroundCommand(void);
void  CAM_ReportHousekeeping(void);
void  CAM_ProcessPR(void);
void  CAM_ResetCounters(void);

/* 
** This function is provided as an example of verifying the size of the command
*/
boolean CAM_VerifyCmdLength(CFE_SB_MsgPtr_t msg, uint16 ExpectedLength);


#endif /* _arducam_app_h_ */

/************************/
/*  End of File Comment */
/************************/
