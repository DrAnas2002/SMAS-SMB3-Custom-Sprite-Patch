;======================================================================================================================;
; these are the line-guided grinder & fuzzy from Super Mario World, faithfully ported to SMAS SMB3!
; just like the name, they'll move on line guides and fall off of them in the same manner as the line-guided platforms
; HOWEVER, due to technical limitations, they can only move in speeds that are multiples of 8 :/
;
; if the sprite's X-position is EVEN, it'll go LEFT; and if ODD, then it'll go RIGHT
; (SMB3 Foundry allows you to see the coordinates of EVERYTHING that you place in DECIMAL for easier tracking!)
;
; IMPORTANT NOTE: put the included 'GFX_Sprite_SkySprites.bin' in 'SMB3/Graphics' so that the sprite renders properly!
;
; made by DrAnas, based upon Thomas's 'all.log': https://bin.smwcentral.net/u/7012/all.7z
;
;======================================================================================================================;
; start of user defines                                                                                                ;
;======================================================================================================================;
!LineGuidedGrinderSprID = $0F       ;> this is the vanilla sprite ID to overwrite with the line-guided grinder

!LineGuidedGrinderPal   = 5         ;> the line-guided grinder's palette (set to 0-7 for palettes 0x8-0xF respectively)
!LineGuidedGrinderGFXPg = 0         ;> if 0, the line-guided grinder's gonna use the 1st GFX page; if 1, then the 2nd GFX page

; the grinder's ticking sound. for the SFX values, please see 'SMB3/Misc_Defines_SMB3.asm'!
!TickSFX                = !Define_SMAS_Sound0060_Grinder

; for the SFX port, the following options are appropriate:
;   - '!RAM_SMB3_Global_SoundCh1' (corresponds to the SFX defines with 'Sound0060' in the name)
;   - '!RAM_SMB3_Global_SoundCh2' (corresponds to the SFX defines with 'Sound0061' in the name)
;   - '!RAM_SMB3_Global_SoundCh3' (corresponds to the SFX defines with 'Sound0063' in the name)
!TickSFXPort            = !RAM_SMB3_Global_SoundCh1

!LineGuidedGrinderTile1 = $A8       ;> the FIRST tile for the grinder's animation
!LineGuidedGrinderTile2 = $AA       ;> the SECOND tile for the grinder's animation

;======================================================================================================================;
!LineGuidedFuzzySprID       = $10   ;> the vanilla sprite IDs to overwrite with the new line-guided fuzzy

!LineGuidedFuzzyUpperTileL  = $BC   ;> the TOPLEFT tile of the line-guided fuzzy
!LineGuidedFuzzyLowerTileL  = $BD   ;> the BOTTOMLEFT tile of the line-guided fuzzy

!LineGuidedFuzzyUpperTileR  = $BE   ;> the TOPRIGHT tile of the line-guided fuzzy
!LineGuidedFuzzyLowerTileR  = $BF   ;> the BOTTOMRIGHT tile of the line-guided fuzzy

!LineGuidedFuzzyPal         = 1     ;> the line-guided fuzzy's palette (set to 0-7 for palettes 0x8-0xF respectively)
!LineGuidedFuzzyGFXPg       = 0     ;> if 0, the line-guided fuzzy's gonna use the 1st GFX page; if 1, then the 2nd GFX page

;======================================================================================================================;
!GrinderHorzHitbox          = 12    ;> the grinder's HORIZONTAL hitbox (IN DECIMAL PIXELS, MUST BE POSITIVE!)
!GrinderVertHitbox          = 12    ;> the grinder's VERTICAL hitbox (IN DECIMAL PIXELS, MUST BE POSITIVE!)
!GrinderHitboxXPos          = 16    ;> the hitbox's X-position (IN DECIMAL PIXELS; NEGATIVE = LEFT, POSITIVE = RIGHT)
!GrinderHitboxYPos          = -16   ;> the hitbox's Y-position (IN DECIMAL PIXELS; NEGATIVE = UP, POSITIVE = DOWN)

!FuzzyHorzHitbox            = 12    ;> the fuzzy's HORIZONTAL hitbox (IN DECIMAL PIXELS, MUST BE POSITIVE!)
!FuzzyVertHitbox            = 12    ;> the fuzzy's VERTICAL hitbox (IN DECIMAL PIXELS, MUST BE POSITIVE!)
!FuzzyHitboxXPos            = 0     ;> the hitbox's X-position (IN DECIMAL PIXELS; NEGATIVE = LEFT, POSITIVE = RIGHT)
!FuzzyHitboxYPos            = -16   ;> the hitbox's Y-position (IN DECIMAL PIXELS; NEGATIVE = UP, POSITIVE = DOWN)

