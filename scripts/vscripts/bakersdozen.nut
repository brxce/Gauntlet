//-----------------------------------------------------------------------------------------------------------------------------
Msg("Loaded Baker's Dozen script\n");

// Include the VScript Library
IncludeScript("VSLib");

//Stages
enum Stage {
	ALL_IN_SAFEROOM, 
	WAIT_FOR_BAIT,
	SPAWNING_SI,       
	WAVE_SPAWNED,       
	COOLDOWN		 
}
DEBUGMODE <- true
const MAX_SPECIALS = 12
const UNDEFINED_FLOW = 0
	
//Round Variables are reset every round	
RoundVars.SpecialsSpawned <- 0  //the total number of specials that have been spawned during the round
RoundVars.CurrentAliveSI <- 0
RoundVars.CurrentStage <- Stage.ALL_IN_SAFEROOM
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
	DominatorLimit = 9 //dominators: charger, smoker, jockey, hunter
	HunterLimit = 4
	BoomerLimit = 2
	SmokerLimit = 3
	SpitterLimit = 2
	ChargerLimit = 2
	JockeyLimit = 3
	
	//SI frequency
	cm_SpecialRespawnInterval = 0 //Time for an SI spawn slot to become available
	SpecialInitialSpawnDelayMin = 0 //Time between spawns in any particular SI class
	SpecialInitialSpawnDelayMax = 0	
	cm_SpecialSlotCountdownTime = 0
	
	//SI behaviour
	cm_AggressiveSpecials = true
	PreferredSpecialDirection = SPAWN_SPECIALS_ANYWHERE
	ShouldAllowSpecialsWithTank = true
	ShouldAllowMobsWithTank = false
	
	//Removing medkits
	weaponsToRemove =
	{
		weapon_first_aid_kit = 0
		weapon_first_aid_kit_spawn = 0
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
	WaveInterval = 40 //Time between SI hits
	SaferoomExitFlow = UNDEFINED_FLOW
	BaitFlowTolerance = UNDEFINED_FLOW
	BaitThreshold = UNDEFINED_FLOW
}

//-----------------------------------------------------------------------------------------------------------------------------
// UPDATE functions: Called every second 
//-----------------------------------------------------------------------------------------------------------------------------
function EasyLogic::Update::CyleStages()
{
	BonusDisplay.SetValue("bonus", GetHealthBonus()) //read in the bonus set by static_scoremod.smx
	
	switch (RoundVars.CurrentStage) {
		case Stage.ALL_IN_SAFEROOM:
			if ( Director.HasAnySurvivorLeftSafeArea() ) {
				SessionState.BaitFlowTolerance = RandomFloat(100, 200)
				SessionState.SaferoomExitFlow = Director.GetFurthestSurvivorFlow()
				SessionState.BaitThreshold = SessionState.SaferoomExitFlow + SessionState.BaitFlowTolerance
				RoundVars.HasFoundSaferoomExitFlow = true
				RoundVars.CurrentStage = Stage.WAIT_FOR_BAIT
				if (DEBUGMODE) { Utils.SayToAll("SaferoomExitFlow: %f", SessionState.SaferoomExitFlow) }
				if (DEBUGMODE) { Utils.SayToAll("BaitFlowTolerance: %f", SessionState.BaitFlowTolerance) }
				if (DEBUGMODE) { Utils.SayToAll("BaitThreshold: %f", SessionState.BaitThreshold) }
				if (DEBUGMODE) { Utils.SayToAll("-> Stage.WAIT_FOR_BAIT") }
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
// HUD: Health bonus
//-----------------------------------------------------------------------------------------------------------------------------

function GetHealthBonus() //static_scoremod.smx uses "vs_tiebreak_bonus" to store bonus in coop gamemodes
{
	local HealthBonus = Convars.GetStr("vs_tiebreak_bonus")
	return HealthBonus.tointeger()
}

::BonusDisplay <- HUD.Item("Bonus: {bonus}")
BonusDisplay.SetValue("bonus", 0)
BonusDisplay.AttachTo(HUD_MID_TOP)

function ChatTriggers::showbonus ( player, args, text )
{
	BonusDisplay.Show()
}
function ChatTriggers::hidebonus ( player, args, text )
{
	BonusDisplay.Show()
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

//No spitters during tank
function Notifications::OnTankSpawned::BlockSpitterSpawns( entity, params ) {
	SessionOptions.SpitterLimit = 0
	RoundVars.TimeBeforeNextHit = floor(SessionState.WaveInterval/2)
	RoundVars.CurrentStage = Stage.COOLDOWN 
}
function Notifications::OnTankKilled::RestoreSpitterSpawns( entity, attacker, params ) {
	SessionOptions.SpitterLimit = 2
}

//-----------------------------------------------------------------------------------------------------------------------------
// Set time between SI Waves
//-----------------------------------------------------------------------------------------------------------------------------
function ChatTriggers::setwaveinterval ( player, args, text ) {
	local time = GetArgument(1)
	local IntervalLength = time.tointeger()
	if ( IntervalLength == null || IntervalLength <= 0) {
		Utils.SayToAll("SI wave interval must be a valid number greater than zero")
		return;
	} else {
		Utils.SayToAll("SI wave interval changed to %s", IntervalLength)
		SessionState.WaveInterval = IntervalLength
	}
}