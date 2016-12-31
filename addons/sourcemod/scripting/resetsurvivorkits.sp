#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include "includes/hardcoop_util.sp"

#define DEBUG_SR 0
#define	NO_TEMP_HEALTH 0.0
#define SECONDARY_SLOT 1

public Plugin:myinfo =
{
	name = "Reset Survivor Kits",
	author = "Breezy",
	description = "Start each map in a campaign with full health and only a single pistol",
	version = "1.0",
	url = ""
};

new Handle:hCvarSurvivorRespawnHealth;

public OnPluginStart() {
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
					#if DEBUG_SR
						new String:ClientName[32];
						GetClientName(client, ClientName, sizeof(ClientName));
						PrintToChatAll("Restored health and reset revive count on %s (entity index %i):", ClientName, client);
					#endif
		}
	}
}

public ResetInventory() {
	for (new client = 0; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
					#if DEBUG_SR
						new String:ClientName[32];
						GetClientName(client, ClientName, sizeof(ClientName));
						PrintToChatAll("Resetting inventory of %s (entity index %i):", ClientName, client);
					#endif
			// Reset survivor inventories so they only hold dual pistols
			for (new i = 0; i < 5; i++) { 
				DeleteInventoryItem(client, i);		
			}	
			GiveItem(client, "pistol");
		}
	}		
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