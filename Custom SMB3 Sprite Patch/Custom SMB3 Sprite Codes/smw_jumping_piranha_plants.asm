;======================================================================================================================;
; this is the jumping piranha plant from Super Mario World, faithfully ported to SMAS SMB3!
; it'll jump around 6 blocks high out of the ground and slowly hover down back to the ground
; based on the sprite ID, it could even spit out fireballs as it reaches the peak of its height!
;
; IMPORTANT NOTE: put the included 'GFX_Sprite_StandardEnemies.bin' in 'SMB3/Graphics' so that the sprite renders properly!
;
; made by DrAnas, based upon Thomas's 'all.log': https://bin.smwcentral.net/u/7012/all.7z
;
;======================================================================================================================;
; start of user defines                                                                                                ;
;======================================================================================================================;
!JumpPirSprID           = $15       ;> the vanilla sprite ID to overwrite with the NORMAL jumping piranha
!FireJumpPirSprID       = $16       ;> the vanilla sprite ID to overwrite with the FIRE-SPITTING jumping piranha

!JumpPirHeadPal         = 1         ;> the NORMAL piranha's HEAD palette (set to 0-7 for palettes 0x8-0xF respectively)
!JumpPirPropelPal       = 2         ;> its PROPELLER palette (set to 0-7 for palettes 0x8-0xF respectively)

!FireJumpPirHeadPal     = 2         ;> the FIRE-SPITTING piranha's HEAD palette (set to 0-7 for palettes 0x8-0xF respectively)
!FireJumpPirPropelPal   = 2         ;> its PROPELLER palette (set to 0-7 for palettes 0x8-0xF respectively)

!JumpPirGFXPg           = 0         ;> if 0, BOTH types of piranhas will use the 1st GFX page; if 1, then the 2nd GFX page

;======================================================================================================================;
; these are the tiles for the piranha's FIRST frame

!JumpPirHeadTopLFrm1    = $E0       ;> the head's TOPLEFT tile
!JumpPirHeadTopRFrm1    = $E0       ;> the head's TOPRIGHT tile
!JumpPirHeadBottomLFrm1 = $E1       ;> the head's BOTTOMLEFT tile
!JumpPirHeadBottomRFrm1 = $E1       ;> the head's BOTTOMRIGHT tile
!JumpPirPropelLHalfFrm1 = $D6       ;> the propeller's LEFT tile
!JumpPirPropelRHalfFrm1 = $D6       ;> the propeller's RIGHT tile

; these are the tiles for the piranha's SECOND frame

!JumpPirHeadTopLFrm2    = $E4       ;> the head's TOPLEFT tile
!JumpPirHeadTopRFrm2    = $E4       ;> the head's TOPRIGHT tile
!JumpPirHeadBottomLFrm2 = $E5       ;> the head's BOTTOMLEFT tile
!JumpPirHeadBottomRFrm2 = $E5       ;> the head's BOTTOMRIGHT tile
!JumpPirPropelLHalfFrm2 = $D7       ;> the propeller's LEFT tile
!JumpPirPropelRHalfFrm2 = $D7       ;> the propeller's RIGHT tile

!MirrorBothHalves       = 1         ;> if 1, the piranha's halves will be mirrored, to save GFX space

;======================================================================================================================;
!NoJumpingProximity     = $1B       ;> how close the player has to be to the piranha for it NOT to jump out anymore

!WaitTillJumpTime       = $40       ;> how many frames it'll wait in the ground before jumping
!MouthOpenTime          = $50       ;> how long it'll open its mouth while jumping out
!SpitFireballFrame      = $40       ;> the EXACT frame within '!MouthOpenTime' where it'll spit out its extended sprite

!StartingJumpSpeed      = -$40      ;> its initial jumping Y-speed (MUST BE NEGATIVE!)
!JumpingDecel           = $02       ;> the deceleration for the jumping Y-speed (MUST BE POSITIVE!)
!StoppingSpeed          = -$10      ;> the Y-speed that once reached, stops it (MUST BE NEGATIVE AND MORE THAN '!StartingJumpSpeed'!)

