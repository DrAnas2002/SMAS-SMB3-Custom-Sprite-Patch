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
incsrc "Custom SMB3 Sprite Codes/smw_jumping_piranha_plants.asm"
incsrc "Custom SMB3 Sprite Codes/smw_ground_grinder.asm"

;======================================================================================================================;
; start of miscellanous user defines                                                                                   ;
;======================================================================================================================;
; ground & line-guided grinder GFX defines

!GrinderTile1       = $A8       ;> the FIRST tile for the grinder's animation
!GrinderTile2       = $AA       ;> the SECOND tile for the grinder's animation

; X/Y-displacements for the grinder's tiles
grinder_x_disps:
    db $F8,$08,$F8,$08
grinder_y_disps:
    db $00,$00,$10,$10

; the X/Y-flip properties for the grinder's tiles
; set to $40 for X-flip, $80 for Y-flip, and $C0 for both!
grinder_flip_props:
    db $00,$40,$80,$C0

;======================================================================================================================;
; start of shared routines!
;
;======================================================================================================================;
; sprite block interaction & gravity routine                                                                           ;
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
; custom optimized 'FinishOAMWrite' routine                                                                            ;
;======================================================================================================================;
; adapted from the routine 'FinishOAMWrite.asm' from PIXI for Super Mario World
; by Akaginite:
; https://github.com/JackTheSpades/SpriteToolSuperDelux/blob/master/routines/FinishOAMWrite.asm
;
; inputs:
;   - 'A' = no. of tiles to draw MINUS 1
;   - 'Y' = tile size:
;       - $00 -> all tiles are 8x8
;       - $02 -> all tiles are 16x16 tiles
;       - $FF -> manually set the size for each tile elsewhere
;
; IMPORTANT NOTE: since this routine requires looping thru the necessary code as many times as the amount of tiles you're drawing
; to carefully avoid tiles from wrapping unnecessarily across the screen, it could be potentially slower than SMB3's limited way
; of preventing the tile-wrapping issue, so ONLY use it if you're doing a VERY COMPLEX GFX routine and you wanna save OAM slots...
;
CustFinishOAMWrite:
; store the tile size in 'Y', and the no. of tiles to loop thru in 'A'
; (since we'll load scratch RAM $08 in 16-bit 'X/Y', we'll need to zero out $09 (its HIGH byte) to avoid confusing issues)
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

;======================================================================================================================;
; shared grinder GFX routine                                                                                           ;
;======================================================================================================================;
GrinderGFX:
; first, immediately store the priority setting using 'XBA' (which saves us a little RAM)
    XBA

