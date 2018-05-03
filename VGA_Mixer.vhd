--
--
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;
LIBRARY lpm;
USE lpm.lpm_components.ALL;


ENTITY VGA_Mixer IS

   PORT(SIGNAL Clock 					: IN std_logic;
        SIGNAL RB1,GB1,BB1 				: IN std_logic;
        SIGNAL RB2,GB2,BB2				: IN std_logic;
        SIGNAL RBOX,GBOX,BBOX			: IN std_logic;
        SIGNAL RTXT,GTXT,BTXT			: IN std_logic;
		
		SIGNAL RO,GO,BO                 : OUT std_logic );		
END VGA_Mixer;

architecture behavior of VGA_Mixer is
BEGIN

VGA_RGB: process(Clock)
BEGIN 
	IF Clock'event and Clock='1' THEN
		RO<=RB1 OR RB2 OR RBOX OR RTXT;
		GO<=GB1 OR GB2 OR GBOX OR GTXT;
		BO<=BB1 OR BB2 OR BBOX OR BTXT;
	END IF;
END process VGA_RGB;	

END behavior;

