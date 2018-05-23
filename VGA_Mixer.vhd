--
--
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;
LIBRARY lpm;
USE lpm.lpm_components.ALL;


ENTITY VGA_Mixer IS

   PORT(SIGNAL Clock              : IN std_logic;
        SIGNAL H_RESET,H_ON,V_ON  : IN std_logic;
        SIGNAL H_POS,V_POS        : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

        SIGNAL SPI_CE,SPI_CK,SPI_DI: IN std_logic;
        
        SIGNAL FONT_DATIN         : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        
        SIGNAL NET_CDV,NET_ERR    : IN std_logic;
        SIGNAL NET_RXD            : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        SIGNAL CLK50              : IN std_logic;
        
        SIGNAL VRAM_ADDR          : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); 
        SIGNAL VRAM_OE1,VRAM_WE1  : OUT std_logic;
        SIGNAL NBUF_CER,VRAM_CEL  : OUT std_logic;
        
        SIGNAL SPI_DO             : OUT std_logic;
        SIGNAL RGB_OUT            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    
        SIGNAL FONT_ADDR          : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
        SIGNAL VDATA              : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        
        SIGNAL TESTO              : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL ST                 : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        SIGNAL FTESTD             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        SIGNAL NRSTO              : OUT std_logic;
        SIGNAL NMCLK              : OUT std_logic;
        SIGNAL NMDIO              : INOUT std_logic;

        SIGNAL NET_TXE            : OUT std_logic;
        SIGNAL NET_TXD            : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);

        SIGNAL NBUF_ADDR          : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); 
        SIGNAL NBUF_OE,NBUF_WE    : OUT std_logic;
        SIGNAL NDATA              : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL STO                : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
         );    
END VGA_Mixer;

architecture behavior of VGA_Mixer is
    SIGNAL FBCNT,FVCNT:STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL TCCNT,FCCNT:STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL VBUSY,WRDY:STD_LOGIC;
    SIGNAL VDATA_BUF,LDATA:STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL LFDATA:STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL LFO:STD_LOGIC;

    SIGNAL SPI_BCNT,SPI_ST:STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL SPI_DBUF,SPI_SDO:STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL SPI_ADDR:STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL SPI_WR,SPI_W1,SPI_W2,SPI_WCLR:STD_LOGIC;
    
    SIGNAL SPI_CON:STD_LOGIC_VECTOR(5 DOWNTO 0);
    
    SIGNAL NRST,NRP_NA16,NRP_RST:STD_LOGIC;
    SIGNAL SPI_NRD,SPI_NWR,SPI_NSD:STD_LOGIC; 

    SIGNAL NET_SST  :STD_LOGIC_VECTOR(1 DOWNTO 0);         
    SIGNAL NET_SCNT :STD_LOGIC_VECTOR(1 DOWNTO 0);         
    SIGNAL NET_SPTR :STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL NET_STAG,NET_SAVETAG :STD_LOGIC_VECTOR(31 DOWNTO 0);
    
    SIGNAL NET_WDAT,NET_SBUF :STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL NET_WR,NA16,WL1,WL2:STD_LOGIC;
    
BEGIN

VRAM_CEL<='0';
NBUF_CER<='0';
VRAM_OE1<=NOT VBUSY;
VRAM_WE1<=NOT SPI_WCLR;

--T1<=WRDY;
ST<=FVCNT & FCCNT;

VDATA <= "ZZZZZZZZ" WHEN SPI_WCLR = '0' ELSE VDATA_BUF;

NRSTO <=NRST;
NMDIO <= SPI_DI WHEN (SPI_CON(1 DOWNTO 0)="10") AND (SPI_CON(4 DOWNTO 3)="00") ELSE 'Z';
NMCLK <= (NOT SPI_CK) WHEN (SPI_CON(1)='1') AND (SPI_CON(4 DOWNTO 3)="00") ELSE NRP_RST;  --'0';  --NOTE MCLK IS NOT SPI_CK!!!

SPI_DO<= NMDIO WHEN (SPI_CON(1 DOWNTO 0)="11") AND (SPI_CON(4 DOWNTO 3)="00") ELSE SPI_SDO(7);
 
FTESTD<=FBCNT;

--NRP_RST<='1' WHEN (SPI_ST<"100") AND (SPI_CON(4 DOWNTO 3)="01") ELSE '0';
TESTO<=SPI_SDO;
STO<=NET_SST;

NBUF_OE<='0' WHEN (SPI_CON(1 DOWNTO 0)="10") AND (SPI_CON(4 DOWNTO 3)="10") ELSE '1';
NBUF_WE<='1' WHEN (SPI_CON(4 DOWNTO 3)>="10") OR (NET_WR='0') ELSE (CLK50 AND NET_WR);

