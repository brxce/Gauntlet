#pragma semicolon 1

#define DEBUG 1
#define INFECTED_TEAM 3
#define ZC_BOOMER 2
#define ZC_SPITTER 4
#define ZC_TANK 8
#define CMD_ATTACK 0

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"
#define BLOCKSIZE 32

#include <sourcemod>
#include <sdktools>
#include <adt_array>
#include <left4downtown>

// Bibliography: "[L4D2] Defib using bots" by "DeathChaos25"
//@TODO account for late joiners replacing bots
public Plugin:myinfo = 
{
	name = "AI targeting",
	author = PLUGIN_AUTHOR,
	description = "Controls the survivor targeting behaviour of special infected",
	version = PLUGIN_VERSION,
	url = ""
};

new Handle:arraySurvivors; // dynamic array holding only the survivor entity IDs
new targetSurvivor[MAXPLAYERS]; // survivor target of each special infected

public OnPluginStart() {
	// Initialise dynamic arrays
	arraySurvivors = CreateArray(BLOCKSIZE);
	// Round Reset
	HookEvent("round_freeze_end", EventHook:OnRoundFreezeEnd, EventHookMode_PostNoCopy);
	// Assigning targets to spawned infected
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_incapacitated", RefreshTargets, EventHookMode_Pre);
	HookEvent("player_death", RefreshTargets, EventHookMode_Pre);
}

/***********************************************************************************************************************************************************************************

																			SURVIVOR TARGET TRACKING

***********************************************************************************************************************************************************************************/

public Action:OnRoundFreezeEnd() {
	ClearArray(arraySurvivors);
}

// Survivors with permanent health
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	for (new i = 0; i < MaxClients; i++) {
		if (IsSurvivor(i)) {
			PushArrayCell(arraySurvivors, i);
		}
	}
}

/***********************************************************************************************************************************************************************************

																			AI TARGET PREFERENCING

***********************************************************************************************************************************************************************************/

public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) {
	new playerID = GetEventInt(event, "userid");
	new player = GetClientOfUserId(playerID);
	if (IsBotCapper(player)) {
		// Assign a survivor for the infected to target
		targetSurvivor[player] = GetTargetSurvivor();
		#if DEBUG
			decl String:infectedName[32];
			decl String:targetName[32];
			GetClientName(player, infectedName, sizeof(infectedName));
			GetClientName(targetSurvivor[player], targetName, sizeof(targetName));
			LogMessage("%s spawned and was assigned target: %s", infectedName, targetName);
		#endif
	} 
}

public Action:RefreshTargets(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client)) {
		// if a survivor has been incapped/killed - redirect SI away from them; if an SI has been cleared, allow targeting on the freed survivor
		if ( (StrEqual(name, "player_incapacitated") && IsSurvivor(client)) || (StrEqual(name, "player_death") && IsClientInGame(client)) ) {
			// Assign new targets to infected
			for (new i = 1; i < MaxClients; i++) {
				if (IsBotCapper(i) && IsPlayerAlive(i)) {
					targetSurvivor[i] = GetTargetSurvivor();
				}
			}
		}
	}	
}

GetTargetSurvivor() {
	new target = -1;
	new arraySize = GetArraySize(arraySurvivors);
	if (arraySize > 0) {
		new lastIndex = arraySize - 1;
		// Check if there are survivors holding permanent health
		new bool:bDoesPermHealthRemain = false;
		for (new i = 0; i < arraySize; i++) {
			new survivor = GetArrayCell(arraySurvivors, i);
			if (GetEntProp(survivor, Prop_Send, "m_currentReviveCount") < 1  && IsMobile(survivor)) {
				bDoesPermHealthRemain = true;
			}
		}
		// Pick a random target, only choose mobile perm health survivor if possible
		new randomIndex;
		new randomSurvivor;
		do {
			randomIndex = GetRandomInt(0, lastIndex);		
			randomSurvivor = GetArrayCell(arraySurvivors, randomIndex);		 
		} while (bDoesPermHealthRemain && GetEntProp(randomSurvivor, Prop_Send, "m_currentReviveCount") > 0);
		target = randomSurvivor;
	}
	return target;
}

// Influence AI targeting
// causes SMAC_Commands to kick for command spamming
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if (IsBotCapper(client)) {
		new botID = GetClientUserId(client);
		// Prefer health bonus survivors
		new target = targetSurvivor[client];
		if (IsSurvivor(target)) {
			// if not already pinned
			if (IsMobile(target)) {
				new targetID = GetClientUserId(target);		
				new commandClient = GetAnyValidClient();
				// Client commands appear to continue firing sometimes for a short while after death
				if (commandClient > 0 && IsBotInfected(client)) {
					ScriptCommand(commandClient, "script", "CommandABot({cmd=%i,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", CMD_ATTACK, botID, targetID); // attack
				}				
			}			
		}
	}	
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

ScriptCommand(client, const String:command[], const String:arguments[], any:...) {
	new String:vscript[PLATFORM_MAX_PATH];
	VFormat(vscript, sizeof(vscript), arguments, 4);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, vscript);
	SetCommandFlags(command, flags | FCVAR_CHEAT);
}

// @return: true if client is a survivor that is not dead/incapacitated nor pinned by an SI
bool:IsMobile(client) {
	new bool:bIsMobile = true;
	if (IsSurvivor(client)) {
		if (IsPinned(client) || IsIncapacitated(client)) {
			bIsMobile = false;
		}
	} 
	return bIsMobile;
}

// @return: true if client is a survivor that is either smoked, hunted, charged or jockeyed
bool:IsPinned(client) {
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true; // smoker
		if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true; // hunter
		if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true; // charger
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

// @return: true if player is a dead/incapacitated survivor
bool:IsIncapacitated(client) {
	new bool:bIsIncapped = false;
	if ( IsSurvivor(client) ) {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}

bool:IsBotCapper(client) {
	if (IsBotInfected(client)) {
		new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if ( zombieClass != ZC_BOOMER && zombieClass != ZC_SPITTER && zombieClass != ZC_TANK ) {
			return true;
		}
	}
	return false;
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

