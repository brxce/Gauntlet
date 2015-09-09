//-----------------------------------------------------------------------------------------------------------------------------
Msg("Loaded Half Baked script\n");

// Include the VScript Library
IncludeScript("VSLib")

//Stages
enum Stage {
	INITIALISE, 
	WAIT_FOR_BAIT,
	SPAWNING_SI,       
	WAVE_SPAWNED,       
	COOLDOWN		 
}
DEBUGMODE <- false
const MAX_SPECIALS = 6
const UNDEFINED_FLOW = -1
	
//Round Variables are reset every round	
RoundVars.SpecialsSpawned <- 0  //the total number of specials that have been spawned during the round
RoundVars.CurrentAliveSI <- 0
RoundVars.CurrentStage <- Stage.INITIALISE
RoundVars.TimeBeforeNextHit <- 0
RoundVars.HasFoundSaferoomExitFlow <- false

//-----------------------------------------------------------------------------------------------------------------------------
// SETTINGS loaded at the start of the game
//-----------------------------------------------------------------------------------------------------------------------------
MutationOptions <-
{
	ActiveChallenge = 1	
	cm_AllowSurvivorRescue = 0 //disables rescue closet functionality in coop
	
	//SI specifications
	cm_MaxSpecials = 0 //let CycleStages() manage SI spawning
	cm_BaseSpecialLimit = 3 
	DominatorLimit = 5 //dominators: charger, smoker, jockey, hunter
	HunterLimit = 2
	BoomerLimit = 1
	SmokerLimit = 1
	SpitterLimit = 1
	ChargerLimit = 1
	JockeyLimit = 2
	
	//SI frequency
	cm_SpecialRespawnInterval = 0 //Time for an SI spawn slot to become available
	SpecialInitialSpawnDelayMin = 0 //Time between spawns in any particular SI class
	SpecialInitialSpawnDelayMax = 0	
	cm_SpecialSlotCountdownTime = 0
	
	//SI behaviour
	cm_AggressiveSpecials = true
	PreferredSpecialDirection = SPAWN_SPECIALS_ANYWHERE
	BehindSurvivorsSpawnDistance = 0
	ShouldAllowSpecialsWithTank = true
	ShouldAllowMobsWithTank = false
	
	//Removing spawns
	weaponsToRemove =
	{
		weapon_first_aid_kit = 0
		weapon_adrenaline = 0
		weapon_molotov= 0
		weapon_vomitjar = 0
		weapon_pipebomb = 0
	}
	function AllowWeaponSpawn( classname )
	{
		if ( classname in weaponsToRemove )
		{
			return false;
		}
		return true;
	}	
}	

//-----------------------------------------------------------------------------------------------------------------------------
// 'GLOBALS' for the mutation [ refer to with SessionState ]
//-----------------------------------------------------------------------------------------------------------------------------
MutationState <-
{
	WaveInterval = 30 // Time between SI hits
	SaferoomExitFlow = UNDEFINED_FLOW
	BaitFlowTolerance = UNDEFINED_FLOW
	BaitThreshold = UNDEFINED_FLOW
}

//-----------------------------------------------------------------------------------------------------------------------------
// UPDATE functions: Called every second 
//-----------------------------------------------------------------------------------------------------------------------------
function EasyLogic::Update::CyleStages() {
	ScoreDisplay.SetValue("score", GetScore()) //read in the score set by static_scoremod.smx
	if (DEBUGMODE) { SIspawned.SetValue("spawned", RoundVars.SpecialsSpawned) }
	if (DEBUGMODE) { AliveSI.SetValue("liveSI", RoundVars.CurrentAliveSI) }
	
	switch (RoundVars.CurrentStage) {
		case Stage.INITIALISE:
			if ( Director.HasAnySurvivorLeftSafeArea() ) {
				SessionState.BaitFlowTolerance = RandomFloat(100, 150)
				SessionState.SaferoomExitFlow = Director.GetFurthestSurvivorFlow()
				SessionState.BaitThreshold = SessionState.SaferoomExitFlow + SessionState.BaitFlowTolerance
				RoundVars.HasFoundSaferoomExitFlow = true
				RoundVars.CurrentStage = Stage.WAIT_FOR_BAIT
				if (DEBUGMODE) { 
					Utils.SayToAll("SaferoomExitFlow: %f", SessionState.SaferoomExitFlow) 
					Utils.SayToAll("BaitFlowTolerance: %f", SessionState.BaitFlowTolerance) 
					Utils.SayToAll("BaitThreshold: %f", SessionState.BaitThreshold) 
					Utils.SayToAll("-> Stage.WAIT_FOR_BAIT") 
				}
			}
			break;
		case Stage.WAIT_FOR_BAIT:
			local AverageSurvivorFlow = GetAverageSurvivorFlowDistance()
			if (AverageSurvivorFlow > SessionState.BaitThreshold) {
				SessionOptions.cm_MaxSpecials = MAX_SPECIALS
				//makes first SI hit of a map harder; afterwards this is reset in PlayerInfectedSpawned() function
				SessionOptions.PreferredSpecialDirection = SPAWN_ABOVE_SURVIVORS 
				RoundVars.CurrentStage = Stage.SPAWNING_SI
				if (DEBUGMODE) { Utils.SayToAll("-> Stage.SPAWNING_SI") }
			}
			break;
		case Stage.SPAWNING_SI:
			if ( RoundVars.SpecialsSpawned % MAX_SPECIALS == 0 ) { //give the survivors a break
				RoundVars.CurrentStage = Stage.WAVE_SPAWNED
				if (DEBUGMODE) { Utils.SayToAll("-> Stage.WAVE_SPAWNED") }
			}
			break;
		case Stage.WAVE_SPAWNED:
			SessionOptions.cm_MaxSpecials = 0 //stop more SI spawning
			RoundVars.TimeBeforeNextHit = SessionState.WaveInterval
			RoundVars.CurrentStage = Stage.COOLDOWN
			if (DEBUGMODE) { Utils.SayToAll("-> Stage.COOLDOWN") }
			break;
		case Stage.COOLDOWN:				
			//If cooldownperiod has finished, change current stage
			if ( RoundVars.TimeBeforeNextHit == 0 ) {
				SessionOptions.cm_MaxSpecials = MAX_SPECIALS
				RoundVars.CurrentStage = Stage.SPAWNING_SI
				if (DEBUGMODE) { Utils.SayToAll("-> Stage.SPAWNING_SI") }
			} 
			else {
				RoundVars.TimeBeforeNextHit-- 
			}
			break;
	}
}	