NA16<='1' WHEN SPI_CON(4 DOWNTO 3)>"10" ELSE '0';
NBUF_ADDR<=(NA16 & SPI_ADDR) WHEN SPI_CON(4 DOWNTO 3)>"01" ELSE ('0' & NET_SPTR);
NDATA<=NET_WDAT WHEN (NET_SST>"00") AND (SPI_CON(4 DOWNTO 3)<="01") ELSE "ZZZZZZZZ" ;


NET_RCV:process(CLK50,NRP_RST)
BEGIN
  IF NRP_RST='1' THEN
      NET_SPTR<=CONV_STD_LOGIC_VECTOR(0,16);    --For Rcv-Packet Buf-Ptr
      NET_SST<="11";                            --WAIT FOR SFD
      NET_STAG<=CONV_STD_LOGIC_VECTOR(0,32);    --For Rcv-Packet Time-Tag
      NET_SCNT<="00";
      NET_WR<='0';
      WL1<='0';
      WL2<='0';
  ELSIF CLK50'event and CLK50='1' THEN
      IF NET_STAG(31 DOWNTO 28)<"1111" THEN     --MAX TIMER COUNTER=80.53S
          NET_STAG<=NET_STAG+1;
      END IF;
      
      NET_SBUF<=NET_RXD & NET_SBUF(7 DOWNTO 2);
      
      IF NET_SST="00" THEN
          IF  NET_CDV='1' AND NET_RXD="11" THEN
              IF SPI_CON(4 DOWNTO 3)<="01" THEN
                  NET_SST<="01";
              ELSE
                  NET_SST<="11";
              END IF;   
          END IF;
          
          NET_SAVETAG<=NET_STAG;
          NET_WR<='0';      
          NET_SCNT<="00";
      ELSIF NET_SST="01"  AND NET_CDV='1' THEN
          IF SPI_CON(4 DOWNTO 3)>"01" THEN
              NET_SST<="11";
          ELSIF NET_SCNT="00" THEN
              NET_WDAT<=NET_SBUF; --NET_SAVETAG(7 DOWNTO 0);
              NET_WR<='1';
          ELSIF NET_SCNT="01" THEN
              NET_WDAT<=NET_SAVETAG(15 DOWNTO 8);
              NET_WR<='1';
              NET_SPTR<=NET_SPTR+1;
          ELSIF NET_SCNT="10" THEN
              NET_WDAT<=NET_SAVETAG(23 DOWNTO 16);
              NET_WR<='1';
              NET_SPTR<=NET_SPTR+1;
          ELSE
              NET_WDAT<=NET_SAVETAG(31 DOWNTO 24);
              NET_WR<='1';
              NET_SPTR<=NET_SPTR+1;
              NET_SST<="10";
          END IF; 
          
          
          NET_SCNT<=NET_SCNT+1;
          
               
      ELSIF NET_SST="10"  THEN
          IF SPI_CON(4 DOWNTO 3)>"01" THEN
              NET_SST<="11";
          ELSIF  NET_CDV='1' THEN
              IF NET_SCNT="00" THEN
                  NET_WDAT<=NET_SBUF;
                  NET_SPTR<=NET_SPTR+1;
                  NET_WR<='1';
              ELSE         
                  NET_WR<='0';
              END IF;
              WL1<='0';
              WL2<='0'; 
          ELSE
              IF NET_SCNT="00" THEN
                  NET_WDAT<=NET_SBUF;
                  NET_SPTR<=NET_SPTR+1;
                  NET_WR<='1';
              ELSIF WL1='0' THEN
                  NET_SAVETAG(15 DOWNTO 0)<=NET_SPTR AND "0000011111111111";
                  WL1<='1';
                  NET_WDAT<=NET_SPTR(7 DOWNTO 0);
                  NET_SPTR<=(NET_SPTR AND "1111100000000000");
                  NET_WR<='1';
              ELSIF WL2='0' THEN
                  WL2<='1';
                  NET_WDAT<=NET_SAVETAG(15 DOWNTO 8);
                  NET_SPTR<=NET_SPTR+1;
                  NET_WR<='1';
              ELSE
                  NET_WR<='0';         
                  IF NET_SPTR(15 DOWNTO 11)<"11111" THEN
                      NET_SPTR(15 DOWNTO 11)<=NET_SPTR(15 DOWNTO 11)+1;
                  END IF;
                  NET_SST<="11";
              END IF; 

          END IF;
          
          NET_SCNT<=NET_SCNT+1;
          
      ELSIF NET_SST="11" THEN
          NET_SPTR<=(NET_SPTR AND "1111100000000000") OR "0000000000000010";
          IF NET_CDV='0' THEN
              NET_SST<="00";
          END IF;
          NET_WR<='0';
          
      ELSE      
          NET_WR<='0';          
      END IF;     
      
  END IF;