; the base speed for ALL line-guided sprites (MUST BE A MULTIPLE OF 0x8, OTHERWISE THE SPRITE WILL LIKELY DERAIL FROM
; FROM THE LINE GUIDES!)
!BaseLineGuideSpeed         = $08

;======================================================================================================================;
; end of user defines                                                                                                  ;
;======================================================================================================================;
; please don't touch these! these are for ease of coding
!LineGuidedSprActiveFlg = $4D
!LineGuidedSprDirOffset = $68

;======================================================================================================================;
; hijacks                                                                                                              ;
;======================================================================================================================;
; repoint the LINE-GUIDED GRINDER'S main pointer somewhere in automatically-found freespace
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!LineGuidedGrinderSprID*3)
    dl SMWLineGuidedSprsMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!LineGuidedGrinderSprID*3)
    dl SMWLineGuidedSprsInit

; since sadly none of the vanilla player/sprite hitboxes suit our line-guided sprites, we'll need to code our own...
; even more sadly, even if we call our interaction thru here, it still assumes our vanilla player/sprite hitbox!
; hence, we'll dummy out its interaction pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!LineGuidedGrinderSprID*3)
    dl $EAEA6B

; for the off-screen detection, use a height of 16 pixels & a width of 48 pixels
org !SprPalHeightWidthProps+!LineGuidedGrinderSprID
    db !OA1_HEIGHT16|!OA1_WIDTH48

; have a special hitbox for line guides and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!LineGuidedGrinderSprID
    db !OA2_TDOGRP9|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!LineGuidedGrinderSprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; dummy out the hitbox since we'll code our own, and be immune to ALL weapons & kicked sprites!
org !SprHitboxImmuneProps+!LineGuidedGrinderSprID
    db !OAT_BOUNDBOX00|!OAT_WEAPONIMMUNITY|!OAT_HITNOTKILL

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!LineGuidedGrinderSprID
    db !KILLACT_NORMALANDKILLED

; set the sprite's palette as desired
org !SprRealPalTable+!LineGuidedGrinderSprID
    db !LineGuidedGrinderPal

; ditto with the sprite page
org !SprGFXPageTable+!LineGuidedGrinderSprID
    db !LineGuidedGrinderGFXPg

;======================================================================================================================;
; line-guided fuzzy-related hijacks                                                                                    ;
;======================================================================================================================;
; now repoint the LINE-GUIDED FUZZY'S main pointer somewhere in automatically-found freespace
; (the pointer is 24-bit, hence we need to multiply the desired sprite no. by 3 to get the right pointer)
org SMB3_NorSprStatus02_Normal_NormalSpriteMainPointers+(!LineGuidedFuzzySprID*3)
    dl SMWLineGuidedSprsMain

; ditto with the init pointer
org SMB3_NorSprStatus01_Init_NormalSpriteInitPointers+(!LineGuidedFuzzySprID*3)
    dl SMWLineGuidedSprsInit

; since sadly none of the vanilla player/sprite hitboxes suit our line-guided sprites, we'll need to code our own...
; even more sadly, even if we call our interaction thru here, it still assumes our vanilla player/sprite hitbox!
; hence, we'll dummy out its interaction pointer with 'RTL : NOP : NOP' in little-endian
org !SprCustInteractTable+(!LineGuidedFuzzySprID*3)
    dl $EAEA6B

; for the off-screen detection, use a height of 16 pixels & a width of 48 pixels
org !SprPalHeightWidthProps+!LineGuidedFuzzySprID
    db !OA1_HEIGHT16|!OA1_WIDTH48

; have a special hitbox for line guides and ALWAYS use the 16-bit X-position for certain calculations in vertical levels
org !SprBlkDetectMiscProps+!LineGuidedFuzzySprID
    db !OA2_TDOGRP9|!OA2_USE16BITX

; just run the normal code when frozen so we can deal with it ourselves, be unstompable, and be immune to tail attacks!
org !SprGameHaltMiscProps+!LineGuidedFuzzySprID
    db !OA3_HALT_NORMALONLY|!OA3_NOTSTOMPABLE|!OA3_TAILATKIMMUNE

