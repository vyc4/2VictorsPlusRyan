To-do:

- Custom instructions: li, si, beq

- Add conversion from $sp to $r29

- Read Keyboard Input via polling
	- Determine where to store the keyboard input: ram/regfile/special reg?

- Random number generator?

Notes:

- Stack pointer ($sp=$29): points to bottom of current frame

- Data Memory(RAM)
	- Total memory: 4096 words (0x000-0xFFF)
	- Keypress memory: 1 word (0xFFF)
	- Display Memory: 300 words (0xE00-0xF2B)
	- Data memory: starts at 0x000 going up
	- Stack memory: starts at 0xDFF going down

- PS2 Keyboard data values:
	- Up: 75	(0111 0101)
	- Down: 72	(0111 0010)
	- Left: 6b	(0110 1011)
	- Right: 74	(0111 0100)
	- Space: 29	
	- ESC: 76

