#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define VLC_DEBUG 1
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
	HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_Pre);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
}

 //for when a survivor died the previous map, and starts the next with partial permanent health
public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	#if VLC_DEBUG
		PrintToChatAll("(Left4Downtown2) L4D_OnFirstSurvivorLeftSafeArea");
	#endif
	RestoreHealth();
}

//fail-safe in case end of map health restoration does not work
public Action:Event_RoundFreezeEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
#if VLC_DEBUG
	PrintToChatAll("round_freeze_end");
#endif
	RestoreHealth(); 
}

public Action:Event_MapTransition(Handle:event, const String:name[], bool:dontBroadcast)
{
#if VLC_DEBUG
	PrintToChatAll("(post)map_transition");
#endif
	ResetInventory();
	RestoreHealth();
}

public RestoreHealth()
{
	for (new client = 0; client <= MaxClients; client++)
	{
		if ( IsSurvivor(client) )
		{
#if VLC_DEBUG
	PrintToChatAll("Restored health and reset revive count on client: %i", client);
#endif
			GiveItem(client, "health"); //give full health			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0) //remove temp hp
			{
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

public ResetInventory()
{
	for (new client = 0; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
#if VLC_DEBUG
	PrintToChatAll("Resetting inventory of client: %i", client);
#endif
			for (new i = 0; i < 5; i++) { //clear all slots in player's inventory
				 	new equipment = GetPlayerWeaponSlot(client, i);
					if (equipment != -1) { //if slot is not empty
						if (i == SECONDARY_SLOT) { 
							RemovePlayerItem(client, equipment);
							GiveItem(client, "pistol"); 
#if VLC_DEBUG
PrintToChatAll("- confiscated a secondary weapon");
#endif
						} else {							
							RemovePlayerItem(client, equipment);
#if VLC_DEBUG
	PrintToChatAll("- confiscated a piece weaponry/equipment");
#endif
						}
					}				
			}	
		}
	}		
}

GiveItem(client, String:Item[22])
{
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", Item);
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}

bool:IsSurvivor(client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}