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
incsrc "Custom SMB3 Sprite Codes/smw_line_guided_sprites.asm"

;======================================================================================================================;
; start of miscellanous user defines                                                                                   ;
;======================================================================================================================;

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
    JML Return16Bit

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

Draw16x16SprSharedCont:
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
Return16Bit:
; exit 16-bit 'X/Y', restore the sprite slot index, & continue!
    SEP #$10
    LDX.b !SprSlotIndex
    RTL

freecode

;======================================================================================================================;
; custom player hitbox routine                                                                                         ;
;======================================================================================================================;
; inputs:
;   - scratch RAM $00: the hitbox's X-position (NEGATIVE values = LEFT, POSITIVE ones = RIGHT)
;   - scratch RAM $01: the hitbox's Y-position (NEGATIVE values = UP, POSITIVE ones = DOWN)
;   - scratch RAM $02: the HORIZONTAL hitbox (MUST BE POSITIVE!)
;   - scratch RAM $03: the VERTICAL hitbox (MUST BE POSITIVE!)
;   - carry: if SET, then the player has touched the hitbox; if CLEAR, then they haven't
;
SprCustomPlayerHitbox:
; don't do anything if the sprite's horizontally or vertically off-screen!
    LDA.w !RAM_SMB3_Level_NorSpr_XOffscreenFlag,x
    ORA.w !RAM_SMB3_Level_NorSpr_YOffscreenFlag,x
    BNE .return

; multiply the horizontal & vertical hitbox values by 2 and store it for easier comparison
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ASL
    STA.b !RAM_SMB3_Global_ScratchRAM04
    LDA.b !RAM_SMB3_Global_ScratchRAM03
    ASL
    STA.b !RAM_SMB3_Global_ScratchRAM05

; for the HORIZONTAL hitbox's X-position, first offset the sprite's ON-SCREEN X-position appropriately, then check the
; distance between THAT and the player's ON-SCREEN X-position
; if the distance < our desired hitbox, continue with the VERTICAL hitbox, otherwise return!
    LDA.b !RAM_SMB3_Level_NorSpr_OnScreenXPos,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM00
    SEC : SBC !RAM_SMB3_Level_Player_OnScreenXPos
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM02
    CMP.b !RAM_SMB3_Global_ScratchRAM04
    BCS .return

; for the VERTICAL hitbox's Y-position, first offset the sprite's ON-SCREEN Y-position appropriately, then check the
; distance between THAT and the player's ON-SCREEN Y-position
; if the distance < our desired hitbox, continue further, otherwise return!
    LDA.b !RAM_SMB3_Level_NorSpr_OnScreenYPos,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM01
    SEC : SBC !RAM_SMB3_Level_Player_OnScreenYPos
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM03
    CMP.b !RAM_SMB3_Global_ScratchRAM05
    BCS .return

; SET the carry to indicate contact
    SEC
    RTL

.return
; CLEAR the carry to indicate NO contact
    CLC
    RTL

freecode
