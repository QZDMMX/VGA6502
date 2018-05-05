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
        
        SIGNAL T1,T2              : OUT std_logic;
        SIGNAL FTESTD             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) );    
END VGA_Mixer;

architecture behavior of VGA_Mixer is
    SIGNAL FBCNT:STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL FCCNT:STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL VBUSY,WRDY:STD_LOGIC;
    SIGNAL VDATA_BUF,LDATA:STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL LFDATA:STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL LFO:STD_LOGIC;

BEGIN

VRAM_CE2<='1';
VRAM_CE1<='0';
VRAM_OE1<=NOT VBUSY;

--RGB_OUT<="00000000";
T1<=VBUSY;
T2<=WRDY;

VDATA <= "ZZZZZZZZ" WHEN VBUSY = '1' ELSE VDATA_BUF;
FTESTD<="0000";

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

H_CNT: process(Clock)
BEGIN 
  IF Clock'event and Clock='1' THEN
      IF H_RESET='1' THEN
          FBCNT<="0000";
          FCCNT<="0000000";
          VBUSY<='1';
          WRDY<='0';
      ELSIF (H_POS<640) AND (V_ON='1') THEN
        IF FBCNT<"1001" THEN
          FBCNT<=FBCNT+1;
        ELSE
          FBCNT<="0000";
          FCCNT<=FCCNT+1;
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
        
        IF (FBCNT(0)='0') AND (H_POS(9)='0') THEN
          VRAM_ADDR<='0' & V_POS(8 DOWNTO 1) & H_POS(8 DOWNTO 1);
        ELSIF (FBCNT="1001") THEN
          VRAM_ADDR<="01111" & V_POS(9 DOWNTO 4) & FCCNT(5 DOWNTO 0);
        END IF;

        IF (FBCNT="0000") THEN
          LFO<=FONT_DATIN(15);
          LFDATA<=FONT_DATIN;
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
      END IF;
      
  END IF;
END process H_CNT;  

--VRAM_ADDR<="01111" & V_POS(9 DOWNTO 4) & FCCNT(5 DOWNTO 0);
FONT_ADDR<=VDATA(6 DOWNTO 0) & V_POS(3 DOWNTO 0);

END behavior;

