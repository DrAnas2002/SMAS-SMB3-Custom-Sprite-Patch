;======================================================================================================================;
; this is the thwimp from Super Mario World, faithfully ported to SMAS SMB3!
; by default, this guy will jump around 7 tiles high & 3 tiles wide, back & forth between two points
; he can interact with floors & ceilings, but NOT with walls
;
; IMPORTANT NOTE: put the included 'GFX_Sprite_BoomBoom.bin' in 'SMB3/Graphics' so that the sprite renders properly!
;
; made by DrAnas, based upon Thomas's 'all.log': https://bin.smwcentral.net/u/7012/all.7z
;
;======================================================================================================================;
; start of user defines                                                                                                ;
;======================================================================================================================;
!ThwimpSprID        = $02       ;> this is the vanilla sprite ID to overwrite with the new thwimp

!JumpXSpeed         = $10       ;> the thwimp's base X-speed while jumping (can be positive or negative as per choice)
!JumpYSpeed         = -$60      ;> the thwimp's base Y-speed while jumping (MUST BE NEGATIVE!)

; these four Y-speeds down below MUST BE POSITIVE!

!MaxFallYSpeed      = $40       ;> this is the Y-speed where the thwimp's fall will be capped
!BaseYAccel         = $03       ;> the base acceleration for the thwimp's Y-speed when he jumps
!FallingYAccel      = $05       ;> the EXTRA Y-acceleration that's applied ON TOP of the thwimp's base one when he falls
!HitCeilYSpeed      = $10       ;> this is the X-speed at which the thwimp will be knocked back down after hitting a ceiling

;======================================================================================================================;
!TimeUntilJump      = $40       ;> how long for the thwimp to wait before jumping

; for the SFX values, please see 'SMB3/Misc_Defines_SMB3.asm'!
!JumpSFX            = !Define_SMAS_Sound0060_HitHead

; for the SFX port, the following options are appropriate:
;   - '!RAM_SMB3_Global_SoundCh1' (corresponds to the SFX defines with 'Sound0060' in the name)
;   - '!RAM_SMB3_Global_SoundCh2' (corresponds to the SFX defines with 'Sound0061' in the name)
;   - '!RAM_SMB3_Global_SoundCh3' (corresponds to the SFX defines with 'Sound0063' in the name)
!JumpSFXPort        = !RAM_SMB3_Global_SoundCh1

!ThwimpUpperTileL   = $7E       ;> the TOPLEFT tile of the thwimp
!ThwimpLowerTileL   = $7F       ;> the BOTTOMLEFT tile of the thwimp

!ThwimpUpperTileR   = $7E       ;> the TOPRIGHT tile of the thwimp
!ThwimpLowerTileR   = $7F       ;> the BOTTOMRIGHT tile of the thwimp

!MirrorBothHalves   = 1         ;> if 1, the thwimp's halves will be mirrored, just like in the original SMW

!ThwimpPal          = 5         ;> the thwimp's palette (set to 0-7 for palettes 0x8-0xF respectively)
!ThwimpGFXPg        = 1         ;> if 0, the thwimp's gonna use the 1st GFX page; if 1, then the 2nd GFX page

;======================================================================================================================;
; end of user defines                                                                                                  ;
;======================================================================================================================;
; please don't touch these! these are for ease of coding
!ThwimpJumpCounter  = !RAM_SMB3_Level_NorSpr_Table7E1021
!ThwimpJumpTimer    = !RAM_SMB3_Level_NorSpr_DecrementingTable7E0518

;======================================================================================================================;
; hijacks                                                                                                              ;
;======================================================================================================================;
; repoint our desired sprite's main pointer somewhere in vanilla freespace
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!ThwimpSprID*3)
    dl SMWThwimpMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!ThwimpSprID*3)
    dl SMWThwimpInit

; since the thwimp uses default interaction, we'll dummy out his stomped-on pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!ThwimpSprID*3)
    dl $EAEA6B

; for the visibility detection, use a height of 32 pixels & a width of 16
org !SprPalHeightWidthProps+!ThwimpSprID
    db !OA1_HEIGHT32|!OA1_WIDTH16

; have a block hitbox of 16x16 and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!ThwimpSprID
    db !OA2_TDOGRP1|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!ThwimpSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; have a player hitbox of 16x16 and be immune to fireballs!
org !SprHitboxImmumeProps+!ThwimpSprID
    db !OAT_BOUNDBOX01|!OAT_FIREIMMUNITY

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!ThwimpSprID
    db !KILLACT_NORMALANDKILLED

; set the thwimp's pal. as desired
org !SprRealPalTable+!ThwimpSprID
    db !ThwimpPal

; ditto with the sprite page
org !SprGFXPageTable+!ThwimpSprID
    db !ThwimpGFXPg

; always make sure to automatically find freespace, otherwise it'll overwrite important vanilla data!
freecode

;======================================================================================================================;
; initialization routine                                                                                               ;
;======================================================================================================================;
; initialize the thwimp's jump counter as the table used by default ($1021,x) isn't initialized fully for some reason
SMWThwimpInit:
    STZ.w !ThwimpJumpCounter,x
    RTL

;======================================================================================================================;
; main routine                                                                                                         ;
;======================================================================================================================;
SMWThwimpMain:
; if the sprite's NOT alive or the game's frozen, return and simply draw the graphics!
    LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
    EOR #$02
    ORA.b !GameFrozenFlag
    BNE ThwimpGFX

; delete if off-screen
    JSL !SubOffScreen

