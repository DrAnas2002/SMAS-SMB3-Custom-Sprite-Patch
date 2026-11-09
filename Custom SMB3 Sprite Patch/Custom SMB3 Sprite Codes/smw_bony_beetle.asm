;======================================================================================================================;
; this is the bony beetle from Super Mario World. however, it's NOT a true accurate port as only a small part of the
; behavior is from SMW, and the rest is based on the vanilla dry bones code
;
; by default, this guy will stop and protrude spikes out of his shell after some time, then continue walking again
;
; while his spikes are showing up, you can't stomp on him, but when they're not, he'll crumble just like the dry bones!
;
; IMPORTANT NOTE: put the included 'GFX_Sprite_BoomBoom.bin' & 'GFX_Sprite_FlyingBoomBoom.bin' in 'SMB3/Graphics'
; so that the sprite renders properly!
;
; made by DrAnas, partially based upon Thomas's 'all.log': https://bin.smwcentral.net/u/7012/all.7z
; credit to S.Koopa0 for the bony beetle GFX: https://mfgg.net/index.php?act=resdb&param=02&c=1&id=41816
;
;======================================================================================================================;
; start of user defines                                                                                                ;
;======================================================================================================================;
!BonyBeetleSprID        = $04       ;> this is the vanilla sprite ID to overwrite with the new bony beetle

!BaseXSpeed             = $08       ;> the bony beetle's base X-speed, shouldn't be less than $04!
!CrumbledTime           = $FF       ;> how long he stays in his crumbled state after being stomped on
!ShakeTime              = $40       ;> the remainder of '!CrumbledTime', below which he'll start to shake until he gets back up

!TimeUntilHide          = $FF       ;> how long until he's gonna start hiding in his shell
!ShellHideTime          = $A0       ;> how long he'll stay hidden in his shell for

; this is the remainder of '!CrumbledTime' where the 'about to crumble/get back up' frame will show up
; this will also handle how long the frame changes from the 'about to crumble/get back up' one to the fully-crumbled one
; when the bony beetle's stomped on
!AboutToCrumbleTime     = $10

; this is the amount of time STARTING FROM '!TimeUntilHide', below which the FIRST 'hiding in shell' frame will show up
!Show1stSpikeTime       = $70

; this is the amount of time STARTING FROM '!Show1stSpikeTime', below which the SECOND 'hiding in shell' frame will show up
!Show2ndSpikeTime       = $68

; these are the bony beetle's TOPLEFT, TOPRIGHT, BOTTOMLEFT, and BOTTOMRIGHT tiles respectively
bony_beetle_tiles:
    db $2E,$30,$2F,$31              ;\ 0x0-0x1: walking frames
    db $32,$34,$33,$35              ;/

    db $7C,$7E,$7D,$7F              ;> 0x2: 'about to crumble/get back up' frame

    db $DC,$DE,$DD,$DF              ;> 0x3: fully-crumbled frame

    db $6E,$7A,$6F,$7B              ;\ 0x4-0x5: 'hiding in shell' frames
    db $36,$38,$37,$39              ;/

; which sprite page each frame's gonna use (corresponding to the frame in 'bony_beetle_tiles')
; $00 = 1st sprite page; $01 = 2nd sprite page
bony_beetle_frame_pg:
    db $01,$01,$01,$00,$01,$01

!BonyBeetlePal          = 6         ;> the bony beetle's palette (set to 0-7 for palettes 0x8-0xF respectively)

;======================================================================================================================;
; end of user defines                                                                                                  ;
;======================================================================================================================;
; please don't touch these! these are for ease of coding
!BonyBeetleAnimFrame        = !RAM_SMB3_Level_NorSpr_Table7E0068
!BonyBeetleStunTimer        = !RAM_SMB3_Level_NorSpr_DecrementingTable7E0518
!BonyBeetleUntilHideTimer   = !RAM_SMB3_Level_NorSpr_DecrementingTable7E0520
!BonyBeetleShakeTimer       = !RAM_SMB3_Level_NorSpr_DecrementingTable7E06AB
!BonyBeetleCrumbledFlag     = !RAM_SMB3_Level_NorSpr_Table7E0669

;======================================================================================================================;
; hijacks                                                                                                              ;
;======================================================================================================================;
; repoint our desired sprite's main pointer somewhere in vanilla freespace
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!BonyBeetleSprID*3)
    dl SMWBonyBeetleMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!BonyBeetleSprID*3)
    dl SMWBonyBeetleInit

; the bony beetle will have a custom interaction, so we gotta point to it here
org !SprCustInteractTable+(!BonyBeetleSprID*3)
    dl BonyBeetleCustInt

