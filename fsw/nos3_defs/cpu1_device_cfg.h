/*
**  GSC-18128-1, "Core Flight Executive Version 6.7"
**
**  Copyright (c) 2006-2019 United States Government as represented by
**  the Administrator of the National Aeronautics and Space Administration.
**  All Rights Reserved.
**
**  Licensed under the Apache License, Version 2.0 (the "License");
**  you may not use this file except in compliance with the License.
**  You may obtain a copy of the License at
**
**    http://www.apache.org/licenses/LICENSE-2.0
**
**  Unless required by applicable law or agreed to in writing, software
**  distributed under the License is distributed on an "AS IS" BASIS,
**  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
**  See the License for the specific language governing permissions and
**  limitations under the License.
*/

/*
** CPU1 - NOS3
*/

#ifndef _cpu1_device_cfg_
#define _cpu1_device_cfg_

/*
** Note: These includes are required for HWLIB
*/
#include "cfe.h"
#include "osapi.h"

/* Note: NOS3 uart requires matching handle and bus number */

/*
** SAMPLE Configuration
*/
#define SAMPLE_CFG
#define SAMPLE_CFG_STRING           "usart_29"
#define SAMPLE_CFG_HANDLE           29 
#define SAMPLE_CFG_BAUDRATE_HZ      115200
#define SAMPLE_CFG_MS_TIMEOUT       50            /* Max 255 */
//#define SAMPLE_CFG_DEBUG


#endif /* _cpu1_device_cfg_ */