!HoveringGravCap        = $08       ;> the MAXIMUM Y-speed at which the piranha will hover/fall down (MUST BE POSITIVE!)
!HoveringGravity        = $01       ;> the gravity for the hovering Y-speed (MUST BE POSITIVE!)

;======================================================================================================================;
; what extended sprite the FIRE-SPITTING piranha spits out (please see 'Misc_Defines_SMB3.asm' for the extended sprite IDs,
; which are indicated as '!Define_SMB3_SpriteID_ExtSprXX')
!FireJumpPirExtSprID    = !Define_SMB3_SpriteID_ExtSpr04_NipperFire

!FireJumpPirExtSprXSpd1 = $10       ;> the X-speed of the FIRST extended sprite spawned (can be positive or negative)
!FireJumpPirExtSprXSpd2 = -$10      ;> the X-speed of the SECOND extended sprite spawned (can be positive or negative)
!FireJumpPirExtSprYSpd  = -$30      ;> the Y-speed of BOTH extended sprites (can be positive or negative)

;======================================================================================================================;
; end of user defines                                                                                                  ;
;======================================================================================================================;
; please don't touch these! these are for ease of coding
!JumpPirPhase           = !RAM_SMB3_Level_NorSpr_Table7E1021
!JumpPirJumpTimer       = !RAM_SMB3_Level_NorSpr_DecrementingTable7E0518
!JumpPirHeadAnimTimer   = !RAM_SMB3_Level_NorSpr_Table7E0691
!JumpPirPropelAnimTimer = !RAM_SMB3_Level_NorSpr_Table7E0669
!JumpPirAnimFrame       = !RAM_SMB3_Level_NorSpr_Table7E0689

;======================================================================================================================;
; normal jumping piranha plant-related hijacks                                                                         ;
;======================================================================================================================;
; repoint the NORMAL jumping piranha plant's main pointer somewhere in automatically-found freespace
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!JumpPirSprID*3)
    dl JumpPirMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!JumpPirSprID*3)
    dl JumpPirInit

; since the sprite uses default interaction, we'll dummy out its stomped-on pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!JumpPirSprID*3)
    dl $EAEA6B

; for the off-screen detection, use a height of 32 pixels & a width of 32 pixels
org !SprPalHeightWidthProps+!JumpPirSprID
    db !OA1_HEIGHT32|!OA1_WIDTH32

; have a special block hitbox that makes it sink one block below where it actually is, and ALWAYS use the 16-bit X-position
; for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!JumpPirSprID
    db !OA2_TDOGRP3|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, & be unstompable!
org !SprGameHaltMiscProps+!JumpPirSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE

; have a player hitbox of 16x16
org !SprHitboxImmuneProps+!JumpPirSprID
    db !OAT_BOUNDBOX01

; die in a puff of smoke
org !SprKillActionProps+!JumpPirSprID
    db !KILLACT_POOFDEATH

; set the sprite's palette as desired
org !SprRealPalTable+!JumpPirSprID
    db !JumpPirHeadPal

; ditto with the sprite page
org !SprGFXPageTable+!JumpPirSprID
    db !JumpPirGFXPg

;======================================================================================================================;
; fire-spitting jumping piranha plant-related hijacks                                                                  ;
;======================================================================================================================;
; now repoint the FIRE-SPITTING jumping piranha plant's main pointer somewhere in vanilla
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!FireJumpPirSprID*3)
    dl JumpPirMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!FireJumpPirSprID*3)
    dl JumpPirInit

; since the sprite uses default interaction, we'll dummy out its stomped-on pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!FireJumpPirSprID*3)
    dl $EAEA6B

; for the visibility detection, use a height of 32 pixels & a width of 32
org !SprPalHeightWidthProps+!FireJumpPirSprID
    db !OA1_HEIGHT32|!OA1_WIDTH32

