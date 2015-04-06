.data
dmem: .word 0x00000000
gridmem: .word 0x00000A00
dispmem: .word 0x00000C00

.text

main:
addi $r29, $r0, 0x00000EFF	## stack pointer

addi $r20, $r0, 0x75		## up direction
addi $r21, $r0, 0x72		## down direction
addi $r22, $r0, 0x74		## right direction
addi $r23, $r0, 0x6b		## left direction
addi $r24, $r0, 0		## old direction = 0
addi $r25, $r0, 0xa96		## snake head location
addi $r26, $r0, 7		## initialize color of snake (white)
addi $r27, $r0, 1		## initialize color of food
addi $r28, $r0, 1		## initialize length of snake
addi $r30, $r0, 0		## initialize direction to 0

addi $r2, $r0, 0xC00		## initialize loop counter
addi $r3, $r2, 0x0000012C		## end of grid
addi $r1, $r0, 2		## initial background color (black)
jal scroll

addi $r30, $r0, 0x74		## initialize direction (right)
sw $r28, 0($r25)		## store initial length of snake into gridMem head location

loopStart:


custj1 0			## puts new direction into r30
bne $r30, $r24, checkDirectionValid	## if current direction isnt old direction, branch (potentially valid)

updateHead:			## check new location in register
beq $r30, $r20, moveUp
beq $r30, $r21, moveDown
beq $r30, $r22, moveRight
beq $r30, $r23, moveLeft


checkFood:
## store next location in a register
## load that location from memory into another register
## if that other register has food value or snake value, do something
## otherwise, continue to decrementGridMem

addi $r17, $r28, 1		## increment length by 1
sw $r17, 0($r25)		## put increased value

decrementGridMem:
addi $r2, $r0, 0xC00		## initialize loop counter
addi $r3, $r2, 0x0000012C		## end of grid
jal scroll


addi $r24, $r30, 0		## r24 is now old direction

addi $r18, $r0, 0
addi $r19, $r0, 15
j delay

j loopStart
halt



moveUp:
addi $r25, $r25, -20
j checkFood
moveDown:
addi $r25, $r25, 20
j checkFood
moveRight:
addi $r25, $r25, 1
j checkFood
moveLeft:
addi $r25, $r25, -1
j checkFood


checkDirectionValid:
beq $r30, $r20, checkUp
beq $r30, $r21, checkDown
beq $r30, $r22, checkRight
beq $r30, $r23, checkLeft
j updateHead

checkUp:
bne $r24, $r21, updateHead
addi $r30, $r24, 0
j updateHead

checkDown:
bne $r24, $r20, updateHead
addi $r30, $r24, 0
j updateHead

checkRight:
bne $r24, $r23, updateHead
addi $r30, $r24, 0
j updateHead

checkLeft:
bne $r24, $r22, updateHead
addi $r30, $r24, 0
j updateHead

scroll:
addi $r5, $r0, 0xA00		## gridmemory
addi $r29, $r29, -1
sw $r31, 0($r29)

scrollStart:
bne $r30, $r0, incGrid
addi $r1, $r0, 2

scrollContinue:
sw $r1, 0($r2)			## write value in r1 to r2
addi $r2, $r2, 1		## iterate
addi $r5, $r5, 1		## iterate
addi $r1, $r0, 2		## ensure background color
blt $r2, $r3, scrollStart		## r2 iterates until it reaches r3

scrollFinish:
lw $r31, 0($r29)		## reset stack
addi $r29, $r29, 1
jr $r31

incGrid:
lw $r6, 0($r5)			## put gridmemory into register 6
bne $r6, $r0, decrementValue		## decrement all values not equal to zero
j scrollContinue

decrementValue:
addi $r6, $r6, -1		## decrement value
sw $r6, 0($r5)
bne $r6, $r0, writeColor		## if register 6 is not zero, write a color
j scrollContinue

writeColor:
addi $r1, $r26, 0		## write snake color to r1
j scrollContinue

delay:
addi $r18, $r18, 1
addi $r10, $r0, 0x0000FFFE
addi $r9, $r0, 0

delayStart:
addi $r9, $r9, 1
nop
nop
blt $r9, $r10, delayStart

delayFinish:
beq $r18, $r19, loopStart
j delay