END process NET_RCV; 


SPI: process(SPI_CK,SPI_CE)
BEGIN 
  IF SPI_CE='1' THEN
      SPI_ST<="000";
      SPI_BCNT<="000";
      SPI_WR<='0';

--      NRST<='0';
      SPI_CON<="000000";
      SPI_SDO<="11111111";
  ELSIF SPI_CK'event and SPI_CK='1' THEN
      SPI_DBUF<=SPI_DBUF(6 DOWNTO 0) & SPI_DI;
      
      SPI_BCNT<=SPI_BCNT+1;
      IF SPI_BCNT="111" THEN
          IF SPI_ST(2)='0' THEN   -- 0->1->2->3->4->4.....
              SPI_ST<=SPI_ST+1;
          END IF;
          
          IF SPI_ST="000" AND SPI_DBUF(6 DOWNTO 5)="10" THEN
              NRST<=SPI_DBUF(0) OR NRST;  --FOR FIRST SPI-CMD,NET RST ENDS

              SPI_CON(5)<=SPI_DBUF(4);     -- =1  WHEN IN NBUF WRITE ,SEND PACKET;WHEN NET-RCV,RESET BUF-PTR 
              SPI_CON(4)<=SPI_DBUF(3);     -- =00 FOR SMI OP,=01 FOR NET-RCV,=10 FOR NBUF READ(PAGE 0),=11 FOR NBUF SEND & SEND (PAGE 1)
              SPI_CON(3)<=SPI_DBUF(2);     -- SPI_CON(4 DOWNTO 3) AS ABOVE

              SPI_CON(2)<='1';             -- =1 FOR VALID CMD
              SPI_CON(1)<=SPI_DBUF(0);     -- ='0' FOR VGA STORE,='1' FOR NET/MDC_MDIO OP
              SPI_CON(0)<=SPI_DI;          -- ='0' FOR MDIO OUT,='1' FOR SMI-MDIO INPUT                
              
              IF SPI_DBUF(4 DOWNTO 2)="101" THEN    --RESET NET-RCV BUF-PTR
                  NRP_RST<='1';
              END IF; 
              
--              SPI_SDO<="01111110";           
          END IF;
          
          IF SPI_ST="001" AND SPI_CON(2)='1' THEN
              SPI_ADDR(7 DOWNTO 0)<=SPI_DBUF(6 DOWNTO 0) & SPI_DI;
              NRP_RST<='0';              
          END IF;
          
          IF SPI_ST="010" AND SPI_CON(2)='1' THEN
              SPI_ADDR(15 DOWNTO 8)<=SPI_DBUF(6 DOWNTO 0) & SPI_DI;              
          END IF;
          
          IF SPI_ST="011" AND SPI_CON(2)='1' AND SPI_CON(1)='0' THEN
              SPI_WR<='1';
          END IF;

          IF SPI_ST(2)='1' AND SPI_CON(2)='1' AND SPI_CON(1)='0' THEN
              SPI_ADDR<=SPI_ADDR+1;
              SPI_WR<='1';
          END IF;

          IF SPI_ST>="011" AND SPI_CON(2)='1' AND SPI_CON(1)='1' THEN

              IF SPI_CON(4 DOWNTO 3)="01" THEN
                  SPI_SDO<=NET_SPTR(15 DOWNTO 8);
              ELSIF (SPI_CON(4 DOWNTO 3)="10") THEN
                  SPI_NRD<='1';
                  SPI_SDO<=NDATA;
              ELSIF (SPI_CON(4 DOWNTO 3)="11") THEN
                  SPI_NWR<='1';
                  SPI_NSD<=SPI_CON(5);                  
              END IF;   
              SPI_ADDR<=SPI_ADDR+1;
          ELSE
              SPI_SDO<=NET_SPTR(15 DOWNTO 8);
          END IF;                              
      ELSE
          SPI_SDO<=SPI_SDO(6 DOWNTO 0) & '0';
          SPI_WR<='0';
          SPI_NRD<='0';
          SPI_NWR<='0';  
          SPI_NSD<='0';  
      END IF;
  END IF;     
    
END process SPI; 
 
SPIWA: process(SPI_WR,SPI_WCLR)
BEGIN
  IF SPI_WCLR='1' THEN
    SPI_W1<='0';
  ELSIF SPI_WR'event and SPI_WR='1' THEN
    SPI_W1<='1';
  END IF;
END process SPIWA; 

