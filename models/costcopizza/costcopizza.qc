$modelname "slashco\costcopizza.mdl"

$bodygroup "costcopizza"
{
	studio "costcopizza.smd"
}

$surfaceprop "Plastic_barrel"

$contents "solid"

$staticprop

$opaque

$cdmaterials "models\slashco\costcopizza\"

$sequence idle "costcopizza.smd" fps 1

$collisionmodel "costcopizza.smd"
{
	$mass 10
}