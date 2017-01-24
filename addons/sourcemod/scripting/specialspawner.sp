#pragma semicolon 1

#define DEBUG_WEIGHTS 0
#define DEBUG_SPAWNQUEUE 0
#define DEBUG_TIMERS 0
#define DEBUG_POSITIONER 0

#define VANILLA_COOP_SI_LIMIT 2
#define SI_HARDLIMIT 16
#define NUM_TYPES_INFECTED 6

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

new Handle:hCvarReadyUpEnabled;
new Handle:hCvarConfigName;
new bool:bShowSpawnerHUD[MAXPLAYERS];

// Modules
new String:Spawns[NUM_TYPES_INFECTED][16] = {"smoker", "boomer", "hunter", "spitter", "jockey", "charger"};
new SpawnCounts[NUM_TYPES_INFECTED];
#include "includes/hardcoop_util.sp"
#include "modules/SS_SpawnCustomisation.sp"
#include "modules/SS_SpawnTimers.sp"
#include "modules/SS_SpawnQueue.sp"
#include "modules/SS_SpawnPositioner.sp"

/*
 * TODO:
 * fix mins/maxs error
 * Create command to load, without restarting, another config while one is already loaded
*/

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, customisation and queue modules goes to the developers of the 'l4d2_autoIS'' plugin                            
***********************************************************************************************************************************************************************************/
  
