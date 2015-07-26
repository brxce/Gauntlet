#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <left4downtown>
#include <l4d2lib>

#define VLC_DEBUG 1
#define	NO_TEMP_HEALTH 0
#define SECONDARY_SLOT 1

new g_bHasLeftStart = false;

public Plugin:myinfo =
{
	name = "Versus like coop",
	author = "Breezy",
	description = "Start maps in coop with full health, pills and a single pistol",
	version = "1.0",
	url = ""
};

public OnPluginStart()
{
	HookEvent("player_spawn", EventHook:OnMapStarted, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnMapCompleted, EventHookMode_Pre);
}

public OnMapStarted()
{
	if (g_bHasLeftStart) //prevent non-survivor "player_spawn" events i.e. infected triggering this function
	{
		return Plugin_Continue;
	} else {
		GiveHealth();	
		ResetInventory();
	}
}

public Action:L4D_OnFirstSurvivorLeftSafeArea()
{
	g_bHasLeftStart = true;
}

public OnMapCompleted()
{
	g_bHasLeftStart = false; //reset for next map
}

public GiveHealth()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2)
		{
			decl String:name[63]
			GetClientName(client, name, sizeof(name));
			GiveItem(client, "health"); //give full health			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0) //remove temp hp
			{
				new temphpoffset = FindSendPropOffs("CTerrorPlayer","m_healthBuffer");
				SetEntDataFloat(client, temphpoffset, NO_TEMP_HEALTH, true);
			}
		}
	}
}

public ResetInventory()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)== 2)
		{
			for (new i = 0; i < 5; i++) { //clear all slots in player's inventory
				if (i == SECONDARY_SLOT) { 
					GiveItem(client, "pistol"); //ensures this is a single pistol
					//EquipPlayerWeapon(client, "weapon_pistol"); ?
				} else { //clear slot
					new equipment = GetPlayerWeaponSlot(client, i);
					AcceptEntityInput(equipment, "kill");
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