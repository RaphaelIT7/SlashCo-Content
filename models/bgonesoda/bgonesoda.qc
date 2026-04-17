$modelname "models\slashco\items\bgonesoda.mdl"

$staticprop

$bodygroup "bgonesoda"
{
	studio "bgonesoda.smd"
}


$surfaceprop "plastic"

$contents "solid"

$illumposition -0.117 0 -0.019

$cdmaterials "models\props_slashco\items\bgonesoda\"

$attachment "anim_attachment_RH" "static_prop" 0 0 0 rotate -90 0 0

$cbox 0 0 0 0 0 0

$bbox -0.493 -0.603 -5.855 0.493 0.37 5.816

$definebone "static_prop" "" 0 0 0 0 0 0 0 0 0 0 0 0


$sequence "idle" {
	"bgonesoda_anims\idle.smd"
	fadein 0.2
	fadeout 0.2
	fps 30
}

$collisionmodel "bgonesoda_physics.smd"
{
	$mass 20
	$inertia 10
	$damping 0.01
	$rotdamping 1
	$rootbone "Root_bone"

}