; dummy out the hitbox since we'll code our own, and be immune to ALL weapons & kicked sprites!
org !SprHitboxImmuneProps+!LineGuidedFuzzySprID
    db !OAT_BOUNDBOX00|!OAT_WEAPONIMMUNITY|!OAT_HITNOTKILL

; just run the normal code when killed so we can deal with it ourselves
org !SprKillActionProps+!LineGuidedFuzzySprID
    db !KILLACT_NORMALANDKILLED

; set the sprite's palette as desired
org !SprRealPalTable+!LineGuidedFuzzySprID
    db !LineGuidedFuzzyPal

; ditto with the sprite page
org !SprGFXPageTable+!LineGuidedFuzzySprID
    db !LineGuidedFuzzyGFXPg

; always make sure to automatically find freespace, otherwise it'll overwrite important vanilla data!
freecode

;======================================================================================================================;
; initialization routine                                                                                               ;
;======================================================================================================================;
SMWLineGuidedSprsInit:
; if the sprite's X-position is ODD, go RIGHT; and if EVEN, go LEFT
; (here, 0x0 = RIGHT & 0x8 = LEFT, so we isolate bit 5 of the X-position to get either 0x0 or 0x10 respectively, then
; divide it further by 2 to potentially get 0x8)
    LDA.b !RAM_SMB3_Level_NorSpr_XPosLo,x
    AND #$10
    LSR
    STA.b !LineGuidedSprDirOffset,x

; continue with the rest of the vanilla line-guided sprite init, just because it's already there
    JML SMB3_NorSpr03C_LineGuidedWoodPlatform_Status01

;======================================================================================================================;
; main routine                                                                                                         ;
;======================================================================================================================;
SMWLineGuidedSprsMain:
; always run the GFX, which will be far different depending on the sprite
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CMP #!LineGuidedGrinderSprID
    BEQ .grinderGFX

;======================================================================================================================;
.fuzzyGFX
; every 8 frames, X-flip the ground fuzzy's body
    LDA.b !RAM_SMB3_Global_FrameCounter
    AND #$07
    BNE +
    LDA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x
    EOR #$40
    STA.w !RAM_SMB3_Level_NorSpr_YXPPCCCT,x

; prepare the line-guided fuzzy's tiles
+   LDA #!LineGuidedFuzzyUpperTileL
    STA.b !RAM_SMB3_Global_ScratchRAM0A
    LDA #!LineGuidedFuzzyLowerTileL
    STA.b !RAM_SMB3_Global_ScratchRAM0B
    LDA #!LineGuidedFuzzyUpperTileR
    STA.b !RAM_SMB3_Global_ScratchRAM0C
    LDA #!LineGuidedFuzzyLowerTileR
    STA.b !RAM_SMB3_Global_ScratchRAM0D

; since our hitbox will be physically displaced, we must preserve the sprite's original X-position first, then offset it
; appropriately to align with the hitbox
; (our custom sprite GFX routine will use the X-position as a base for the tile X-displacements, and this is PARAMOUNT
; for not letting them wrap horizontally across the screen!)
    LDA.b !RAM_SMB3_Level_NorSpr_XPosLo,x
    PHA
    CLC : ADC #$10
    STA.b !RAM_SMB3_Level_NorSpr_XPosLo,x

; don't let both halves be X-flipped!
    LDA #$00

; call our custom 16x16 GFX routine!
    JSL Draw16x16Sprite

; restore the original X-position and continue further!
    PLA
    STA.b !RAM_SMB3_Level_NorSpr_XPosLo,x
    BRA .mainCont

;======================================================================================================================;
.grinderGFX
; call the grinder GFX routine
    JSL LineGuidedGrinderGFX

;======================================================================================================================;
.mainCont
; if the sprite's NOT alive or the game's frozen, return and simply draw the graphics!
    LDA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x
    EOR #$02
    ORA.b !GameFrozenFlag
    BNE .return

; play the ticking sound every 4 frames if NOT the fuzzy
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CMP #!LineGuidedFuzzySprID
    BEQ +
    LDA.b !RAM_SMB3_Global_FrameCounter
    AND #$03
    BNE +
    LDA #!TickSFX               ;> the ticking SFX in question
    STA.w !TickSFXPort

; delete if off-screen
+   JSL !SubOffScreen

