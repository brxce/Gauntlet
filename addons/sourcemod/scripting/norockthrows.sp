#pragma semicolon 1

#define DEBUG
#define INFECTED_TEAM 3
#define ZC_TANK 8
#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>

public Plugin:myinfo = 
{
	name = "No Rock Throws",
	author = PLUGIN_AUTHOR,
	description = "Blocks AI tanks from throwing rocks",
	version = PLUGIN_VERSION,
	url = ""
};

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if (IsBotTank(client)) {
		buttons &= ~IN_ATTACK2;
	}
	return Plugin_Continue;
}

bool:IsBotTank(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (GetClientTeam(client) == INFECTED_TEAM) {
		new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == ZC_TANK) {
			if(IsFakeClient(client)) { // is a bot
				return true;
			}
		}
	}
	return false; // otherwise
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}
