// Created by Crowbar 0.64

$modelname "slashco\shadowman.mdl"

$bodygroup "ShadowMan"
{
	studio "ShadowMan.smd"
}

$surfaceprop "flesh"

$contents "solid"

$illumposition -0.026 0.211 36.653

$eyeposition 0 0 73

$opaque

$cdmaterials "models\slashco\shadowman\"

$cbox 0 0 0 0 0 0

$bbox -7.785 -29.273 -2.546 9.46 29.311 77.638

$attachment "eye_left" "ValveBiped.Bip01_Head1" 1.4 3 3.3
$attachment "eye_right" "ValveBiped.Bip01_Head1" -1.4 3 3.3

$poseparameter "move_yaw" -180 180 loop 0
$poseparameter "body_pitch" -90 90 loop 0
$poseparameter "body_yaw" -90 90 loop 0

$sequence "idle" {
	"anims\standing.smd"
	fadein 0.2
	fadeout 0.2
	fps 20
	loop
}