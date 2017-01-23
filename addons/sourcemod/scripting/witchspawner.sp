#pragma semicolon 1
#define DEBUG 1

#include <sourcemod>
#include "includes/hardcoop_util.sp"

new Handle:hWitchTimer;
new Handle:hWitchPeriod;
new Handle:hWitchPeriodMode;
new Handle:hWitchWaitTimer;

new bool:g_bIsWitchCountFull;
new bool:g_bHasWitchTimerStarted;
new bool:g_bHasWitchWaitTimerStarted;

new g_WitchCount;
new Handle:hWitchLimit;

public Plugin:myinfo = 
{
	name = "Witch Spawner",
	author = "Tordecybombo",
	description = "Periodically spawns witches",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	// Resetting at the end of rounds
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	// Witch tracking
	HookEvent("witch_spawn", evtWitchSpawn);
	HookEvent("witch_killed", evtWitchKilled);
	
	hWitchLimit = CreateConVar("l4d2_ais_witch_limit", "3", "[-1 = Director spawns witches] The max amount of witches present at once (independant of l4d2_ais_limit).", FCVAR_PLUGIN, true, -1.0, true, 100.0);
	hWitchPeriod = CreateConVar("l4d2_ais_witch_period", "12.0", "The time (seconds) interval in which exactly one witch will spawn", FCVAR_PLUGIN, true, 1.0);
	hWitchPeriodMode = CreateConVar("l4d2_ais_witch_period_mode", "1", "The witch spawn rate consistency [0=CONSTANT|1=VARIABLE]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	RestartWitchTimer(0.0);
	g_WitchCount = 0;
	g_bHasWitchTimerStarted = false;
	g_bHasWitchWaitTimerStarted = false;
	g_bIsWitchCountFull = false;
}

public OnRoundOver() {
	EndWitchWaitTimer();
	EndWitchTimer();
}

public Action:evtWitchSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	g_WitchCount++;
}

public Action:evtWitchKilled(Handle:event, const String:name[], bool:dontBroadcast) {
	g_WitchCount--;
	if( g_bIsWitchCountFull ) {
	 	g_bIsWitchCountFull = false;
		StartWitchWaitTimer(0.0);
	}
}

/***********************************************************************************************************************************************************************************

                                                                 START TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

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
				LogMessage("Mode: %b | Witches: %d | Next(Witch): %.3f s", GetConVarInt(hWitchPeriodMode), g_WitchCount, time);
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

StartWitchWaitTimer(Float:time) {
	EndWitchWaitTimer();
	if( GetConVarInt(hWitchLimit) > 0 ) {
		if( g_WitchCount < GetConVarInt(hWitchLimit) ) {
			g_bHasWitchWaitTimerStarted = true;
			hWitchWaitTimer = CreateTimer( time, StartWitchTimer );
			
				#if DEBUG
					LogMessage("Mode: %b | Witches: %d | Next(WitchWait): %.3f s", GetConVarInt(hWitchPeriodMode), g_WitchCount, time);
				#endif
				
		} else {//if witch count reached limit, wait until a witch killed event to start witch timer
			g_bIsWitchCountFull = true;
			
				#if DEBUG
					LogMessage(" Witch Limit reached. Waiting for witch death.");
				#endif		
				
		}
	}
}

/***********************************************************************************************************************************************************************************

                                                                   END TIMERS
                                                                    
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

//take account of both witch timers when restarting overall witch timer
RestartWitchTimer(Float:time) {
	EndWitchTimer();
	StartWitchWaitTimer(time);
}
