$modelname "slashco\jellocup.mdl"

$bodygroup "jellocup"
{
	studio "jellocup.smd"
}

$surfaceprop "Plastic_barrel"

$contents "solid"

$staticprop

$opaque

$cdmaterials "models\slashco\jellocup\"

$sequence idle "jellocup.smd" fps 1

$collisionmodel "jellocup_physics.smd"
{
	$mass 10
}