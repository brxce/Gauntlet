#pragma semicolon 1

#define DEBUG
#define MAX_HEALTH 100
#define	NO_TEMP_HEALTH 0.0
#define SECONDARY_SLOT 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include "includes/hardcoop_util.sp"

new Handle:hCvarLeechThreshold;
new Handle:hCvarLeechPercent;
new Handle:hCvarLeechChance;
new Handle:hCvarCommonLeechAmount;
new Handle:hCvarSurvivorRespawnHealth;

new bool:should_leech = true;

public Plugin:myinfo = 
{
	name = "Health Management",
	author = "breezy",
	description = "Providing alternative health sources to survivor team",
	version = "",
	url = ""
};

public OnPluginStart() {
	hCvarLeechThreshold = CreateConVar("leech_threshold", "50", "Below this health level (inc. temp health), survivors are able to leech");
	hCvarLeechPercent = CreateConVar("leech_percent", "0.1", "Percentage of dealt dmg leeched as health");
	hCvarLeechChance = CreateConVar("leech_chance", "0.5", "Percent change of health leech occurring");
	hCvarCommonLeechAmount = CreateConVar("leech_common_ammount", "1", "Health leeched, pending 'leech_chance', from killing a common");
	HookEvent("revive_success", OnReviveSuccess, EventHookMode_PostNoCopy);
	HookEvent("infected_hurt", Event_OnCommonKilled);
	RegConsoleCmd("sm_leech", Cmd_ToggleLeech, "Toggle health leeching");
	// Reset health upon respawning
	hCvarSurvivorRespawnHealth = FindConVar("z_survivor_respawn_health");
	SetConVarInt(hCvarSurvivorRespawnHealth, 100);
	HookConVarChange(hCvarSurvivorRespawnHealth, ConVarChanged:OnRespawnHealthChanged);
	HookEvent("map_transition", EventHook:ResetSurvivors, EventHookMode_PostNoCopy); // finishing a map
	HookEvent("round_freeze_end", EventHook:ResetSurvivors, EventHookMode_PostNoCopy); // restarting map after a wipe 
}
	
public OnPluginEnd() {
	ResetConVar(hCvarSurvivorRespawnHealth);
}

public OnRespawnHealthChanged() {
	SetConVarInt(hCvarSurvivorRespawnHealth, 100);
}

public ResetSurvivors() {
	RestoreHealth();
	ResetInventory();
}

 //restoring health of survivors respawning with 50 health from a death in the previous map
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	RestoreHealth();
}


public RestoreHealth() {
	for (new client = 1; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
			GiveItem(client, "health");
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", NO_TEMP_HEALTH);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
		}
	}
}

public ResetInventory() {
	for (new client = 0; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
			// Reset survivor inventories so they only hold dual pistols
			for (new i = 0; i < 5; i++) { 
				DeleteInventoryItem(client, i);		
			}	
			GiveItem(client, "pistol");
		}
	}		
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

public Action:OnReviveSuccess( Handle:event, const String:eventName[], bool:dontBroadcast ) {
	new revived = GetClientOfUserId( GetEventInt(event, "subject") );
	if( IsSurvivor(revived) && IsPlayerAlive(revived) ) {
		GiveItem( revived, "pain_pills" );
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

GiveItem(client, String:itemName[]) {
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", itemName);
	SetCommandFlags("give", flags);
}

/*
GiveItem(client, String:itemName[22]) {	
	new item = CreateEntityByName(itemName);
	new Float:clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);
	TeleportEntity(item, clientOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(item); 
	EquipPlayerWeapon(client, item);
}*/

DeleteInventoryItem(client, slot) {
	new item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) {
		RemovePlayerItem(client, item);
	}	
}