; run our custom player interaction to account for the graphical offsetting of our sprites with the line guides
; (luckily no need to worry about sprites or projectiles!)
    JSL SMWLineGuidedSprsInteract

; if it's NOT activated yet, simply update the X/Y-positions!
    LDA.b !LineGuidedSprActiveFlg,x
    BEQ +

; if it IS activated, continue further with the line guide interaction
    LSR
    BEQ .verticalAlign

; otherwise, increase its falling rate & update the X/Y-positions in the progress
    INC.b !RAM_SMB3_Level_NorSpr_YSpeed,x
+   JML .updatePos

.return
    RTL

;======================================================================================================================;
.verticalAlign
; if NOT moving VERTICALLY, check its HORIZONTAL alignment with the line guide tiles
    LDA.b !RAM_SMB3_Level_NorSpr_YSpeed,x
    BEQ .horizontalAlign

; if NEAR halfway DOWN the line guide tile grid, immediately start detecting the tiles to interact with, otherwise,
; simply update the X/Y positions
    LDA.b !RAM_SMB3_Level_NorSpr_YPosLo,x
    AND #$0F
    CMP #$06
    BEQ .lineGuideTileDetectLoopStart
    JML .updatePos

;======================================================================================================================;
.horizontalAlign
; if NOT EXACTLY halfway ACROSS the line guide tile grid, simply update the X/Y positions, immediately start detecting
; the tiles to interact with, otherwise, simply update the X/Y positions
    LDA.b !RAM_SMB3_Level_NorSpr_XPosLo,x
    AND #$0F
    CMP #$08
    BEQ .lineGuideTileDetectLoopStart
    JML .updatePos

;======================================================================================================================;
.lineGuideTileDetectLoopStart
; now prepare the starting point for looping thru the 4 tiles the sprite may touch
    LDA #$03
    STA.b !RAM_SMB3_Global_ScratchRAM0C

; here in the vanilla SMB3's line-guided sprite code, RAM $0418 was used, which in the original NES game would hold
; the sprite's relative index within its sprite group, which is apparently the original bank its code was in. afterwards,
; it would be used to get the necessary hitbox from the table at 'DATA_21BB30'
; however, that won't work well for our needs, so we'll be getting the last 4 bits of the sprite's REAL hitbox, then divide
; it by 2 for the tile-detecting routine
    PHX
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    TAX
    LDA.l !SprBlkDetectMiscProps,x
    PLX
    AND #$F0
    LSR
    TAY
.lineGuideTileDetectLoop
; store the above result to scratch RAM $0D in 'Y' for the below tile-detecting routine
; (I'm not 100% sure how that'll truly affect the tile interaction...)
    STY.b !RAM_SMB3_Global_ScratchRAM0D

; detect which tile the sprite's touching, and store it to scratch RAM $08, which in turn is indexed by the loop counter index
; 'Y' will access a table called 'DATA_21ADCA', which apparently determines the Y/X-offset pairs for interacting with
; a block in certain situations according to its hitbox option from 'ObjectGroup_Attributes2':
;   - row 1: sprite Y-speed >= 0x0 (on the ground or moving DOWN)
;   - row 2: sprite Y-speed < 0x0 (moving UP)
;   - row 3: sprite X-speed < 0x0 (moving LEFT)
;   - row 4: sprite X-speed >= 0x0 (moving RIGHT)
    JSL !SprDetectTile
    LDY.b !RAM_SMB3_Global_ScratchRAM0C
    STA.w !RAM_SMB3_Global_ScratchRAM08,y

; increase 'Y' by 2 to access the next Y/X-offset pairs
    LDY.b !RAM_SMB3_Global_ScratchRAM0D
    INY #2

; keep thru looping thru the 4 tiles the sprite may touch until the loop counter index is NEGATIVE
    DEC.b !RAM_SMB3_Global_ScratchRAM0C
    BPL .lineGuideTileDetectLoop

;======================================================================================================================;
.lineGuideTileLoopStart
; prepare the starting point for looping thru all index offsets looking for the next line guide tile
    LDA #$0C
    STA.b !RAM_SMB3_Global_ScratchRAM0C

; store the directional offset in advance for easier checking
    LDA.b !LineGuidedSprDirOffset,x
    STA.b !RAM_SMB3_Global_ScratchRAM0D
