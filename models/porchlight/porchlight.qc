$modelname "slashco\porchlight.mdl"

$bodygroup "porchlight"
{
	studio "porchlight.smd"
}

$surfaceprop "Plastic_barrel"

$contents "solid"

$staticprop

$opaque

$cdmaterials "models\slashco\porchlight\"

$sequence idle "porchlight.smd" fps 1

$collisionmodel "porchlight_physics.smd"
{
	$mass 10
}