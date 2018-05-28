#pragma semicolon 1

#define DEBUG
#define MAX_HEALTH 100

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include "includes/hardcoop_util.sp"

new Handle:hCvarLeechThreshold;
new Handle:hCvarLeechPercent;
new Handle:hCvarLeechChance;
new Handle:hCvarCommonLeechAmount;

new bool:should_leech = true;

public Plugin:myinfo = 
{
	name = "Health Leech",
	author = "breezy",
	description = "Leach health by damaging infected",
	version = "",
	url = ""
};

public OnPluginStart() {
	hCvarLeechThreshold = CreateConVar("leech_threshold", "50", "Below this health level (inc. temp health), survivors are able to leech");
	hCvarLeechPercent = CreateConVar("leech_percent", "0.1", "Percentage of dealt dmg leeched as health");
	hCvarLeechChance = CreateConVar("leech_chance", "0.5", "Percent change of health leech occurring");
	hCvarCommonLeechAmount = CreateConVar("leech_common_ammount", "1", "Health leeched, pending 'leech_chance', from killing a common");
	HookEvent("infected_hurt", Event_OnCommonKilled);
	RegConsoleCmd("sm_leech", Cmd_ToggleLeech, "Toggle health leeching");
}
	
// OnTakeDamage() only provides correct argument values when they're reference pointers
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	if ( should_leech && IsSurvivor(attacker) &&IsPlayerAlive(attacker) && IsBotInfected(victim) && !IsTank(victim) ) {
		if ( FloatCompare(GetRandomFloat(0.0, 1.0), GetConVarFloat(hCvarLeechChance)) == -1 ) {
			new health_current = GetPermHealth(attacker);
			new health_leeched = RoundToNearest(FloatMul(damage, GetConVarFloat(hCvarLeechPercent)));
			new new_health =  health_current + health_leeched;
			if ( health_current < GetConVarInt(hCvarLeechThreshold) && new_health < MAX_HEALTH ) {
				SetEntityHealth(attacker, new_health);
			} 
		} 
	} 
}


public Action:Event_OnCommonKilled(Handle:event, const String:name[], bool:dontBroadcast) {
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if ( should_leech && IsSurvivor(attacker) && IsPlayerAlive(attacker) ) {
		if ( FloatCompare(GetRandomFloat(0.0, 1.0), GetConVarFloat(hCvarLeechChance)) == -1  ) {
			new health_current = GetPermHealth(attacker);
			new new_health =  health_current + GetConVarInt(hCvarCommonLeechAmount);
			if ( health_current < GetConVarInt(hCvarLeechThreshold) && new_health < MAX_HEALTH ) {
				SetEntityHealth(attacker, new_health);
			} 
		}
	}
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype) {
	return;
}

public OnClientPutInServer(client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnClientDisconnect(client) {
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public Action:Cmd_ToggleLeech(client, args) {
	if ( IsSurvivor(client) && IsPlayerAlive(client) ) { 
		should_leech = !should_leech;
		if ( should_leech ) {
			PrintToChatAll("Health leeching enabled.");
		} else {
			PrintToChatAll("Health leeching disabled.");
		}
	}
}

GetPermHealth(client) {
	return GetEntProp(client, Prop_Send, "m_iHealth");
}
