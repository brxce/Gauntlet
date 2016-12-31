#pragma semicolon 1

#define DEBUG 0
#define SPAWN_ATTEMPT_INTERVAL 0.5
#define MAX_SPAWN_ATTEMPTS 60

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <l4d2_direct>
#include <left4downtown>
#include "includes/hardcoop_util.sp"

// Bibliography: "current" by "CanadaRox"

public Plugin:myinfo = 
{
	name = "Coop Bosses",
	author = "Breezy",
	description = "Ensures there is exactly one tank on every non finale map in coop",
	version = "1.0",
	url = ""
};

new Handle:hCvarFlowTankEnable;
new Handle:hCvarDirectorNoBosses; // blocks witches unfortunately, needs testing for reliability with tanks

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
	RegConsoleCmd("sm_toggletank", Cmd_ToggleTank, "Toggle flow tank spawn");
	
	// Event hooks
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_start", EventHook:OnFinaleStart, EventHookMode_PostNoCopy);
	
	// Console Variables
	hCvarFlowTankEnable = CreateConVar("flow_tank_enable", "1", "Enable percentage tank spawns");
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

public Action:Cmd_ToggleTank(client, args) {
	if( L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor || IsGenericAdmin(client) ) {
		new bool:flowTankFlag = GetConVarBool(hCvarFlowTankEnable);
		SetConVarBool( hCvarFlowTankEnable, !flowTankFlag );
		if( flowTankFlag ) {
			Client_PrintToChatAll( true, "Flow tank has been {G}enabled" );
		} else {
			Client_PrintToChatAll(true, "Flow tank has been {O}disabled");
		}		
	} else {
		PrintToChat( client, "Command is only available to survivor team" );
	}
	return Plugin_Handled;
}


/***********************************************************************************************************************************************************************************

																				PER ROUND
																	
***********************************************************************************************************************************************************************************/

// Announce boss percent
public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	g_bIsRoundActive = true;
	g_bHasEncounteredTank = false;
	g_iMapTankSpawnAttemptCount = 0;
	g_bIsTankTryingToSpawn = false;
	g_bIsFinale = false;
	if( GetConVarBool(hCvarFlowTankEnable) ) {
		// Tank percent
		g_iTankPercent = GetRandomInt(20, 80);
		PrintToChatAll("\x01Tank: [\x04%i%%\x01]", g_iTankPercent);
		// Limit tanks
		SetConVarBool(hCvarDirectorNoBosses, true); 
	}	
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
	if( GetConVarBool(hCvarFlowTankEnable) ) {
		// If survivors have left saferoom
		if (g_bIsRoundActive) {
			// If they have surpassed the boss percent
			new iMaxSurvivorCompletion = GetMaxSurvivorCompletion();
			if (iMaxSurvivorCompletion > g_iTankPercent) {
				// If they have not already fought the tank
				if (!g_bHasEncounteredTank && !g_bIsFinale) {			
					if (!g_bIsTankTryingToSpawn) {
						Client_PrintToChatAll(true, "[CB] Attempting to spawn tank at {G}%d%% {N}map distance...", g_iTankPercent); 
						g_bIsTankTryingToSpawn = true;
						CreateTimer( SPAWN_ATTEMPT_INTERVAL, Timer_SpawnTank, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
					} 
				} 
			} 
		}  
	}
	
}

public Action:Timer_SpawnTank( Handle:timer ) {	
	#if DEBUG
		PrintToChatAll("Spawn attempts: %d", g_iMapTankSpawnAttemptCount);
	#endif	
	// spawn a tank with z_spawn_old (cmd uses director to find a suitable location)			
	if( IsTankInPlay() ) {
		g_bHasEncounteredTank = true;
		PrintToChatAll("[CB] A tank has spawned");
		return Plugin_Stop; 
	} else if( g_iMapTankSpawnAttemptCount >= MAX_SPAWN_ATTEMPTS ) {
		g_bHasEncounteredTank = true;
		PrintToChatAll("[CB] Failed to find a spawn for tank in maximum allowed attempts"); 
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
	if( IsBotTank(tank) && GetConVarBool(hCvarFlowTankEnable) ) {
		// If this tank is too early or late, kill it
		if( GetMaxSurvivorCompletion() < g_iTankPercent || g_bHasEncounteredTank )  {
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

public OnFinaleStart() {
	g_bIsFinale = true;
	SetConVarBool(hCvarDirectorNoBosses, false); 
}