//-----------------------------------------------------------------------------------------------------------------------------
Msg("Loaded Bossy script\n");

// Include the VScript Library
IncludeScript("VSLib");

//Boss enumerations
enum Boss {
	TANK = 8
	WITCH = 11 //witch bride
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
		local FurthestFlow = Director.GetFurthestSurvivorFlow()
		local FurthestSurvivor = Players.SurvivorWithHighestFlow()
		if (BDEBUG) { 
			local MaxFlow = GetMaxFlowDistance()
			local CurrentFlow = (FurthestFlow/MaxFlow) * 100
			Utils.SayToAll("Current: [%i]", CurrentFlow.tointeger())
		}
		if (FurthestFlow >= RoundVars.TankFlowDist && !RoundVars.HasEncounteredTank) { 
			//spawn tank
			Utils.SpawnZombieNearPlayer(FurthestSurvivor, Boss.TANK, 1500.0, 1000.0, false)
			RoundVars.HasEncounteredTank = true
		} else if (FurthestFlow >= RoundVars.WitchFlowDist && !RoundVars.HasEncounteredWitch) { 
			//spawn witch
			Utils.SpawnZombieNearPlayer(FurthestSurvivor, Boss.WITCH, 1500.0, 1000.0, false)
			RoundVars.HasEncounteredWitch = true
		}		
	}
}

function GetRandomMapFlow(BossType) {
	local MaxFlow = GetMaxFlowDistance()
	if (BDEBUG) { Utils.SayToAll("Max flow distance: %f", MaxFlow) }
	local RandomFlow = RandomFloat(0, MaxFlow)
	if (BDEBUG) { Utils.SayToAll("RandomFlow: %f", RandomFlow) }
	//Print as a percent
	local FlowPercentage = (RandomFlow/MaxFlow) * 100
	if (BDEBUG) { Utils.SayToAll("RandomFlow/MaxFlow: %f", FlowPercentage) }
	local BossPercent = FlowPercentage.tointeger()
	Utils.SayToAll("%s: [%i%%]", BossType, BossPercent)
	return RandomFlow
}