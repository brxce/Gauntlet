#pragma semicolon 1

#define DEBUG 0
#define SPAWN_ATTEMPT_INTERVAL 0.5
#define MAX_SPAWN_ATTEMPTS 500

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include "includes/hardcoop_util.sp"

// Bibliography: "current" by "CanadaRox"
// All credits to the l4d2_autoIS.smx authors for the witch spawning code

public Plugin:myinfo = 
{
	name = "Coop Bosses",
	author = "Breezy, Tordecybombo",
	description = "Customisable tank and witch spawning in coop",
	version = "2.0",
	url = ""
};

new Handle:hCvarFlowTankEnable;
new Handle:hCvarDirectorNoBosses; // blocks witches unfortunately, needs testing for reliability with tanks

// Tanks
new g_iTankPercent;
new g_iMapTankSpawnAttemptCount;
new g_bIsTankTryingToSpawn;
new g_bHasEncounteredTank;

// Witches
new Handle:hWitchTimer;
new Handle:hWitchPeriod;
new Handle:hWitchPeriodMode;
new Handle:hWitchWaitTimer;

new bool:g_bIsWitchCountFull;
new bool:g_bHasWitchTimerStarted;
new bool:g_bHasWitchWaitTimerStarted;

new g_WitchCount;
new Handle:hWitchLimit;

new g_bIsRoundActive;
new g_bIsFinale;

public OnPluginStart() {
	// Command
	RegConsoleCmd("sm_boss", Cmd_BossPercent, "Spawn percent for boss");
	RegConsoleCmd("sm_tank", Cmd_BossPercent, "Spawn percent for boss");
	RegConsoleCmd("sm_toggletank", Cmd_ToggleTank, "Toggle flow tank spawn");
	RegConsoleCmd("sm_witch", Cmd_WitchSettings, "Adjust witch settings");
	
	// Map events
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_start", EventHook:OnFinaleStart, EventHookMode_PostNoCopy);
	// Witch tracking
	HookEvent("witch_spawn", Event_WitchSpawn, EventHookMode_PostNoCopy);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_PostNoCopy);
	
	// Tank cvars
	hCvarFlowTankEnable = CreateConVar("flow_tank_enable", "1", "Enable percentage tank spawns");
	hCvarDirectorNoBosses = FindConVar("director_no_bosses");
	// Witch cvars
	hWitchLimit = CreateConVar("cb_witch_limit", "-1", "[-1 = Director spawns witches] The max amount of witches present at once (independant of plugin limit).", FCVAR_PLUGIN, true, -1.0, true, 100.0);
	hWitchPeriod = CreateConVar("cb_witch_period", "12.0", "The time (seconds) interval in which exactly one witch will spawn", FCVAR_PLUGIN, true, 1.0);
	hWitchPeriodMode = CreateConVar("cb_witch_period_mode", "1", "The witch spawn rate consistency [0=CONSTANT|1=VARIABLE]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
}

public Action:Event_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	g_WitchCount++;
}

public Action:Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast) {
	g_WitchCount--;
	if( g_bIsWitchCountFull ) {
	 	g_bIsWitchCountFull = false;
		StartWitchWaitTimer(0.0);
	}
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
	if( IsSurvivor(client) && IsGenericAdmin(client) ) {
		new bool:flowTankFlag = GetConVarBool(hCvarFlowTankEnable);
		SetConVarBool( hCvarFlowTankEnable, !flowTankFlag );
		if( GetConVarBool(hCvarFlowTankEnable) ) {
			CPrintToChatAll("Flow tank has been {blue}enabled" );
		} else {
			CPrintToChatAll("Flow tank has been {red}disabled");
		}		
	} else {
		PrintToChat( client, "You do not have access to this command" );
	}
	return Plugin_Handled;
}