; prepare the sprite page setting likewise and factor in our special priority option from the 'XBA'
; (we can only access the sprite GFX page table with 'X' here since we're not in the same bank as it,
; hence the register shenanigans. the normal 'YXPPCCCT' output from 'Object_ShakeAndCalcSprite' also forces the priority
; to be IN FRONT of normal FG and it's difficult to work with that)
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    TAX
    XBA
    ORA.l !SprGFXPageTable,x
    STA.b !RAM_SMB3_Global_ScratchRAM0D
    LDX.b !SprSlotIndex

; call 'Object_ShakeAndCalcSprite' (a.k.a. 'CODE_279DF9' in YF's orig. disasm.) & restore the sprite slot index afterwards,
; as the routine doesn't already restore it
    JSL !SprShakeAndCalcTilePos
    LDX.b !SprSlotIndex

; since we wanna change the tiles, we must get into 16-bit 'X/Y' to access the OAM index via sprite RAM $C6,x
    REP #$10
    LDY.b !SprOAMIndex,x

;======================================================================================================================;
.startGrinderLoop
; loop for four tiles!
    LDX #$0003
.grinderLoop
; setup each tile's X/Y-displacements
    LDA.l grinder_x_disps,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM01
    STA.w SMB3_OAMBuffer[$00].XDisp,y
    LDA.l grinder_y_disps,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM00
    STA.w SMB3_OAMBuffer[$00].YDisp,y

; preserve the tile loop counter index and change the grinder's tile based on the frame counter
; (we divide it by 4 to slow it down a bit and restrict the total no. of frames to 0x0-0x1 for the final check)
    PHX
    LDX.w #!GrinderTile1
    LDA.b !RAM_SMB3_Global_FrameCounter
    LSR #2
    AND #$01
    BNE +
    LDX.w #!GrinderTile2
+   TXA
    STA.w SMB3_OAMBuffer[$00].Tile,y
    PLX

; now the 'YXPPCCCT', factoring in our sprite page & priority setting from before
; (scratch RAM $03 from 'Object_ShakeAndCalcSprite' already holds the sprite's palette)
    LDA.b !RAM_SMB3_Global_ScratchRAM03
    ORA.b !RAM_SMB3_Global_ScratchRAM0D
    ORA.l grinder_flip_props,x
    STA.w SMB3_OAMBuffer[$00].Prop,y

; increase the OAM index by 4 each loop, and terminate once the tile loop counter becomes NEGATIVE
    INY #4
    DEX
    BPL .grinderLoop
.return16Bit
; exit 16-bit 'X/Y' & return, restoring the sprite slot index in the progress
    SEP #$10
    LDX.b !SprSlotIndex

; now since SMB3's way of preventing tiles from wrapping horizontally across the screen is VERY limited for our needs here,
; we'll finish the OAM write with a specialized routine entirely!
; we'll be setting 'Y' to 0x2 to make all tiles 16x16, & 'A' to the total no. of tiles drawn MINUS 1,
; which in the grinder's case is 4 tiles total
    LDY #$02
    LDA #$03
    JML CustFinishOAMWrite

freecode

;======================================================================================================================;
; custom shared 16x16 sprite routine                                                                                   ;
;======================================================================================================================;
; adapted from the vanilla routine 'Object_Draw16x16Sprite' (a.k.a. 'CODE_279F91' in YF's orig. disasm.)
;
; inputs:
;   'A': if 0x0, then all tiles will be drawn normally, but if NON-ZERO, both halves will be X-flipped
;   - scratch RAM $0A: the sprite's TOPLEFT tile
;   - scratch RAM $0B: the sprite's BOTTOMLEFT tile
;   - scratch RAM $0C: the sprite's TOPRIGHT tile
;   - scratch RAM $0D: the sprite's BOTTOMRIGHT tile
;
Draw16x16Sprite:
; store the setting for X-flipping both halves & restore the sprite slot index
; (since we'll load scratch RAM $08 in 16-bit 'X/Y', we'll need to zero out $09 (its HIGH byte) to avoid confusing issues)
    STA.b !RAM_SMB3_Global_ScratchRAM08
    STZ.b !RAM_SMB3_Global_ScratchRAM09
    LDX.b !SprSlotIndex

; first, to avoid the sprite's tiles from wrapping across the screen, check if it's horizontally or vertically off-screen
    JSL SMB3_CheckIfSpriteIsHorizontallyOffScreen_Main
    JSL SMB3_CheckIfSpriteIsVerticallyOffScreen_Main

; call 'Object_ShakeAndCalcSprite' (a.k.a. 'CODE_279DF9' in YF's orig. disasm.) & restore the sprite slot index afterwards,
; as the routine doesn't already restore it
    JSL !SprShakeAndCalcTilePos
    LDX.b !SprSlotIndex

; since we wanna change the tiles, we must get into 16-bit 'X/Y' to access the OAM index via sprite RAM $C6,x
    REP #$10
    LDY.b !SprOAMIndex,x

; if the sprite's VERTICALLY off-screen, don't draw anything! otherwise, the tiles will wrap across the screen
; (scratch RAM $04 here holds the VERTICAL off-screen flag from sprite RAM $0681,x)
    LDA.b !RAM_SMB3_Global_ScratchRAM04
    BEQ +
    JML .return16Bit

; setup the X-displacements (the bottom half will be displaced 8 pixels RIGHT)
+   LDA.b !RAM_SMB3_Global_ScratchRAM01
    STA.w SMB3_OAMBuffer[$00].XDisp,y
    STA.w SMB3_OAMBuffer[$01].XDisp,y
    CLC : ADC #$08
    STA.w SMB3_OAMBuffer[$02].XDisp,y
    STA.w SMB3_OAMBuffer[$03].XDisp,y

; setup the Y-displacements (every 2 tiles will be displaced 8 pixels DOWN)
; (for whatever reason, without setting the carry everytime I add something, there's a chance that on the left edge of the screen,
; the tiles will be strangely shifted up by 1 pixel)
    LDA.b !RAM_SMB3_Global_ScratchRAM00
    STA.w SMB3_OAMBuffer[$00].YDisp,y
    STA.w SMB3_OAMBuffer[$02].YDisp,y
    CLC : ADC #$08
    STA.w SMB3_OAMBuffer[$01].YDisp,y
    STA.w SMB3_OAMBuffer[$03].YDisp,y

; now set the 'YXPPCCCT', where scratch RAM $02 from 'Object_ShakeAndCalcSprite' already holds the sprite's palette,
; and $03 holds the other properties such as X/Y-flip
; (we'll also take into account the setting for X-flipping both halves as applicable)
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ORA.b !RAM_SMB3_Global_ScratchRAM03
    STA.w SMB3_OAMBuffer[$00].Prop,y
    STA.w SMB3_OAMBuffer[$01].Prop,y
    LDX.b !RAM_SMB3_Global_ScratchRAM08
    BEQ +
    EOR #$40
+   STA.w SMB3_OAMBuffer[$02].Prop,y
    STA.w SMB3_OAMBuffer[$03].Prop,y

; now we can safely setup the tiles
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0B
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0C
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0D
    STA.w SMB3_OAMBuffer[$03].Tile,y

; if the sprite's X-flipped ONLY, swap the tiles accordingly, otherwise check for the Y-flip
    BIT.b !RAM_SMB3_Global_ScratchRAM02
    BVC .checkYFlip
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0B
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0C
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0D
    STA.w SMB3_OAMBuffer[$01].Tile,y

;======================================================================================================================;
.checkYFlip
; if Y-flipped ONLY, swap the tiles accordingly once more
    BIT.b !RAM_SMB3_Global_ScratchRAM02
    BPL .setTileSizes
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0B
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0C
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0D
    STA.w SMB3_OAMBuffer[$02].Tile,y

; if BOTH X- & Y-flipped, swap the tiles accordingly once more
    BIT.b !RAM_SMB3_Global_ScratchRAM02
    BVC .setTileSizes
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0B
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0C
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM0D
    STA.w SMB3_OAMBuffer[$00].Tile,y

;======================================================================================================================;
.setTileSizes
; since the OAM tile size RAM is 1 byte PER TILE, compared to the other RAM addresses like X/Y-displacements,
; which is 4 bytes PER TILE, we're gonna have to divide the OAM index by 4 for proper access
    REP #$20
    PHY
    TYA
    LSR #2
    TAY
    SEP #$20

; unfortunately I can't fully understand this yet, but it appears to manipulate the HORIZONTAL off-screen flag from
; sprite RAM $0651,x (held in scratch RAM $07) to set each tile's X-position high bit so that no tile inappropriately
; wraps across the screen
    LDA.b !RAM_SMB3_Global_ScratchRAM07
    ROL #2
    PHP
    AND #$01
    STA.w SMB3_OAMTileSizeBuffer[$00].Slot,y
    STA.w SMB3_OAMTileSizeBuffer[$01].Slot,y
    PLP
    ROL
    AND #$01
    STA.w SMB3_OAMTileSizeBuffer[$02].Slot,y
    STA.w SMB3_OAMTileSizeBuffer[$03].Slot,y
    PLY
.return16Bit
; exit 16-bit 'X/Y', restore the sprite slot index, & continue!
    SEP #$10
    LDX.b !SprSlotIndex
    RTL

freecode
