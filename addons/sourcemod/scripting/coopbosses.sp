#pragma semicolon 1

#define DEBUG 1
#define KICKDELAY 0.1
#define INFECTED_TEAM 3
#define ZC_TANK 8

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

new g_iTankPercent;
new g_bHasEncounteredTank;
new g_bIsRoundActive;
new g_bIsFinale;

public OnPluginStart() {
	// Command
	RegConsoleCmd("sm_boss", Cmd_BossPercent, "Spawn percent for boss");
	RegConsoleCmd("sm_tank", Cmd_BossPercent, "Spawn percent for boss");
	RegConsoleCmd("sm_witch", Cmd_BossPercent, "Spawn percent for boss");
	
	// Event hooks
	HookEvent("tank_spawn", LimitTankSpawns, EventHookMode_Pre);
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_start", EventHook:OnFinaleStart, EventHookMode_PostNoCopy);
	
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
	g_bIsRoundActive = true;
	// Tank percent
	g_iTankPercent = GetRandomInt(20, 80);
	PrintToChatAll("\x01Tank: [\x04%i%%\x01]", g_iTankPercent);
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
				SpawnTank();
			} 
		}
	} 
}

SpawnTank() {	
	// spawn a tank with z_spawn_old (cmd uses director to find a suitable location)			
		#if DEBUG
			PrintToChatAll("[CB] Spawning intended percent tank..."); 
		#endif
		
	while (!IsTankInPlay()) {
		CheatCommand("z_spawn_old", "tank", "auto");
	}
	
	g_bHasEncounteredTank = true;
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
			ForcePlayerSuicide(tank);			
		} 		
	}
	
	return Plugin_Continue;
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
	return RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
}

// Executes, without setting sv_cheats to 1, a console command marked as a cheat
CheatCommand(String:command[], String:argument1[], String:argument2[]) {
	//new client = GetAnyClientInGame();
	new client = CreateFakeClient("[CB] Command Dummy");
	if (client > 0) {
		ChangeClientTeam(client, INFECTED_TEAM);
		
		// Get user bits and command flags
		new userFlagsOriginal = GetUserFlagBits(client);
		new flagsOriginal = GetCommandFlags(command);
		
		// Set as Cheat
		SetUserFlagBits(client, ADMFLAG_ROOT);
		SetCommandFlags(command, flagsOriginal ^ FCVAR_CHEAT);
		
		// Execute command
		FakeClientCommand(client, "%s %s %s", command, argument1, argument2); 
		CreateTimer(KICKDELAY, Timer_KickBot, client, TIMER_FLAG_NO_MAPCHANGE);
		
		// Reset user bits and command flags
		SetCommandFlags(command, flagsOriginal);
		SetUserFlagBits(client, userFlagsOriginal);
	} else {
		LogError("Could not create a dummy client to execute cheat command");
	}	
}

bool:IsBotTank(client) {
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