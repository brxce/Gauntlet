#pragma semicolon 1

#define DEBUG
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3
#define	ZC_TANK 8

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = 
{
	name = "Survivor Bot Godmode",
	author = PLUGIN_AUTHOR,
	description = "Bot survivors can only take damage from tanks",
	version = PLUGIN_VERSION,
	url = ""
};

public OnClientPutInServer(client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client) {
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	if (IsBotSurvivor(victim) && !IsTank(attacker)) {
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

bool:IsTank(client) {
	if (IsValidClient(client)) {
		new playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (GetClientTeam(client) == TEAM_INFECTED && playerClass == ZC_TANK) {
			return true;
		}
	}
	return false;
}

bool:IsBotSurvivor(client) {
	if (IsValidClient(client)) {
		if (GetClientTeam(client) == TEAM_SURVIVORS && IsFakeClient(client)) {
			return true;
		}
	}
	return false;
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}