SPIWB: process(Clock,SPI_WCLR)
BEGIN
  IF SPI_WCLR='1' THEN
    SPI_W2<='0';
  ELSIF Clock'event and Clock='1' THEN
    SPI_W2<=SPI_W1;
    VDATA_BUF<=SPI_DBUF;
  END IF;
END process SPIWB; 

RGB: process(LDATA,LFO,FBCNT,VDATA)
BEGIN
  IF (FBCNT(0)='0') THEN
    RGB_OUT<=(LFO OR LDATA(7)) & (LFO OR LDATA(6)) & (LFO OR LDATA(5)) & (LFO OR LDATA(4)) & LDATA(3) & (LFO OR LDATA(2)) & (LFO OR LDATA(1)) & LDATA(0) ;
  ELSIF (H_POS(9)='0') THEN
    RGB_OUT<=(LFO OR VDATA(7)) & (LFO OR VDATA(6)) & (LFO OR VDATA(5)) & (LFO OR VDATA(4)) & VDATA(3) & (LFO OR VDATA(2)) & (LFO OR VDATA(1)) & VDATA(0) ;
  ELSE
    RGB_OUT<=(LFO) & (LFO) & (LFO) & (LFO) & '0' & (LFO) & (LFO) & '0' ;
  END IF;     
    
END process RGB; 

SCANV: process(H_ON,V_ON)
BEGIN
  IF V_ON='0' THEN
      FVCNT<="0000";
  ELSIF H_ON'event and H_ON='0' THEN
      FVCNT<=FVCNT+1;
  END IF;
END process SCANV; 

SCAN: process(Clock)
BEGIN
  IF Clock'event and Clock='1' THEN
      IF V_ON='0' THEN
          FBCNT<="0000";
          FCCNT<="000000000000";
          TCCNT<="000000000000";
          
          VBUSY<='0';
          WRDY<='1';
--          LDATA<="00000000";
          
          IF WRDY='1' AND SPI_W2='1' THEN
              VRAM_ADDR<='0' & SPI_ADDR;
              SPI_WCLR<='1';
          ELSE
              SPI_WCLR<='0';
          END IF;
      ELSIF H_RESET='1' THEN
          VBUSY<='1';
          WRDY<='0';
          SPI_WCLR<='0';
          VRAM_ADDR<="01111" & TCCNT;
          FCCNT<=TCCNT;
      ELSIF H_POS<640 THEN
          IF FBCNT<"1001" THEN
              FBCNT<=FBCNT+1;
          ELSE
              FBCNT<="0000";
          END IF;
          
          IF FBCNT="0001" THEN
              FCCNT<=FCCNT+1;
          END IF;
          
          IF FBCNT="0001" AND FVCNT="1111" THEN
              TCCNT<=TCCNT+1;
          END IF;
          
          IF (FBCNT(0)='0') OR (FBCNT="1001") THEN
              VBUSY<='1';
          ELSE
              VBUSY<='0';
          END IF;

          IF (FBCNT(3)='0') AND (FBCNT(0)='0') THEN
              WRDY<='1';
          ELSE
              WRDY<='0';
          END IF;
        
          IF WRDY='1' AND SPI_W2='1' THEN
              VRAM_ADDR<='0' & SPI_ADDR;
              SPI_WCLR<='1';
          ELSE
              SPI_WCLR<='0';
              IF (FBCNT(0)='0') AND (H_POS(9)='0') THEN
                  VRAM_ADDR<='0' & V_POS(8 DOWNTO 1) & H_POS(8 DOWNTO 1);
              ELSIF (FBCNT="1001") THEN
                  VRAM_ADDR<="01111" & FCCNT;
              END IF;   
          END IF;
          
          IF (FBCNT="0000") THEN
              LFO<=FONT_DATIN(15) XOR VDATA(7);
              IF VDATA(7)='1' THEN
                  LFDATA<=NOT FONT_DATIN;
              ELSE
                  LFDATA<= FONT_DATIN;
              END IF;
          ELSE
              LFO<=LFDATA(CONV_INTEGER(NOT FBCNT));
          END IF;

          IF H_POS(9)='0' THEN
              LDATA<=VDATA;
          ELSE
              LDATA<="00000000";
          END IF;
      ELSE
          VBUSY<='0';
          WRDY<='1';
        
          IF WRDY='1' AND SPI_W2='1' THEN
              VRAM_ADDR<='0' & SPI_ADDR;
              SPI_WCLR<='1';
          ELSE
              SPI_WCLR<='0';
          END IF;
           
      END IF;   
  END IF; 
END process SCAN; 


FONT_ADDR<=VDATA(6 DOWNTO 0) & FVCNT(3 DOWNTO 0);

END behavior;

