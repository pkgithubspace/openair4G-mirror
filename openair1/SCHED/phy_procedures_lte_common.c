/*******************************************************************************

  Eurecom OpenAirInterface
  Copyright(c) 1999 - 2011 Eurecom

  This program is free software; you can redistribute it and/or modify it
  under the terms and conditions of the GNU General Public License,
  version 2, as published by the Free Software Foundation.

  This program is distributed in the hope it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin St - Fifth Floor, Boston, MA 02110-1301 USA.

  The full GNU General Public License is included in this distribution in
  the file called "COPYING".

  Contact Information
  Openair Admin: openair_admin@eurecom.fr
  Openair Tech : openair_tech@eurecom.fr
  Forums       : http://forums.eurecom.fsr/openairinterface
  Address      : Eurecom, 2229, route des crêtes, 06560 Valbonne Sophia Antipolis, France

*******************************************************************************/

/*! \file phy_procedures_lte_eNB.c
* \brief Implementation of common utilities for eNB/UE procedures from 36.213 LTE specifications
* \author R. Knopp, F. Kaltenberger
* \date 2011
* \version 0.1
* \company Eurecom
* \email: knopp@eurecom.fr,florian.kaltenberger@eurecom.fr
* \note
* \warning
*/
#include "PHY/defs.h"
#include "PHY/extern.h"
#include "MAC_INTERFACE/defs.h"
#include "MAC_INTERFACE/extern.h"
#include "SCHED/defs.h"
#include "SCHED/extern.h"


void get_Msg3_alloc(LTE_DL_FRAME_PARMS *frame_parms,
		    unsigned char current_subframe, 
		    unsigned int current_frame,
		    unsigned int *frame,
		    unsigned char *subframe) {

  // Fill in other TDD Configuration!!!!

  if (frame_parms->frame_type == 0) {
    *subframe = current_subframe+6;
    if (*subframe>9) {
      *subframe = *subframe-10;
      *frame = current_frame+1;
    }
    else {
      *frame=current_frame;
    }
  }
  else {
    if (frame_parms->tdd_config == 1) {
      switch (current_subframe) {
	
      case 0:
	*subframe = 7;
	*frame = current_frame;
	break;
      case 4:
	*subframe = 2;
	*frame = current_frame+1;
	break;
      case 5:
	*subframe = 2;
	*frame = current_frame+1;
	break;
      case 9:
	*subframe = 7;
	*frame = current_frame+1;
	break;
      }
    }
    else if (frame_parms->tdd_config == 3) {
      switch (current_subframe) {
	
      case 0:
      case 5:
      case 6:
	*subframe = 2;
	*frame = current_frame+1;
	break;
      case 7:
	*subframe = 3;
	*frame = current_frame+1;
	break;
      case 8:
	*subframe = 4;
	*frame = current_frame+1;
	break;
      case 9:
	*subframe = 2;
	*frame = current_frame+2;
	break;
      }
    }
  }
}

void get_Msg3_alloc_ret(LTE_DL_FRAME_PARMS *frame_parms,
			unsigned char current_subframe, 
			unsigned int current_frame,
			unsigned int *frame,
			unsigned char *subframe) {
  if (frame_parms->frame_type == 0) {
    // always retransmit in n+8
    *subframe = current_subframe+8;
    if (*subframe>9) {
      *subframe = *subframe-10;
      *frame = current_frame+1;
    }
    else {
      *frame=current_frame;
    }
  }
  else {
    if (frame_parms->tdd_config == 1) {
      // original PUSCH in 2, PHICH in 6 (S), ret in 2
      // original PUSCH in 3, PHICH in 9, ret in 3
      // original PUSCH in 7, PHICH in 1 (S), ret in 7
      // original PUSCH in 8, PHICH in 4, ret in 8
      *frame = current_frame+1;
    }
    else if (frame_parms->tdd_config == 3) {
      // original PUSCH in 2, PHICH in 8, ret in 2 next frame
      // original PUSCH in 3, PHICH in 9, ret in 3 next frame
      // original PUSCH in 4, PHICH in 0, ret in 4 next frame
      *frame=current_frame+1;
    }
  }
}

