// Created by Crowbar 0.74
//replace a NAME with your prop name

$modelname "models\slashco\items\slashcofile.mdl"

$staticprop

$model "slashcofile" "slashcofile.smd"

$attachment "anim_attachment_RH" "ValveBiped.Anim_Attachment_RH" 0 0 0 rotate -90 -90 0


$surfaceprop "plastic"    

$contents "solid"

$illumposition -0.117 0 -0.019

$cdmaterials "models\props_slashco\items\slashcofile"

$cbox 0 0 0 0 0 0

$bbox -0.493 -0.603 -5.855 0.493 0.37 5.816

$definebone "static_prop" "" 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000

$sequence "idle" {
	"prop_ani\idle.smd"
	fadein 0.2
	fadeout 0.2
	fps 30
}

$collisionmodel "slashcofile_phys.smd"
{
	$mass 20  
	$inertia 10
	$damping 0.01
	$rotdamping 1
	$rootbone "Root_bone"	

}
