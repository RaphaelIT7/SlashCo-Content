$modelname "slashco\beerkeg.mdl"

$bodygroup "beerkeg"
{
	studio "beerkeg.smd"
}

$surfaceprop "Plastic_barrel"

$contents "solid"

$staticprop

$cdmaterials "models\slashco\beerkeg\"

$sequence idle "beerkeg.smd" fps 1

$collisionmodel "beerkeg_physics.smd"
{
	$mass 10
}