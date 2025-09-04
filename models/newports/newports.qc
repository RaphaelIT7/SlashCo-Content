$modelname "slashco\newports.mdl"

$bodygroup "newports"
{
	studio "newports.smd"
}

$surfaceprop "Plastic_barrel"

$contents "solid"

$staticprop

$opaque

$cdmaterials "models\slashco\newports\"

$sequence idle "newports.smd" fps 1

$collisionmodel "newports.smd"
{
	$mass 10
}