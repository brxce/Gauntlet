#pragma semicolon 1

#define DEBUG 0
#define INFECTED_TEAM 3
#define ZC_TANK 8
#define SPAWN_ATTEMPT_INTERVAL 0.5
#define MAX_SPAWN_ATTEMPTS 60

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <left4downtown>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

// Bibliography: "current" by "CanadaRox"

public Plugin:myinfo = 
{
	name = "Coop Bosses",
	author = PLUGIN_AUTHOR,
	description = "Ensures there is exactly one tank on every non finale map in coop",
	version = PLUGIN_VERSION,
	url = ""
};

new Handle:hCvarDirectorNoBosses; // blocks witches unfortunately, needs testing for reliability with tanks

new g_iMaxFlow;
new g_iTankPercent;
new g_iMapTankSpawnAttemptCount;
new g_bIsTankTryingToSpawn;
new g_bHasEncounteredTank;
new g_bIsRoundActive;
new g_bIsFinale;

public OnPluginStart() {
	// Command
	RegConsoleCmd("sm_boss", Cmd_BossPercent, "Spawn percent for boss");
	RegConsoleCmd("sm_tank", Cmd_BossPercent, "Spawn percent for boss");
	RegConsoleCmd("sm_witch", Cmd_BossPercent, "Spawn percent for boss");
	
	// Event hooks
	//HookEvent("tank_spawn", LimitTankSpawns, EventHookMode_Pre);
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_start", EventHook:OnFinaleStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	
	// Console Variables
	hCvarDirectorNoBosses = FindConVar("director_no_bosses");
}

public OnPluginEnd() {
	ResetConVar(hCvarDirectorNoBosses);
}

public Action:Cmd_BossPercent(client, args) {
	if (g_bIsRoundActive) {
		if (client > 0) {
			PrintToChat(client, "\x01Tank: [\x04%i%%\x01]", g_iTankPercent);
		} else {
			PrintToChatAll("\x01Tank: [\x04%i%%\x01]", g_iTankPercent);	
		}		
	} 
}


/***********************************************************************************************************************************************************************************

																				PER ROUND
																	
***********************************************************************************************************************************************************************************/

// Announce boss percent
public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	g_iMaxFlow = 0;
	g_bIsRoundActive = true;
	g_bHasEncounteredTank = false;
	g_iMapTankSpawnAttemptCount = 0;
	g_bIsTankTryingToSpawn = false;
	g_bIsFinale = false;
	// Tank percent
	g_iTankPercent = GetRandomInt(20, 80);
	PrintToChatAll("\x01Tank: [\x04%i%%\x01]", g_iTankPercent); // Printout disabled because of unreliability due to occasional delayed tank spawns 
	// Limit tanks
	SetConVarBool(hCvarDirectorNoBosses, true); 
}

public OnRoundOver() {
	g_bIsFinale = false;
	g_bIsRoundActive = false;
	g_bHasEncounteredTank = false;
}

/***********************************************************************************************************************************************************************************

																			TANK SPAWN MANAGEMENT
																	
***********************************************************************************************************************************************************************************/