; interact with the player
    JSL !SprPlayerInteract

; update the X/Y-positions & interact with blocks
    JSL !SprUpdateXPos
    JSL !SprUpdateYPos

; interact with blocks
    JSL !SprBlockInteract

; apply gravity
    LDA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
    BMI .baseAccel
    CMP #!MaxFallYSpeed             ;> maximum falling Y-speed
    BCS .capFallSpd
    ADC #!FallingYAccel             ;> additional acceleration while falling
.baseAccel
    CLC : ADC #!BaseYAccel          ;> base acceleration, used thruout the jump
    BRA +

.capFallSpd
    LDA #!MaxFallYSpeed             ;> Y-speed to cap the max falling speed with
+   STA.b !RAM_SMB3_Level_NorSpr_YSpeed,x

; if he hits a ceiling, knock him back down
    LDA.b !SprBlkdStatus,x
    AND #$08
    BEQ .didntTouchCeiling
    LDA #!HitCeilYSpeed             ;> Y-speed at which to knock him back down
    STA.b !RAM_SMB3_Level_NorSpr_YSpeed,x

; if the thwimp's not touching ground, just draw the GFX
.didntTouchCeiling
    LDA.b !SprBlkdStatus,x
    AND #$04
    BEQ ThwimpGFX

; this line was originally an SMW code for setting the Y-speed on ground to 0x0 normally or 0x10 if on a slope,
; but honestly, that's useless as right afterwards, the Y-speed is zeroed out. instead, we must call the code
; for aligning the sprite properly with the ground as it seems that '!SprBlockInteract/Object_WorldDetectN1'
; doesn't handle that already unlike SMW's sprite-block interaction routine
    JSL !AlignSprWithGround

; clear out the X/Y-speeds
    STZ.b !RAM_SMB3_Level_NorSpr_XSpeed,x
    STZ.b !RAM_SMB3_Level_NorSpr_YSpeed,x

; automatically move the thwimp with conveyor belts!
    JSL !ConveyorMoveSpr

; branch if the wait timer is 0x0, as the thwimp's just hit the ground
; if the wait timer is 0x1, then it's time to jump. otherwise, branch to just draw the GFX
    LDA.w !ThwimpJumpTimer,x
    BEQ .landOnGround
    DEC
    BNE ThwimpGFX
    LDA #!JumpYSpeed                ;> Y-speed to give at the start of the thwimp's jump
    STA.b !RAM_SMB3_Level_NorSpr_YSpeed,x

; increase the thwimp's jumping state & when it becomes 0x1, shift the carry around to make it 0x0
; accordingly, set the RIGHT or LEFT X-speed
    INC.w !ThwimpJumpCounter,x
    LDA.w !ThwimpJumpCounter,x
    LSR
    LDA #!JumpXSpeed                ;> RIGHT X-speed
    BCC +
    LDA #-!JumpXSpeed               ;> LEFT X-speed
+   STA.b !RAM_SMB3_Level_NorSpr_XSpeed,x

; draw the GFX!
    BRA ThwimpGFX

;======================================================================================================================;
.landOnGround
; play the SFX for hitting the ground
    LDA #!JumpSFX
    STA.w !JumpSFXPort

; how long to wait before jumping
    LDA #!TimeUntilJump
    STA.w !ThwimpJumpTimer,x

;======================================================================================================================;
; graphics routine (continues directly from the main code)                                                             ;
;======================================================================================================================;
ThwimpGFX:
; first, to avoid the thwimp's tiles from wrapping across the screen, check if he's horizontally or vertically off-screen
    JSL SMB3_CheckIfSpriteIsHorizontallyOffScreen_Main
    JSL SMB3_CheckIfSpriteIsVerticallyOffScreen_Main

; call 'Object_ShakeAndDraw' (a.k.a. 'CODE_279EBC' in YF's orig. disasm.)
    JSL !SprShakeAndDraw

; as it turns out, the above routine already sets up the X/Y-positions of our four tiles to make a 16x16 sprite,
; and it even sets up our palettes! however, we wanna change the tiles, so we must get into 16-bit 'X/Y'
; to access the OAM index via sprite RAM $C6,x
    REP #$10
    LDY.b !SprOAMIndex,x

if !MirrorBothHalves == 1
; flip the second half of the thwimp's body if applicable
    LDA.w SMB3_OAMBuffer[$01].Prop,y
    EOR #$40
    STA.w SMB3_OAMBuffer[$01].Prop,y
    STA.w SMB3_OAMBuffer[$03].Prop,y
endif

; now draw the four tiles for the thwimp
    LDA #!ThwimpUpperTileL
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA #!ThwimpUpperTileR
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA #!ThwimpLowerTileL
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA #!ThwimpLowerTileR
    STA.w SMB3_OAMBuffer[$03].Tile,y

; if the sprite's Y-flipped in general (such as when dead), swap around the tiles!
    LDA !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    AND #$80
    BEQ .return16Bit

    LDA #!ThwimpUpperTileL
    STA.w SMB3_OAMBuffer[$02].Tile,y
    LDA #!ThwimpUpperTileR
    STA.w SMB3_OAMBuffer[$03].Tile,y
    LDA #!ThwimpLowerTileL
    STA.w SMB3_OAMBuffer[$00].Tile,y
    LDA #!ThwimpLowerTileR
    STA.w SMB3_OAMBuffer[$01].Tile,y

; exit 16-bit 'X/Y' & return!
.return16Bit
    SEP #$10
    RTL
