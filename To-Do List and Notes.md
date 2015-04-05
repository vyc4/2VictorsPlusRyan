To-do:

- Custom instructions: li, si, beq

- Add conversion from $sp to $r29

- Read Keyboard Input via polling
	- Determine where to store the keyboard input: ram/regfile/special reg?


Notes:

- Stack pointer ($sp=$29): points to bottom of current frame
- R0 = zero
- - R0 = zero

- beq 10000 $rd, $rs, N
- custr1 01001
- custr2 01010
- custr3 01011
- custr4 01100
- custr5 01101
- custr6 01110
- curst7 01111
- custi1 10001 $rd, $rs, N
- custi2 10010 $rd, $rs, N
- custi3 10011 $rd, $rs, N
- custi4 10100 $rd, $rs, N
- custj1 10111 (ckk - check keyboard input)
- custj2 11000

- Data Memory(RAM)
	- Total memory: 4096 words (0x000-0xFFF)
	- Display Memory: 300 words (0xE00-0xF2B)
	- Data memory: starts at 0x000 going up
	- Stack memory: starts at 0xDFF going down

