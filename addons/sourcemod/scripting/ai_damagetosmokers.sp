#pragma semicolon 1

#define DEBUG 1
#define INFECTED_TEAM 2
#define ZC_SMOKER 1
#define DAMAGE_REDUCTION_FACTOR 3.0

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new isUsingTongue[MAXPLAYERS];
new clientHealth[MAXPLAYERS];

public Plugin:myinfo = 
{
	name = "AI: Damage to Smokers",
	author = PLUGIN_AUTHOR,
	description = "Negates damage buff to smokers in coop grabbing survivors with their tongue",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	HookEvent("tongue_grab", OnTongueGrab, EventHookMode_Pre);
	HookEvent("tongue_release", OnTongueRelease, EventHookMode_Pre);
}

/***********************************************************************************************************************************************************************************

																			TRACKING TONGUE USE
																	
***********************************************************************************************************************************************************************************/

public Action:OnPlayerSpawn(Handle:event, String:eventName[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));	
	if (IsValidClient(client)) {
		decl String:name[32];
		GetClientName(client, name, sizeof(name));
		if (StrContains(name, "smoker", false) != -1) {
			isUsingTongue[client] = false;
			#if DEBUG
				new iHealth = GetEntProp(client, Prop_Send, "m_iHealth");			
				if (clientHealth[client] != iHealth) {
					clientHealth[client] = iHealth;			
					PrintToChatAll("\x04%s spawned with health: \x01%i", name, clientHealth[client]);
				}
			#endif
		}
	}	
}

public Action:OnPlayerHurt(Handle:event, String:eventName[], bool:dontBroadcast) {
	#if DEBUG
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		decl String:name[32];
		GetClientName(client, name, sizeof(name));
		if(StrContains(name, "smoker", false) != -1) {
			new iHealth = GetEntProp(client, Prop_Send, "m_iHealth");
			if ((IsValidEntity(iHealth)) && (clientHealth[client] != iHealth) ) {
				clientHealth[client] = iHealth;			
				PrintToChatAll("%s's health: %i", name, clientHealth[client]);
			}
		}	
	#endif
	return Plugin_Continue;
}

public Action:OnTongueGrab(Handle:event, String:name[], bool:dontBroadcast) {
	new tongueOwner = GetClientOfUserId(GetEventInt(event, "userid"));
	isUsingTongue[tongueOwner] = true;
	#if DEBUG
		PrintToChatAll("Reducing damage to smoker");
	#endif
}

public Action:OnTongueRelease(Handle:event, String:name[], bool:dontBroadcast) {
	new tongueOwner = GetClientOfUserId(GetEventInt(event, "userid"));
	isUsingTongue[tongueOwner] = false;
	#if DEBUG
		PrintToChatAll("No longer reducing damage to smoker");
	#endif
}

/***********************************************************************************************************************************************************************************

																			DAMAGE REDUCTION
																	
***********************************************************************************************************************************************************************************/

public OnClientPostAdminCheck(client) {
    // hook bots spawning
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	decl String:name[32];
	GetClientName(victim, name, sizeof(name));
	if(StrContains(name, "smoker", false) != -1) {
		if (isUsingTongue[victim]) {
			new Float:reducedDamage = FloatDiv(damage, DAMAGE_REDUCTION_FACTOR);
			damage = reducedDamage - FloatFraction(reducedDamage); // remove decimal parts from damage value
			return Plugin_Changed;
		}		
	}
	return Plugin_Continue;
}

public OnClientDisconnect(client) {
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/

/* This function does not seem to be working; returns false on bot smokers
bool:IsBotSmoker(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (GetClientTeam(client) == INFECTED_TEAM) {
		new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == ZC_SMOKER) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}
*/

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}