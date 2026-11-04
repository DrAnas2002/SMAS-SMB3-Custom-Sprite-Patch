;======================================================================================================================;
; this file contains the 'incbins' to your custom sprite codes, plus whatever custom routines you wanna add for your sprites
; make sure this is in the same place as 'custom_smb3_sprites_patch.asm'!
; also, at the end of each custom routine, put 'freecode/freedata', otherwise important vanilla code's gonna be overwritten!
;
;======================================================================================================================;
; custom sprite code files                                                                                             ;
;======================================================================================================================;
incsrc "Custom SMB3 Sprite Codes/smw_thwimp.asm"
;incsrc "Custom SMB3 Sprite Codes/smw_hothead_and_lil_sparky.asm"
incsrc "Custom SMB3 Sprite Codes/smw_bony_beetle.asm"

;======================================================================================================================;
; shared routines                                                                                                      ;
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