u8 get_Msg3_harq_pid(LTE_DL_FRAME_PARMS *frame_parms,
		     u32 frame,
		     unsigned char current_subframe) {

  u8 ul_subframe=0;
  u32 ul_frame;

  if (frame_parms->frame_type ==0) {
    ul_subframe = (current_subframe>4) ? (current_subframe-4) : (current_subframe+6);
    ul_frame    = (current_subframe>3) ? (frame+1) : frame; 
  }
  else {
    switch (frame_parms->tdd_config) {
    case 1:
      switch (current_subframe) {

      case 9:
      case 0:
	ul_subframe = 7;
	break;
      case 5:
      case 7:
	ul_subframe = 2;
	break;

      }
      break;
    case 3:
      switch (current_subframe) {

      case 0:
      case 5:
      case 6:
	ul_subframe = 2;
	break;
      case 7:
	ul_subframe = 3;
	break;
      case 8:
	ul_subframe = 4;
	break;
      case 9:
	ul_subframe = 2;
	break;
      }
      break;
    case 4:
      switch (current_subframe) {

      case 0:
      case 5:
      case 6:
      case 8:
      case 9:
	ul_subframe = 2;
	break;
      case 7:
	ul_subframe = 3;
	break;
      }
      break;
    case 5:
      ul_subframe =2;
      break;
    default:
      LOG_E(PHY,"get_Msg3_harq_pid: Unsupported TDD configuration %d\n",frame_parms->tdd_config);
      mac_xface->macphy_exit("");
      break;
    }
  }
    
  return(subframe2harq_pid(frame_parms,ul_frame,ul_subframe));

}

unsigned char ul_ACK_subframe2_dl_subframe(LTE_DL_FRAME_PARMS *frame_parms,unsigned char subframe,unsigned char ACK_index) {

  if (frame_parms->frame_type == 0) {
    return((subframe<4) ? subframe+6 : subframe-4);
  }
  else {
    switch (frame_parms->tdd_config) {
    case 3:
      if (subframe == 2) {  // ACK subframes 5 and 6
	if (ACK_index==2)
	  return(1);
	return(5+ACK_index);
      }
      else if (subframe == 3) {   // ACK subframes 7 and 8
	return(7+ACK_index);  // To be updated
      }
      else if (subframe == 4) {  // ACK subframes 9 and 0
	return((9+ACK_index)%10);
      }
      else {
	LOG_E(PHY,"phy_procedures_lte_common.c/subframe2_dl_harq_pid: illegal subframe %d for tdd_config %d\n",
	    subframe,frame_parms->tdd_config);
	return(0);
      }
      break;
    case 1:
      if (subframe == 2) {  // ACK subframes 5 and 6
	return(5+ACK_index);
      }
      else if (subframe == 3) {   // ACK subframe 9
	return(9);  // To be updated
      }
      else if (subframe == 7) {   // ACK subframes 0 and 1
	return(ACK_index);  // To be updated
      }
      else if (subframe == 8) {   // ACK subframe 4
	return(4);  // To be updated
      }
      else {
	LOG_E(PHY,"phy_procedures_lte_common.c/subframe2_dl_harq_pid: illegal subframe %d for tdd_config %d\n",
	    subframe,frame_parms->tdd_config);
	return(0);
      }
      break;
    }
  }
  return(0);
}