// Track on every game frame whether the survivor percent has reached the boss percent
public OnGameFrame() {
	// If survivors have left saferoom
	if (g_bIsRoundActive) {
		// If they have surpassed the boss percent
		new iMaxSurvivorCompletion = GetMaxSurvivorCompletion();
		if (iMaxSurvivorCompletion > g_iTankPercent) {
			// If they have not already fought the tank
			if (!g_bHasEncounteredTank && !g_bIsFinale) {			
				if (!g_bIsTankTryingToSpawn) {
#if DEBUG
	PrintToChatAll("[CB] Attempting to spawn tank at %d%% map distance...", g_iTankPercent); 
#endif
					g_bIsTankTryingToSpawn = true;
					CreateTimer( SPAWN_ATTEMPT_INTERVAL, Timer_SpawnTank, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
				} 
			} 
		} 
	}  
}

public Action:Timer_SpawnTank( Handle:timer ) {		
	PrintToChatAll("Spawn attempts: %d", g_iMapTankSpawnAttemptCount);
	// spawn a tank with z_spawn_old (cmd uses director to find a suitable location)			
	if( IsTankInPlay() || g_iMapTankSpawnAttemptCount >= MAX_SPAWN_ATTEMPTS ) {
		g_bHasEncounteredTank = true;
		PrintToChatAll("[CB] Percentage Tank spawned or max spawn attempts reached..."); 
		return Plugin_Stop; 
	} else {
		CheatCommand("z_spawn_old", "tank", "auto");
		++g_iMapTankSpawnAttemptCount;
		return Plugin_Continue;
	}
}

// Slay extra tanks
public Action:LimitTankSpawns(Handle:event, String:name[], bool:dontBroadcast) {
	// Do not touch finale tanks
	if (g_bIsFinale)return Plugin_Continue;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new tank = client;
	if (IsBotTank(tank)) {
		// If this tank is too early or late, kill it
		if (GetMaxSurvivorCompletion() < g_iTankPercent || g_bHasEncounteredTank)  {
			ForcePlayerSuicide(tank);		
#if DEBUG
	decl String:mapName[32];
	GetCurrentMap(mapName, sizeof(mapName));
	LogError("Map %s:", mapName);
	if (GetMaxSurvivorCompletion() < g_iTankPercent) {
		LogError("Premature tank spawned. Slaying...");
	} else if (g_bHasEncounteredTank) {
		LogError("Surplus tank spawned. Slaying...");
	}
	LogError("- Tank Percent: %i", g_iTankPercent);
	LogError("- MaxSurvivorCompletion: %i", GetMaxSurvivorCompletion()); 
#endif			
		} 		
	}
	
	return Plugin_Continue;
}

public Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new tank = GetClientOfUserId(GetEventInt(event, "userid"));
    CreateTimer( 3.0, Timer_AggravateTank, any:tank, TIMER_FLAG_NO_MAPCHANGE );
    // Aggravate the tank upon spawn in case he spawns out of survivor's line of sight
}

public Action:Timer_AggravateTank( Handle:timer, any:tank ) {
    // How to aggravate a tank that has spawned out of sight? Remote damage does not appear to aggravate them.
    return Plugin_Stop;
}

public OnFinaleStart() {
	g_bIsFinale = true;
	SetConVarBool(hCvarDirectorNoBosses, false); 
}

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/

// Get current survivor percent
stock GetMaxSurvivorCompletion() {
	new Float:flow = 0.0;
	decl Float:tmp_flow;
	decl Float:origin[3];
	decl Address:pNavArea;
	for (new client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) &&
			L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor)
		{
			GetClientAbsOrigin(client, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null)
			{
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = MAX(flow, tmp_flow);
			}
		}
	}
	#if DEBUG
		new current = RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
		if (g_iMaxFlow < current) {
			g_iMaxFlow  = current;
			PrintToChatAll("%d%%", g_iMaxFlow );
		} 	
	#endif
	return RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
}

// Executes through a dummy client, without setting sv_cheats to 1, a console command marked as a cheat
CheatCommand(String:command[], String:argument1[] = "", String:argument2[] = "") {
	static commandDummy;
	new flags = GetCommandFlags(command);		
	if ( flags != INVALID_FCVAR_FLAGS ) {
		if ( !IsValidClient(commandDummy) || IsClientInKickQueue(commandDummy) ) { // Dummy may get kicked by SMAC_Antispam.smx
			commandDummy = CreateFakeClient("[CB] Command Dummy");
			ChangeClientTeam(commandDummy, _:L4D2Team_Spectator);
		}
		if ( IsValidClient(commandDummy) ) {
			new originalUserFlags = GetUserFlagBits(commandDummy);
			new originalCommandFlags = GetCommandFlags(command);			
			SetUserFlagBits(commandDummy, ADMFLAG_ROOT); 
			SetCommandFlags(command, originalCommandFlags ^ FCVAR_CHEAT);				
			FakeClientCommand(commandDummy, "%s %s %s", command, argument1, argument2);
			SetCommandFlags(command, originalCommandFlags);
			SetUserFlagBits(commandDummy, originalUserFlags);
		} else {
			LogError("Could not create a dummy client to execute cheat command");
		}	
	}
}

stock bool:IsBotTank(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (GetClientTeam(client) == INFECTED_TEAM) {
		new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == ZC_TANK) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}

// Kick dummy bot 
public Action:Timer_KickBot(Handle:timer, any:client) {
	if (IsClientInGame(client) && (!IsClientInKickQueue(client))) {
		if (IsFakeClient(client))KickClient(client);
	}
}