; for the visibility detection, use a height of 32 pixels & a width of 16
org !SprPalHeightWidthProps+!BonyBeetleSprID
    db !OA1_HEIGHT32|!OA1_WIDTH16

; have a block hitbox of 16x16 and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!BonyBeetleSprID
    db !OA2_TDOGRP1|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!BonyBeetleSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; have a player hitbox of 16x16, turn away upon touching another sprite, and be immune to fireballs!
org !SprHitboxImmumeProps+!BonyBeetleSprID
    db !OAT_BOUNDBOX01|!OAT_BOUNCEOFFOTHERS|!OAT_FIREIMMUNITY

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!BonyBeetleSprID
    db !KILLACT_NORMALANDKILLED

; set the sprite's pal. as desired
org !SprRealPalTable+!BonyBeetleSprID
    db !BonyBeetlePal

; always make the bony beetle use the first sprite page by default so that we can more easily manipulate it
org !SprGFXPageTable+!BonyBeetleSprID
    db $00

; always make sure to automatically find freespace, otherwise it'll overwrite important vanilla data!
freecode

;======================================================================================================================;
; initialization routine                                                                                               ;
;======================================================================================================================;
; initialize the bony beetle's X-speed & flip towards the player based on the last time the screen scrolled, and in addition,
; initialize his timer to start hiding in his shell
; (setup the bank wrapper in the process 'cause both the init and main are likely to be in separate freespace banks
; & we can't properly access the tables otherwise)
SMWBonyBeetleInit:
    PHB : PHK : PLB
    LDY.b !LastScrollDir
    LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    EOR.w bony_beetle_x_flip,y
    STA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    LDA.w bony_beetle_x_spds,y
    STA.b !RAM_SMB3_Level_NorSpr_XSpeed,x
    LDA #!TimeUntilHide
    STA.w !BonyBeetleUntilHideTimer,x
    PLB
    RTL

;======================================================================================================================;
; main routine                                                                                                         ;
;======================================================================================================================;
SMWBonyBeetleMain:
; always run the GFX!
    JSL BonyBeetleGFX

; if the sprite's NOT alive or the game's frozen, return and simply draw the graphics!
    LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
    EOR #$02
    ORA.b !GameFrozenFlag
    BNE .return

;======================================================================================================================;
.alive
; delete if off-screen
    JSL !SubOffScreen

; apply vanilla gravity and interact with blocks, plus, check for the player's contact!
    JSL SprGravAndBlkInteract
    JSL !CheckPlayerCont

; skip straight to the not-moving code if the stun timer's running! otherwise, clear the crumbled flag
    LDA.w !BonyBeetleStunTimer,x
    BNE .notMoving
    STZ.w !BonyBeetleCrumbledFlag,x

; if the time until hiding's up, set the stun timer to '!ShellHideTime'!
    LDA.w !BonyBeetleUntilHideTimer,x
    BNE +
    LDA #!ShellHideTime
    STA.w !BonyBeetleStunTimer,x

; handle the conveyor belt interaction
+   JSL !SprConveyorCheckCarry

; here, the output 'Y' from the above routine = 0xFF if the sprite goes AGAINST the conveyor, but it's 0x1 if it goes WITH it
; however, for easier indexing, we'll increase the output by 1, so in actuality the outputs now become 0x0 & 0x2
    LDY.w !SprConvTileTouched
    INY

; set the carry if the sprite's X-flipped & transfer the 'Y' output from above to 'X' since 'LDA.l $XXXXXX,y' is non-existent
    LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    ASL #2
    TYX

; if the carry from the above's SET, store the necessary conveyor X-speed as-is; if CLEAR, invert it beforehand
; (restore the sprite slot index as well!)
    LDA.l bony_beetle_conv_x_spds,x
    BCS +
    EOR #$FF : INC
+   LDX.b !SprSlotIndex
    STA.b !RAM_SMB3_Level_NorSpr_XSpeed,x

; animate if on the ground, restricting the total amount of frames to 0x0-0x1
; (we use the sprite slot index as a base and further manipulate it with 'ASLs', 'LSRs' & the global frame counter,
; so that each sprite animates uniquely at a proper rate)
    LDA.b !SprBlkdStatus,x
    AND #$04
    BEQ .return
    TXA
    ASL #2
    EOR.b !RAM_SMB3_Global_FrameCounter
    LSR #3
    AND #$01
    STA.w !BonyBeetleAnimFrame,x
.return
    RTL

;======================================================================================================================;
.notMoving
; zero out the bony beetle's X-speed for the duration of the stun timer
    STZ.b !RAM_SMB3_Level_NorSpr_XSpeed,x

; if the bony beetle's crumbled flag's SET, run the specific code for that, otherwise run his hiding behavior
    LDA.w !BonyBeetleCrumbledFlag,x
    BNE .crumbledState

;======================================================================================================================;
.hidingState
    LDY.w !BonyBeetleStunTimer,x
; reset the frame to 0x0 shortly before hiding
    LDA #$00

; if the stun timer < '!Show1stSpikeTime', show the FIRST 'hiding in shell' frame (0x4), otherwise keep the above frame (0x0) as-is
    CPY #!Show1stSpikeTime
    BCS +
    LDA #$04

; if < ('!Show1stSpikeTime-!Show2ndSpikeTime'), keep the above frame (0x4) as-is, otherwise...
    CPY #(!Show1stSpikeTime-!Show2ndSpikeTime)
    BCC +

; ...if < '!Show2ndSpikeTime', show the SECOND 'hiding in shell' frame (0x5), otherwise keep the above frame (0x4) as-is
    CPY #!Show2ndSpikeTime
    BCS +
    INC
+   STA.w !BonyBeetleAnimFrame,x

; finally, if EXACTLY 0x1, return!
; (without checking it like this, the bony beetle will immediately start hiding again)
    CPY #$01
    BNE .return2

; otherwise, reset the time until the bony beetle's gonna hide
    LDA #!TimeUntilHide
    STA.w !BonyBeetleUntilHideTimer,x
.return2
    RTL

;======================================================================================================================;
.crumbledState
; if the stun timer < '!AboutToCrumbleTime' or >= its inversion, show the 'about to crumble/get back up' frame,
; but in between those times, show the fully-crumbled one
    LDY.w !BonyBeetleStunTimer,x
    LDA #$02
    CPY #!AboutToCrumbleTime
    BCC +
    CPY #-!AboutToCrumbleTime
    BCS +
    LDA #$03
+   STA.w !BonyBeetleAnimFrame,x

; if the bony beetle's stun timer < '!ShakeTime', set the shake timer as such
    LDA.w !BonyBeetleStunTimer,x
    CMP #!ShakeTime
    BCS +
    STA.w !BonyBeetleShakeTimer,x

; if the bony beetle's stun timer's EXACTLY 0x1, return!
; (without checking it like this, the bony beetle will immediately start hiding again)
+   LDA.w !BonyBeetleStunTimer,x
    CMP #$01
    BNE .return3

; otherwise, get back up and face the player head-on, and reset the time until hiding!
    JSL !SubHorzPosCoarse
    STA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    LDA #!TimeUntilHide
    STA.w !BonyBeetleUntilHideTimer,x
.return3
    RTL

;======================================================================================================================;
; graphics routine                                                                                                     ;
;======================================================================================================================;
BonyBeetleGFX:
; first, to avoid the bony beetle's tiles from wrapping across the screen, check if he's horizontally or vertically off-screen
    JSL SMB3_CheckIfSpriteIsHorizontallyOffScreen_Main
    JSL SMB3_CheckIfSpriteIsVerticallyOffScreen_Main

; backup the 'YXPPCCCT' sprite table in advance as we'll need to check it more easily
    LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    STA.b !RAM_SMB3_Global_ScratchRAM0A

; call 'Object_ShakeAndDraw' (a.k.a. 'CODE_279EBC' in YF's orig. disasm.)
    JSL !SprShakeAndDraw

; as it turns out, the above routine already sets up the X/Y-positions of our four tiles to make a 16x16 sprite,
; and it even sets up our palettes! however, we wanna change the tiles, so we must get into 16-bit 'X/Y'
; to access the OAM index via sprite RAM $C6,x
    REP #$10
    LDY.b !SprOAMIndex,x

; since we're in 16-bit 'X/Y', we'll need to clear the HIGH byte of '!BonyBeetleAnimFrame' before transferring it to 'X'
; as our sprite page & tilemap indexes, otherwise crashes will likely ensue. we'll preserve the base cleared value first
    LDA #$00
    XBA
    LDA.w !BonyBeetleAnimFrame,x
    TAX
    PHA

; now first, based on the above, change the sprite page accordingly first
; (it seems I cannot manipulate the sprite table counterpart...)
    LDA.w SMB3_OAMBuffer[$00].Prop,y
    EOR.l bony_beetle_frame_pg,x
    STA.w SMB3_OAMBuffer[$00].Prop,y
    STA.w SMB3_OAMBuffer[$01].Prop,y
    STA.w SMB3_OAMBuffer[$02].Prop,y
    STA.w SMB3_OAMBuffer[$03].Prop,y

; now draw the four tiles for the bony beetle, indexed by the animation frame TIMES 4 since we animate four tiles at once
    PLA
    ASL #2
    TAX
    LDA.l bony_beetle_tiles,x
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA.l bony_beetle_tiles+1,x
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.l bony_beetle_tiles+2,x
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA.l bony_beetle_tiles+3,x
    STA.w SMB3_OAMBuffer[$03].Tile,y

; swap the tiles accordingly if X-flipped (unfortunately, because of how seemingly complex & messy SMB3's GFX routines are,
; if I directly manipulate the tile X/Y-displacements, the tiles will wrap across the screen, which is VERY frustrating...)
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    AND #$40
    BEQ .notXFlipped

    LDA.l bony_beetle_tiles,x
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.l bony_beetle_tiles+1,x
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA.l bony_beetle_tiles+2,x
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA.l bony_beetle_tiles+3,x
    STA.w SMB3_OAMBuffer[$02].Tile,y

;======================================================================================================================;
.notXFlipped
; if Y-flipped in general (such as when dead), swap around the tiles!
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    BPL .return16Bit

    LDA.l bony_beetle_tiles,x
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA.l bony_beetle_tiles+1,x
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA.l bony_beetle_tiles+2,x
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA.l bony_beetle_tiles+3,x
    STA.w SMB3_OAMBuffer[$01].Tile,y

; swap the tiles accordingly AGAIN if X-flipped AND upside-down at once
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    AND #$40
    BEQ .return16Bit

    LDA.l bony_beetle_tiles,x
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA.l bony_beetle_tiles+1,x
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA.l bony_beetle_tiles+2,x
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.l bony_beetle_tiles+3,x
    STA.w SMB3_OAMBuffer[$00].Tile,y

; exit 16-bit 'X/Y' & return, restoring the sprite slot index in the progress
.return16Bit
    SEP #$10
    LDX.b !SprSlotIndex
    RTL

;======================================================================================================================;
; interaction routine                                                                                                  ;
;======================================================================================================================;
; this code is adapted heavily from the dry bones interaction code at 'CODE_28C4FD'
BonyBeetleCustInt:
; if the bony beetle hides & shows his spikes, hurt the player unless he has a goomba shoe on
    LDA.w !BonyBeetleAnimFrame,x
    CMP #$04
    BCS .checkGoombaShoe

; don't interact at all if the bony beetle's crumbled flag's set!
    LDA.w !BonyBeetleCrumbledFlag,x
    BNE .return

; hurt the player depending on the value of scratch RAM $0B? not sure where that's from...
    LDA.b !RAM_SMB3_Global_ScratchRAM0B
    LSR
    BCC .hurtPlayer

;======================================================================================================================;
.crumbleBonyBeetle
; set the stun timer to '!CrumbledTime' & set his crumbled flag
    LDA #!CrumbledTime
    STA.w !BonyBeetleStunTimer,x
    INC.w !BonyBeetleCrumbledFlag,x

; this was in the original code and changes the player's bouncing Y-speed if the ROM is a European one,
; tho it wouldn't hurt to keep it in
if !Define_Global_ROMToAssemble&(!ROM_SMASW_E|!ROM_SMAS_E|!ROM_SMB3_E) != $00
    LDA #$AA
else
    LDA #$C0
endif
    STA.b !RAM_SMB3_Level_Player_YSpeed

; play the crumbled SFX & setup the consecutive scoring
    LDA #!Define_SMAS_Sound0060_DryBonesCollapse
    STA.w !RAM_SMB3_Global_SoundCh1
    LDA.w !RAM_SMB3_Level_ConsecutiveEnemiesStompedCounter
    JSL !GiveConsecPts100
    INC.w !RAM_SMB3_Level_ConsecutiveEnemiesStompedCounter
.return
    RTL

;======================================================================================================================;
.checkGoombaShoe
; if the player has a goomba/kuribo shoe on, stomp on the bony beetle normally, otherwise hurt them!
    LDA.w !RAM_SMB3_Level_Player_InKuriboShoeFlag
    BEQ .hurtPlayer
    BRA .crumbleBonyBeetle

.hurtPlayer
    JML !HurtPlayer

;======================================================================================================================;
; miscellaneous tables                                                                                                 ;
;======================================================================================================================;
bony_beetle_x_spds:
    db !BaseXSpeed,-!BaseXSpeed

bony_beetle_conv_x_spds:
    db !BaseXSpeed,!BaseXSpeed,!BaseXSpeed+(!BaseXSpeed/4)

bony_beetle_x_flip:
    db $40,$00
