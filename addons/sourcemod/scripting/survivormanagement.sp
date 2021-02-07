#pragma semicolon 1

#define DEBUG 0

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "includes/hardcoop_util.sp"

// Bibliography: "sb_takecontrol" by "pan xiaohai"

public Plugin:myinfo = 
{
name = "Survivor Management",
	author = "Breezy",
	description = "Survivor manager for Gauntlet that provides !join, !return and !respawn commands",
	version = "1.0",
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
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}
	
	// Check if they are using the command from spectator
	if (L4D2_Team:GetClientTeam(client) == L4D2_Team:L4D2Team_Spectator) {
		TakeControlOfASurvivorBot(client);	
	} else {
		PrintToChat(client, "Survivor team is full");
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
	new commandFlags;
	commandFlags = GetCommandFlags("warp_to_start_area");
	
	//Execute command
	SetCommandFlags("warp_to_start_area", commandFlags & ~FCVAR_CHEAT);	
	FakeClientCommand(client, "warp_to_start_area");	
	SetCommandFlags("warp_to_start_area", commandFlags);
}

/***********************************************************************************************************************************************************************************

														SPAWN A SURVIVOR (WORK AROUND FOR 'RESPAWNING DEAD' BUG)

***********************************************************************************************************************************************************************************/

public Action:Cmd_Respawn(client, args) {
	if( IsSurvivor(client) && !IsPlayerAlive(client) ) {
		if( g_bHasLeftStartArea ) {
			PrintToChat(client, "Cannot respawn player after a survivor has left saferoom");
		} else {
			// Move player to spectators
			ChangeClientTeam(client, _:L4D2Team_Spectator);
			
			// Create a fake client
			new bot = CreateFakeClient("Dummy Survivor");
			if(bot != 0) {		
				ChangeClientTeam(bot, _:L4D2Team_Survivor);
				// Error checking
				if(!DispatchKeyValue(bot, "classname", "SurvivorBot") == false) {
					// Kick bot
					SetEntityRenderColor(bot, 128, 0, 0, 255);				
					CreateTimer(1.0, Timer_KickBot, bot, TIMER_FLAG_NO_MAPCHANGE);  
					TakeControlOfASurvivorBot(client);	
					return Plugin_Handled;
				}				
			}
			PrintToChatAll("\x01Failed to create a new survivor");					
		}
	} else {
		PrintToChat( client, "You are not dead." );
	}
	return Plugin_Handled;
}

public bool:IsSurvivorBotAvailable() {
	// Count the number of survivors controlled by players
	new survivorCount = 0;
	new playerSurvivorCount = 0;	
	for (new i = 1; i <= MaxClients; i++) {
		if( IsSurvivor(i) ) {
			if( !IsFakeClient(i) ) {
				 playerSurvivorCount++;
			} 
			survivorCount++;
		}
	}
	
		#if DEBUG
			PrintToChatAll("Player controlled survivors: %d", playerSurvivorCount);
			PrintToChatAll("Total survivors: %d", survivorCount);
		#endif
		
	// Determine whether survivor bot is available
	if (playerSurvivorCount < survivorCount) {
		return true;
	} else {
		return false; // all survivors are controlled by players
	}
}

public TakeControlOfASurvivorBot( client ) {
	if( IsSurvivorBotAvailable() && L4D2_Team:GetClientTeam(client) == L4D2Team_Spectator ) {
		FakeClientCommand(client, "jointeam 2");
	} else {
		PrintToChat( client, "No survivor available to give to player" );
	}
}