unsigned char ul_ACK_subframe2_M(LTE_DL_FRAME_PARMS *frame_parms,unsigned char subframe) {

  if (frame_parms->frame_type == 0) {
    return(1);
  }
  else {
    switch (frame_parms->tdd_config) {
    case 3:
      if (subframe == 2) {  // ACK subframes 5 and 6
	return(2); // should be 3
      }
      else if (subframe == 3) {   // ACK subframes 7 and 8
	return(2);  // To be updated
      }
      else if (subframe == 4) {  // ACK subframes 9 and 0
	return(2);
      }
      else {
	LOG_E(PHY,"phy_procedures_lte_common.c/subframe2_dl_harq_pid: illegal subframe %d for tdd_config %d\n",
	    subframe,frame_parms->tdd_config);
	return(0);
      }
      break;
    case 1:
      if (subframe == 2) {  // ACK subframes 5 and 6
	return(2);
      }
      else if (subframe == 3) {   // ACK subframe 9
	return(1);  // To be updated
      }
      else if (subframe == 7) {   // ACK subframes 0 and 1
	return(2);  // To be updated
      }
      else if (subframe == 8) {   // ACK subframe 4
	return(1);  // To be updated
      }
      else {
	LOG_E(PHY,"phy_procedures_lte_common.c/subframe2_dl_harq_pid: illegal subframe %d for tdd_config %d\n",
	    subframe,frame_parms->tdd_config);
	return(0);
      }
      break;
    }
  }
  return(0);
}

// This function implements table 10.1-1 of 36-213, p. 69
u8 get_ack(LTE_DL_FRAME_PARMS *frame_parms,
	   harq_status_t *harq_ack,
	   unsigned char subframe,
	   unsigned char *o_ACK) {

  //printf("get_ack: SF %d\n",subframe);
  u8 status=0;
  u8 subframe_dl;

  if (frame_parms->frame_type == FDD) {
    if (subframe < 4)
      subframe_dl = subframe + 6;
    else
      subframe_dl = subframe - 4;
    o_ACK[0] = harq_ack[subframe_dl].ack;
    status = harq_ack[subframe_dl].send_harq_status;
    printf("get_ack: Getting ACK/NAK for PDSCH (subframe %d) => %d\n",subframe_dl,o_ACK[0]);
  }
  else {
    switch (frame_parms->tdd_config) {
    case 1:
      if (subframe == 2) {  // ACK subframes 5 (forget 6)
	o_ACK[0] = harq_ack[5].ack;  
	status = harq_ack[5].send_harq_status;
      }
      else if (subframe == 3) {   // ACK subframe 9
	o_ACK[0] = harq_ack[9].ack;
	status = harq_ack[9].send_harq_status;
      }
      else if (subframe == 4) {  // nothing
	status = 0;
      }
      else if (subframe == 7) {  // ACK subframes 0 (forget 1)
	o_ACK[0] = harq_ack[0].ack;  
	status = harq_ack[0].send_harq_status;
      }
      else if (subframe == 8) {   // ACK subframes 4
	o_ACK[0] = harq_ack[4].ack;
	status = harq_ack[4].send_harq_status;
      }
      else {
	LOG_E(PHY,"phy_procedures_lte.c: get_ack, illegal subframe %d for tdd_config %d\n",
	    subframe,frame_parms->tdd_config);
	return(0);
      }
      break;
    case 3:
      if (subframe == 2) {  // ACK subframes 5 and 6
	if (harq_ack[5].send_harq_status == 1) {
	  o_ACK[0] = harq_ack[5].ack; 
	  if (harq_ack[6].send_harq_status == 1)
	    o_ACK[1] = harq_ack[6].ack;
	} 
	else if (harq_ack[6].send_harq_status == 1)
	  o_ACK[0] = harq_ack[6].ack;
	status = harq_ack[5].send_harq_status + (harq_ack[6].send_harq_status<<1);
      }
      else if (subframe == 3) {   // ACK subframes 7 and 8
	if (harq_ack[7].send_harq_status == 1) {
	  o_ACK[0] = harq_ack[7].ack; 
	  if (harq_ack[8].send_harq_status == 1)
	    o_ACK[1] = harq_ack[8].ack;
	} 
	else if (harq_ack[8].send_harq_status == 1)
	  o_ACK[0] = harq_ack[8].ack;

	status = harq_ack[7].send_harq_status + (harq_ack[8].send_harq_status<<1);
	//printf("status %d : o_ACK (%d,%d)\n", status,o_ACK[0],o_ACK[1]);
      }
      else if (subframe == 4) {  // ACK subframes 9 and 0
	if (harq_ack[9].send_harq_status == 1) {
	  o_ACK[0] = harq_ack[9].ack; 
	  if (harq_ack[0].send_harq_status == 1)
	    o_ACK[1] = harq_ack[0].ack;
	} 
	else if (harq_ack[8].send_harq_status == 1)
	  o_ACK[0] = harq_ack[8].ack;

	status = harq_ack[9].send_harq_status + (harq_ack[0].send_harq_status<<1);
      }
      else {
	LOG_E(PHY,"phy_procedures_lte.c: get_ack, illegal subframe %d for tdd_config %d\n",
	    subframe,frame_parms->tdd_config);
	return(0);
      }
      break;
    
    }
  }
  //printf("status %d\n",status);

  return(status);
}

