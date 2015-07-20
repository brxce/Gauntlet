//-----------------------------------------------------------------------------------------------------------------------------
Msg("Activating Noxious\n");

// Include the VScript Library
IncludeScript("VSLib");

//Stages
STAGE_SPAWNING_SI   	<- 0        // spawning SI
STAGE_MAX_SI_SPAWNED   	<- 1        // stop SI spawns
STAGE_COOLDOWN			<- 2        // waiting period between SI hits
//Time between SI hits
ENC_MIN_INTERVAL	<- 40
ENC_MAX_INTERVAL	<- 45
//Timer(seconds) - Round Variables are reset every round
RoundVars.RoundTimer <- 0	
RoundVars.ShouldRunRoundTimer <- false
RoundVars.SpecialsSpawned <- 0  //the total number of specials that have been spawned during the round
RoundVars.CurrentAliveSI <- 0
RoundVars.CurrentStage <- STAGE_SPAWNING_SI

//-----------------------------------------------------------------------------------------------------------------------------
// SETTINGS loaded at the start of the game
//-----------------------------------------------------------------------------------------------------------------------------
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
	cm_SpecialRespawnInterval = 0 //Time for an SI spawn slot to become available
	SpecialInitialSpawnDelayMin = 0 //Time between spawns in any particular SI class
	SpecialInitialSpawnDelayMax = 0	
	cm_SpecialSlotCountdownTime = 0
	
	//SI behaviour
	cm_AggressiveSpecials = true
	PreferredSpecialDirection = SPAWN_SPECIALS_ANYWHERE
	ShouldAllowSpecialsWithTank = true
	ShouldAllowMobsWithTank = false
}	

//-----------------------------------------------------------------------------------------------------------------------------
// 'GLOBALS' for the mutation [ refer to with SessionState ]
//-----------------------------------------------------------------------------------------------------------------------------
MutationState <-
{
	InDebugMode = false
	TimeBeforeNextHit = 0
	//Used to display the round time in minutes second format
	MinutesComponent = 0
	SecondsComponent = 0
}

//-----------------------------------------------------------------------------------------------------------------------------
// UPDATE functions: Called every second 
//-----------------------------------------------------------------------------------------------------------------------------
function EasyLogic::Update::CyleStage()
{
	//Only start stage cycle if survivors have left the safe area
	if ( Director.HasAnySurvivorLeftSafeArea() )
	{
        RoundVars.ShouldRunRoundTimer = true
		switch (RoundVars.CurrentStage)
		{
			case STAGE_SPAWNING_SI:
				if ( RoundVars.SpecialsSpawned % 12 == 0 ) //Every twelfth SI spawn, take a break
				{
					RoundVars.CurrentStage = STAGE_MAX_SI_SPAWNED
				}
				break;
			case STAGE_MAX_SI_SPAWNED:
				SessionOptions.cm_MaxSpecials = 0 //stop more SI spawning
				SessionState.TimeBeforeNextHit = RandomInt ( ENC_MIN_INTERVAL, ENC_MAX_INTERVAL )
				RoundVars.CurrentStage = STAGE_COOLDOWN
				break;
			case STAGE_COOLDOWN:				
				//If cooldownperiod has finished, change current stage
				if ( SessionState.TimeBeforeNextHit == 0 ) 
				{
					SessionOptions.cm_MaxSpecials = 12
					RoundVars.CurrentStage = STAGE_SPAWNING_SI
				} 
				else 
				{
					SessionState.TimeBeforeNextHit-- 
				}
				break;
		}
	}	
}

function EasyLogic::Update::UpdateRoundTime() //increments the total round time
{
	if (RoundVars.ShouldRunRoundTimer)
	{
		RoundVars.RoundTimer++
		SessionState.MinutesComponent = floor(RoundVars.RoundTimer/60)
		SessionState.SecondsComponent = RoundVars.RoundTimer % 60
		timer.SetValue("minutes", SessionState.MinutesComponent)
		timer.SetValue("seconds", SessionState.SecondsComponent)
	} 
}
//-----------------------------------------------------------------------------------------------------------------------------
// GAME EVENT DIRECTIVES
//-----------------------------------------------------------------------------------------------------------------------------

function OnRoundStart()
{
	timer.Hide() //hide by default
}

//Round Timer stop directives
function Notifications::OnMapEnd::EndRoundTimer()
{
	RoundVars.ShouldRunRoundTimer = false 
}

//Tracking SI numbers through their spawn and death events. Not currently used, but may be useful later
function Notifications::OnSpawn::PlayerInfectedSpawned( player, params )
{
    if ( player.GetTeam() == INFECTED )
	{
		RoundVars.CurrentAliveSI++
		RoundVars.SpecialsSpawned++
	}
}
function Notifications::OnDeath::PlayerInfectedDied( victim, attacker, params )
{
    if ( !victim.IsPlayerEntityValid() ) {
        return
    }    
    if ( victim.GetTeam() == INFECTED )
	{
		RoundVars.CurrentAliveSI--
	}
}

//No spitters during tank
function Notifications::OnTankSpawned::StopSpitterSpawns( entity, params )
{
	SessionOptions.SpitterLimit = 0
}
function Notifications::OnTankKilled::RestoreSpitterSpawns( entity, attacker, params )
{
	SessionOptions.SpitterLimit = 2
}

//-----------------------------------------------------------------------------------------------------------------------------
// HUD: ROUND TIMER
//-----------------------------------------------------------------------------------------------------------------------------
::timer <- HUD.Item("{minutes}m {seconds}s")
timer.SetValue("minutes", 0)
timer.SetValue("seconds", 0)
timer.AttachTo(HUD_MID_TOP)

function ChatTriggers::showtimer ( player, args, text )
{
	timer.Show()
}
function ChatTriggers::hidetimer ( player, args, text )
{
	timer.Hide()
}