/*

*/ 

#include "stm8s.h"

#define BRR     115200
#define Fosc    16000000 	
#define BRRL    (((Fosc)/(BRR))>>4)
#define BRRH    (((((Fosc)/(BRR))&0xf000)>>8)|(((Fosc)/(BRR))&0x000f))

#define SPI_CEL       GPIOA->ODR &=~(1<<3)
#define SPI_CEH       GPIOA->ODR |=(1<<3)
#define SPI_CKL       GPIOC->ODR &=~(1<<5)
#define SPI_CKH       GPIOC->ODR |=(1<<5)
#define SPI_SDL       GPIOC->ODR &=~(1<<6) 
#define SPI_SDH       GPIOC->ODR |=(1<<6)
#define SPI_SDI       (GPIOC->IDR & 0x80)

#define FPGA_CEL       GPIOA->ODR &=~(1<<1)
#define FPGA_CEH       GPIOA->ODR |=(1<<1)

#define CFG_NCFGL     GPIOD->ODR &=~(1<<4)
#define CFG_NCFGH     GPIOD->ODR |=(1<<4)
#define CFG_CKL       GPIOD->ODR &=~(1<<3)
#define CFG_CKH       GPIOD->ODR |=(1<<3)
#define CFG_SDL       GPIOD->ODR &=~(1<<2)
#define CFG_SDH       GPIOD->ODR |=(1<<2)
#define CFG_NST       (GPIOC->IDR & 0x08)
#define CFG_DONE      (GPIOC->IDR & 0x10)

@near uint8_t tbuf[300]; 
uint8_t st_cfg=0,cfg_ver=0;
uint16_t cfg_chksum=0;

static void HW_Config(void);

void delay_us(uint16_t k)
{ uint8_t w;

	do{	w=88;
		do {w--;} while(0);
		do {w--;} while(0);
	}while(--k);
}


//Shift out nb bits of d(MSB first)
void SPI_WDN(uint8_t d,uint8_t nb)
{   uint8_t m=0x80;

	for(;nb>0;nb--,m>>=1)
	{	SPI_CKL;
		if(d & m)  SPI_SDH;
		else       SPI_SDL;
        SPI_CKH;
	}
//    SPI_CKL;
}

void SPI_WD(uint8_t d)
{   uint8_t m;

	for(m=0x80;m>0;m>>=1)
	{	SPI_CKL;
		if(d & m)  SPI_SDH;
		else       SPI_SDL;
        SPI_CKH;
	}
    SPI_CKL;
}

uint8_t SPI_RD(void)
{   uint8_t n=0,i;

    SPI_SDH;
	for(i=0;i<8;i++)
	{	SPI_CKL;
		n<<=1;
		if(SPI_SDI)  n|=1;
		SPI_CKH;
	}
    SPI_CKL;
	return(n);
}

uint8_t FLASH_RDID(void)
{   uint8_t id;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x9F);	//RDID
	id=SPI_RD();
	if(id==0xC2){
	    id=SPI_RD();
	    id=SPI_RD();
	}
	else			//Err Manufacturer ID
	    id=0;	
	
	SPI_CEH;
	return(id);
}

uint8_t FLASH_RDSR(void)
{   uint8_t k;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x05);	//RDSR
	k=SPI_RD();
	SPI_CEH;
	SPI_CEH;
	return(k);
}

uint8_t FLASH_WRSR(uint8_t new_sr)
{   uint8_t w;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x06);	//WREN
	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x01);	//WRSR
    SPI_WD(new_sr);
	SPI_CEH;
	
	SPI_CEL;
	SPI_WD(0x05);	//RDSR
    w=40;
	while(w>0)
	{	if(!(SPI_RD() & 1)) break;
	    delay_us(1000);
		w--;
	}
	SPI_CEH;
	
	return(w);
}

uint8_t FLASH_ER_CHIP(void)
{   uint8_t w;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x06);	//WREN
	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x60);	//CHIP ERASE,6.5s typ.20s max
	SPI_CEH;

	SPI_CEL;
	SPI_WD(0x05);	//RDSR
    w=200;
	while(w>0)
	{	if(!(SPI_RD() & 1)) break;
	    delay_us(100000);
		w--;
	}
	SPI_CEH;
	
	return(w);
}