//-----------------------------------------------------------------------------------------------------------------------------
// HUD: Coop score
//-----------------------------------------------------------------------------------------------------------------------------

function GetScore() //static_scoremod.smx uses "vs_tiebreak_bonus" console variable to store the team score in coop gamemode
{
	local Score = Convars.GetStr("vs_tiebreak_bonus")
	return Score.tointeger()
}

::ScoreDisplay <- HUD.Item("Score: {score}")
ScoreDisplay.SetValue("score", 0)
ScoreDisplay.AttachTo(HUD_MID_TOP)

function ChatTriggers::showscore ( player, args, text )
{
	ScoreDisplay.Show()
}
function ChatTriggers::hidescore ( player, args, text )
{
	ScoreDisplay.Hide()
}

//-----------------------------------------------------------------------------------------------------------------------------
// HUD: SI Debug
//-----------------------------------------------------------------------------------------------------------------------------

if (DEBUGMODE) { // display SI spawn tracking on HUD
	::AliveSI <- HUD.Item("SI alive: {liveSI}")
	::AliveSI.SetValue("liveSI", 0)
	::AliveSI.AttachTo(HUD_FAR_LEFT)
	
	::SIspawned <- HUD.Item("SI spawned: {spawned}")
	SIspawned.SetValue("spawned", 0)
	SIspawned.AttachTo(HUD_FAR_RIGHT)
}

//-----------------------------------------------------------------------------------------------------------------------------
// GAME EVENT directives
//-----------------------------------------------------------------------------------------------------------------------------

//Tracking SI numbers through their spawn and death events
//Not currently used, but may be useful for unforeseen future features
function Notifications::OnSpawn::PlayerInfectedSpawned( player, params )
{
    if ( player.GetTeam() == INFECTED ) {
		RoundVars.CurrentAliveSI++
		RoundVars.SpecialsSpawned++
		if (RoundVars.SpecialsSpawned % MAX_SPECIALS == 0) { // checked here as a failsafe to prevent extra large SI hits
			SessionOptions.cm_MaxSpecials = 0
			RoundVars.CurrentStage = Stage.WAVE_SPAWNED
			if (DEBUGMODE) { Utils.SayToAll("-> Stage.WAVE_SPAWNED") }
		}
	} else if (RoundVars.SpecialsSpawned >= MAX_SPECIALS) {
		SessionOptions.PreferredSpecialDirection = SPAWN_SPECIALS_ANYWHERE
	}
}
function Notifications::OnDeath::PlayerInfectedDied( victim, attacker, params )
{
    if ( !victim.IsPlayerEntityValid() ) {
        return
    } else if ( victim.GetTeam() == INFECTED ) {
		RoundVars.CurrentAliveSI--
	}
}

//SI spawning during tank
function Notifications::OnTankSpawned::ModifySpecialSpawning( entity, params ) {
	SessionOptions.SpitterLimit = 0
	RoundVars.CurrentStage = Stage.SPAWNING_SI 
}
function Notifications::OnTankKilled::RestoreSpitterSpawns( entity, attacker, params ) {
	SessionOptions.SpitterLimit = 2
}

//-----------------------------------------------------------------------------------------------------------------------------
// Set the interval between SI Waves
//-----------------------------------------------------------------------------------------------------------------------------
function ChatTriggers::setwaveinterval ( player, args, text ) {
	local interval = GetArgument(1)
	local seconds = interval.tointeger()
	if ( seconds == null || seconds <= 0) {
		Utils.SayToAll("SI wave interval must be a valid number of seconds greater than zero")
		return
	} else {
		Utils.SayToAll("SI wave interval changed to %i", seconds)
		SessionState.WaveInterval = seconds
	}
}