public Plugin:myinfo = 
{
	name = "Special Spawner",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "1.0",
	url = ""
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax) { 
	// L4D2 check
	decl String:mod[32];
	GetGameFolderName(mod, sizeof(mod));
	if( !StrEqual(mod, "left4dead2", false) ) {
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart() {	
	// Load modules
	SpawnCustomisation_OnModuleStart();
	SpawnTimers_OnModuleStart();
	SpawnQueue_OnModuleStart();
	SpawnPositioner_OnModuleStart();
	// Compatibility with server_namer.smx
	hCvarReadyUpEnabled = CreateConVar("l4d_ready_enabled", "1", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	hCvarConfigName = CreateConVar("l4d_ready_cfg_name", "Hard Coop", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	SetConVarFlags( hCvarReadyUpEnabled, FCVAR_CHEAT ); SetConVarFlags( hCvarConfigName, FCVAR_CHEAT ); // get rid of 'symbol is assigned a value that is never used' compiler warnings
	// 	Cvars
	SetConVarBool( FindConVar("director_spectate_specials"), true );
	SetConVarBool( FindConVar("director_no_specials"), true ); // Disable Director spawning specials naturally
	SetConVarInt( FindConVar("z_safe_spawn_range"), 0 );
	SetConVarInt( FindConVar("z_spawn_safety_range"), 0 );
	//SetConVarInt( FindConVar("z_spawn_range"), 750 ); // default 1500 (potentially very far from survivors) is remedied if SpawnRelocator module is active 
	SetConVarInt( FindConVar("z_discard_range"), 1250 ); // Discard Zombies farther away than this	
	// Resetting at the end of rounds
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("survival_round_start", EventHook:OnSurvivalRoundStart, EventHookMode_PostNoCopy);
	// Faster spawns
	HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
	// Customisation commands
	RegConsoleCmd("sm_weight", Cmd_SetWeight, "Set spawn weights for SI classes");
	RegConsoleCmd("sm_limit", Cmd_SetLimit, "Set individual, total and simultaneous SI spawn limits");
	RegConsoleCmd("sm_timer", Cmd_SetTimer, "Set a variable or constant spawn time (seconds)");
	// Admin commands
	RegAdminCmd("sm_resetspawns", Cmd_ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("sm_resettimer", Cmd_StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
}

public OnPluginEnd() {
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") ); // Disable Director spawning specials naturally
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range"));
	ResetConVar( FindConVar("z_spawn_range") );
	ResetConVar( FindConVar("z_discard_range") );
}

/***********************************************************************************************************************************************************************************

                                                 					PER ROUND
                                                                    
***********************************************************************************************************************************************************************************/

public OnConfigsExecuted() {	
	// Load customised cvar values to override any .cfg values
	LoadCacheSpawnLimits();
	LoadCacheSpawnWeights(); 
	CreateTimer( 0.1, Timer_DrawSpawnerHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	// Disable for PvP modes
	decl String:gameMode[16];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	if( StrContains(gameMode, "versus", false) != -1 || StrContains(gameMode, "scavenge", false) != -1 ) {
		SetFailState("Plugin does not support PvP modes");
	} 
	g_bHasSpawnTimerStarted = false;
	StartSpawnTimer();
}

public OnSurvivalRoundStart() {
	g_bHasSpawnTimerStarted = false;
	StartSpawnTimer();
}

public OnRoundOver() {
	EndSpawnTimer();
}

// Kick infected bots immediately after they die to allow quicker infected respawn
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(player) ) {
		CreateTimer(1.0, Timer_KickBot, player);
	}
}

/***********************************************************************************************************************************************************************************

                                                           SPAWN TIMER AND CUSTOMISATION CMDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_SetLimit(client, args) {
	if(L4D2_Team:GetClientTeam(client) != L4D2_Team: L4D2Team_Survivor && !IsGenericAdmin(client) ) {
		PrintToChat(client, "Command only available to survivor team");
		return Plugin_Handled;
	} 
	
	if (args == 2) {
		// Read in the SI class
		new String:sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		// Read in limit value 
		new String:sLimitValue[32];     
		GetCmdArg(2, sLimitValue, sizeof(sLimitValue));
		new iLimitValue = StringToInt(sLimitValue);    
		// Must be valid limit value		
		if( iLimitValue < 0 ) {
			PrintToChat(client, "Limit value must be >= 0");
		} else {
			// Apply limit value to appropriate class
			if( StrEqual(sTargetClass, "all", false) ) {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnLimitsCache[i] = iLimitValue;
				}
				PrintToChatAll("All SI limits have been set to %d", iLimitValue);
			} else if( StrEqual(sTargetClass, "max", false) ) {  // Max specials
				SILimitCache = iLimitValue;
				Client_PrintToChatAll(true, "-> {O}Max SI {N}limit set to {G}%i", iLimitValue);		           
			} else if( StrEqual(sTargetClass, "group", false) ) {
				SpawnSizeCache = iLimitValue;
				Client_PrintToChatAll(true, "-> SI {O}group spawn {B}size set to {G}%i", iLimitValue);
			} else {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(Spawns[i], sTargetClass, false) ) {
						SpawnLimitsCache[i] = iLimitValue;
						Client_PrintToChatAll(true, "-> {O}%s {N}limit set to {G}%i", sTargetClass, iLimitValue);
					}
				}
			}
		}	 
	} else {  // Invalid command syntax
		Client_PrintToChat(client, true, "{O}!limit/sm_limit {B}<class> <limit>");
		Client_PrintToChat(client, true, "{B}<class> {N}[ all | max | group | smoker | boomer | hunter | spitter | jockey | charger ]");
		Client_PrintToChat(client, true, "{B}<limit> {N}[ >= 0 ]");
	}
	// Load cache into appropriate cvars
	LoadCacheSpawnLimits(); 
	return Plugin_Handled;  
}

public Action:Cmd_SetWeight(client, args) {
	if(L4D2_Team:GetClientTeam(client) != L4D2_Team: L4D2Team_Survivor && !IsGenericAdmin(client) ) {
		PrintToChat(client, "Command only available to survivor team");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		decl String:arg[16];
		GetCmdArg(1, arg, sizeof(arg));	
		if( StrEqual(arg, "reset", false) ) {
			ResetWeights();
			ReplyToCommand(client, "Spawn weights reset to default values");
		} 
	} else if( args == 2 ) {
		// Read in the SI class
		new String:sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));

		// Read in limit value 
		new String:sWeightPercent[32];     
		GetCmdArg(2, sWeightPercent, sizeof(sWeightPercent));
		new iWeightPercent = StringToInt(sWeightPercent);      
		if( iWeightPercent < 0 || iWeightPercent > 100 ) {
			PrintToChat( client, "0 <= weight value <= 100") ;
			return Plugin_Handled;
		} else { //presets for spawning special infected i only
			if( StrEqual(sTargetClass, "all", false) ) {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnWeightsCache[i] = iWeightPercent;			
				}	
				Client_PrintToChat(client, true, "-> {O}All spawn weights {N}set to {G}%d", iWeightPercent );	
			} else {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(sTargetClass, Spawns[i], false) ) {
						SpawnWeightsCache[i] =  iWeightPercent;
						Client_PrintToChat(client, true, "-> {O}%s {N}weight set to {G}%d", Spawns[i], iWeightPercent );				
					}
				}	
			}
			
		}
	} else {
		Client_PrintToChat( client, true, "{O}!weight/sm_weight {B}<class> <value>" );
		Client_PrintToChat( client, true, "{B}<class> {N}[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ] " );	
		Client_PrintToChat( client, true, "{B}value {N}[ >= 0 ] " );	
	}
	LoadCacheSpawnWeights();
	return Plugin_Handled;
}

public Action:Cmd_SetTimer(client, args) {
	if(L4D2_Team:GetClientTeam(client) != L4D2_Team: L4D2Team_Survivor && !IsGenericAdmin(client) ) {
		PrintToChat(client, "Command only available to survivor team");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		new Float:time;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		if (time < 0.0) { 
			time = 1.0; // don't want a constant spawn time of 0s
		}
		SetConVarFloat( hSpawnTimeMin, time );
		SetConVarFloat( hSpawnTimeMax, time );
		SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
		Client_PrintToChat(client, true, "[SS] Spawn timer set to constant {G}%.3f {N}seconds", time);
	} else if( args == 2 ) {
		new Float:min, Float:max;
		decl String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		min = StringToFloat(arg);
		GetCmdArg( 2, arg, sizeof(arg) );
		max = StringToFloat(arg);
		if( min > 0.0 && max > 1.0 && max > min ) {
			SetConVarFloat( hSpawnTimeMin, min );
			SetConVarFloat( hSpawnTimeMax, max );
			SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
			Client_PrintToChat(client, true, "[SS] Spawn timer will be between {G}%.3f {N}and {G}%.3f {N}seconds", min, max );
		} else {
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.0) spawn time");
		}
	} else {
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                         ADMIN COMMANDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_ResetSpawns(client, args) {	
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		if( IsBotInfected(i) ) {
			ForcePlayerSuicide(i);
		}
	}	
	StartCustomSpawnTimer(SpawnTimes[0]);
	ReplyToCommand( client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.3f seconds.", GetConVarFloat(hSpawnTimeMin) );
	return Plugin_Handled;
}

public Action:Cmd_StartSpawnTimerManually(client, args) {
	if( args < 1 ) {
		StartSpawnTimer();
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
	} else {
		new Float:time = 1.0;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		
		if (time < 0.0) {
			time = 1.0;
		}
		
		StartCustomSpawnTimer(time);
		ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.3f seconds.", time);
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                         SPAWNER HUD
                                                                    
***********************************************************************************************************************************************************************************/

public Action:OnPlayerRunCmd( client, &buttons ) {
	if( IsSurvivor(client) && buttons & IN_USE && buttons & IN_RELOAD ) {
		bShowSpawnerHUD[client] = true;
	} else {
		bShowSpawnerHUD[client] = false;
	}
}

public Action:Timer_DrawSpawnerHUD( Handle:timer ) {
	new Handle:spawnerHUD = CreatePanel();
	FillHeaderInfo(spawnerHUD);
	FillSpecialInfectedInfo(spawnerHUD);
	FillTimerInfo(spawnerHUD);
	// Send to survivors
	for( new i = 1; i < MAXPLAYERS; i++ ) {
		if( IsValidClient(i) && !IsFakeClient(i) && bShowSpawnerHUD[i] ) {
			SendPanelToClient( spawnerHUD, i, DummySpawnerHUDHandler, 3 ); 
		}
	}
	CloseHandle(spawnerHUD);
	return Plugin_Continue;
}

FillHeaderInfo(Handle:spawnerHUD) {
	SetPanelTitle(spawnerHUD, "Spawner HUD");
	// Server SI limit
	new String:buffer[64];
	Format( buffer, sizeof(buffer), "SI limit server cap: %i", GetConVarInt(hSILimitServerCap) );
	DrawPanelText(spawnerHUD, buffer);
	DrawPanelText(spawnerHUD, " \n");
}

FillSpecialInfectedInfo(Handle:spawnerHUD) {
	// Potential SI
	new String:SILimit[32];
	Format( SILimit, sizeof(SILimit), "SI limit -> %d/%d", CountSpecialInfectedBots(), GetConVarInt(hSILimit) );
	DrawPanelText(spawnerHUD, SILimit);
	// Simultaneous spawn limit
	new String:simultaneousSpawnLimit[32];
	Format( simultaneousSpawnLimit, sizeof(simultaneousSpawnLimit), "Group spawn size -> %d", GetConVarInt(hSpawnSize) );
	DrawPanelText(spawnerHUD, simultaneousSpawnLimit);
	// Individual class weights and limits
	new String:classCustomisationInfo[NUM_TYPES_INFECTED][64];
	for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		Format( 
			classCustomisationInfo[i],
			128, 
			"%s | weight: %d | limit: %d/%d ",
			Spawns[i], GetConVarInt(hSpawnWeights[i]), CountSIClass(i + 1), GetConVarInt(hSpawnLimits[i])
		);
		DrawPanelText(spawnerHUD, classCustomisationInfo[i]);
	}
	DrawPanelText(spawnerHUD, " \n");
}

FillTimerInfo(Handle:spawnerHUD) {
	// Section heading
	DrawPanelText(spawnerHUD, "Timer:");
	// Min spawn time
	new String:timerMin[32];
	Format( timerMin, sizeof(timerMin), "Min: %f", GetConVarFloat(hSpawnTimeMin) );
	DrawPanelText(spawnerHUD, timerMin);
	// Max spawn time
	new String:timerMax[32];
	Format( timerMax, sizeof(timerMax), "Max: %f", GetConVarFloat(hSpawnTimeMax) );
	DrawPanelText(spawnerHUD, timerMax);
}

public DummySpawnerHUDHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

CountSIClass( targetClass ) {
	new iClassSpawnVolume;
	for( new i = 0; i < MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == targetClass ) {
			iClassSpawnVolume++;
		}
	}	
	return iClassSpawnVolume;
}