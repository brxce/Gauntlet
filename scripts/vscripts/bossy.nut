//-----------------------------------------------------------------------------------------------------------------------------
Msg("Loaded Bossy script\n");

// Include the VScript Library
IncludeScript("VSLib");

//Boss enumerations
enum Boss {
	TANK = 8
	WITCH = 7
	WITCHBRIDE = 11 //witch bride
}

BDEBUG <- false

//Flow percentages
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
			RoundVars.TankFlowDist = GetRandomMapFlow("Tank")
			RoundVars.WitchFlowDist = GetRandomMapFlow("Witch")
			//@TODO Adjust for overlap
		}
	} else { //check if a tank/witch needs to be spawned
		local FarthestFlow = Director.GetFurthestSurvivorFlow()
		local FarthestSurvivor = Players.SurvivorWithHighestFlow()
		local MinSpawnDist = 1000.0
		local MaxSpawnDist = 1500.0
		if (BDEBUG) { 
			local MaxFlow = GetMaxFlowDistance()
			local Current = (FarthestFlow/MaxFlow) * 100
			Utils.SayToAll("Current: [%i]", Current.tointeger())
		}
		if (FarthestFlow >= RoundVars.TankFlowDist && !RoundVars.HasEncounteredTank) { 
			//spawn tank
			Utils.SpawnZombieNearPlayer(FarthestSurvivor, Boss.TANK, MaxSpawnDist, MinSpawnDist, false)
			RoundVars.HasEncounteredTank = true
		} else if (FarthestFlow >= RoundVars.WitchFlowDist && !RoundVars.HasEncounteredWitch) { 
			//spawn witch
			Utils.SpawnZombieNearPlayer(FarthestSurvivor, Boss.WITCHBRIDE, MaxSpawnDist, MinSpawnDist, false)
			RoundVars.HasEncounteredWitch = true
		}		
	}
}

function GetRandomMapFlow(BossType) {
	local MaxFlow = GetMaxFlowDistance()
	if (BDEBUG) { Utils.SayToAll("Max flow distance: %f", MaxFlow) }
	local RandomFlow;
	do {
		RandomFlow = RandomFloat(0, MaxFlow)
	} while RandomFlow > 90.0 // no tank/witches near end safe room
	if (BDEBUG) { Utils.SayToAll("RandomFlow: %f", RandomFlow) }
	//Print as a percent
	local FlowPercentage = (RandomFlow/MaxFlow) * 100
	if (BDEBUG) { Utils.SayToAll("RandomFlow/MaxFlow: %f", FlowPercentage) }
	local BossPercent = FlowPercentage.tointeger()
	Utils.SayToAll("%s: [%i%%]", BossType, BossPercent)
	return RandomFlow
}