#pragma semicolon 1

#define DEBUG 0
#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS 2
#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

// Bibliography: "sb_takecontrol" by "pan xiaohai"

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
	RegConsoleCmd("sm_respawn", Cmd_Respawn, "Respawn if user spawned dead in saferoom");
	RegConsoleCmd("sm_return", Cmd_Return, "if respawned out of map and team has not left safe area yet");
}

public Action:Cmd_Join(client, args) {
	if (!IsValidClient(client)) return Plugin_Handled;
	
	// Check if they are using the command from spectator
	if (GetClientTeam(client) == TEAM_SPECTATORS) {
		if (IsSurvivorBotAvailable()) { // Check if survivor team is full
			// Take control of a survivor
			CheatCommand(client, "sb_takecontrol");
		} else {
			PrintToChat(client, "Survivor team is full");
		}
	} 
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

																	SAFEROOM ENTERING/LEAVING FLAG

***********************************************************************************************************************************************************************************/

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	g_bHasLeftStartArea = true;
}

public OnRoundFreezeEnd() {
	g_bHasLeftStartArea = false;
}

/***********************************************************************************************************************************************************************************

														RETURN TO SAFEROOM (IF GLITCHED OUT OF MAP ON LOAD FOLLOWING WIPE)

***********************************************************************************************************************************************************************************/

public Action:Cmd_Return(client, args) {
	if (IsSurvivor(client) && !g_bHasLeftStartArea) {
		ReturnPlayerToSaferoom(client);
	}
}

ReturnPlayerToSaferoom(client) {
	CheatCommand(client, "warp_to_start_area");
}

/***********************************************************************************************************************************************************************************

														SPAWN A SURVIVOR (WORK AROUND FOR 'RESPAWNING DEAD' BUG)

***********************************************************************************************************************************************************************************/

public Action:Cmd_Respawn(client, args) {
	if (IsSurvivor(client) && !IsPlayerAlive(client) && !g_bHasLeftStartArea) {
		// Move player to spectators
		ChangeClientTeam(client, TEAM_SPECTATORS);
		
		// Create a fake client
		new bot = CreateFakeClient("Dummy");
		if(bot != 0) {
			ChangeClientTeam(bot, 2);			
			// Error checking
			if(DispatchKeyValue(bot, "classname", "SurvivorBot") == false) {
				PrintToChatAll("\x01Create bot failed");
				return Plugin_Handled;
			}			
			if(DispatchSpawn(bot) == false) {
				PrintToChatAll("\x01Create bot failed");
				return Plugin_Handled;
			}
			
			// Kick bot
			SetEntityRenderColor(bot, 128, 0, 0, 255);	 			
			CreateTimer(1.0, Timer_Kick, bot, TIMER_FLAG_NO_MAPCHANGE);  
		}
		
		// Take control of new survivor
		CheatCommand(client, "sb_takecontrol");
	}
	return Plugin_Handled;
}

public Action:Timer_Kick(Handle:timer, any:bot) {
	KickClient(bot, "fake player");
	return Plugin_Stop;
}
/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

CheatCommand(client, const String:command[]) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, command);
	SetCommandFlags(command, flags);
}

public bool:IsSurvivorBotAvailable() {
	// Count the number of survivors controlled by players
	new playerSurvivorCount = 0;	
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			if ( GetClientTeam(i) == TEAM_SURVIVORS && !IsFakeClient(i) ) {
				 playerSurvivorCount++;
			}
		}
	}
	// Find the size of the survivor team
	new maxSurvivors =  GetConVarInt(FindConVar("survivor_limit"));
	// Determine whether the team is full
	if (playerSurvivorCount < maxSurvivors) {
		return true;
	} else {
		return false; // all survivors are controlled by players
	}
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}