public Action:Cmd_WitchSettings(client, args) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if (args == 2) {
		// Which setting are we adjusting
		new String:witchSetting[32];
		GetCmdArg(1, witchSetting, sizeof(witchSetting));
		new String:sValue[32];     
		GetCmdArg(2, sValue, sizeof(sValue));
		new iValue = StringToInt(sValue);    
		// Must be valid limit value	
		if( StrEqual(witchSetting, "limit", false) ) {
			SetConVarInt( hWitchLimit, iValue );
			CPrintToChatAll("Witch limit set to {blue}%d", iValue );
		} else if( StrEqual(witchSetting, "period", false) ) {
			SetConVarFloat( hWitchPeriod, float(iValue) );
			CPrintToChatAll( "Witch spawn period set to {blue}%d", iValue );
		} else if( StrEqual(witchSetting, "mode", false) ) {
			SetConVarInt( hWitchPeriodMode, iValue );
			CPrintToChatAll( "Witch spawn mode set to {blue}%d", iValue );
		} else {
			ReplyToCommand(client, "witch < limit | period | mode > < value >");
			ReplyToCommand(client, "<period> The time (seconds) interval in which exactly one witch will spawn [ >= 1 ]");
			ReplyToCommand(client, "<mode> The witch spawn rate consistency [ 0 = CONSTANT | 1 = VARIABLE ]");
		}
	} else {
		ReplyToCommand(client, "witch < limit | period | mode > < value >");
		ReplyToCommand(client, "<period> The time (seconds) interval in which exactly one witch will spawn [ >= 1 ]");
		ReplyToCommand(client, "<mode> The witch spawn rate consistency [ 0 = CONSTANT | 1 = VARIABLE ]");
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

																				PER ROUND
																	
***********************************************************************************************************************************************************************************/

// Announce boss percent
public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	g_bIsRoundActive = true;
	g_bIsFinale = false;
	
	// Tank component initialisation
	g_bHasEncounteredTank = false;
	g_iMapTankSpawnAttemptCount = 0;
	g_bIsTankTryingToSpawn = false;
	if( GetConVarBool(hCvarFlowTankEnable) ) {
		// Tank percent
		g_iTankPercent = GetRandomInt(20, 80);
		PrintToChatAll("\x01Tank: [\x04%i%%\x01]", g_iTankPercent);
		// Limit tanks
		SetConVarBool(hCvarDirectorNoBosses, true); 
	}
	
	// Witch timer
	RestartWitchTimer(0.0);
	g_WitchCount = 0;
	g_bHasWitchTimerStarted = false;
	g_bHasWitchWaitTimerStarted = false;
	g_bIsWitchCountFull = false;
}

public OnRoundOver() {
	g_bIsFinale = false;
	g_bIsRoundActive = false;
	g_bHasEncounteredTank = false;
	
	g_WitchCount = 0;
	g_bHasWitchTimerStarted = false;
	g_bHasWitchWaitTimerStarted = false;
	g_bIsWitchCountFull = false;
	
	EndWitchWaitTimer();
	EndWitchTimer();
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
						CPrintToChatAll("{olive}[{default}CB{olive}]{default} Attempting to spawn tank at {blue}%d%%{default} map distance...", g_iTankPercent); 
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
		return Plugin_Stop; 
	} else if( g_iMapTankSpawnAttemptCount >= MAX_SPAWN_ATTEMPTS ) {
		g_bHasEncounteredTank = true;
		PrintToChatAll("{olive}[{default}CB{olive}]{default} Failed to find a spawn for tank in maximum allowed attempts"); 
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

/***********************************************************************************************************************************************************************************

                                                                WITCH START TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

//take account of both witch timers when restarting overall witch timer
RestartWitchTimer(Float:time) {
	EndWitchTimer();
	StartWitchWaitTimer(time);
}

StartWitchWaitTimer(Float:time) {
	EndWitchWaitTimer();
	if( GetConVarInt(hWitchLimit) > 0 ) {
		if( g_WitchCount < GetConVarInt(hWitchLimit) ) {
			g_bHasWitchWaitTimerStarted = true;
			hWitchWaitTimer = CreateTimer( time, StartWitchTimer );
			
				#if DEBUG
					PrintToChatAll("Mode: %b | Witches: %d | Next(WitchWait): %.3f s", GetConVarInt(hWitchPeriodMode), g_WitchCount, time);
				#endif
				
		} else {//if witch count reached limit, wait until a witch killed event to start witch timer
			g_bIsWitchCountFull = true;
			
				#if DEBUG
					PrintToChatAll(" Witch Limit reached. Waiting for witch death.");
				#endif		
				
		}
	}
}

public Action:StartWitchTimer( Handle:timer ) {
	g_bHasWitchWaitTimerStarted = false;
	new Float:fWitchPeriod = GetConVarFloat(hWitchPeriod);
	EndWitchTimer();
	if( GetConVarInt(hWitchLimit) > 0 ) {
		new Float:time;
		if( GetConVarBool(hWitchPeriodMode) ) {
			time = GetRandomFloat(0.0, fWitchPeriod);
		} else {
			time = fWitchPeriod;
		}
		g_bHasWitchTimerStarted = true;
		hWitchTimer = CreateTimer( time, SpawnWitchAuto, fWitchPeriod - time );
		
			#if DEBUG
				PrintToChatAll("Mode: %b | Witches: %d | Next(Witch): %.3f s", GetConVarInt(hWitchPeriodMode), g_WitchCount, time);
			#endif
			
	}
	return Plugin_Handled;
}

public Action:SpawnWitchAuto(Handle:timer, any:waitTime) {
	g_bHasWitchTimerStarted = false;
	if( g_WitchCount < GetConVarInt(hWitchLimit) ) {
		CheatCommand("z_spawn_old", "witch", "auto", true);
	}
	StartWitchWaitTimer(waitTime);
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                  WITCH END TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

EndWitchWaitTimer() {
	if( g_bHasWitchWaitTimerStarted ) {
		CloseHandle(hWitchWaitTimer);
		g_bHasWitchWaitTimerStarted = false;
	}
}

EndWitchTimer() {
	if( g_bHasWitchTimerStarted ) {
		CloseHandle(hWitchTimer);
		g_bHasWitchTimerStarted = false;
	}
}