;======================================================================================================================;
; these are the li'l sparky & hothead from Super Mario World, faithfully ported to SMAS SMB3!
; by default, these guys will move around solid blocks but be stranded if placed in mid-air, so be careful placing them!
;
; if the sprite's X-position is EVEN, it'll go LEFT; and if ODD, then it'll go RIGHT
; (SMB3 Foundry allows you to see the coordinates of EVERYTHING that you place in DECIMAL for easier tracking!)
;
; IMPORTANT NOTE: put the included 'GFX_Sprite_BoomBoom.bin' & 'GFX_Sprite_FlyingBoomBoom.bin' in 'SMB3/Graphics'
; so that the sprite renders properly!
;
; made by DrAnas, based upon Thomas's 'all.log': https://bin.smwcentral.net/u/7012/all.7z
;
;======================================================================================================================;
; start of user defines                                                                                                ;
;======================================================================================================================;
; the base speed for ALL wall-following sprites. the li'l sparky's speed will automatically be DOUBLE this value!
!BaseMovingSpeed        = $08

; how many frames until the sprite turns around. the li'l sparky's time will automatically be HALF this value!
!TimeTillTurn           = $1A

; how many frames WITHIN '!TimeTillTurn' until the sprite changes direction
; the li'l sparky's time will automatically be HALF this value!
!TimeTillChangeDir      = $10

;======================================================================================================================;
!LilSparkySprID         = $05       ;> the vanilla sprite IDs to overwrite with the new li'l sparky

!LilSparkyBodyTile      = $64       ;> the li'l sparky's body tile

!LilSparkyPal           = 1         ;> the li'l sparky's palette (set to 0-7 for palettes 0x8-0xF respectively)
!LilSparkyGFXPg         = 3         ;> if 0, the li'l sparky's gonna use the 1st GFX page; if 1, then the 2nd GFX page

;======================================================================================================================;
!HotheadSprID           = $1A       ;> the vanilla sprite IDs to overwrite with the new hothead

!HotheadOpenEyeTile     = $76       ;> the hothead's OPEN eye tile
!HotheadClosedEyeTile   = $77       ;> his CLOSED eye tile for when he's randomly blinking

!HotheadPal             = 1         ;> the hothead's palette (set to 0-7 for palettes 0x8-0xF respectively)
!HotheadGFXPg           = 3         ;> if 0, the hothead's gonna use the 1st GFX page; if 1, then the 2nd GFX page

; the tile numbers for the body tiles
; in order for each frame: TOPLEFT, TOPRIGHT, BOTTOMLEFT, and BOTTOMRIGHT
hothead_body_tiles:
    db $60,$62,$62,$60              ;> 1st frame
    db $62,$60,$60,$62              ;> 2nd frame

; X/Y-displacements for the body tiles
hothead_body_x_disps:
    db $F8,$08,$F8,$08
hothead_body_y_disps:
    db $F8,$F8,$08,$08

; the X/Y-flip properties for the body tiles
; set to $40 for X-flip, $80 for Y-flip, and $C0 for both!
hothead_body_flip_props:
    db $00,$00,$C0,$C0              ;> 1st frame
    db $40,$40,$80,$80              ;> 2nd frame

;======================================================================================================================;
; end of user defines                                                                                                  ;
;======================================================================================================================;
; please don't touch these! these are for ease of coding
!SprMoveDir         = !RAM_SMB3_Level_NorSpr_Table7E1021
!SprBlinkTimer      = !RAM_SMB3_Level_NorSpr_DecrementingTable7E0518
!SprTurnTimer       = !RAM_SMB3_Level_NorSpr_DecrementingTable7E0520

;======================================================================================================================;
; hijacks                                                                                                              ;
;======================================================================================================================;
; repoint our desired sprite's main pointer somewhere in vanilla
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!LilSparkySprID*3)
    dl WallFollowersMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!LilSparkySprID*3)
    dl WallFollowersInit

; since the li'l sparky uses default interaction, we'll dummy out his stomped-on pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!LilSparkySprID*3)
    dl $EAEA6B

