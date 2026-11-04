;======================================================================================================================;
; this patch allows you to to replace whatever vanilla SMAS SMB3 sprites you want with your own custom sprite codes!
; it also allows you to add whatever custom routines you might need for your sprites
;
; STRICTLY REQUIRES YOSHIFANATIC'S SMAS SMB3 DISASSEMBLY FOR OPTIMAL INSERTION & REMOVAL!
; https://github.com/DrAnas2002/SMW-SMAS-SMASW-Disassembly-LINUX
;
; using this patch on the STANDALONE SMB3 version is HIGHLY RECOMMENDED, especially since there's no direct Linux support
; for assembling the full game yet (may change in the future!)
;
; HOW TO APPLY THE PATCH?
;   1. drag the whole 'Custom SMB3 Sprite Patch' folder to 'SMB3/Custom'
;
;   2. open 'Asar_Patches_SMB3.asm' & under 'macro SMB3_InsertIntegratedPatches()', put this directly:
;   incsrc "Custom SMB3 Sprite Patch/custom_smb3_sprites_patch.asm"
;
;   3. now go to 'SMB3/RomMap/ROM_Map_SMB3_U.asm' and set '!Define_Global_ApplyAsarPatches' to '!TRUE'
;
;   4. SKIP THIS STEP IF THE DISASSEMBLY'S FRAMEWORK IS UPDATED TO REMOVE THIS PARTICULAR OVERSIGHT!
;   go to 'Global/Global_Macros.asm' & around line 1,076, change '%GetROMSize' to '%GetROMSize()'
;
;   5. finally, go back to 'SMB3' & either run 'Assemble_SMB3.bat' if on Windows, or 'assemble_smb3__linux.sh' if on Linux
;   to assemble the standalone SMB3 ROM. you could theoretically assemble the whole SMAS easily if on Windows, but again,
;   there's no native Linux support yet, and you'd have to change 'StartingFreespace to something else to avoid corruptions
;
;   6. enjoy your custom sprites!
;
; IMPORTANT NOTE: it's assumed you know how to easily edit your SMAS SMB3 levels indirectly, particularly via SMB3 Foundry.
; if not, then please read this WIP tutorial of mine! https://github.com/DrAnas2002/SMAS-SMB3-Level-Editing-Tutorial
;
; IMPORTANT NOTE 2: since there's no direct SMAS SMB3 editor yet, you can't directly place your new sprites there.
; depending on what vanilla sprite pointers you overwrote, you'd have to go to SMB3 Foundry and place those particular
; sprites there, then port your level data over to your SMAS SMB3 hack your your desired hex editor and see from here
;
; for a list of all vanilla sprites, please see 'SMB3/Notes.txt'. those IDs correspond mostly to the sprite list Foundry shows,
; but for some reason, Foundry WON'T directly let you place sprite 0x00. if you don't care about it, you can ignore the rest of this note
;
; HOWEVER, if you DO care, then to work around it, you need to keep track of all instances of a certain other sprite that you place
; (for some reason Foundry doesn't show you the hex sprite IDs yet) and afterwards, once you port your sprite data over to the
; SMAS SMB3 side, you can hex-edit all instances of that sprite ID to sprite 0x00
;
; for instance, if I put unknown sprite 0x20 (which is one ID after the vine head in Foundry), I'd have to keep track of that
; in my hex editor and replace all instances with sprite 0x00. the whole sprite data typically starts at the value 0x01,
; so starting from the byte directly after it, you must count every 3 bytes to keep track of the sprite IDs
;
; phew, kinda long to explain, isn't it? if SMB3 Foundry allows you to directly place sprite 0x00 AND see every hex sprite IDs,
; this tedium should be largely eliminated!
;
; IMPORTANT NOTE 3: if you're using YF's original disassembly, please set this to 0, otherwise you'll get a bunch of errors!
; it's set to 1 as by default I'm using hericium1's documented version of YF's disasm.:
; https://github.com/hericium1/SMW-SMAS-SMASW-Disassembly/tree/main

!Hericium1DisASM    = 1

; made by DrAnas, and credit to Yoshifanatic for the fantastically-designed SMAS disassembly!

;======================================================================================================================;
; shared label defines                                                                                                 ;
;======================================================================================================================;
macro define_label_names(name, label_yf, label_hericium1)
    if !Hericium1DisASM == 0
        !<name> = <label_yf>
    else
        !<name> = <label_hericium1>
    endif
endmacro

%define_label_names(SubOffScreen, CODE_279BC4, Object_DeleteOffScreen)
%define_label_names(SprShakeAndDraw, CODE_279EBC, Object_ShakeAndDraw)
%define_label_names(SprUpdateYPos, CODE_27A7D9, CODE_27A7D9)
%define_label_names(SprUpdateXPos, CODE_27A7F0, Object_ApplyXVel)
%define_label_names(SprBlockInteract, CODE_278B93, Object_WorldDetectN1)
%define_label_names(AlignSprWithGround, CODE_278B67, CODE_278B67)
%define_label_names(SprPlayerInteract, CODE_279B70, CODE_279B70)
%define_label_names(FlipSprDir, CODE_28B905, Object_AboutFace)
%define_label_names(CheckPlayerCont, CODE_27A317, Object_HitTestRespond)
%define_label_names(SubHorzPosCoarse, CODE_27A7AE, Object_CalcCoarseXDiff)
%define_label_names(SubVertPosCoarse, CODE_27A7C5, CODE_27A7C5)
%define_label_names(ConveyorMoveSpr, CODE_278B28, CODE_278B28)
%define_label_names(SprConveyorCheckCarry, CODE_278B48, CODE_278B48)
%define_label_names(HurtPlayer, CODE_28CEA8, CODE_28CEA8)
%define_label_names(GiveConsecPts100, CODE_278A8A, CODE_278A8A)
%define_label_names(GetSprClippingVals1, CODE_27A413, Object_CalcBoundBox)
%define_label_names(GetSprClippingVals2, CODE_27A43A, CODE_27A43A)
%define_label_names(SprSprIntersect, CODE_27A460, CODE_27A460)

%define_label_names(SprPalHeightWidthProps, DATA_21B047, ObjectGroup_Attributes)
%define_label_names(SprBlkDetectMiscProps, DATA_21B0FB, ObjectGroup_Attributes2)
%define_label_names(SprGameHaltMiscProps, DATA_21B1AF, ObjectGroup_Attributes3)
%define_label_names(SprHitboxImmumeProps, DATA_21AE78, Object_AttrFlags)
%define_label_names(SprKillActionProps, DATA_21B317, ObjectGroup_KillAction)
%define_label_names(SprRealPalTable, DATA_21B263, SNES_ObjectGroup_AttributesPalette)
%define_label_names(SprGFXPageTable, DATA_21B3CB, SNES_ObjectGroup_PatTableSelHi)
%define_label_names(SprCustInteractTable, DATA_288438, ObjectGroup_CollideJumpTable)

;======================================================================================================================;
; shared variable defines                                                                                              ;
;======================================================================================================================;
; please don't touch these! these are for ease of coding
!LastScrollDir      = $25
!SprSlotIndex       = $9B
!GameFrozenFlag     = $9C
!SprBlkdStatus      = $A7
!SprOAMIndex        = $C6

; this RAM address isn't labelled in hericium1's disasm. yet, but it's $0210 (2 bytes!)
!Horz_Scroll        = $0210

; this RAM address is already labelled in hericium1's disasm., and it's $0216 (2 bytes!), but in case you use YF's
; original disasm., I included it here as well
!Vert_Scroll        = $0216

; this RAM address isn't labelled in hericium1's disasm. yet, but it's $06B7
!SprInWater         = $06B7

; this RAM address isn't labelled in hericium1's disasm. yet, but it's $07B5
!SprConvTileTouched = $07B5

;======================================================================================================================;
; all the defines from here were copied from 'smb3.asm' of Captain Southbird's disasm.:
; https://github.com/captainsouthbird/smb3/blob/master/smb3.asm

; 'ObjectGroup_Attributes' (a.k.a. 'DATA_21B047' in YF's orig. disasm.) table settings

; bits 0-1: this seems to be completely redundant since defining any of these in the final value for the sprite's attributes
; does nothing-- the palette won't change! this is of course a leftover from the NES version, where you could only choose
; four palettes for your sprites. still, I left them here for documentation's sake

!OA1_PAL0           = %00000000         ;> the sprite uses sprite palette 0x8
!OA1_PAL1           = %00000001         ;> the sprite uses sprite palette 0x9
!OA1_PAL2           = %00000010         ;> the sprite uses sprite palette 0xA
!OA1_PAL3           = %00000011         ;> the sprite uses sprite palette 0xB

; bits 2-3: the sprite's HEIGHT that'll be checked for VERTICAL visibility testing via 'SMB3_CheckIfSpriteIsVerticallyOffScreen_Main'
; so that none of the sprite's tiles wrap across the screen
; for the object's ACTUAL hitbox, please see the '!OAT_BOUNDBOXxx' defines

!OA1_HEIGHT16       = %00000000         ;> the sprite's 16 pixels tall
!OA1_HEIGHT32       = %00000100         ;> the sprite's 32 pixels tall
!OA1_HEIGHT48       = %00001000         ;> the sprite's 48 pixels tall
!OA1_HEIGHT64       = %00001100         ;> the sprite's 64 pixels tall

; bits 2-3: the sprite's WIDTH that'll be checked for HORIZONTAL visibility testing via 'SMB3_CheckIfSpriteIsHorizontallyOffScreen_Main'
; so that none of the sprite's tiles wrap across the screen

!OA1_WIDTH8         = %00000000         ;> the sprite's 8 pixels wide
!OA1_WIDTH16        = %00010000         ;> the sprite's 16 pixels wide
!OA1_WIDTH24        = %00100000         ;> the sprite's 24 pixels wide
!OA1_WIDTH32        = %00110000         ;> the sprite's 32 pixels wide
!OA1_WIDTH40        = %01000000         ;> the sprite's 40 pixels wide
!OA1_WIDTH48        = %01010000         ;> the sprite's 48 pixels wide

;======================================================================================================================;
; 'ObjectGroup_Attributes2' (a.k.a. 'DATA_21B0FB' in YF's orig. disasm.) table settings

; bit 0: if set, then the sprite WON'T go into the shelled (state 0x3) or squashed (state 0x7) states when stomped on
!OA2_NOSHELLORSQUASH    = %00000001

; bit 1: SB calls this the 'grounded player mod', and if set, it modifies the player-sprite interaction
; while the player's on the ground
; this is how he explains it in 'prg000.asm' of his disasm. (https://github.com/captainsouthbird/smb3/blob/master/PRG/prg000.asm):
;
; "What does this do?
; First off, Player must be on solid ground
; Then, either the object is falling faster than $0A OR the object is on the ground
; In those cases, we jump to Object_HoldKickOrHurtPlayer
;
; The only real apparent function here is that a fast-falling or grounded object
; will force into the "Hold, Kick, or Hurt Player" routine without doing the
; the other checks, but with the Player being on the ground, it's hard for him
; not to get hit anyway.  As such, I can't really for sure tell what the
; intention of this code was really supposed to be??
;
; Otherwise it is PRG000_D218"
;
; ('Object_HoldKickOrHurtPlayer' = 'CODE_279AFA' in YF's orig. disasm.; 'PRG000_D218' = 'CODE_2799D9')
!OA2_GNDPLAYERMOD       = %00000010

; bit 2: if set, the sprite WON'T care about being stomped
; (i.e., it doesn't matter whether the player touches the top or sides of the sprite. NOT the same as '!OA3_NOTSTOMPABLE'!)
!OA2_STOMPDONTCARE      = %00000100

; bit 3: if set, then when applying X-speed, the HIGH BYTE of the X-position will be calculated
; (applies to VERTICAL LEVELS ONLY!)
; if NOT set, the high byte will be fixed at zero
; (this seems like a redundant option... it's HIGHLY RECOMMENDED to have it set anyway)
!OA2_USE16BITX          = %00001000

; bits 4-7: this selects what X/Y-offsets are used by the sprite to detect a tile, like a wooden block
; for the tile detection X/Y-offsets in question, please see 'DATA_21ADCA' (a.k.a. 'Object_TileDetectOffsets' in 'prg000.asm')
; each option is around 4 bytes each from that table
!OA2_TDOGRP0            = %00000000     ;> use group 0's tile detection offsets
!OA2_TDOGRP1            = %00010000     ;> use group 1's tile detection offsets
!OA2_TDOGRP2            = %00100000     ;> use group 2's tile detection offsets
!OA2_TDOGRP3            = %00110000     ;> use group 3's tile detection offsets
!OA2_TDOGRP4            = %01000000     ;> use group 4's tile detection offsets
!OA2_TDOGRP5            = %01010000     ;> use group 5's tile detection offsets
!OA2_TDOGRP6            = %01100000     ;> use group 6's tile detection offsets
!OA2_TDOGRP7            = %01110000     ;> use group 7's tile detection offsets
!OA2_TDOGRP8            = %10000000     ;> use group 8's tile detection offsets
!OA2_TDOGRP9            = %10010000     ;> use group 9's tile detection offsets
!OA2_TDOGRP10           = %10100000     ;> use group 10's tile detection offsets
!OA2_TDOGRP11           = %10110000     ;> use group 11's tile detection offsets
!OA2_TDOGRP12           = %11000000     ;> use group 12's tile detection offsets

;======================================================================================================================;
; 'ObjectGroup_Attributes3' (a.k.a. 'DATA_21B1AF' in YF's orig. disasm.) table settings

; bits 0-3: this selects what action should occur with the sprite when the game's frozen/halted (i.e., the player's dead or hurt)
;
; IMPORTANT NOTE: the MOST COMMONLY used one is 'OA3_HALT_NORMALONLY', which continues running the sprite's normal state
; if in state 0x2, otherwise it'll do nothing at all
;
; this DOESN'T mean that the other states will be ignored (i.e., a sprite in shelled state will continue to use the built-in
; shell-type drawing code), but no handling is performed
;
; usually then, the normal state will have some kind of code to deal with the game being frozen, like calling its own GFX routine
;
; for some reason however, certain sprites, such as the spike, goomba shoe, buster beetle, and ptooie, have their OWN code
; for when the game's frozen, but that's quite messy and thus 'OA3_HALT_NORMALONLY' is HIGHLY RECOMMENDED

!OA3_HALT_HOTFOOTSPECIAL    = %00000000    ;> 0x0: special frozen behavior for the hotfoot
!OA3_HALT_JUSTDRAW          = %00000001    ;> 0x1: just draw a 16x16 tilemap for the sprite when frozen
!OA3_HALT_JUSTDRAWTALL      = %00000010    ;> 0x2: just draw a 16x32 tilemap for the sprite when frozen
!OA3_HALT_SPIKESPECIAL      = %00000011    ;> 0x3: special frozen behavior for the spike (the green guy, of course!)
!OA3_HALT_DONOTHING         = %00000100    ;> 0x4: do nothing at all (includes NOT running its GFX routine, so it'll be invisible while frozen!)
!OA3_HALT_NORMALONLY        = %00000101    ;> 0x5: if the sprite's in the normal state (0x2), then run the actual normal code, otherwise do nothing
!OA3_HALT_JUSTDRAWWIDE      = %00000110    ;> 0x6: just draw a wide 48x16 tilemap for the sprite when frozen
!OA3_HALT_DONOTHING2        = %00000111    ;> 0x7: duplicate of '!OA3_HALT_DONOTHING'
!OA3_HALT_KURIBOSPECIAL     = %00001000    ;> 0x8: special frozen behavior for the goomba/kuribo shoe
!OA3_HALT_DONOTHING3        = %00001001    ;> 0x9: duplicate of '!OA3_HALT_DONOTHING'
!OA3_HALT_JUSTDRAWMIRROR    = %00001010    ;> 0x10: just draw a mirrored 16x16 tilemap for the sprite when frozen (i.e., both halves are mirrored)
!OA3_HALT_ENDCARDSPECIAL    = %00001011    ;> 0x11: special frozen behavior for the goal card at the end of the level
!OA3_HALT_DONOTHING4        = %00001100    ;> 0x12: duplicate of '!OA3_HALT_DONOTHING'
!OA3_HALT_BUSTERSPECIAL     = %00001101    ;> 0x13: special frozen behavior for the buster beetle
!OA3_HALT_PIRANHASPECIAL    = %00001110    ;> 0x14: special frozen behavior for the ptooie

; bit 4: if set IN CONJUNCTION with 'OA2_NOSHELLORSQUASH' (otherwise it WON'T WORK!), then when the player stomps on the sprite,
; it'll be squashed (state 0x7) instead of shelled (state 0x3)
; also, if the player stomps on it with a goomba/kuribo shoe, then it'll be in the killed state (state 0x6)
!OA3_SQUASH             = %00010000

; bit 5: if set, then if the player tries to stomp on the sprite, they'll be hurt! (i.e., a spiky enemy)
!OA3_NOTSTOMPABLE       = %00100000

; bit 6: if set, then the sprite will die into the shelled state (i.e., the sprite turns into a shell when hit from beneath)
; also, if set, then the sprite will call its respective entry from the table 'ObjectGroup_CollideJumpTable'
; (a.k.a. 'DATA_288438' in YF's orig. disasm.) whenever applicable
!OA3_DIESHELLED         = %01000000

; bit 7: if set, the sprite's immune to the player's raccoon tail
!OA3_TAILATKIMMUNE      = %10000000

;======================================================================================================================;
; 'Object_AttrFlags' (a.k.a. 'DATA_21AE78' in YF's orig. disasm.) table settings

; bits 0-3: selects a hitbox/bounding box against the player from 'Object_BoundBox' (a.k.a. 'DATA_21AE38' in YF's orig. disasm.)
!OAT_BOUNDBOX00         = %00000000
!OAT_BOUNDBOX01         = %00000001
!OAT_BOUNDBOX02         = %00000010
!OAT_BOUNDBOX03         = %00000011
!OAT_BOUNDBOX04         = %00000100
!OAT_BOUNDBOX05         = %00000101
!OAT_BOUNDBOX06         = %00000110
!OAT_BOUNDBOX07         = %00000111
!OAT_BOUNDBOX08         = %00001000
!OAT_BOUNDBOX09         = %00001001
!OAT_BOUNDBOX10         = %00001010
!OAT_BOUNDBOX11         = %00001011
!OAT_BOUNDBOX12         = %00001100
!OAT_BOUNDBOX13         = %00001101
!OAT_BOUNDBOX14         = %00001110
!OAT_BOUNDBOX15         = %00001111

; bit 4: if set, then if the sprite touches another sprite, the former will turn away from the latter
!OAT_BOUNCEOFFOTHERS    = %00010000

; bit 5: if set, the sprite's immune to ALL of the player's weapons such as fireballs & hammers
!OAT_WEAPONIMMUNITY     = %00100000

; bit 6: if set, the sprite's immune ONLY to the player's fireballs
!OAT_FIREIMMUNITY       = %01000000

; bit 7: if set, the sprite will run its own collision routine instead of the standard held state handling
; (i.e., the sprite won't be killed by touching the player's held sprite, such as a shell)
!OAT_HITNOTKILL         = %10000000

;======================================================================================================================;
; 'Object_DoKillAction' (a.k.a. 'DATA_21B317' in YF's orig. disasm.) table settings
; determines what action is taken when the sprite's in the killed state (0x6)
; NOTE: any action type other than 0 always sets the frame to 0x2 (unless the sprite's not general-purpose, i.e. its sprite slot >= 0x5)

!KILLACT_STANDARD           = 0         ;> 0x0: standard killed behavior (does not set frame 0x2)
!KILLACT_JUSTDRAW16X16      = 1         ;> 0x1: just draw a 16x16 tilemap for the sprite when killed
!KILLACT_JUSTDRAWMIRROR     = 2         ;> 0x2: just draw a mirrored 16x16 tilemap for the sprite when killed (i.e., both halves are mirrored)
!KILLACT_JUSTDRAW16X32      = 3         ;> 0x3: just draw a 16x32 tilemap for the sprite when killed
!KILLACT_JUSTDRAWTALLFLIP   = 4         ;> 0x4: just draw a horizontally-flipped 16x32 tilemap for the sprite when killed
!KILLACT_NORMALANDKILLED    = 5         ;> 0x5: run the normal AND killed states simultaneously (sinking/vertical tilemap flip)
!KILLACT_GIANTKILLED        = 6         ;> 0x6: giant sprite death (i.e., giant goomba & koopa)
!KILLACT_POOFDEATH          = 7         ;> 0x7: die in a puff of smoke ('poof')
!KILLACT_DRAWMOVENOHALT     = 8         ;> 0x8: draw the sprite & move unless the game's frozen (i.e., the player dies)
!KILLACT_NORMALSTATE        = 9         ;> 0x9: run the normal state when killed

incsrc "custom_smb3_sprites_codes.asm"
