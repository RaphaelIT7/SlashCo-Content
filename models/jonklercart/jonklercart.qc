$modelname "slashco\jonklercart.mdl"

$bodygroup "jonklercart"
{
	studio "jonklercart.smd"
}

$surfaceprop "Plastic_barrel"

$contents "solid"

$staticprop

$opaque

$cdmaterials "models\slashco\jonklercart\"

$sequence idle "jonklercart_physics.smd" fps 1

$collisionmodel "jonklercart.smd"
{
	$mass 10
}