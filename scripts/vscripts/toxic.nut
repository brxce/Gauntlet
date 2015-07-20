//-----------------------------------------------------
Msg("Activating Toxic\n");

/*
	ENUMERATION/CONSTANT DEFINITIONS
	SPAWN_BEHIND_SURVIVORS = 1
	SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS = 3
	SPAWN_ABOVE_SURVIVORS = 6
	SPAWN_SPECIALS_ANYWHERE = 4	
	n.b. assigning multiple values to PreferredSpecialDirection seems to prevent the script from loading
*/

MutationOptions <-
{
	ActiveChallenge = 1	
	
	//SI specifications
	cm_MaxSpecials = 12
	cm_BaseSpecialLimit = 3 
	DominatorLimit = 9 //dominators: charger, smoker, jockey, hunter
	HunterLimit = 3
	BoomerLimit = 2
	SmokerLimit = 3
	SpitterLimit = 2
	ChargerLimit = 3
	JockeyLimit = 3
	
	//SI frequency
	cm_SpecialRespawnInterval = 20 //Time for an SI spawn slot to become available
	SpecialInitialSpawnDelayMin = 20 //Time between spawns in any particular SI class
	SpecialInitialSpawnDelayMax = 30	
	cm_SpecialSlotCountdownTime = 20
	
	//SI Details
	cm_AggressiveSpecials = true
	PreferredSpecialDirection = SPAWN_SURVIVORS
	ShouldAllowSpecialsWithTank = true
	ShouldAllowMobsWithTank = false
	
	// Director Phases - SI still seem to spawn during Relax phases
	SustainPeakMinTime = 5
	SustainPeakMaxTime = 10
	IntensityRelaxThreshold = 1.10
	RelaxMinInterval = 15 //Allow for recovery between SI hits
	RelaxMaxInterval = 15
	RelaxMaxFlowTravel = 3000

}	

//No spitters during tank
function onGameEvent_tank_spawn ( params ) 
{
	SessionOptions.SpitterLimit = 0
}
//Restore SI numbers after tank is killed
function onGameEvent_tank_killed ( params )
{
	SessionOptions.SpitterLimit = 2
}