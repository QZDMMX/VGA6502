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
        
        SIGNAL VRAM_ADDR          : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); 
        SIGNAL VRAM_OE1,VRAM_WE1  : OUT std_logic;
        SIGNAL VRAM_CE1,VRAM_CE2  : OUT std_logic;
        
        SIGNAL SPI_DO             : OUT std_logic;
        SIGNAL RGB_OUT            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    
        SIGNAL FONT_ADDR          : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
        SIGNAL VDATA              : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        
        SIGNAL T1                 : OUT std_logic;
        SIGNAL ST                 : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        SIGNAL FTESTD             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) );    
END VGA_Mixer;

architecture behavior of VGA_Mixer is
    SIGNAL FBCNT,FVCNT:STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL TCCNT,FCCNT:STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL VBUSY,WRDY:STD_LOGIC;
    SIGNAL VDATA_BUF,LDATA:STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL LFDATA:STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL LFO:STD_LOGIC;

    SIGNAL SPI_BCNT,SPI_CON,SPI_ST:STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL SPI_DBUF:STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL SPI_ADDR:STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL SPI_WR,SPI_W1,SPI_W2,SPI_WCLR:STD_LOGIC;

BEGIN

VRAM_CE2<='1';
VRAM_CE1<='0';
VRAM_OE1<=NOT VBUSY;
VRAM_WE1<=NOT SPI_WCLR;

T1<=WRDY;
ST<=FVCNT & FCCNT;

VDATA <= "ZZZZZZZZ" WHEN SPI_WCLR = '0' ELSE VDATA_BUF;

FTESTD<=FBCNT;

SPI: process(SPI_CK,SPI_CE)
BEGIN 
  IF SPI_CE='1' THEN
      SPI_ST<="000";
      SPI_BCNT<="000";
      SPI_WR<='0';
      SPI_CON(2)<='0';
  ELSIF SPI_CK'event and SPI_CK='1' THEN
      SPI_DBUF<=SPI_DBUF(6 DOWNTO 0) & SPI_DI;
      
      SPI_BCNT<=SPI_BCNT+1;
      IF SPI_BCNT="111" THEN
          IF SPI_ST(2)='0' THEN
              SPI_ST<=SPI_ST+1;
          END IF;
          
          IF SPI_ST="000" AND SPI_DBUF(6 DOWNTO 3)="1101" THEN
              SPI_CON(2)<='1';
              SPI_CON(1)<=SPI_DBUF(0);
              SPI_CON(0)<=SPI_DI;
          END IF;
          
          IF SPI_ST="001" AND SPI_CON(2)='1' THEN
              SPI_ADDR(7 DOWNTO 0)<=SPI_DBUF(6 DOWNTO 0) & SPI_DI;
          END IF;
          
          IF SPI_ST="010" AND SPI_CON(2)='1' THEN
              SPI_ADDR(15 DOWNTO 8)<=SPI_DBUF(6 DOWNTO 0) & SPI_DI;
          END IF;
          
          IF SPI_ST="011" AND SPI_CON(2)='1' THEN
              SPI_WR<='1';
          END IF;

          IF SPI_ST(2)='1' AND SPI_CON(2)='1' THEN
              SPI_ADDR<=SPI_ADDR+1;
              SPI_WR<='1';
          END IF;
      ELSE
          SPI_WR<='0';    
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
              		LFDATA<=FONT_DATIN;
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