u8 Np6[4]={0,1,3,5};
u8 Np15[4]={0,3,8,13};
u8 Np25[4]={0,5,13,22};
u8 Np50[4]={0,11,27,44};
u8 Np75[4]={0,16,41,66};
u8 Np100[4]={0,22,55,88};
// This is part of the PUCCH allocation procedure (see Section 10.1 36.213)
u16 get_Np(u8 N_RB_DL,u8 nCCE,u8 plus1) {
  u8 *Np;
  switch (N_RB_DL) {
    case 6:
      Np=Np6;
      break;
    case 15:
      Np=Np15;
      break;
    case 25:
      Np=Np25;
      break;
    case 50:
      Np=Np50;
      break;
    case 75:
      Np=Np75;
      break;
    case 100:
      Np=Np100;
      break;
    default:
      LOG_E(PHY,"get_Np() FATAL: unsupported N_RB_DL %d\n",N_RB_DL);
      return(0);
      break;
    }

  if (nCCE>=Np[2])
    return(Np[2+plus1]);
  else if (nCCE>=Np[1])
    return(Np[1+plus1]);
  else
    return(Np[0+plus1]);
}

lte_subframe_t subframe_select(LTE_DL_FRAME_PARMS *frame_parms,unsigned char subframe) {

  // if FDD return dummy value
  if (frame_parms->frame_type == 0)
    return(SF_DL);

  switch (frame_parms->tdd_config) {

  case 1:
    switch (subframe) {
    case 0:
    case 4:
    case 5:
    case 9:
      return(SF_DL);
      break;
    case 2:
    case 3:
    case 7:
    case 8:
      return(SF_UL);
      break;
    default:
      return(SF_S);
      break;
    }
  case 3:
    if  ((subframe<1) || (subframe>=5)) 
      return(SF_DL);
    else if ((subframe>1) && (subframe < 5))  
      return(SF_UL);
    else if (subframe==1)
      return (SF_S);
    else  {
      LOG_E(PHY,"[PHY_PROCEDURES_LTE] Unknown subframe number\n");
      return(255);
    }
    break;
  default:
    LOG_E(PHY,"subframe %d Unsupported TDD configuration %d\n",subframe,frame_parms->tdd_config);
    mac_xface->macphy_exit("");
    return(255);
    
  }
}

lte_subframe_t get_subframe_direction(u8 Mod_id,u8 subframe) {

  return(subframe_select(&PHY_vars_eNB_g[Mod_id]->lte_frame_parms,subframe));

}

