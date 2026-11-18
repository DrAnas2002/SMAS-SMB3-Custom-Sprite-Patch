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
!BonyBeetleSprID        = $01       ;> this is the vanilla sprite ID to overwrite with the new bony beetle

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
; repoint the bony beetle's main pointer somewhere in automatically-found freespace
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!BonyBeetleSprID*3)
    dl SMWBonyBeetleMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!BonyBeetleSprID*3)
    dl SMWBonyBeetleInit

; the bony beetle will have a custom interaction, so we gotta point to it here
org !SprCustInteractTable+(!BonyBeetleSprID*3)
    dl BonyBeetleCustInt

; for the off-screen detection, use a height of 32 pixels & a width of 32 pixels
org !SprPalHeightWidthProps+!BonyBeetleSprID
    db !OA1_HEIGHT32|!OA1_WIDTH32

; have a block hitbox of 16x16 and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!BonyBeetleSprID
    db !OA2_TDOGRP1|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!BonyBeetleSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; have a player hitbox of 16x16, turn away upon touching another sprite, and be immune to fireballs!
org !SprHitboxImmuneProps+!BonyBeetleSprID
    db !OAT_BOUNDBOX01|!OAT_BOUNCEOFFOTHERS|!OAT_FIREIMMUNITY

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!BonyBeetleSprID
    db !KILLACT_NORMALANDKILLED

; set the sprite's palette as desired
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
; (we'll have to do some register shenanigans, such as transferring the sprite slot index from 'X' to 'Y',  since we can't
; easily access the necessary tables here with 'Y', and we'll also restore the sprite slot index appropriately afterwards)
SMWBonyBeetleInit:
    TXY
    LDX.b !LastScrollDir
    LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,y
    EOR.l bony_beetle_x_flip,x
    STA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,y
    LDA.l bony_beetle_x_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_XSpeed,y

    LDX.b !SprSlotIndex
    LDA #!TimeUntilHide
    STA.w !BonyBeetleUntilHideTimer,x
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
    BNE .return2

;======================================================================================================================;
.alive
; delete if off-screen
    JSL !SubOffScreen

; apply vanilla gravity and interact with blocks, plus, check for the player's contact!
    JSL SprGravAndBlkInteract
    JSL !CheckPlayerCont

; turn away after touching other sprites (unfortunately the vanilla routine for it can't be accessed with 'JSR',
; so we must do a 'JSL2RTS' to it)
    PHK
    PEA.w .return-1
    PEA.w CODE_279B7D-1
    JML !TurnAfterTouchingSprJSR
.return

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

; here, RAM $07B5 from the above routine = 0xFF if the sprite goes AGAINST the conveyor, but it's 0x1 if it goes WITH it
; furthermore, in the normal sprite-block interaction routine, it seems that $07B5 is set to 0x0 when on normal ground
; however, for easier indexing, we'll increase it by 1, so in actuality the outputs now become 0x0, 0x2 & 0x1 respectively
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
    BEQ .return2
    TXA
    ASL #2
    EOR.b !RAM_SMB3_Global_FrameCounter
    LSR #2

; animate faster if the bony beetle goes AGAINST the conveyor, otherwise, add an additional 'LSR' to further slow it down
; (we check the UNAFFECTED output as amazingly, the 'INY' from before DIDN'T reload 'Y' at all!)
    LDY.w !SprConvTileTouched
    CPY #$FF
    BEQ +
    LSR
+   AND #$01
    STA.w !BonyBeetleAnimFrame,x
.return2
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
    BNE .return3

; otherwise, reset the time until the bony beetle's gonna hide
    LDA #!TimeUntilHide
    STA.w !BonyBeetleUntilHideTimer,x
.return3
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
    BNE .return4

; otherwise, get back up and face the player head-on, and reset the time until hiding!
    JSL !SubHorzPosCoarse
    STA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    LDA #!TimeUntilHide
    STA.w !BonyBeetleUntilHideTimer,x
.return4
    RTL

;======================================================================================================================;
; graphics routine                                                                                                     ;
;======================================================================================================================;
BonyBeetleGFX:
; backup the 'YXPPCCCT' sprite table in advance as we'll need to check it more easily
    LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    STA.b !RAM_SMB3_Global_ScratchRAM08

; prepare the bony beetle's tiles based on the current animation frame
; (we'll multiply the current frame by 4 since we have four tiles PER FRAME to work with)
    LDA.w !BonyBeetleAnimFrame,x
    ASL #2
    TAX
    LDA.l bony_beetle_tiles,x
    STA.b !RAM_SMB3_Global_ScratchRAM0A
    LDA.l bony_beetle_tiles+2,x
    STA.b !RAM_SMB3_Global_ScratchRAM0B
    LDA.l bony_beetle_tiles+1,x
    STA.b !RAM_SMB3_Global_ScratchRAM0C
    LDA.l bony_beetle_tiles+3,x
    STA.b !RAM_SMB3_Global_ScratchRAM0D

; don't let both halves be X-flipped!
    LDA #$00

; call our custom 16x16 GFX routine!
    JSL Draw16x16Sprite

; get into 16-bit 'X/Y' again to access the OAM index properly
    REP #$10
    LDY.b !SprOAMIndex,x

; now based on the animation frame again, change the sprite page accordingly as well
; (it seems I cannot manipulate the sprite table counterpart, and since we'll be in 16-bit 'X/Y', we'll have to clear
; the HIGH byte of '!BonyBeetleAnimFrame' to avoid confusing issues)
    LDA #$00
    XBA
    LDA.w !BonyBeetleAnimFrame,x
    TAX

    LDA.w SMB3_OAMBuffer[$00].Prop,y
    EOR.l bony_beetle_frame_pg,x
    STA.w SMB3_OAMBuffer[$00].Prop,y
    STA.w SMB3_OAMBuffer[$01].Prop,y
    STA.w SMB3_OAMBuffer[$02].Prop,y
    STA.w SMB3_OAMBuffer[$03].Prop,y

; exit 16-bit 'X/Y', restore the sprite slot index, & continue!
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
    db -!BaseXSpeed,!BaseXSpeed

bony_beetle_conv_x_spds:
    db !BaseXSpeed,!BaseXSpeed,!BaseXSpeed+(!BaseXSpeed/4)

bony_beetle_x_flip:
    db $00,$40
