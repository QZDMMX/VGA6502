-- 
--  Horiz_sync  ------------------------------------__________--------
--  H_count       0                    640         659       755    799
--  pixel_column  0                    640
--  video_on      01---------------------10000000
--  RGB-OUT       001--------------------1000000
--  H_RESET       00--------------------------------------------------1
--  H_ST          012301230123
--  HBCNT         01234567890123456789
--                RRXRXRXRXRRRXRXRXRXR
--                                              H_count= 699
--  ------------------------------------------------------X-----------
--  V_count  
--  pixel_row     ][                  ]-------------------------------
--  Vert_sync      -----------------------------------------------_______------------
--  V_count         0                                      480    493-494          524
--
--  VRAM:
--  0000-F000:256*240 GRAM
--  F000-FFFF:4K      TRAM