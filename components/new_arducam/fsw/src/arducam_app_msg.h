/*******************************************************************************
** File:
**  arducam_app_msg.h
**
** Purpose:
**  Define Arducam App Messages and info
**
** Notes:
**
**
*******************************************************************************/
#ifndef _ARDUCAM_APP_MSG_H_
#define _ARDUCAM_APP_MSG_H_

#include "osapi.h" // for types used below
#include "cfe_sb.h" // for CFE_SB_CMD_HDR_SIZE, CFE_SB_TLM_HDR_SIZE


/*
** ARDUCAM App command codes
*/
#define ARDUCAM_APP_NOOP_CC            0
#define ARDUCAM_APP_RESET_COUNTERS_CC  1
#define ARDUCAM_GET_DEV_DATA_CC        2
#define ARDUCAM_CONFIG_CC              3
#define ARDUCAM_OTHER_CMD_CC           4
#define ARDUCAM_RAW_CMD_CC             5
#define ARDUCAM_APP_RESET_DEV_CNTRS_CC 6
#define ARDUCAM_SEND_DEV_HK_CC         7
#define ARDUCAM_SEND_DEV_DATA_CC       8

/*************************************************************************/

/*
** Type definition (generic "no arguments" command)
*/
typedef struct
{
    uint8 CmdHeader[CFE_SB_CMD_HDR_SIZE];

} ARDUCAM_NoArgsCmd_t;

/*
** The following commands all share the "NoArgs" format
**
** They are each given their own type name matching the command name, which_open_mode
** allows them to change independently in the future without changing the prototype
** of the handler function
*/
typedef ARDUCAM_NoArgsCmd_t ARDUCAM_Noop_t;
typedef ARDUCAM_NoArgsCmd_t ARDUCAM_ResetCounters_t;
typedef ARDUCAM_NoArgsCmd_t ARDUCAM_Process_t;

typedef ARDUCAM_NoArgsCmd_t ARDUCAM_GetDevData_cmd_t;
typedef ARDUCAM_NoArgsCmd_t ARDUCAM_Other_cmd_t;
typedef ARDUCAM_NoArgsCmd_t ARDUCAM_SendDevHk_cmd_t;
typedef ARDUCAM_NoArgsCmd_t ARDUCAM_SendDevData_cmd_t;

/*
** ARDUCAM write configuration command
*/
typedef struct
{
    uint8    CmdHeader[CFE_SB_CMD_HDR_SIZE];
    uint32   MillisecondStreamDelay;

} ARDUCAM_Config_cmd_t;

/*
** ARDUCAM raw command
*/
typedef struct
{
    uint8    CmdHeader[CFE_SB_CMD_HDR_SIZE];
    uint8    RawCmd[5];
} ARDUCAM_Raw_cmd_t;

/*************************************************************************/
/*
** Type definition (ARDUCAM App housekeeping)
*/

typedef struct
{
    uint8 CommandErrorCounter;
    uint8 CommandCounter;
} OS_PACK ARDUCAM_HkTlm_Payload_t;

typedef struct
{
    uint8                  TlmHeader[CFE_SB_TLM_HDR_SIZE];
    ARDUCAM_HkTlm_Payload_t Payload;

} OS_PACK ARDUCAM_HkTlm_t;

#endif /* _ARDUCAM_APP_MSG_H_ */

/************************/
/*  End of File Comment */
/************************/