uint8_t FLASH_ER_BLOCK(uint32_t addr)
{   uint8_t w;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x06);	//WREN
	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x52);	//BLOCK ERASE,400ms typ. 2s max
	SPI_WD(addr>>16);
	SPI_WD(addr>>8);
	SPI_WD(addr & 255);
	SPI_CEH;

	SPI_CEL;
	SPI_WD(0x05);	//RDSR
    w=200;
	while(w>0)
	{	if(!(SPI_RD() & 1)) break;
	    delay_us(10000);
		w--;
	}
	SPI_CEH;
	
	return(w);
}

uint8_t FLASH_ER_SECTOR(uint32_t addr)
{   uint8_t w;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x06);	//WREN
	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x20);	//SECTOR ERASE,40ms typ. 0.2s max
	SPI_WD(addr>>16);
	SPI_WD(addr>>8);
	SPI_WD(addr & 255);
	SPI_CEH;

	SPI_CEL;
	SPI_WD(0x05);	//RDSR
    w=20;
	while(w>0)
	{	if(!(SPI_RD() & 1)) break;
	    delay_us(10000);
		w--;
	}
	SPI_CEH;
	
	return(w);
}

uint8_t FLASH_PROG_BYTE(uint32_t addr,uint8_t n)
{   uint8_t w;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x06);	//WREN
	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x02);	//BYTE PROG,9us typ. 50us max
	SPI_WD(addr>>16);
	SPI_WD(addr>>8);
	SPI_WD(addr & 255);
	SPI_WD(n);
	SPI_CEH;

	SPI_CEL;
	SPI_WD(0x05);	//RDSR
    w=50;
	while(w>0)
	{	if(!(SPI_RD() & 1)) break;
	    delay_us(1);
		w--;
	}
	SPI_CEH;
	
	return(w);
}

uint8_t FLASH_PROG_PAGE(uint32_t addr,@near uint8_t * buf,uint16_t cnt)
{   uint8_t w;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x06);//WREN
	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x02);	//PAGE PROG,50us typ. 3ms max
	SPI_WD(addr>>16);
	SPI_WD(addr>>8);
	SPI_WD(addr & 255);
	for(w=0;cnt>0;cnt--)
		SPI_WD(buf[w++]);
	SPI_CEH;

	SPI_CEL;
	SPI_WD(0x05);	//RDSR
    w=30;
	while(w>0)
	{	if(!(SPI_RD() & 1)) break;
	    delay_us(100);
		w--;
	}
	SPI_CEH;
	
	return(w);
}

uint8_t FLASH_RD_BYTE(uint32_t addr,uint8_t rd_end)
{	uint8_t w;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x03);	//READ
	SPI_WD(addr>>16);
	SPI_WD(addr>>8);
	SPI_WD(addr & 255);
	w=SPI_RD();	
	if(rd_end) SPI_CEH;
	
	return(w);	
}

uint16_t FLASH_RD_BUF(uint32_t addr,@near uint8_t * buf,uint16_t cnt)
{	uint16_t i;

	SPI_CEH;
	SPI_CEL;
	SPI_WD(0x03);	//READ
	SPI_WD(addr>>16);
	SPI_WD(addr>>8);
	SPI_WD(addr & 255);
	for(i=0;i<cnt;i++)
		buf[i]=SPI_RD();	
	SPI_CEH;
	
	return(cnt);	
}

void CFG_FPGA(void)
{	uint16_t i,n;
    uint8_t  j,k,t[6];
	
	st_cfg=0;
	cfg_ver=0;
	
	CFG_NCFGL;
	
	if(!FLASH_RDID())
	{	st_cfg=4;	//No CFG FLASH
		return;
	}
	FLASH_RD_BUF(0x1F000,t,6);
	if(t[0]!=0xCF)
	{	st_cfg=5;	//No CFG ID
		return;
	}
	
	cfg_ver=t[1];
	n=t[2]+(t[3]<<8);
	
	if(!n)
	{	st_cfg=6;	//CFG LEN Err
		return;
	}
	
//CFG SEQUENCE:
//DCLK=0;
//NCFG=0;DELAY 1MS;NCFG=1;
//WHEN NST=1,SEND ALL BYTES IN SEQ D0-->D7 @POSEDGE OF DCLK
//IF FCFGDONE=0,CFG ERR,ELSE SEND 100*0XFF 
	CFG_CKL;
	CFG_NCFGL;delay_us(1000);CFG_NCFGH;
	cfg_chksum=0;
	for(i=0;i<n;i++)
	{	if(i==0) k=FLASH_RD_BYTE(0x10000,0);
	    else     k=SPI_RD();
		
		cfg_chksum+=k;
		for(j=0;j<8;j++)
		{	if(k & 1)	CFG_SDH;
			else        CFG_SDL;
			CFG_CKH;
			k>>=1;
			CFG_CKL;
		}
	}
	SPI_CEH;
	
	if(CFG_DONE)
	{	CFG_SDH;
		for(i=0;i<800;i++) 
		{  CFG_CKH;CFG_CKL;  }
		if(CFG_NST) st_cfg=0;	//cfg OK
		else 		st_cfg=1;	//cfg Err
	}
	else	        st_cfg=2;	//cfg fail
	CFG_SDL;
	
//	n=t[4]+(t[5]<<8);
//	if(cfg_chksum!=n) st_cfg=0;
}