u8 phich_subframe_to_harq_pid(LTE_DL_FRAME_PARMS *frame_parms,u32 frame,u8 subframe) {

  //LOG_D(PHY,"phich_subframe_to_harq_pid.c: frame %d, subframe %d\n",frame,subframe);
  return(subframe2harq_pid(frame_parms,
			   phich_frame2_pusch_frame(frame_parms,frame,subframe),
			   phich_subframe2_pusch_subframe(frame_parms,subframe)));
}

unsigned int is_phich_subframe(LTE_DL_FRAME_PARMS *frame_parms,unsigned char subframe) {

  if (frame_parms->frame_type == 0) {
    return(1);
  }
  else {
    switch (frame_parms->tdd_config) {
    case 1:
      if ((subframe == 1) || (subframe == 4) || (subframe == 6) || (subframe == 9))
	return(1);
      break;
    case 3:
      if ((subframe == 0) || (subframe == 8) || (subframe == 9))
	return(1);
      break;
    case 4:
      if ((subframe == 0) || (subframe == 8) )
	return(1);
      break;
    case 5:
      if (subframe == 0)
	return(1);
      break;
    default:
      return(0);
      break;
    }
  }
  return(0);
}


LTE_eNB_UE_stats* get_eNB_UE_stats(u8 Mod_id, u16 rnti) {
  s8 UE_id;
  if ((PHY_vars_eNB_g == NULL) || (PHY_vars_eNB_g[Mod_id] == NULL)) {
    LOG_E(PHY,"get_eNB_UE_stats: No phy_vars_eNB found (or not allocated) for Mod_id %d\n",Mod_id);
    return NULL;
  }
  UE_id = find_ue(rnti, PHY_vars_eNB_g[Mod_id]);
  if (UE_id == -1) {
    LOG_E(PHY,"get_eNB_UE_stats: UE with rnti %x not found\n",rnti);
    return NULL;
  }
  return(&PHY_vars_eNB_g[Mod_id]->eNB_UE_stats[(u32)UE_id]);
}

//TCS LOLAmesh
s8 find_ue(u16 rnti, PHY_VARS_eNB *phy_vars_eNB) {
  u8 i,j;
  u8 nb_corntis;

  for (i=0;i<NUMBER_OF_UE_MAX;i++) {
  	// We look for the rnti
    //  if( i < 2) LOG_D(PHY,"UE %d rnti %x \n", i, phy_vars_eNB->dlsch_eNB[i][0]->rnti);
    
    if ((phy_vars_eNB->dlsch_eNB[i]) && 
	(phy_vars_eNB->dlsch_eNB[i][0]) &&
	(phy_vars_eNB->dlsch_eNB[i][0]->rnti == rnti))  {
      return(i);
      
      /*for (j=0; j < 8 ; j++ ){
	if ((phy_vars_eNB->dlsch_eNB[i][0]->harq_processes[j]->rnti ==rnti) || 
	    (phy_vars_eNB->dlsch_eNB[i][0]->rnti == rnti))  {
	  return(i);
	  }
	}*/
    }
    // We look for the cornti
    if ((phy_vars_eNB->dlsch_eNB[i]) && (phy_vars_eNB->dlsch_eNB[i][0])) {
      nb_corntis = phy_vars_eNB->dlsch_eNB[i][0]->corntis.count;
       
      for (j=0;j<nb_corntis;j++) {
	//	LOG_D(PHY,"[eNB] nb cornti %d for UE %d %x\n", nb_corntis, i, phy_vars_eNB->dlsch_eNB[i][0]->corntis.array[j]);
	if ((phy_vars_eNB->dlsch_eNB[i][0]->corntis.array[j] == rnti)) {
	  return i;//return(j);
	}
      }
    }// if ((phy_vars_eNB->dlsch_eNB[i]) && (phy_vars_eNB->dlsch_eNB[i][0]))
  }// for (i=0;i<NUMBER_OF_UE_MAX;i++)

  return(-1);
}