; have a special block hitbox that makes it sink one block below where it actually is, and ALWAYS use the 16-bit X-position
; for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!FireJumpPirSprID
    db !OA2_TDOGRP3|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, & be unstompable!
org !SprGameHaltMiscProps+!FireJumpPirSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE

; have a player hitbox of 16x16
org !SprHitboxImmuneProps+!FireJumpPirSprID
    db !OAT_BOUNDBOX01

; die in a puff of smoke
org !SprKillActionProps+!FireJumpPirSprID
    db !KILLACT_POOFDEATH

; set the sprite's palette as desired
org !SprRealPalTable+!FireJumpPirSprID
    db !FireJumpPirHeadPal

; ditto with the sprite page
org !SprGFXPageTable+!FireJumpPirSprID
    db !JumpPirGFXPg

; always make sure to automatically find freespace, otherwise it'll overwrite important vanilla data!
freecode

;======================================================================================================================;
; initialization routine                                                                                               ;
;======================================================================================================================;
JumpPirInit:
; initialize the jumping piranhas' phase counter as the table used by default ($1021,x) isn't initialized fully for some reason
    STZ.w !JumpPirPhase,x

; shift half a block RIGHT of its spawn X-position
    LDA.b !RAM_SMB3_Level_NorSpr_XPosLo,x
    CLC : ADC #$08
    STA.b !RAM_SMB3_Level_NorSpr_XPosLo,x

; shift UP 1 pixel from its Y-position
    DEC.b !RAM_SMB3_Level_NorSpr_YPosLo,x
    LDA.b !RAM_SMB3_Level_NorSpr_YPosLo,x
    CMP #$FF
    BNE +
    DEC.b !RAM_SMB3_Level_NorSpr_YPosHi,x
+   RTL

;======================================================================================================================;
; main routine                                                                                                         ;
;======================================================================================================================;
; please note that the GFX routine will be drastically different from SMW's due to how both games' GFX routines work!
JumpPirMain:
; first, to avoid the sprite's tiles from wrapping across the screen, check if it's horizontally or vertically off-screen
    JSL SMB3_CheckIfSpriteIsHorizontallyOffScreen_Main
    JSL SMB3_CheckIfSpriteIsVerticallyOffScreen_Main

; prepare the propeller palette in advance based on the sprite no.
    LDA #(!JumpPirPropelPal<<1)
    LDY.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CPY #!FireJumpPirSprID
    BNE +
    LDA #(!FireJumpPirPropelPal<<1)
+   STA.b !RAM_SMB3_Global_ScratchRAM0A