void WRITE_VRAM_PAGE(uint16_t addr,@near uint8_t * buf,uint16_t cnt)
{	uint16_t i;
	FPGA_CEH;
	FPGA_CEL;
	SPI_WD(0XD0);
	SPI_WD(addr & 0xff);
	SPI_WD(addr >>8);
	for(i=0;i<cnt;i++)
		SPI_WD(buf[i]);
	FPGA_CEH;
	FPGA_CEH;	
}

void main(void)
{
  uint16_t i,j,k,n,tout;
  uint8_t t,ck,pid,cmd,lastpid;
  
    
	HW_Config();
	
	FLASH_RD_BUF(0x1F000,tbuf,6);
	CFG_FPGA();
	k=0;
	n=0;
	ck=0;
	pid=0;
	lastpid=255;
	
	FPGA_CEH;
	FPGA_CEL;
	SPI_WD(0XD0);
	SPI_WD(0X00);
	SPI_WD(0X00);
	for(i=0;i<0XF000;i++)
		SPI_WD(i);

	FPGA_CEH;
	FPGA_CEH;
	FPGA_CEL;
	SPI_WD(0XD0);
	SPI_WD(0X00);
	SPI_WD(0XF0);
	for(i=0;i<0X1000;i++)
		SPI_WD(i);
	FPGA_CEH;

	for(i=0x20;i<=0x24;i++)
{	
	FPGA_CEH;
	FPGA_CEH;
	FPGA_CEL;
	SPI_WDN(0XD2,8);
	SPI_WDN(0XFF,8);
	SPI_WDN(0XFF,8);
	SPI_WDN(0XFF,8);
	SPI_WDN(0XFF,8);
	
	SPI_WDN(0XD8,8);	//Read Reg:11 0110 00-001 00000-Z0 hhhh hh-hh llll ll-ll xxxx xx
	SPI_WDN(i,8);
	
	FPGA_CEH;
	FPGA_CEH;
	FPGA_CEL;
	SPI_WDN(0XD3,8);
	k=SPI_RD();
	k=(k<<8) | SPI_RD();
	k=(k<<2) | (SPI_RD()>>6);
	UART1->DR=k>>8;
	UART1->DR=k;
	FPGA_CEH;
}
	//Cmd,pid,PLL,PLH,ADL,ADH,DLL,DLH
	tout=0;
	while(1)
	{
		if(UART1->SR & 0x0f)
		{	k=0;
			t=UART1->DR;
			continue; 
		}
		
        tout++;
		if(tout>10000)
		{	tout=0;
		    ck=0;
			k=0;
		}
		
		if(!(UART1->SR & UART1_SR_RXNE)) continue;
		
		tout=0;
		t=UART1->DR;
		ck+=t;
		tbuf[k++]=t;
		
		if(k==1) cmd=t;
		if(k==2) pid=t;
		if(k==4) n=tbuf[2]+(tbuf[3]<<8);
		if((k>4) && (k>n) && (ck==255)) // 
		{	if(cmd==0xA5)	//查询
			{	tbuf[0]=0x55;
			    tbuf[1]=pid;
			    tbuf[2]=st_cfg;
				tbuf[3]=cfg_ver;
				tbuf[4]=cfg_chksum;
			    tbuf[5]=cfg_chksum >>8;
				for(i=0;i<6;i++)
				{	UART1->DR=tbuf[i];
					while(!(UART1->SR & UART1_SR_TC)) {}
				}
				
				FPGA_CEH;
				FPGA_CEL;
				SPI_WD(0XD0);
				SPI_WD(0X00);
				SPI_WD(0X00);
				for(i=0;i<0XF000;i++)
				    SPI_WD(0);
				FPGA_CEH;
				FPGA_CEH;
				FPGA_CEL;
				SPI_WD(0XD0);
				SPI_WD(0X00);
				SPI_WD(0XF0);
				for(i=0;i<0X1000;i++)
				    SPI_WD(0);
				FPGA_CEH;
				
			}
			else if(cmd==0xAD)	//下载
			{	if(pid!=lastpid)
				{	CFG_NCFGL;
					j=tbuf[4]+(tbuf[5]<<8);
					if(j==0)	FLASH_ER_BLOCK(0x10000);
					k=tbuf[6]+(tbuf[7]<<8);
					FLASH_PROG_PAGE(0x10000+j,tbuf+8,k);
					lastpid=pid;
				}
				UART1->DR=0x5D;while(!(UART1->SR & UART1_SR_TC)) {}
				UART1->DR=pid;while(!(UART1->SR & UART1_SR_TC)) {}
			}
			else if(cmd==0xAF)	//逐块校验
			{	//if(pid!=lastpid)
				{	CFG_NCFGL;
					j=tbuf[4]+(tbuf[5]<<8);					
					n=tbuf[6]+(tbuf[7]<<8);
					k=tbuf[8];
					FLASH_RD_BUF(0x10000+j,tbuf,n);
					ck=0;
					for(i=0;i<n;i++) ck+=tbuf[i];
				}
				if(k==ck)
				{
				    UART1->DR=0x5F;while(!(UART1->SR & UART1_SR_TC)) {}
				    UART1->DR=pid;while(!(UART1->SR & UART1_SR_TC)) {}
				}
			}
			else if(cmd==0xAC)		//配置FPGA
			{	//tbuf[4]=0xCF; //CFG ID
			    //tbuf[5]=Version;
				n=tbuf[6]+(tbuf[7]<<8);	//LEN
				k=tbuf[8]+(tbuf[9]<<8); //chksum
				st_cfg=0;
				CFG_NCFGL;
				if(n>0)
				{		
				//	j=FLASH_RD_BYTE(0x10000,0);
				//	for(i=1;i<n;i++) j+=SPI_RD();
				//	SPI_CEH;
				//	if(j!=k) st_cfg=3;	//CFG DATA MISMATCH;
				//	else
					{	FLASH_ER_SECTOR(0x1F000);
					    FLASH_PROG_PAGE(0x1F000,tbuf+4,6);
					}
				}
				if(!st_cfg) 
				    CFG_FPGA();
				if(!st_cfg)
				{	UART1->DR=0x5C;while(!(UART1->SR & UART1_SR_TC)) {}
				    UART1->DR=pid;while(!(UART1->SR & UART1_SR_TC)) {}
				}
			}
			else if(cmd==0xAE)	//写VRAM
			{	if(pid!=lastpid)
				{//	CFG_NCFGL;
					j=tbuf[4]+(tbuf[5]<<8);
				//	if(j==0)	FLASH_ER_BLOCK(0x10000);
					k=tbuf[6]+(tbuf[7]<<8);
				//	FLASH_PROG_PAGE(0x10000+j,tbuf+8,k);
				    WRITE_VRAM_PAGE(j,tbuf+8,k);
					lastpid=pid;
				}
				UART1->DR=0x5E;while(!(UART1->SR & UART1_SR_TC)) {}
				UART1->DR=pid;while(!(UART1->SR & UART1_SR_TC)) {}
			}
			
			k=0;
			ck=0;
		}
		else if(k>298)
			k=0;
	}
	
	

//    FLASH_WRSR(0);
//	UART1->DR=FLASH_RDSR();
	
    while (1)
    {	
		
//		GPIOA->ODR &= ~(1<<3);
//		SPI->DR=0x0E;
//		while(!(SPI->SR & SPI_SR_TXE));
		//if (SPI->SR & SPI_SR_RXNE) read_from SPI->DR
    }
}


