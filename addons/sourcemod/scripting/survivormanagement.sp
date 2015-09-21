#pragma semicolon 1

#define DEBUG 0
const SPECTATOR = 1;
const SURVIVOR = 2;
#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

public Plugin:myinfo = 
{
	name = "Join Survivors",
	author = PLUGIN_AUTHOR,
	description = "Join a coop game from spectator mode",
	version = PLUGIN_VERSION,
	url = ""
};

new g_bHasLeftStartArea = true;

public OnPluginStart()
{
	HookEvent("round_freeze_end", EventHook:OnRoundFreezeEnd, EventHookMode_PostNoCopy);
	RegConsoleCmd("sm_join", Cmd_Join, "join survivor team in coop from spectator");
	RegConsoleCmd("sm_return", Cmd_Return, "if respawned out of map and team has not left safe area yet");
}

public Action:Cmd_Join(client, args) {
	if (!IsValidClient(client)) return Plugin_Handled;
	
	// Check if they are using the command from spectator
	if (GetClientTeam(client) == SPECTATOR) {
		if (IsSurvivorBotAvailable()) { // Check if survivor team is full
			PrintToChat(client, "Survivor team is full");
		} else {
			// Take control of a survivor
			new flags = GetCommandFlags("sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags ^ FCVAR_CHEAT);
			FakeClientCommand(client, "sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags);
		}
	} 
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

														RETURN TO SAFEROOM (IF GLITCHED OUT OF MAP ON LOAD FOLLOWING WIPE)

***********************************************************************************************************************************************************************************/

public Action:L4d_OnFirstSurvivorLeftSafeArea(client) {
	g_bHasLeftStartArea = true;
}

public OnRoundFreezeEnd() {
	g_bHasLeftStartArea = false;
}

public Action:Cmd_Return(client, args) {
	if (IsSurvivor(client) && !g_bHasLeftStartArea) {
		ReturnPlayerToSaferoom(client);
	}
}

ReturnPlayerToSaferoom(client) {
	new flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "warp_to_start_area");
	SetCommandFlags("warp_to_start_area", flags);
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

public bool:IsSurvivorBotAvailable() {
	// Count the number of survivors controlled by players
	new playerSurvivorCount = 0;	
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			if ( GetClientTeam(i) == SURVIVOR && !IsFakeClient(i) ) {
				 playerSurvivorCount++;
			}
		}
	}
	// Find the size of the survivor team
	new maxSurvivors =  GetConVarInt(FindConVar("survivor_limit"));
	// Determine whether the team is full
	if (playerSurvivorCount < maxSurvivors) {
		return false;
	} else {
		return true; // all survivors are controlled by players
	}
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}