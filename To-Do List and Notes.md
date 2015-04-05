# To-do
- Boundaries (via x-coordinate register maintenance)
- Movement reversal (if mashing)
- Slows down when holding down a button
- Flashing square

## Next
- Food
- Growing Snake


# Notes:
## Register Assignments
- R0 = zero
- R18=
- R19=
- R20= 	up
- R21=	down
- R22=	right
- R23=	left
- R24=	oldReg
- R25=	location of head of snake
- R26=	color of snake
- R27=	color of food
- R28=	length of snake
- R29=	stack pointer (bottom of frame)
- R30=	direction of snake
- R31= 	jal address

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
- Data Memory(RAM)
	- Total memory: 4096 words (0x000-0xFFF)
	- Display Memory: 300 words (0xC00-0xD2C)
	- Grid memory: 300 words (0xA00-0xB2C)
	- Data memory: starts at 0x000 going up
		- 0xA00 to 0xB2C is grid memory
	- Stack memory: starts at 0xDFF going down

