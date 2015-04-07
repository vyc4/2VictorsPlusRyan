# To-do
- Boundaries (via x-coordinate register maintenance)
- Movement reversal (if mashing)
- Slows down when holding down a button
- Flashing square
- Random number generator?

## Next
- Food
- Growing Snake


# Notes:
## Register Assignments
- r0  = zero

- r9  = score (least significant digit)
- r10 = score 
- r11 = score (most significant digit)
- r12 = last keyboard input
- r13 = do not subtract One flag (after eating food)
- r14 = random number memory location
- r15 = delay limit (how long we wait to check for keyboard input between each move)
- r16 = food value (=snake length+1)
- r17 = food color (1-7)
- r18 = food location (000-12B)
- r19 = snake color (1-7)
- r20 = snake head location (000-12B)
- r21 = snake head x (0-19)
- r22 = snake head y (0-14)
- r23 = snake length (1-)
- r24 = snake direction (1-4; 1:UP, 2:DOWN, 3:LEFT, 4:RIGHT)
- r25 = up key value
- r26 = down key value
- r27 = left key value
- r28 = right key value
- r29 = keyboard input (U/D/L/R)
- r30 = stack pointer
- r31 = jal address

## Custom Instructions
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

## Memory Allocation
- Data Memory(RAM): 4096 words (0x000 - 0xFFF)
	- Display Memory: 300 words (0xE00 - 0xF2B)
	- Stack Region: (0xDFF -> 0xB2C)
	- Data Memory: (0x000 -> B2B)
		- Free use (food loc/color): (0x000 - 0x9FE)
		- Next Food starting location: (0x9FF)
		- Grid memory: 300 words (0xA00 - 0xB2B)

## PS2 Keyboard data values:
	- Up: 75	
	- Down: 72	
	- Left: 6b	
	- Right: 74