; prepare the sprite page setting likewise and factor in our special priority BEHIND normal FG for efficiency's sake
; (we can only access the sprite GFX page table with 'X' here since we're not in the same bank as it,
; hence the register shenanigans. the normal 'YXPPCCCT' output from 'Object_ShakeAndCalcSprite' also forces the priority
; to be IN FRONT of normal FG and it's difficult to work with that)
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    TAX
    LDA.l !SprGFXPageTable,x
    ORA #$10
    STA.b !RAM_SMB3_Global_ScratchRAM0B
    LDX.b !SprSlotIndex

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
    JML .finishGFXRoutine

; to make things a bit easier, we'll setup the 'YXPPCCCT' for the head tiles
; (scratch RAM $03 from 'Object_ShakeAndCalcSprite' already holds the sprite's palette)
+   LDA.b !RAM_SMB3_Global_ScratchRAM03
    ORA.b !RAM_SMB3_Global_ScratchRAM0B
    STA.w SMB3_OAMBuffer[$00].Prop,y
    STA.w SMB3_OAMBuffer[$01].Prop,y
if !MirrorBothHalves == 1
    EOR #$40
endif
    STA.w SMB3_OAMBuffer[$03].Prop,y
    STA.w SMB3_OAMBuffer[$04].Prop,y

; setup the palette separately for the propeller!
    LDA.b !RAM_SMB3_Global_ScratchRAM0A
    ORA.b !RAM_SMB3_Global_ScratchRAM0B
    EOR #$40
    STA.w SMB3_OAMBuffer[$05].Prop,y
if !MirrorBothHalves == 1
    EOR #$40
endif
    STA.w SMB3_OAMBuffer[$02].Prop,y

; setup the X-displacements (the bottom half will be displaced 8 pixels RIGHT)
    LDA.b !RAM_SMB3_Global_ScratchRAM01
    STA.w SMB3_OAMBuffer[$00].XDisp,y
    STA.w SMB3_OAMBuffer[$01].XDisp,y
    STA.w SMB3_OAMBuffer[$02].XDisp,y
    CLC : ADC #$08
    STA.w SMB3_OAMBuffer[$03].XDisp,y
    STA.w SMB3_OAMBuffer[$04].XDisp,y
    STA.w SMB3_OAMBuffer[$05].XDisp,y

; setup the Y-displacements (every 2 tiles will be displaced 8 pixels DOWN)
; (for whatever reason, without setting the carry everytime I add something, there's a chance that on the left edge of the screen,
; the tiles will be strangely shifted up by 1 pixel)
    LDA.b !RAM_SMB3_Global_ScratchRAM00
    STA.w SMB3_OAMBuffer[$00].YDisp,y
    STA.w SMB3_OAMBuffer[$03].YDisp,y
    CLC : ADC #$08
    STA.w SMB3_OAMBuffer[$01].YDisp,y
    STA.w SMB3_OAMBuffer[$04].YDisp,y
    CLC : ADC #$08
    STA.w SMB3_OAMBuffer[$02].YDisp,y
    STA.w SMB3_OAMBuffer[$05].YDisp,y

; now let's setup the head's animation timer, clearing its high byte beforehand with 'XBA' before transferring to 'X'
; to avoid potential crashes
; (we divide the timer by 8 to make it animate slower than the propeller, restrict it to frames 0x0-0x1, and finally multiply it by 4
; since we have 4 tiles PER FRAME to work with)
    LDA #$00
    XBA
    LDA.w !JumpPirHeadAnimTimer,x
    LSR #3
    AND #$01
    STA.w !JumpPirAnimFrame,x
    ASL #2
    TAX
    LDA.l jump_pir_head_anim_frames,x
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA.l jump_pir_head_anim_frames+1,x
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.l jump_pir_head_anim_frames+2,x
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA.l jump_pir_head_anim_frames+3,x
    STA.w SMB3_OAMBuffer[$04].Tile,y
    LDX.b !SprSlotIndex

; next, let's setup the propeller's animation timer, clearing its high byte beforehand likewise
; (we divide the timer by 4 to make it animate somewhat slowly, restrict it to frames 0x0-0x1, and finally multiply it by 2
; since we have 2 tiles PER FRAME to work with)
    LDA #$00
    XBA
    LDA.w !JumpPirPropelAnimTimer,x
    LSR #2
    AND #$01
    ASL
    TAX
    LDA.l jump_pir_propel_anim_frames,x
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA.l jump_pir_propel_anim_frames+1,x
    STA.w SMB3_OAMBuffer[$05].Tile,y

; since the OAM tile size RAM is 1 byte PER TILE, compared to the other RAM addresses like X/Y-displacements,
; which is 4 bytes PER TILE, we're gonna have to divide the OAM index by 4 for proper access
    REP #$20
    PHY
    TYA
    LSR #2
    TAY
    SEP #$20

; unfortunately I can't fully understand this yet as I modelled it from the code at 'CODE_27A056' under 'Object_Draw16x16Sprite'
; (a.k.a. 'CODE_279F91' in YF's orig. disasm.), but it appears to manipulate the HORIZONTAL off-screen flag from sprite RAM $0651,x
; (held in scratch RAM $07) to set each tile's X-position high bit so that no tile inappropriately wraps across the screen
    LDA.b !RAM_SMB3_Global_ScratchRAM07
    ROL #2
    PHP
    AND #$01
    STA.w SMB3_OAMTileSizeBuffer[$00].Slot,y
    STA.w SMB3_OAMTileSizeBuffer[$01].Slot,y
    STA.w SMB3_OAMTileSizeBuffer[$02].Slot,y
    PLP
    ROL
    AND #$01
    STA.w SMB3_OAMTileSizeBuffer[$03].Slot,y
    STA.w SMB3_OAMTileSizeBuffer[$04].Slot,y
    STA.w SMB3_OAMTileSizeBuffer[$05].Slot,y
    PLY

;======================================================================================================================;
.finishGFXRoutine
; exit 16-bit 'X/Y', restore the sprite slot index, & continue!
    SEP #$10
    LDX.b !SprSlotIndex

; if the sprite's NOT alive or the game's frozen, return and simply draw the graphics!
    LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
    EOR #$02
    ORA.b !GameFrozenFlag
    BEQ .alive
    RTL

;======================================================================================================================;
.alive
; delete if off-screen
    JSL !SubOffScreen

; interact with the player
    JSL !SprPlayerInteract

; update the Y-position
    JSL !SprUpdateYPos

; call the pointers now!
    LDA.w !JumpPirPhase,x
    JSL SMB3_ExecutePtr_Absolute

JumpingPiranhaPtrs:
    dw WaitInGround                 ; 0x0 - waiting in the ground
    dw JumpOut                      ; 0x1 - jumping out
    dw SlowDown                     ; 0x2 - starting to slow down (shoot fireballs)

;======================================================================================================================;
; phase 0x0: waiting in the ground                                                                                     ;
;======================================================================================================================;
WaitInGround:
; clear the Y-speed!
    STZ.b !RAM_SMB3_Level_NorSpr_YSpeed,x

; return if it's either NOT time to jump out yet, or if the player's within the piranha's proximity
    LDA.w !JumpPirJumpTimer,x
    BNE .return

    JSL SMB3_CheckPlayerPositionRelativeToSprite_X
    LDA.b !RAM_SMB3_Global_ScratchRAM0F
    CLC : ADC #!NoJumpingProximity
    CMP #!NoJumpingProximity*2
    BCC .return

; set the starting jump Y-speed and move on to the next phase!
    LDA #!StartingJumpSpeed
    STA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
    INC.w !JumpPirPhase,x
    STZ.w !JumpPirAnimFrame,x
.return
    RTL

;======================================================================================================================;
; phase 0x1: jumping out                                                                                               ;
;======================================================================================================================;
JumpOut:
; decelerate the piranha's jumping speed while moving upwards, and if its decel reaches the given cap
; (in the original SMW, there was a junk code checking if the downwards Y-speed was more than 0x40, but that's impossible
; to reach as due to the decel, it'll reach a certain NEGATIVE Y-speed required for moving to phase 0x2...)
    LDA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
    BPL .animHead
    CLC : ADC #!JumpingDecel        ;> deceleration for the piranha's jump
    STA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
.animHead
; animate the piranha's head!
    INC.w !JumpPirHeadAnimTimer,x

; switch to the next phase upon decelerating to a certain NEGATIVE X-speed, and set the mouth-opening timer accordingly
    LDA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
    CMP #!StoppingSpeed             ;> Y-speed at which the piranha switches to phase 0x2
    BMI .return
    LDA #!MouthOpenTime             ;> no. of frames to keep the fire-spitting piranha's mouth open in phase 0x2
    STA.w !JumpPirJumpTimer,x
    INC.w !JumpPirPhase,x
.return
    RTL

;======================================================================================================================;
; phase 0x2: slowing down (& shooting fireballs if applicable)                                                         ;
;======================================================================================================================;
SlowDown:
; animate the propeller now!
    INC.w !JumpPirPropelAnimTimer,x

; keep the mouth open until the mouth-opening timer's up
    LDA.w !JumpPirJumpTimer,x
    BNE .mouthOpen
.animMouthNow
; animate the mouth now!
    INC.w !JumpPirHeadAnimTimer,x

; accel slowly downwards every 4 frames
    LDA.b !RAM_SMB3_Global_FrameCounter
    AND #$03
    BNE .touchedGround

    LDA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
    CMP #!HoveringGravCap           ;> max downwards Y-speed for the piranha
    BPL .touchedGround
    CLC : ADC #!HoveringGravity
    STA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
.touchedGround
; interact with blocks now!
    JSL !SprBlockInteract

; wait until the piranha lands inside the ground, then return to phase 0x0!
    LDA.b !SprBlkdStatus,x
    AND #$04
    BEQ .return
    STZ.w !JumpPirPhase,x
    LDA #!WaitTillJumpTime          ;> no. of frames for the piranha to wait in the ground
    STA.w !JumpPirJumpTimer,x
.return
    RTL

;======================================================================================================================;
; hasn't spit fire yet/keeping its mouth open...
.mouthOpen
; just animate the head if it's NOT the fire-spitting plant, and if so, then stop the head's animation timer
    LDY.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CPY #!FireJumpPirSprID
    BNE .animMouthNow
    STZ.w !JumpPirHeadAnimTimer,x

; furthermore, if it's yet NOT time to spit any fire, THEN start the animation, otherwise continue further!
    CMP #!SpitFireballFrame
    BNE .animMouthNow

    LDA #!FireJumpPirExtSprXSpd1    ;> X-speed for the piranha's RIGHT fireball
    JSL +
    LDA #!FireJumpPirExtSprXSpd2    ;> X-speed for the piranha's LEFT fireball
+   STA.b !RAM_SMB3_Global_ScratchRAM00

; now find an empty extended sprite slot, and if found, that slot will be in 'Y'
; (conveniently, this routine already checks if the sprite's off-screen)
    JSL SMB3_FindFreeExtendedSpriteSlot_FixedPriority

; set the ext. spr. no.
    LDA #!FireJumpPirExtSprID
    STA.w !RAM_SMB3_Level_ExtSpr_SpriteID,y

; now set the spawn X-position at the piranha's center
    LDA.b !RAM_SMB3_Level_NorSpr_XPosLo,x
    CLC : ADC #$04
    STA.w !RAM_SMB3_Level_ExtSpr_XPosLo,y
    LDA.b !RAM_SMB3_Level_NorSpr_XPosHi,x
    ADC #$00
    STA.w !RAM_SMB3_Level_ExtSpr_XPosHi,y

; make the spawn Y-position exactly the same as the piranha's
    LDA.b !RAM_SMB3_Level_NorSpr_YPosLo,x
    STA.w !RAM_SMB3_Level_ExtSpr_YPosLo,y
    LDA.b !RAM_SMB3_Level_NorSpr_YPosHi,x
    STA.w !RAM_SMB3_Level_ExtSpr_YPosHi,y

; now set the X/Y-speeds of both fireballs, and continue animating the piranha's mouth!
    LDA #!FireJumpPirExtSprYSpd
    STA.w !RAM_SMB3_Level_ExtSpr_YSpeed,y
    LDA.b !RAM_SMB3_Global_ScratchRAM00
    STA.w !RAM_SMB3_Level_ExtSpr_XSpeed,y
    BRA .animMouthNow

;======================================================================================================================;
; miscellaneous tables                                                                                                 ;
;======================================================================================================================;
jump_pir_head_anim_frames:
    db !JumpPirHeadTopLFrm1, !JumpPirHeadBottomLFrm1, !JumpPirHeadTopRFrm1, !JumpPirHeadBottomRFrm1
    db !JumpPirHeadTopLFrm2, !JumpPirHeadBottomLFrm2, !JumpPirHeadTopRFrm2, !JumpPirHeadBottomRFrm2

jump_pir_propel_anim_frames:
    db !JumpPirPropelLHalfFrm1,!JumpPirPropelRHalfFrm1
    db !JumpPirPropelLHalfFrm2,!JumpPirPropelRHalfFrm2
