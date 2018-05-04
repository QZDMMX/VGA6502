--
--
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;
LIBRARY lpm;
USE lpm.lpm_components.ALL;


ENTITY VGA_Mixer IS

   PORT(SIGNAL Clock 							: IN std_logic;
        SIGNAL H_RESET,H_ON,V_ON	: IN std_logic;
        SIGNAL H_POS,V_POS 				: IN STD_LOGIC_VECTOR(9 DOWNTO 0);

				SIGNAL SPI_CE,SPI_CK,SPI_DI: IN std_logic;
				
        SIGNAL GRAM_DAT 					: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL FONT_DAT						: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        
        SIGNAL VRAM_ADDR					: OUT STD_LOGIC_VECTOR(16 DOWNTO 0); 
        SIGNAL VRAM_OE,VRAM_WE,VRAM_CE: OUT std_logic;
        
        SIGNAL RGB_OUT						: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		
        SIGNAL ST_OUT							: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		    SIGNAL T1,T2,T3                 : OUT std_logic );		
END VGA_Mixer;

architecture behavior of VGA_Mixer is
BEGIN

VGA_RGB: process(Clock)
BEGIN 
	IF Clock'event and Clock='1' THEN

	END IF;
END process VGA_RGB;	

END behavior;

