#pragma semicolon 1

#define DEBUG
#define KICKDELAY 0.1
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

// Stop smokers and spitters running away
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
		new commandDummy = CreateFakeClient("[AI_AS] Command Dummy");
		if (commandDummy > 0) {
			new userFlagBits = GetUserFlagBits(commandDummy);
		
			// Unset cheat flag & allow admin access
			SetCommandFlags(command, flags ^ FCVAR_CHEAT);
			SetUserFlagBits(commandDummy, ADMFLAG_ROOT);
			
			//Execute command
			FakeClientCommand(commandDummy, "%s %s %s", command, parameter1, parameter2);
			CreateTimer(KICKDELAY, Timer_KickBot, any:commandDummy, TIMER_FLAG_NO_MAPCHANGE);
			
			// Reset cheat flag and user flags
			SetCommandFlags(command, flags | FCVAR_CHEAT);
			SetUserFlagBits(commandDummy, userFlagBits);
		}		
	}
}

bool:IsBotInfected(client) {
	return (IsValidClient(client) && GetClientTeam(client) == INFECTED_TEAM && IsFakeClient(client) && IsPlayerAlive(client));
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