#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define VLC_DEBUG 0
#define	NO_TEMP_HEALTH 0.0
#define SECONDARY_SLOT 1

public Plugin:myinfo =
{
	name = "Versus Like Coop",
	author = "Breezy",
	description = "Start each map in a campaign with full health and a single pistol",
	version = "1.0",
	url = ""
};

public OnPluginStart()
{
	HookEvent("map_transition", EventHook:ResetSurvivors, EventHookMode_PostNoCopy); // finishing a map
	HookEvent("round_freeze_end", EventHook:ResetSurvivors, EventHookMode_PostNoCopy); // restarting map after a wipe 
}

public ResetSurvivors() {
	RestoreHealth();
	ResetInventory();
}

 //restoring health of survivors respawning with 50 health from a death in the previous map
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	RestoreHealth();
			#if VLC_DEBUG
				PrintToChatAll("L4D_OnFirstSurvivorLeftSafeArea (Left4Downtown2)");
			#endif
}

public RestoreHealth() {
	for (new client = 0; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
					#if VLC_DEBUG
						new String:ClientName[256];
						GetClientName(client, ClientName, sizeof(ClientName));
						PrintToChatAll("Restored health and reset revive count on %s (client/entity ID %i):", ClientName, client);
					#endif
			GiveItem(client, "health"); //give full health			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0) {//remove temp hp
						#if VLC_DEBUG
							PrintToChatAll("- temporary health was detected and removed");
						#endif
				//alternate way
				//new temphpoffset = FindSendPropOffs("CTerrorPlayer","m_healthBuffer");
				//SetEntDataFloat(client, temphpoffset, NO_TEMP_HEALTH, true);
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", NO_TEMP_HEALTH);
			}
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
		}
	}
}

public ResetInventory() {
	for (new client = 0; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
					#if VLC_DEBUG
						new String:ClientName[256];
						GetClientName(client, ClientName, sizeof(ClientName));
						PrintToChatAll("Resetting inventory of %s (client/entity ID %i):", ClientName, client);
					#endif
			for (new i = 0; i < 5; i++) { //clear all slots in player's inventory
				new equipment = GetPlayerWeaponSlot(client, i);
				if (equipment != -1) { //if slot is not empty
					if (i == SECONDARY_SLOT) { 
						RemovePlayerItem(client, equipment);
						GiveItem(client, "pistol"); //start maps with a single pistol
								#if VLC_DEBUG
								PrintToChatAll("- confiscated a secondary weapon");
								#endif
					} else {							
						RemovePlayerItem(client, equipment);
								#if VLC_DEBUG
									PrintToChatAll("- confiscated a piece of weaponry/equipment");
								#endif
					}
				}				
			}	
		}
	}		
}

GiveItem(client, String:Item[22]) {
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", Item);
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}

bool:IsSurvivor(client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}