static void HW_Config(void)
{
//  GPIO_Init(GPIOB, GPIO_PIN_4, GPIO_MODE_OUT_OD_HIZ_SLOW);	//I2C SCL
//  GPIO_Init(GPIOB, GPIO_PIN_5, GPIO_MODE_OUT_OD_HIZ_SLOW);	//I2C SDA

//  GPIO_Init(GPIOD, GPIO_PIN_5, GPIO_MODE_OUT_PP_HIGH_FAST);	//TXD
//	GPIO_Init(GPIOD, GPIO_PIN_6, GPIO_MODE_IN_PU_NO_IT);		//RXD
	
//	GPIO_Init(GPIOA, GPIO_PIN_3, GPIO_MODE_OUT_PP_HIGH_FAST);	//SPI_NSS
//	GPIO_Init(GPIOC, GPIO_PIN_5, GPIO_MODE_OUT_PP_HIGH_FAST);	//SPI_CLK
//	GPIO_Init(GPIOC, GPIO_PIN_6, GPIO_MODE_OUT_PP_HIGH_FAST);	//SPI_MOSI
//	GPIO_Init(GPIOC, GPIO_PIN_7, GPIO_MODE_IN_PU_NO_IT);		//SPI_MISO
	
//	GPIO_Init(GPIOD, GPIO_PIN_2, GPIO_MODE_OUT_PP_HIGH_FAST);	//FDATA
//	GPIO_Init(GPIOD, GPIO_PIN_3, GPIO_MODE_OUT_PP_HIGH_FAST);	//FDCLK
//	GPIO_Init(GPIOD, GPIO_PIN_4, GPIO_MODE_OUT_PP_HIGH_FAST);	//FNCFG
//	GPIO_Init(GPIOC, GPIO_PIN_3, GPIO_MODE_IN_PU_NO_IT);		//FNST
//	GPIO_Init(GPIOC, GPIO_PIN_4, GPIO_MODE_IN_PU_NO_IT);		//FCFG_DONE
	
//	GPIO_Init(GPIOA, GPIO_PIN_1, GPIO_MODE_OUT_PP_HIGH_FAST);	//PA1
//	GPIO_Init(GPIOA, GPIO_PIN_2, GPIO_MODE_OUT_PP_HIGH_FAST);	//PA2
	
/* Set High speed internal clock prescaler=1 */
    CLK->CKDIVR = 0;

	//Init gpio
	//PA1-PA3=HS OUT,PA3=NSS;
    GPIOA->DDR = 1<<1|1<<2|1<<3;
    GPIOA->CR1 = 1<<1|1<<2|1<<3;
    GPIOA->CR2 = 0<<1|0<<2|1<<3;
    GPIOA->ODR = 0<<1|0<<2|0<<3;
	
	//PB4-5=I2C OD IN
    GPIOB->DDR = 0<<4|0<<5;
    GPIOB->CR1 = 0<<4|0<<5;
    GPIOB->CR2 = 0<<4|0<<5;
    GPIOB->ODR = 1<<4|1<<5;
	
	//PC5-6=HS OUT,PC3/PC4/PC7=HS IN
    GPIOC->DDR = 0<<3|0<<4|1<<5|1<<6|0<<7;	
    GPIOC->CR1 = 1<<3|1<<4|1<<5|1<<6|1<<7;	
    GPIOC->CR2 = 0<<3|0<<4|1<<5|1<<6|0<<7;
    GPIOC->ODR = 1<<3|1<<4|0<<5|0<<6|0<<7;

	//PD2-5=HS OUT,PD5=TXD,PD6=RXD
    GPIOD->DDR = 1<<2|1<<3|1<<4|1<<5|0<<6|0<<7;
    GPIOD->CR1 = 1<<2|1<<3|1<<4|1<<5|1<<6|0<<7;
    GPIOD->CR2 = 1<<2|1<<3|1<<4|1<<5|0<<6|0<<7;
    GPIOD->ODR = 0<<2|0<<3|0<<4|1<<5|0<<6|0<<7;	
	
	//Init uart
    UART1->CR1=0x00;
    UART1->CR2=0x00;
    UART1->CR3=0x00;
    UART1->BRR2=BRRH;			//设置波特率 先给BRR2赋值
    UART1->BRR1=BRRL;			//再给BRR1赋值
	UART1->CR2|=0X0C;     		//Ten=1,Ren=1
	
//	SPI->CR1=0<<7|SPI_CR1_MSTR;	//MSB first,fosc/2,Master
//	SPI->CR2=0;
//	SPI->ICR=0;

//	SPI->CR1 |=SPI_CR1_SPE;
	
}

/**
  * @brief  UART1 and UART3 Configuration for half duplex communication
  * @param  None
  * @retval None
  */

#ifdef USE_FULL_ASSERT

/**
  * @brief  Reports the name of the source file and the source line number
  *   where the assert_param error has occurred.
  * @param file: pointer to the source file name
  * @param line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t* file, uint32_t line)
{ 
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */

  /* Infinite loop */
  while (1)
  {
  }
}
#endif

/**
  * @}
  */

/******************* (C) COPYRIGHT 2011 STMicroelectronics *****END OF FILE****/
