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
; for more graphical customization, please see 'custom_smb3_sprites_codes.asm'!

!GroundGrinderSprID     = $20       ;> this is the vanilla sprite ID to overwrite with the ground grinder

!GroundGrinderPal       = 5         ;> the ground grinder's palette (set to 0-7 for palettes 0x8-0xF respectively)
!GroundGrinderGFXPg     = 0         ;> if 0, the ground grinder's gonna use the 1st GFX page; if 1, then the 2nd GFX page

!BaseXSpeed             = $18       ;> the ground grinder's base X-speed

; the grinder's ticking sound. for the SFX values, please see 'SMB3/Misc_Defines_SMB3.asm'!
!GrinderTickSFX         = !Define_SMAS_Sound0060_Grinder

; for the SFX port, the following options are appropriate:
;   - '!RAM_SMB3_Global_SoundCh1' (corresponds to the SFX defines with 'Sound0060' in the name)
;   - '!RAM_SMB3_Global_SoundCh2' (corresponds to the SFX defines with 'Sound0061' in the name)
;   - '!RAM_SMB3_Global_SoundCh3' (corresponds to the SFX defines with 'Sound0063' in the name)
!GrinderTickSFXPort     = !RAM_SMB3_Global_SoundCh1

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

; since the sprite uses default interaction, we'll dummy out its stomped-on pointer with 'RTL : NOP : NOP' in little-endian
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

; have a player hitbox of 16x16 and be immune to fireballs!
org !SprHitboxImmuneProps+!GroundGrinderSprID
    db !OAT_BOUNDBOX01|!OAT_FIREIMMUNITY

; die in a puff of smoke
org !SprKillActionProps+!GroundGrinderSprID
    db !KILLACT_POOFDEATH

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
; call the grinder GFX routine always, and set the priority to be BEHIND all normal FG
    LDA #$10
    JSL GrinderGFX

; if the sprite's NOT alive or the game's frozen, return and simply draw the graphics!
    LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
    EOR #$02
    ORA.b !GameFrozenFlag
    BNE .return

; play the ticking sound every 4 frames
    LDA.b !RAM_SMB3_Global_FrameCounter
    AND #$03
    BNE +
    LDA #!GrinderTickSFX            ; the ticking SFX in question
    STA.w !GrinderTickSFXPort

; delete if off-screen
+   JSL !SubOffScreen

; apply vanilla gravity and interact with blocks, plus, interact with the player!
    JSL SprGravAndBlkInteract
    JSL !SprPlayerInteract
.return
    RTL

;======================================================================================================================;
; miscellaneous tables                                                                                                 ;
;======================================================================================================================;
ground_grinder_x_spds:
    db -!BaseXSpeed,!BaseXSpeed

ground_grinder_x_flip:
    db $00,$40