.lineGuideTileLoop
; now use the amount of offsets from before to access the index offsets looking for the next line guide tile
    LDX.b !RAM_SMB3_Global_ScratchRAM0C
    LDA.l DATA_21BCC8,x

; now add the directional offset to it & isolate the first 4 bits so we can finally index which of the 4 line guide
; tiles we'll need to check next
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM0D
    AND #$0F
    TAX
    LDA.l DATA_21BCD5,x

    TAY
    LDA.w !RAM_SMB3_Global_ScratchRAM08,y

; if it's one of the athletic line guide tiles...
    CMP.l DATA_21BCE5,x
    BEQ .hitLineGuide

; ...or the castle ones, set the directional offset accordingly & continue from there
    CMP.l DATA_21BCF5,x
    BEQ .hitLineGuide

; if the directional offset is NON-ZERO, stop the sprite!
    CPX.b !RAM_SMB3_Global_ScratchRAM0D
    BNE .stopSpr

; if it's NOT the line guide end, stop the sprite, otherwise, continue further!
    CMP #$D0
    BNE .stopSpr

; change the direction now!
    TXA
    EOR #$08
    TAX
    BRA .hitLineGuide
.stopSpr
    DEC.b !RAM_SMB3_Global_ScratchRAM0C
    BPL .lineGuideTileLoop

; maintain the activated flag
    LDX.b !SprSlotIndex
    INC.b !LineGuidedSprActiveFlg,x

; index the stopping X/Y-speeds, which should all be 0x0
    LDX #$10
.hitLineGuide
; restore the sprite slot index & set the directional offset (either 0x0 or 0x8)
    LDY.b !SprSlotIndex
    TXA
    STA.w !LineGuidedSprDirOffset,y

; set the sprite's X/Y-speeds according to the line guide tile it's on
    LDA.l line_guided_spr_x_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_XSpeed,y
    LDA.l line_guided_spr_y_spds,x
    STA.w !RAM_SMB3_Level_NorSpr_YSpeed,y

.updatePos
; restore the sprite slot index & update the X/Y-positions!
    LDX.b !SprSlotIndex
    JSL !SprUpdateXPos
    JML !SprUpdateYPos

;======================================================================================================================;
; line-guided grinder GFX routine                                                                                      ;
;======================================================================================================================;
LineGuidedGrinderGFX:
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
    LDA.l line_guided_grinder_x_disps,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM01
    STA.w SMB3_OAMBuffer[$00].XDisp,y
    LDA.l line_guided_grinder_y_disps,x
    CLC : ADC.b !RAM_SMB3_Global_ScratchRAM00
    STA.w SMB3_OAMBuffer[$00].YDisp,y

; preserve the tile loop counter index and change the grinder's tile based on the frame counter
; (we divide it by 4 to slow it down a bit and restrict the total no. of frames to 0x0-0x1 for the final check)
    PHX
    LDX.w #!LineGuidedGrinderTile1
    LDA.b !RAM_SMB3_Global_FrameCounter
    LSR #2
    AND #$01
    BNE +
    LDX.w #!LineGuidedGrinderTile2
+   TXA
    STA.w SMB3_OAMBuffer[$00].Tile,y
    PLX

; now set the 'YXPPCCCT', where scratch RAM $02 from 'Object_ShakeAndCalcSprite' already holds the sprite's palette,
; and $03 holds the other properties such as X/Y-flip
    LDA.b !RAM_SMB3_Global_ScratchRAM02
    ORA.b !RAM_SMB3_Global_ScratchRAM03

; now all of the sprite's tiles will also be INDIVIDUALLY X/Y-flipped if the WHOLE sprite's flipped accordingly,
; which we don't want, so we'll cancel out those bits with a bitwise 'NOT' (the '~' here)
    AND #~$C0

; factor in each tile's individual X/Y-flip setting
    ORA.l line_guided_grinder_flip_props,x
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

;======================================================================================================================;
; interaction routine                                                                                                  ;
;======================================================================================================================;
SMWLineGuidedSprsInteract:
; prepare the parameters for the either the grinder or fuzzy's hitbox depending on the sprite ID
.grinderHitbox
    LDA #!GrinderHitboxXPos
    STA.b !RAM_SMB3_Global_ScratchRAM00
    LDA #!GrinderHitboxYPos
    STA.b !RAM_SMB3_Global_ScratchRAM01
    LDA #!GrinderHorzHitbox
    STA.b !RAM_SMB3_Global_ScratchRAM02
    LDA #!GrinderVertHitbox
    STA.b !RAM_SMB3_Global_ScratchRAM03