s8 find_ue_with_active_cornti(u16 rnti, PHY_VARS_eNB *phy_vars_eNB) {
  u8 i,j;
  u8 nb_corntis;

  for (i=0;i<=NUMBER_OF_UE_MAX;i++) {
    
    if ((phy_vars_eNB->dlsch_eNB[i]) && 
	(phy_vars_eNB->dlsch_eNB[i][0]) && 
	(phy_vars_eNB->dlsch_eNB[i][0]->cornti_active > 0) ) {
      
      // phy_vars_eNB->dlsch_eNB[i][0]->cornti_active=0;
      nb_corntis = phy_vars_eNB->dlsch_eNB[i][0]->corntis.count;
      
      for (j=0;j<nb_corntis;j++) {
	if (phy_vars_eNB->dlsch_eNB[i][0]->corntis.array[j] == rnti) {
	  return i;
	}
      }
    }// if ((phy_vars_eNB->dlsch_eNB[i]) && (phy_vars_eNB->dlsch_eNB[i][0]))
  }// for (i=0;i<NUMBER_OF_UE_MAX;i++)
  
  return(-1);
}
u16 find_ue_cornti (u16 rnti, u8 UE_index, PHY_VARS_eNB *phy_vars_eNB) {

  u8 i,j;
  
  if ((phy_vars_eNB->dlsch_eNB[UE_index]) && 
      (phy_vars_eNB->dlsch_eNB[UE_index][0]) ){
    // &&  (phy_vars_eNB->dlsch_eNB[UE_index][0]->rnti)) {
    
    for (j=0;j<phy_vars_eNB->dlsch_eNB[UE_index][0]->corntis.count;j++) {
      if ((phy_vars_eNB->dlsch_eNB[UE_index][0]->corntis.array[j] == rnti)) {
	return rnti;
      }
    }
  }
  
  return(0x0);
  
}

u16 find_ue_with_active_cornti_ul (u16 rnti, u8 UE_index, PHY_VARS_eNB *phy_vars_eNB) {

  u8 i,j;
  
  if ((phy_vars_eNB->ulsch_eNB[UE_index])) {
    // &&  (phy_vars_eNB->dlsch_eNB[UE_index][0]->rnti)) {
    
    for (j=0;j<phy_vars_eNB->dlsch_eNB[UE_index][0]->corntis.count;j++) {
      if ((phy_vars_eNB->dlsch_eNB[UE_index][0]->corntis.array[j] == rnti)) {
	return rnti;
      }
    }
  }
  
  return(0x0);
  
}
u16 find_cornti (u16 rnti, PHY_VARS_eNB *phy_vars_eNB) {
  u8 i,j;
  
  for (i=0;i<NUMBER_OF_UE_MAX;i++) {
    if ((phy_vars_eNB->dlsch_eNB[i]) && 
	(phy_vars_eNB->dlsch_eNB[i][0]) && 
	(phy_vars_eNB->dlsch_eNB[i][0]->rnti)) {
            
      for (j=0;j<phy_vars_eNB->dlsch_eNB[i][0]->corntis.count;j++) {
	if ((phy_vars_eNB->dlsch_eNB[i][0]->corntis.array[j] == rnti)) {
	  return rnti;
	}
      }
    }
  }
  return(0x0);

}

u16 find_cornti_ue (u16 rnti, PHY_VARS_UE *phy_vars_UE) {
  u8 i,j;
  
  for (i=0;i<NUMBER_OF_eNB_MAX;i++) {
    if ((phy_vars_UE->lte_ue_pdcch_vars[i]) && 
	(phy_vars_UE->lte_ue_pdcch_vars[i]->crnti)) {
            
      for (j=0;j<phy_vars_UE->lte_ue_pdcch_vars[i]->corntis_count;j++) {
	if ((phy_vars_UE->lte_ue_pdcch_vars[i]->corntis_array[j] == rnti)) {
	  return rnti;
	}
      }
    }
  }
  return(0);

}
