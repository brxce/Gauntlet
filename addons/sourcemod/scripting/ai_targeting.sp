#pragma semicolon 1

#define DEBUG 0
#define KICKDELAY 0.1
#define INFECTED_TEAM 3
#define ZC_BOOMER 2
#define ZC_SPITTER 4
#define ZC_TANK 8
#define CMD_ATTACK 0

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <adt_array>
#include <left4downtown>

// Bibliography: "[L4D2] Defib using bots" by "DeathChaos25"

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
	arraySurvivors = CreateArray();
	// Assigning targets to spawned infected
	HookEvent("player_spawn", OnPlayerSpawnPre, EventHookMode_Pre);
	HookEvent("player_incapacitated", OnPlayerImmobilised, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerImmobilised, EventHookMode_Pre);
}

/***********************************************************************************************************************************************************************************

																		UPDATING VALID SURVIVOR TARGETS

***********************************************************************************************************************************************************************************/

// Survivors with permanent health
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	RefreshTargets();
}

public OnClientPutInServer(client) { 
	RefreshTargets();
}

public OnClientDisconnectFromServer(client) {
	RefreshTargets();
}


// RefreshTargets() when a survivor is cleared or a survivor has been incapped/killed
public Action:OnPlayerImmobilised(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client)) {
		if ( (StrEqual(name, "player_incapacitated") && IsSurvivor(client)) || (StrEqual(name, "player_death") && IsClientInGame(client)) ) {
			RefreshTargets();
		}
	}	
}

// Re-assign targets to all special infected cappers
RefreshTargets() {
	// Refresh survivor array
	ClearArray(arraySurvivors);
	for (new i = 0; i < MaxClients; i++) {
		if (IsSurvivor(i)) {
			PushArrayCell(arraySurvivors, i);
		}
	}
	 
	// Assign targets
	for (new i = 1; i < MaxClients; i++) {
		if (IsBotCapper(i) && IsPlayerAlive(i)) {
			targetSurvivor[i] = GetTargetSurvivor();
		}
	}
}

/* @return: The entity index to a permanent health carrying survivor that is not being pinned.
 *			In the absence of permanent health a random survivor (whom possibly may be pinned) is assigned as the target.
 *	
*/
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

/***********************************************************************************************************************************************************************************

																	EXECUTING AI TARGET PREFERENCING

***********************************************************************************************************************************************************************************/

// Assign target to any cappers(smoker, hunter, jockey charger) that spawn
public Action:OnPlayerSpawnPre(Handle:event, String:name[], bool:dontBroadcast) {
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

// Influence AI targeting - AI will still prefer close range survivors if assigned targets are significantly farther
// N.B. requires disabling of SMAC_Commands to prevent kicks for command spamming
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if (IsBotCapper(client)) {
		AttackTarget(client);
	}	
}

AttackTarget(client) {
	new botID = GetClientUserId(client);
	// Prefer health bonus survivors
	new target = targetSurvivor[client];
	if (IsSurvivor(target)) {
		// if not already pinned
		if (IsMobile(target)) {
			new targetID = GetClientUserId(target);		
			// Check bot is still alive, and not a dummy client 
			new String:clientName[MAX_NAME_LENGTH];
			if (IsBotInfected(client) && GetClientName(client, clientName, sizeof(clientName)) ) {
				if (StrContains(clientName, "dummy", false) == -1) { // naming convention used in 'special_infected_wave_spawner.smx'
					ScriptCommand("CommandABot({cmd=%i,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", CMD_ATTACK, botID, targetID); // attack
				}
			}				
		}			
	}
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

ScriptCommand(const String:arguments[], any:...) {
	new String:vscript[PLATFORM_MAX_PATH];
	VFormat(vscript, sizeof(vscript), arguments, 2);
	CheatCommand("script", vscript);
}

CheatCommand(const String:command[], const String:parameter1[] = "", const String:parameter2[] = "") {	
	new flags = GetCommandFlags(command);	
	// Check this is a valid command
	if (flags != INVALID_FCVAR_FLAGS) {
		new commandDummy = CreateFakeClient("[AI_T] Command Dummy");
		if (commandDummy > 0) {			
			ChangeClientTeam(commandDummy, INFECTED_TEAM);
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

// Creating a fake client to run the fake command works (kicking newly created client after command execution)
/* @return: entity index of any ingame client, -1 if none could be found
GetAnyClientInGame() {
	for (new target = 1; target <= MaxClients; target++) {
		if (IsClientInGame(target))return target;
	}
	return -1; // no valid client found
}
*/

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

