#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <left4downtown>
#include <l4d2lib>

#define VLC_DEBUG 1
#define	NO_TEMP_HEALTH 0.0
#define SECONDARY_SLOT 1

new g_bHasLeftStart = false;

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
	HookEvent("round_start_post_nav", EventHook:OnMapStarted, EventHookMode_PostNoCopy);
	HookEvent("game_end", EventHook:OnMapCompleted, EventHookMode_Pre);
}

public OnMapStarted()
{
	#if VLC_DEBUG
		PrintToChatAll("Restoring health and resetting inventory");
	#endif
	if (!g_bHasLeftStart) {//non-survivor "player_spawn" events i.e. infected should not trigger this function
		RestoreHealth();
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

public RestoreHealth()
{
	for (new client = 0; client <= MaxClients; client++)
	{
		if ( IsSurvivor(client) )
		{
			GiveItem(client, "health"); //give full health			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0) //remove temp hp
			{
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
			for (new i = 0; i < 5; i++) { //clear all slots in player's inventory
				 	new equipment = GetPlayerWeaponSlot(client, i);
					if (equipment != -1) { //if slot is not empty
						if (i == SECONDARY_SLOT) { 
							//Using AcceptEntityInput() for the secondary causes the new pistols to be dropped on the floor
							RemoveEdict(equipment); 
							GiveItem(client, "pistol"); 
						} else {
							AcceptEntityInput(equipment, "kill");
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