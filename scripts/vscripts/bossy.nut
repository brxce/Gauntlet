//-----------------------------------------------------------------------------------------------------------------------------
Msg("Loaded Bossy script\n")

// Include the VScript Library
IncludeScript("VSLib")

BDEBUG <- false

//Boss enumerations
enum Boss {
	TANK = 8
	WITCH = 7
	WITCHBRIDE = 11
}

//Flow percentages
RoundVars.Current <- 0
RoundVars.TankFlowDist <- 0.0
RoundVars.HasEncounteredTank <- false
RoundVars.WitchFlowDist <- 0.0
RoundVars.HasEncounteredWitch <- false
//Director control flow
RoundVars.HasLeftSafeArea <- false

function EasyLogic::Update::BossDirector() {
	if (!RoundVars.HasLeftSafeArea) {
		if (Director.HasAnySurvivorLeftSafeArea()) { //survivors have just left saferoom; randomise boss percentages
			RoundVars.HasLeftSafeArea = true;
			//Assign a random flow distance to the boss spawns
			RoundVars.TankFlowDist = GetRandomMapFlow("TANK")
			RoundVars.WitchFlowDist = GetRandomMapFlow("WITCHBRIDE")
			//@TODO Adjust for overlap
		}
	} else { //check if a tank/witch needs to be spawned
		local FarthestFlow = Director.GetFurthestSurvivorFlow()
		local FarthestSurvivor = Players.SurvivorWithHighestFlow()
		local MinSpawnDist = 1000.0
		local MaxSpawnDist = 2000.0
		if (BDEBUG) { 
			local MaxFlow = GetMaxFlowDistance()
			local fCurrent = (FarthestFlow/MaxFlow) * 100
			local Current = fCurrent.tointeger()
			if (Current > RoundVars.Current) {
				RoundVars.Current = Current
				Utils.SayToAll("Current: [%i%%]", Current)
			}			
		}
		if (FarthestFlow >= RoundVars.TankFlowDist && !RoundVars.HasEncounteredTank) { 
			//spawn tank
			DirectorScript.SessionOptions.TankLimit = 1 // unblock tank spawns
			Utils.SayToAll("The tank approaches...");
			Utils.SpawnZombieNearPlayer(FarthestSurvivor, Boss.TANK, MaxSpawnDist, MinSpawnDist, true)
		} else if (FarthestFlow >= RoundVars.WitchFlowDist && !RoundVars.HasEncounteredWitch) { 
			//spawn witchbride
			Utils.SayToAll("A witch bride is nearby...")
			Utils.SpawnZombieNearPlayer(FarthestSurvivor, Boss.WITCHBRIDE, MaxSpawnDist, MinSpawnDist, true)
			RoundVars.HasEncounteredWitch = true;
		}		
	}
}

function GetRandomMapFlow(BossType) {
	local RandomFlow
	local MaxFlow = GetMaxFlowDistance()
	local FlowPercentage
	do {
		RandomFlow = RandomFloat(0, MaxFlow)
		FlowPercentage = (RandomFlow/MaxFlow) * 100
	} while (FlowPercentage > 90.0) // no tank/witches near end safe room
	if (BDEBUG) {
		Utils.SayToAll("Generating a %s percentage...", BossType)
		Utils.SayToAll("- Flow: %f", RandomFlow) 
		Utils.SayToAll("- Max flow: %f", MaxFlow) 
	}	
	//Print as a percent
	local BossPercent = FlowPercentage.tointeger()
	Utils.SayToAll("%s: [%i%%]", BossType, BossPercent)
	return RandomFlow
}

// made redundant by TankLimit in hard12 vscripts;also tank.Kill() is not reliable if tank spawns late
function Notifications::OnTankSpawned::LimitTankSpawns (tank, params) {
	if (RoundVars.HasEncounteredTank == false) {
		RoundVars.HasEncounteredTank = true
		DirectorScript.SessionOptions.TankLimit = 0
	} else { // an extra tank has spawned despite TankLimit = 0; this failsafe code might never be reached
		if (Director.GetFurthestSurvivorFlow() < RoundVars.TankFlowDist) { // Tank percentage not yet reached
			Utils.SayToAll("An extra(early) tank spawned! Attempting to kill...")
			tank.Kill()	
		} else if (RoundVars.HasEncounteredTank == true) { // Do not spawn any extra tanks
			Utils.SayToAll("An extra(late) tank spawned! Attempting to kill...")
			tank.Kill()
		}	
	}
}