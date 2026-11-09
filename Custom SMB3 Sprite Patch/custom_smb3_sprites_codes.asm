;======================================================================================================================;
; this file contains the 'incbins' to your custom sprite codes, plus whatever custom routines you wanna add for your sprites
; make sure this is in the same place as 'custom_smb3_sprites_patch.asm'!
; also, at the end of each custom routine, put 'freecode/freedata', otherwise important vanilla code's gonna be overwritten!
;
;======================================================================================================================;
; custom sprite code files                                                                                             ;
;======================================================================================================================;
incsrc "Custom SMB3 Sprite Codes/smw_thwimp.asm"
incsrc "Custom SMB3 Sprite Codes/smw_wall_followers.asm"
incsrc "Custom SMB3 Sprite Codes/smw_bony_beetle.asm"

;======================================================================================================================;
; shared routines                                                                                                      ;
;======================================================================================================================;
; this is an adaptation of the code at 'CODE_28B905' that handles all sorts of basic block interactions
SprGravAndBlkInteract:
    JSL SMB3_HandleNormalSpriteGravity_Main
    LDA.b !SprBlkdStatus,x
    AND #$08
    BEQ .checkWall
    STA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
.checkWall
    LDA.b !SprBlkdStatus,x
    AND #$03
    BEQ .alignFloor
    LDA.b !RAM_SMB3_Level_NorSpr_XSpeed,x
    BEQ .alignFloor
    JSL !FlipSprDir
.alignFloor
    LDA.b !SprBlkdStatus,x
    AND #$04
    BEQ .return
    JSL !AlignSprWithGround
.return
    RTL

freecode

;======================================================================================================================;
; custom optimized 'FinishOAMWrite' routine, adapted from the routine 'FinishOAMWrite.asm' from PIXI for Super Mario World
; by Akaginite:
; https://github.com/JackTheSpades/SpriteToolSuperDelux/blob/master/routines/FinishOAMWrite.asm
; inputs:
;   - 'A' = no. of tiles to draw MINUS 1
;   - 'Y' = tile size:
;       - $00 -> all tiles are 8x8
;       - $02 -> all tiles are 16x16 tiles
;       - $FF -> manually set the size for each tile elsewhere
;
; IMPORTANT NOTE: since this routine requires looping thru the necessary code as many times as the amount of tiles you're drawing
; to carefully avoid tiles from wrapping unnecessarily across the screen, it could be potentially slower than SMB3's limited way
; of preventing the tile-wrapping issue, so ONLY use it if you're doing a VERY COMPLEX GFX routine where SMB3's GFX codes wouldn't
; be enough and you wanna save OAM slots...
CustFinishOAMWrite:
; store the tile size in 'Y', and the no. of tiles to loop thru in 'A'
; (clear the high byte of scratch RAM $08 by zeroing out scratch RAM $09)
    STY.b !RAM_SMB3_Global_ScratchRAM0B
    STA.b !RAM_SMB3_Global_ScratchRAM08
    STZ.b !RAM_SMB3_Global_ScratchRAM09

; prepare the difference between the sprite & camera's Y-positions in advance for easier comparison
    LDA.b !RAM_SMB3_Level_NorSpr_YPosLo,x
    SEC : SBC.w !Vert_Scroll
    STA.b !RAM_SMB3_Global_ScratchRAM00
    LDA.b !RAM_SMB3_Level_NorSpr_YPosHi,x
    SBC.w !Vert_Scroll+1
    STA.b !RAM_SMB3_Global_ScratchRAM01

; ENTER 16-bit 'X/Y'
; (prepare the difference between the sprite & camera's X-positions in advance for easier comparison)
    REP #$10
    LDY.b !SprOAMIndex,x
    LDA.b !RAM_SMB3_Level_NorSpr_XPosHi,x
    XBA
    LDA.b !RAM_SMB3_Level_NorSpr_XPosLo,x

; ENTER 16-bit 'A'
    REP #$20
    SEC : SBC.w !Horz_Scroll
    STA.b !RAM_SMB3_Global_ScratchRAM02
    TYA
    LSR #2
    TAX

; EXIT 16-bit 'A' & SET the carry
    SEP #$21
.finishOAMLoop
    LDA.w SMB3_OAMBuffer[$00].XDisp,y
    SBC.b !RAM_SMB3_Global_ScratchRAM02

; ENTER 16-bit 'A' & SET the carry
    REP #$21
    BPL +
    ORA.w #$FF00
+   ADC.b !RAM_SMB3_Global_ScratchRAM02
    CMP.w #$0100
    TXA

; EXIT 16-bit 'A'
    SEP #$20
    LDA.b !RAM_SMB3_Global_ScratchRAM0B
    BPL +
    LDA.w SMB3_OAMTileSizeBuffer[$00].Slot,x
    AND #$02
+   ADC #$00
    STA.w SMB3_OAMTileSizeBuffer[$00].Slot,x
    LDA.w SMB3_OAMBuffer[$00].YDisp,y
    SEC : SBC.b !RAM_SMB3_Global_ScratchRAM00

; ENTER 16-bit 'A' & SET the carry
    REP #$21
    BPL +
    ORA.w #$FF00
+   ADC.b !RAM_SMB3_Global_ScratchRAM00
    ADC.w #$0010
    CMP.w #$0100
    BCC .next
    LDA.w #$00F0

; EXIT 16-bit 'A'
    SEP #$20
    STA.w SMB3_OAMBuffer[$00].YDisp,y
.next
; EXIT 16-bit 'A' & SET the carry
    SEP #$21
    INY #4
    INX
    DEC.b !RAM_SMB3_Global_ScratchRAM08
    BPL .finishOAMLoop

; EXIT 16-bit 'X/Y'
    SEP #$10
    LDX !SprSlotIndex
    RTL

freecode
