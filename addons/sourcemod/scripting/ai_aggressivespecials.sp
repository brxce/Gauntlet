#pragma semicolon 1

#define DEBUG
#define INFECTED_TEAM 3
#define ASSAULT_DELAY 0.3 // using 0.3 to be safe (command does not register in the first 0.2 seconds after spawn)1

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "AI Aggressive Specials",
	author = PLUGIN_AUTHOR,
	description = "Force SI to be aggressive",
	version = PLUGIN_VERSION,
	url = ""
};

new Handle:hCvarBoomerExposedTimeTolerance;
new Handle:hCvarBoomerVomitDelay;

public OnPluginStart() {
	hCvarBoomerExposedTimeTolerance = FindConVar("boomer_exposed_time_tolerance");
	SetConVarFloat(hCvarBoomerExposedTimeTolerance, 10000.0);
	
	hCvarBoomerVomitDelay = FindConVar("boomer_vomit_delay");
	SetConVarFloat(hCvarBoomerVomitDelay, 0.1);
	
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre);
}

public OnPluginEnd() {
	ResetConVar(hCvarBoomerExposedTimeTolerance);
	ResetConVar(hCvarBoomerVomitDelay);
}

/***********************************************************************************************************************************************************************************

																			AGGRESSIVE UPON SPAWN

***********************************************************************************************************************************************************************************/

// Command SI to be aggressive so they do not run away
public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotInfected(client)) {
		CreateTimer(ASSAULT_DELAY, Timer_PostSpawnAssault, _, TIMER_FLAG_NO_MAPCHANGE);
	}	
}

public Action:Timer_PostSpawnAssault(Handle:timer) {
	CheatCommand("nb_assault");
}

/***********************************************************************************************************************************************************************************

																			STOP SMOKERS & SPITTERS FLEEING

***********************************************************************************************************************************************************************************/

// Stop smokers running away
public Action:OnAbilityUse(Handle:event, const String:name[], bool:dontBroadcast) {
	new String:abilityName[MAX_NAME_LENGTH];
	GetEventString(event, "ability", abilityName, sizeof(abilityName));
	if (StrEqual(abilityName, "ability_tongue") || StrEqual(abilityName, "ability_spit")) {
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		SetEntityMoveType(client, MOVETYPE_NONE);
	}
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

CheatCommand(const String:command[], const String:parameter1[] = "", const String:parameter2[] = "") {	
	new flags = GetCommandFlags(command);	
	// Check this is a valid command
	if (flags != INVALID_FCVAR_FLAGS) {
		new commandClient = GetAnyValidClient();
		if (commandClient != -1) {
			new userFlagBits = GetUserFlagBits(commandClient);
		
			// Unset cheat flag & allow admin access
			SetCommandFlags(command, flags ^ FCVAR_CHEAT);
			SetUserFlagBits(commandClient, ADMFLAG_ROOT);
			
			//Execute command
			FakeClientCommand(commandClient, "%s %s %s", command, parameter1, parameter2);
			
			// Reset cheat flag and user flags
			SetCommandFlags(command, flags | FCVAR_CHEAT);
			SetUserFlagBits(commandClient, userFlagBits);
		}		
	}
}

bool:IsBotInfected(client) {
	return (IsValidClient(client) && GetClientTeam(client) == INFECTED_TEAM && IsFakeClient(client) && IsPlayerAlive(client));
}

GetAnyValidClient() {
	for (new target = 1; target <= MaxClients; target++) {
		if (IsClientInGame(target)) return target;
	}
	return -1;
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}