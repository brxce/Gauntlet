//-----------------------------------------------------------------------------------------------------------------------------
Msg("Loaded Baker's Dozen script\n");

// Include the VScript Library
IncludeScript("VSLib");

//Stages
enum Stage {
	ALL_IN_SAFEROOM, 
	WAIT_FOR_BAIT,
	SPAWNING_SI,       
	MAX_SI_SPAWNED,       
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
RoundVars.SaferoomExitFlow <- UNDEFINED_FLOW
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
	HunterLimit = 3
	BoomerLimit = 2
	SmokerLimit = 3
	SpitterLimit = 2
	ChargerLimit = 3
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
	BaitFlowTolerance = UNDEFINED_FLOW
	BaitThreshold = UNDEFINED_FLOW
}

//-----------------------------------------------------------------------------------------------------------------------------
// UPDATE functions: Called every second 
//-----------------------------------------------------------------------------------------------------------------------------
function EasyLogic::Update::CyleStages()
{
	BonusDisplay.SetValue("bonus", GetHealthBonus()) //read in the bonus from static_scoremod.smx
	
	switch (RoundVars.CurrentStage) {
		case Stage.ALL_IN_SAFEROOM:
			if ( Director.HasAnySurvivorLeftSafeArea() ) {
				RoundVars.CurrentStage = Stage.WAIT_FOR_BAIT
				SessionState.BaitThreshold = RoundVars.SaferoomExitFlow + SessionState.BaitFlowTolerance
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
			if ( RoundVars.SpecialsSpawned % 12 == 0 ) { //Every twelfth SI spawn, take a break
				RoundVars.CurrentStage = Stage.MAX_SI_SPAWNED
				if (DEBUGMODE) { Utils.SayToAll("-> Stage.MAX_SI_SPAWNED") }
			}
			break;
		case Stage.MAX_SI_SPAWNED:
			SessionOptions.cm_MaxSpecials = 0 //stop more SI spawning
			RoundVars.TimeBeforeNextHit = SessionState.WaveInterval
			RoundVars.CurrentStage = Stage.COOLDOWN
			if (DEBUGMODE) { Utils.SayToAll("-> Stage.COOLDOWN") }
			break;
		case Stage.COOLDOWN:				
			//If cooldownperiod has finished, change current stage
			if ( RoundVars.TimeBeforeNextHit == 0 ) {
				SessionOptions.cm_MaxSpecials = 12
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
BonusDisplay.SetValue("bonus", GetHealthBonus())
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
function Notifications::OnRoundStart::SetBonusDisplay() //because Bonus Display is set to 0 at the start of a round
{
	BonusDisplay.SetValue("bonus", GetHealthBonus())
}

function Notifications::OnLeaveSaferoom::StoreFlowDistance(entity, params)
{
	if (!RoundVars.HasFoundSaferoomExitFlow) 
	{
		SessionState.BaitFlowTolerance = RandomFloat(500, 750)
		RoundVars.SaferoomExitFlow = Director.GetFurthestSurvivorFlow()
		RoundVars.HasFoundSaferoomExitFlow = true
		if (DEBUGMODE) { Utils.SayToAll("BaitFlowTolerance: %f", SessionState.BaitFlowTolerance) }
	} 
}

/* May be made redundant by OnRoundStart::SetBonusDisplay()
function Notifications::OnMapEnd::CleanUp()
{
	BonusDisplay.SetValue("bonus", GetHealthBonus())
}
*/

//Tracking SI numbers through their spawn and death events
//Not currently used, but may be useful for unforeseen future features
function Notifications::OnSpawn::PlayerInfectedSpawned( player, params )
{
    if ( player.GetTeam() == INFECTED ) {
		RoundVars.CurrentAliveSI++
		RoundVars.SpecialsSpawned++
	} else if (RoundVars.SpecialsSpawned >= 12) {
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