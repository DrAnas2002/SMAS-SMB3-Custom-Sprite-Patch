;======================================================================================================================;
; this is the ground grinder from Super Mario World, faithfully ported to SMAS SMB3!
; it's very simple-- it moves on the ground and the player can't step on it normally unless, of course, they have a goomba shoe
;
; IMPORTANT NOTE: put the included 'GFX_Sprite_SkySprites.bin' in 'SMB3/Graphics' so that the sprite renders properly!
;
; made by DrAnas, based upon Thomas's 'all.log': https://bin.smwcentral.net/u/7012/all.7z
;
;======================================================================================================================;
; start of user defines                                                                                                ;
;======================================================================================================================;
!GroundGrinderSprID     = $20       ;> this is the vanilla sprite ID to overwrite with the ground grinder

!GroundGrinderPal       = 5         ;> the ground grinder's palette (set to 0-7 for palettes 0x8-0xF respectively)
!GroundGrinderGFXPg     = 0         ;> if 0, the ground grinder's gonna use the 1st GFX page; if 1, then the 2nd GFX page

!GroundGrinderTile1     = $A8       ;> the FIRST tile for the grinder's animation
!GroundGrinderTile2     = $AA       ;> the SECOND tile for the grinder's animation

!BaseXSpeed             = $18       ;> the ground grinder's base X-speed

; the grinder's ticking sound. for the SFX values, please see 'SMB3/Misc_Defines_SMB3.asm'!
!TickSFX                = !Define_SMAS_Sound0060_Grinder

; for the SFX port, the following options are appropriate:
;   - '!RAM_SMB3_Global_SoundCh1' (corresponds to the SFX defines with 'Sound0060' in the name)
;   - '!RAM_SMB3_Global_SoundCh2' (corresponds to the SFX defines with 'Sound0061' in the name)
;   - '!RAM_SMB3_Global_SoundCh3' (corresponds to the SFX defines with 'Sound0063' in the name)
!TickSFXPort            = !RAM_SMB3_Global_SoundCh1

;======================================================================================================================;
; hijacks                                                                                                              ;
;======================================================================================================================;
; repoint the grinder's main pointer somewhere in automatically-found freespace
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!GroundGrinderSprID*3)
    dl SMWGroundGrinderMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!GroundGrinderSprID*3)
    dl SMWGroundGrinderInit

; since the sprite uses default interaction, we'll dummy out its interaction pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!GroundGrinderSprID*3)
    dl $EAEA6B

; for the off-screen detection, use a height of 32 pixels & a width of 32 pixels
org !SprPalHeightWidthProps+!GroundGrinderSprID
    db !OA1_HEIGHT32|!OA1_WIDTH32

; have a block hitbox of 16x16 and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!GroundGrinderSprID
    db !OA2_TDOGRP1|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!GroundGrinderSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; have a player hitbox of 16x16 and be immune to ALL weapons & kicked sprites!
org !SprHitboxImmuneProps+!GroundGrinderSprID
    db !OAT_BOUNDBOX01|!OAT_WEAPONIMMUNITY|!OAT_HITNOTKILL

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!GroundGrinderSprID
    db !KILLACT_NORMALANDKILLED

; set the sprite's palette as desired
org !SprRealPalTable+!GroundGrinderSprID
    db !GroundGrinderPal

; ditto with the sprite page
org !SprGFXPageTable+!GroundGrinderSprID
    db !GroundGrinderGFXPg

; always make sure to automatically find freespace, otherwise it'll overwrite important vanilla data!
freecode

;======================================================================================================================;
; initialization routine                                                                                               ;
;======================================================================================================================;
; initialize the grinder's X-speed & flip towards the player based on the last time the screen scrolled
; (we'll have to do some register shenanigans, such as transferring the sprite slot index from 'X' to 'Y',  since we can't
; easily access the necessary tables here with 'Y', and we'll also restore the sprite slot index appropriately afterwards)
SMWGroundGrinderInit:
    TXY
    LDX.b !LastScrollDir
    LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,y
    EOR.l ground_grinder_x_flip,x
    STA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,y
    LDA.l ground_grinder_x_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_XSpeed,y
    LDX.b !SprSlotIndex
    RTL

;======================================================================================================================;
; main routine                                                                                                         ;
;======================================================================================================================;
SMWGroundGrinderMain:
; call the grinder GFX routine always!
    JSL GroundGrinderGFX

; if the sprite's NOT alive or the game's frozen, return and simply draw the graphics!
    LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
    EOR #$02
    ORA.b !GameFrozenFlag
    BNE .return

; play the ticking sound every 4 frames
    LDA.b !RAM_SMB3_Global_FrameCounter
    AND #$03
    BNE +
    LDA #!TickSFX                   ;> the ticking SFX in question
    STA.w !TickSFXPort

; delete if off-screen
+   JSL !SubOffScreen

; apply vanilla gravity and interact with blocks, plus, interact with the player!
    JSL SprGravAndBlkInteract
    JSL !SprPlayerInteract
.return
    RTL

;======================================================================================================================;
; ground grinder GFX routine                                                                                           ;
;======================================================================================================================;
GroundGrinderGFX:
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
    LDA.l ground_grinder_x_disps,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM01
    STA.w SMB3_OAMBuffer[$00].XDisp,y
    LDA.l ground_grinder_y_disps,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM00
    STA.w SMB3_OAMBuffer[$00].YDisp,y

; preserve the tile loop counter index and change the grinder's tile based on the frame counter
; (we divide it by 4 to slow it down a bit and restrict the total no. of frames to 0x0-0x1 for the final check)
    PHX
    LDX.w #!GroundGrinderTile1
    LDA.b !RAM_SMB3_Global_FrameCounter
    LSR #2
    AND #$01
    BNE +
    LDX.w #!GroundGrinderTile2
+   TXA
    STA.w SMB3_OAMBuffer[$00].Tile,y
    PLX

; now set the 'YXPPCCCT', where scratch RAM $02 from 'Object_ShakeAndCalcSprite' already holds the sprite's palette,
; and $03 holds the other properties such as X/Y-flip
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ORA.b !RAM_SMB3_Global_ScratchRAM03

; now the priority bits from $03 are STRICTLY SET TO 0x30, which makes the sprite go IN FRONT of normal FG
; all of the sprite's tiles will also be INDIVIDUALLY X/Y-flipped if the WHOLE sprite's flipped accordingly
; we don't want these things at all, so we'll cancel out all four bits with a bitwise 'NOT' (the '~' here),
; and set our desired priority to 0x10 to make the sprite go BEHIND all normal FG
    AND #~$F0
    ORA #$10

; factor in each tile's individual X/Y-flip setting
    ORA.l ground_grinder_flip_props,x
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

SMWGroundSprsInteract:
    RTL

;======================================================================================================================;
; miscellaneous tables                                                                                                 ;
;======================================================================================================================;
; X/Y-displacements for the grinder's tiles
ground_grinder_x_disps:
    db $F8,$08,$F8,$08
ground_grinder_y_disps:
    db $00,$00,$10,$10

; the X/Y-flip properties for the grinder's tiles
; set to $40 for X-flip, $80 for Y-flip, and $C0 for both!
ground_grinder_flip_props:
    db $00,$40,$80,$C0

ground_grinder_x_spds:
    db -!BaseXSpeed,!BaseXSpeed

ground_grinder_x_flip:
    db $00,$40