; (since we're using a custom routine for finishing drawing all tiles so that no tiles wrap across the screen,
; there's no point in setting the visibility detection properties)

; have a block hitbox of 16x16 and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!LilSparkySprID
    db !OA2_TDOGRP1|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!LilSparkySprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; have a player hitbox of 16x16 and be immune to fireballs!
org !SprHitboxImmumeProps+!LilSparkySprID
    db !OAT_BOUNDBOX01|!OAT_FIREIMMUNITY

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!LilSparkySprID
    db !KILLACT_NORMALANDKILLED

; set the li'l sparky's pal. as desired
org !SprRealPalTable+!LilSparkySprID
    db !LilSparkyPal

; ditto with the sprite page
org !SprGFXPageTable+!LilSparkySprID
    db !LilSparkyGFXPg

;======================================================================================================================;
; repoint our desired sprite's main pointer somewhere in vanilla
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!HotheadSprID*3)
    dl WallFollowersMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!HotheadSprID*3)
    dl WallFollowersInit

; since the hothead uses default interaction, we'll dummy out his stomped-on pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!HotheadSprID*3)
    dl $EAEA6B

; (since we're using a custom routine for finishing drawing all tiles so that no tiles wrap across the screen,
; there's no point in setting the visibility detection properties)

; have a block hitbox of 16x16 and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!HotheadSprID
    db !OA2_TDOGRP1|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!HotheadSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; have a player hitbox of 16x16 and be immune to fireballs!
org !SprHitboxImmumeProps+!HotheadSprID
    db !OAT_BOUNDBOX01|!OAT_FIREIMMUNITY

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!HotheadSprID
    db !KILLACT_NORMALANDKILLED

; set the hothead's pal. as desired
org !SprRealPalTable+!HotheadSprID
    db !HotheadPal

; ditto with the sprite page
org !SprGFXPageTable+!HotheadSprID
    db !HotheadGFXPg

; always make sure to automatically find freespace, otherwise it'll overwrite important vanilla data!
freecode

;======================================================================================================================;
; initialization routine                                                                                               ;
;======================================================================================================================;
WallFollowersInit:
; move DOWN (VERTICALLY) if on an EVEN X-position, otherwise move RIGHT (HORIZONTALLY) if on an ODD X-position instead
; (note that in the original SMW, an extra sprite table was used to store the rotation direction, but since it's not referenced
; in the main code, we can simply use scratch RAM instead)
    LDA.b !RAM_SMB3_Level_NorSpr_XPosLo,x
    PHX
    LDY.b !SprSlotIndex
    LDX #$00
    AND #$10
    STA.b !RAM_SMB3_Global_ScratchRAM00
    BNE +
    INX
+   LDA.l move_around_blk_init_y_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_XSpeed,y
    LDA.l move_around_blk_init_y_spds+1,x
    STA.w !RAM_SMB3_Level_NorSpr_YSpeed,y
    PLX

; (in between these lines of code in the original SMW, the in-water flag was set for some reason, perhaps for the urchin?)

; store the initial movement direction
    LDA.b !RAM_SMB3_Global_ScratchRAM00
    EOR #$10
    LSR #2
    STA.w !SprMoveDir,x
    RTL

;======================================================================================================================;
; main routine                                                                                                         ;
;======================================================================================================================;
WallFollowersMain:
; always run the GFX, which will be far different depending on the sprite
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CMP #!LilSparkySprID
    BEQ +
    JSL HotheadGFX
    BRA ++
+   JSL LilSparkyGFX

; if the sprite's NOT alive or the game's frozen, return and simply draw the graphics!
++  LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
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

; (in between these lines of code in the original SMW, there was lots of urchin-specific code, plus some code for despawning
; the spike top if he passes below the screen, but for now, we're not porting either of these two sprites...)

; branch if in the process of turning
    LDA.w !SprTurnTimer,x
    BNE .startTurning

; set some fake X/Y-speeds for handling block interaction
; (we'll have to do weird X/Y-register shenanigans for it to work as intended as putting a bank wrapper over the whole code
; totally messes everything up for some reason :/)
    PHX
    LDY.b !SprSlotIndex
    LDA.w !SprMoveDir,x
    TAX
    LDA.l move_around_blk_fake_y_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_YSpeed,y
    LDA.l move_around_blk_fake_x_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_XSpeed,y
    PLX

; interact with blocks
    JSL !SprBlockInteract

;; call the code for aligning the sprite properly with the ground if it happens to touch it, as it seems that
;; '!SprBlockInteract/Object_WorldDetectN1' doesn't handle that already unlike SMW's sprite-block interaction routine
;    LDA.b !SprBlkdStatus,x
;    AND #$04
;    BEQ +
;    JSL !AlignSprWithGround

; if hitting a wall, set the timer for turning
+   LDA.b !SprBlkdStatus,x
    AND #$0F
    BNE .startTurning

; (in between these lines of code in the original SMW, a misc. decrementing sprite table was set to 0x8 for showing the
; spike top's diagonal frame, plus more code checking the urchin's sprite no., after which the turning timer would be set to 0x38)

; this is how long the hothead will take to turn, and the li'l sparky will take HALF that time, so TWICE as fast
    LDA #!TimeTillTurn
    LDY.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CPY #!LilSparkySprID
    BNE +
    LSR

; (in between these lines of code in the original SMW, there was an unnecessary 'NOP' here...)

+   STA.w !SprTurnTimer,x

; (in between these lines of code in the original SMW, there was more code checking the urchin's sprite no., after which
; the turning timer would be set to 0x20)

;======================================================================================================================;
; this is what frame within the turning timer the hothead will change direction at, and the li'l sparky will take HALF that time
.startTurning
    LDA #!TimeTillChangeDir
    LDY.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CPY #!LilSparkySprID
    BNE +
    LSR

; (in between these lines of code in the original SMW, there was another 'NOP' here...)

; handle changing direction at the OUTER corners
+   CMP.w !SprTurnTimer,x
    BNE ++
    INC.w !SprMoveDir,x
    LDA.w !SprMoveDir,x
    CMP #$04
    BNE +
    STZ.w !SprMoveDir,x
+   CMP #$08
    BNE ++
    LDA #$04
    STA.w !SprMoveDir,x

; handle changing direction at the INNER corners
++  PHX
    LDY.b !SprSlotIndex
    LDA.w !SprMoveDir,x
    TAX
    LDA.w !SprBlkdStatus,y
    AND.l move_around_blk_blkd_status,x
    BEQ .setSpeeds

; (in between these lines of code in the original SMW, a misc. decrementing sprite table was set to 0x8 for showing the
; spike top's diagonal frame, but for now we're not porting him...)

    PHX
    LDX.b !SprSlotIndex
    DEC.w !SprMoveDir,x
    PLX
    LDA.w !SprMoveDir,y
    BPL +
    LDA #$03
    BRA ++
+   CMP #$03
    BNE .setSpeeds
    LDA #$07
++  STA.w !SprMoveDir,y

;======================================================================================================================;
.setSpeeds
; set the X/Y-speeds based on the direction
    LDA.l move_around_blk_y_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_YSpeed,y
    LDA.l move_around_blk_x_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_XSpeed,y
    PLX

; if the current sprite's the li'l sparky, double its X/Y-speeds!
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CMP #!LilSparkySprID
    BNE .updatePos
    ASL.b !RAM_SMB3_Level_NorSpr_XSpeed,x
    ASL.b !RAM_SMB3_Level_NorSpr_YSpeed,x
.updatePos
; update the X/Y-positions
    JSL !SprUpdateXPos
    JML !SprUpdateYPos

;======================================================================================================================;
; li'l sparky graphics routine                                                                                         ;
;======================================================================================================================;
LilSparkyGFX:
; call 'Object_ShakeAndCalcSprite' (a.k.a. 'CODE_279DF9' in YF's orig. disasm.) & restore the sprite slot index afterwards,
; as the routine doesn't already restore it
+   JSL !SprShakeAndCalcTilePos
    LDX.b !SprSlotIndex

; as it turns out, the above routine sets up our raw 'YXPPCCCT' properties! however, we must get into 16-bit 'X/Y'
; to access the OAM index via sprite RAM $C6,x and also draw the hothead's four tiles on our own
    REP #$10
    LDY.b !SprOAMIndex,x

; set the li'l sparky's body tile's X/Y-displacements & tile number...
    LDA.b !RAM_SMB3_Global_ScratchRAM01
    STA.w SMB3_OAMBuffer[$00].XDisp,y
    LDA.b !RAM_SMB3_Global_ScratchRAM00
    STA.w SMB3_OAMBuffer[$00].YDisp,y
    LDA #!LilSparkyBodyTile
    STA.w SMB3_OAMBuffer[$00].Tile,y

; ...and then the 'YXPPCCCT', which will change based on the frame counter
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ORA.b !RAM_SMB3_Global_ScratchRAM03
    STA.w SMB3_OAMBuffer[$00].Prop,y

; now manipulate the frame counter with 'LSRs', and if it hits 0x1, X-flip the tiles!
    LDA.b !RAM_SMB3_Global_FrameCounter
    LSR #3
    AND #$01
    BNE .return16Bit

    LDA.w SMB3_OAMBuffer[$00].Prop,y
    EOR #$40
    STA.w SMB3_OAMBuffer[$00].Prop,y

; exit 16-bit 'X/Y' & return, restoring the sprite slot index in the progress
.return16Bit
    SEP #$10
    LDX.b !SprSlotIndex

; now we could be using SMB3's 16x16 sprite GFX routine, but that uses FOUR OAM slots to make a 16x16 tile, and manually
; dealing with the X/Y-flip there is a bit wasteful for our needs
; instead, we'll finish the OAM write with a specialized routine entirely!
; we'll be setting 'Y' to 0x2 to make the li'l sparky's tilemap a TRUE 16x16 one which takes up only ONE slot,
; & 'A' to the total no. of tiles drawn MINUS 1, which is only 1 tile here
    LDY #$02
    LDA #$00
    JML CustFinishOAMWrite

;======================================================================================================================;
; hothead graphics routine                                                                                             ;
;======================================================================================================================;
HotheadGFX:
; call the RNG, and if it hits 0x0, set the blinking timer normally
    LDA.w !RAM_SMB3_Global_RandomByte02
    AND #$FF
    BNE +
    LDA #$0C
    STA.w !SprBlinkTimer,x

; if the hothead's killed, then set the blinking timer to 0xFF so that he closes his eyes forever, and prevent him from
; getting Y-flipped
+   LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
    CMP #$02
    BEQ +
    LDA #$FF
    STA.w !SprBlinkTimer,x

; (please note that in the original SMW, the above two blocks of code were shared by ALL wall-following sprites-- that is,
; the hothead, urchin, spike top, fuzzy, and li'l sparky, but only the first two sprites actually make use of it...)

; here, we do a bitwise 'NOT' with the '~' (tilde) to effectively cancel out the Y-flip bit
+   LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    AND #~$80
    STA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x

; setup the eye tile based on the blinking timer

    LDY #!HotheadOpenEyeTile        ;> OPEN eye tile when the blinking timer's up
    LDA.w !SprBlinkTimer,x
    BEQ +
    LDY #!HotheadClosedEyeTile      ;> CLOSED eye tile when the blinking timer's ticking
+   STY.b !RAM_SMB3_Global_ScratchRAM0C

; call 'Object_ShakeAndCalcSprite' (a.k.a. 'CODE_279DF9' in YF's orig. disasm.) & restore the sprite slot index afterwards,
; as the routine doesn't already restore it
+   JSL !SprShakeAndCalcTilePos
    LDX.b !SprSlotIndex

; as it turns out, the above routine sets up our raw 'YXPPCCCT' properties! however, we must get into 16-bit 'X/Y'
; to access the OAM index via sprite RAM $C6,x and also draw the hothead's four tiles on our own
    REP #$10
    LDY.b !SprOAMIndex,x

; first, start with the eyes! they've gotta be IN FRONT of the hothead's whole body
; to make things a little easier, we'll write the eye tile first
    LDA.b !RAM_SMB3_Global_ScratchRAM0C
    STA.w SMB3_OAMBuffer[$00].Tile,y

; since we're in 16-bit 'X/Y', we'll need to clear the HIGH byte of '!SprMoveDir' before transferring it to 'X',
; otherwise crashes will likely ensue
    LDA #$00
    XBA
    LDA.w !SprMoveDir,x
    TAX

; now set the eye tile's X/Y-displacements according to the movement direction
    LDA.b !RAM_SMB3_Global_ScratchRAM01
    CLC : ADC.l hothead_eye_x_disps,x
    STA.w SMB3_OAMBuffer[$00].XDisp,y
    LDA.b !RAM_SMB3_Global_ScratchRAM00
    ADC.l hothead_eye_y_disps,x
    STA.w SMB3_OAMBuffer[$00].YDisp,y

; now setup the eye tile's 'YXPPCCCT' via scratch RAM $02 & $03 from 'Object_ShakeAndCalcSprite'
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ORA.b !RAM_SMB3_Global_ScratchRAM03
    STA.w SMB3_OAMBuffer[$00].Prop,y

; since the OAM tile size RAM is 1 byte PER TILE, compared to the other RAM addresses like X/Y-displacements,
; which is 4 bytes PER TILE, we're gonna have to divide the OAM index by 4 for proper access
+   PHY
    REP #$20
    TYA
    LSR #2
    TAY
    SEP #$20

; make the eye tile 8x8 & restore the original OAM index
    LDA #$00
    STA.w SMB3_OAMTileSizeBuffer[$00].Slot,y
    PLY

;======================================================================================================================;
; now loop for the 4 body tiles!
    LDX #$0003
.bodyLoop
; set each body tile's X/Y-displacements...
    LDA.b !RAM_SMB3_Global_ScratchRAM01
    CLC : ADC.l hothead_body_x_disps,x
    STA.w SMB3_OAMBuffer[$01].XDisp,y
    LDA.b !RAM_SMB3_Global_ScratchRAM00
    ADC.l hothead_body_y_disps,x
    STA.w SMB3_OAMBuffer[$01].YDisp,y

; ...then its tile no. & 'YXPPCCCT' based on which frame it's on
    LDA.l hothead_body_tiles,x
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ORA.b !RAM_SMB3_Global_ScratchRAM03
    ORA.l hothead_body_flip_props,x
    STA.w SMB3_OAMBuffer[$01].Prop,y

; now manipulate the frame counter with 'LSRs', and if it hits 0x1, X-flip the tiles!
    LDA.b !RAM_SMB3_Global_FrameCounter
    LSR #3
    AND #$01
    BNE +

    LDA.l hothead_body_tiles+4,x
    STA.w SMB3_OAMBuffer[$01].Tile,y
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ORA.b !RAM_SMB3_Global_ScratchRAM03
    ORA.l hothead_body_flip_props+4,x
    STA.w SMB3_OAMBuffer[$01].Prop,y

; since the OAM tile size RAM is 1 byte PER TILE, compared to the other RAM addresses like X/Y-displacements,
; which is 4 bytes PER TILE, we're gonna have to divide the OAM index by 4 for proper access
+   PHY
    REP #$20
    TYA
    LSR #2
    TAY
    SEP #$20

; make all body tiles 16x16 & restore the original OAM index
    LDA #$02
    STA.w SMB3_OAMTileSizeBuffer[$01].Slot,y
    PLY

; increase the OAM index by 4 each loop, and terminate once the tile loop counter becomes NEGATIVE
    INY #4
    DEX
    BPL .bodyLoop

; exit 16-bit 'X/Y' & return, restoring the sprite slot index in the progress
.return16Bit
    SEP #$10
    LDX.b !SprSlotIndex

; now since SMB3's way of preventing tiles from wrapping horizontally across the screen is VERY limited for our needs here,
; we'll finish the OAM write with a specialized routine entirely!
; we'll be setting 'Y' to 0xFF since all tile sizes are manually setup, & 'A' to the total no. of tiles drawn MINUS 1,
; which in the hothead's case is 5 tiles total
    LDY #$FF
    LDA #$04
    JML CustFinishOAMWrite

;======================================================================================================================;
; miscellaneous tables                                                                                                 ;
;======================================================================================================================;
; X/Y-displacements for the hothead's eye tile, for each direction of movement, making him 'look' in that specific direction
hothead_eye_x_disps:
    db $07,$07,$01,$01,$01,$01,$07,$07
hothead_eye_y_disps:
    db $00,$08,$08,$00,$00,$08,$08,$00

;======================================================================================================================;
; initial Y-speeds for the sprites that move around blocks
move_around_blk_init_y_spds:
    db !BaseMovingSpeed,$00,!BaseMovingSpeed

; REAL X/Y-speeds for each direction
move_around_blk_x_spds:
    db !BaseMovingSpeed,$00,-!BaseMovingSpeed,$00,-!BaseMovingSpeed,$00,!BaseMovingSpeed,$00
move_around_blk_y_spds:
    db $00,!BaseMovingSpeed,$00,-!BaseMovingSpeed,$00,!BaseMovingSpeed,$00,-!BaseMovingSpeed

; FAKE X/Y-speeds for each direction
move_around_blk_fake_x_spds:
    db $01,$FF,$FF,$01,$FF,$01,$01,$FF
move_around_blk_fake_y_spds:
    db $01,$01,$FF,$FF,$01,$01,$FF,$FF

; blocked statuses for each direction, used to determine whether or not the sprite's hit a wall
move_around_blk_blkd_status:
    db $01,$04,$02,$08,$02,$04,$01,$08