.fuzzyHitbox
    LDA.w !RAM_SMB3_Level_NorSpr_SpriteID,x
    CMP #!LineGuidedFuzzySprID
    BNE .checkHitbox
    LDA #!FuzzyHitboxXPos
    STA.b !RAM_SMB3_Global_ScratchRAM00
    LDA #!FuzzyHitboxYPos
    STA.b !RAM_SMB3_Global_ScratchRAM01
    LDA #!FuzzyHorzHitbox
    STA.b !RAM_SMB3_Global_ScratchRAM02
    LDA #!FuzzyVertHitbox
    STA.b !RAM_SMB3_Global_ScratchRAM03

.checkHitbox
; now run the hitbox interaction code, and return if there's no contact!
    JSL SprCustomPlayerHitbox
    BCC .return

; if the player has a goomba/kuribo shoe on, stomp on the sprite normally, otherwise hurt them!
    LDA.w !RAM_SMB3_Level_Player_InKuriboShoeFlag
    BEQ .hurtPlayer

; if the player's Y-speed is NEGATIVE (i.e., jumping), just hurt the player!
    LDA.b !RAM_SMB3_Level_Player_YSpeed
    BMI .hurtPlayer

;======================================================================================================================;
.stompOnSpr
; this was in the original code and changes the player's bouncing Y-speed if the ROM is a European one,
; tho it wouldn't hurt to keep it in
if !Define_Global_ROMToAssemble&(!ROM_SMASW_E|!ROM_SMAS_E|!ROM_SMB3_E) != $00
    LDA #$AA
else
    LDA #$C0
endif
    STA.b !RAM_SMB3_Level_Player_YSpeed

; kill the sprite, of course!
    LDA #$06
    STA.w !RAM_SMB3_Level_NorSpr_CurrentStatus,x

; play the normal stomp SFX & setup the consecutive scoring
    LDA #!Define_SMAS_Sound0060_Contact
    STA.w !RAM_SMB3_Global_SoundCh1
    LDA.w !RAM_SMB3_Level_ConsecutiveEnemiesStompedCounter
    JSL !GiveConsecPts100
    INC.w !RAM_SMB3_Level_ConsecutiveEnemiesStompedCounter
.return
    RTL

.hurtPlayer
    JML !HurtPlayer

;======================================================================================================================;
; miscellaneous tables                                                                                                 ;
;======================================================================================================================;
; X/Y-displacements for the grinder's tiles
line_guided_grinder_x_disps:
    db $08,$18,$08,$18
line_guided_grinder_y_disps:
    db $F8,$F8,$08,$08

; the X/Y-flip properties for the grinder's tiles
; set to $40 for X-flip, $80 for Y-flip, and $C0 for both!
line_guided_grinder_flip_props:
    db $00,$40,$80,$C0

;======================================================================================================================;
line_guided_spr_x_spds:
; FORWARD speeds
    db $00,!BaseLineGuideSpeed,!BaseLineGuideSpeed,!BaseLineGuideSpeed*2
    db !BaseLineGuideSpeed*2,!BaseLineGuideSpeed*2,!BaseLineGuideSpeed,!BaseLineGuideSpeed
; REVERSE speeds
    db $00,-!BaseLineGuideSpeed,-!BaseLineGuideSpeed,-(!BaseLineGuideSpeed*2)
    db -(!BaseLineGuideSpeed*2),-(!BaseLineGuideSpeed*2),-!BaseLineGuideSpeed,-!BaseLineGuideSpeed
; stopping speed
    db $00

line_guided_spr_y_spds:
; FORWARD speeds
    db -(!BaseLineGuideSpeed*2),-(!BaseLineGuideSpeed*2),-(!BaseLineGuideSpeed*2),-(!BaseLineGuideSpeed*2)
    db $00,!BaseLineGuideSpeed*2,!BaseLineGuideSpeed*2,!BaseLineGuideSpeed*2
; REVERSE speeds
    db !BaseLineGuideSpeed*2,!BaseLineGuideSpeed*2,!BaseLineGuideSpeed*2,!BaseLineGuideSpeed*2
    db $00,-(!BaseLineGuideSpeed*2),-(!BaseLineGuideSpeed*2),-(!BaseLineGuideSpeed*2)
; stopping speed
    db $00

