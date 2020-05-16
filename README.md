# Next186_SiDi
Port for SiDi / MiST of Next186 core.

The core boots, but you need to load the bios that are looking for it in the last 8k of the SD.
I can not access the SD, connecting an SD directly to the FPGA works but through ARM I can not access, I have also tried with VHD file but without success.
Another problem is that when implementing the MIST framework I run out of M9K memory since the core occupies all the memory.
I have used Quartus 17.1 to generate the clocks, if you try for MIST Quartus 13.1 you have to delete all the .QIP files.
