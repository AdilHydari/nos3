/************************************************************************
** File:
**  arducam_app_events.h
**
** Purpose:
**  Define Arducam App Event IDs
**
** Notes:
**
*************************************************************************/
#ifndef _ARDUCAM_APP_EVENTS_H_
#define _ARDUCAM_APP_EVENTS_H_

#define ARDUCAM_RESERVED_EID           0
#define ARDUCAM_STARTUP_INF_EID        1
#define ARDUCAM_COMMAND_ERR_EID        2
#define ARDUCAM_COMMANDNOP_INF_EID     3
#define ARDUCAM_COMMANDRST_INF_EID     4
#define ARDUCAM_INVALID_MSGID_ERR_EID  5
#define ARDUCAM_LEN_ERR_EID            6
#define ARDUCAM_PIPE_ERR_EID           7
#define ARDUCAM_CMD_DEVRST_INF_EID     8
#define ARDUCAM_UART_ERR_EID           9
#define ARDUCAM_UART_WRITE_ERR_EID    10
#define ARDUCAM_UART_READ_ERR_EID     11
#define ARDUCAM_COMMANDRAW_INF_EID    12
#define ARDUCAM_UART_MSG_CNT_DBG_EID  13
#define ARDUCAM_MUTEX_ERR_EID         14
#define ARDUCAM_CREATE_DEVICE_ERR_EID 15
#define ARDUCAM_DEVICE_REG_ERR_EID    16
#define ARDUCAM_DEVICE_REG_INF_EID    17

#define ARDUCAM_EVENT_COUNTS 17

#endif /* _ARDUCAM_APP_EVENTS_H_ */

/************************/
/*  End of File Comment */
/************************/
