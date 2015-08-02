#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <left4downtown>
#include <l4d2lib>

#define VLC_DEBUG 1
#define POST_ROUNDSTART_DELAY 2.5
//#define POST_TEAMWIPED_DELAY 6.0
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
	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
	//HookEvent("mission_lost", EventHook:OnTeamWiped, EventHookMode_PostNoCopy);
}

public OnRoundStart()
{
	CreateTimer(POST_ROUNDSTART_DELAY, Timer_PostRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_PostRoundStart(Handle:timer)
{
	#if VLC_DEBUG
		PrintToChatAll("Timer_PostRoundStart");
	#endif
	RestoreHealth();
	ResetInventory();		

}

/*
public OnTeamWiped()
{
	CreateTimer(POST_TEAMWIPED_DELAY, Timer_PostTeamWiped, _, TIMER_FLAG_NO_MAPCHANGE); 
}

public Action:Timer_PostTeamWiped (Handle: timer)
{
	#if VLC_DEBUG
		PrintToChatAll("Timer_PostTeamWiped");
	#endif
	RestoreHealth();
	ResetInventory();
}
*/

public RestoreHealth()
{
	for (new client = 0; client <= MaxClients; client++)
	{
		if ( IsSurvivor(client) )
		{
#if VLC_DEBUG
	PrintToChatAll("Found a survivor, restoring health and resetting revive count");
#endif
			GiveItem(client, "health"); //give full health			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0) //remove temp hp
			{
#if VLC_DEBUG
	PrintToChatAll("- and removing temp health");
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
	PrintToChatAll("");
	PrintToChatAll("Found a survivor");
#endif
			for (new i = 0; i < 5; i++) { //clear all slots in player's inventory
				 	new equipment = GetPlayerWeaponSlot(client, i);
					if (equipment != -1) { //if slot is not empty
						if (i == SECONDARY_SLOT) { 
							//Using AcceptEntityInput() for the secondary causes the new pistols to be dropped on the floor
							RemoveEdict(equipment); 
							GiveItem(client, "pistol"); 
#if VLC_DEBUG
PrintToChatAll("- Deleting a secondary item");
#endif
						} else {							
							AcceptEntityInput(equipment, "kill");
#if VLC_DEBUG
	PrintToChatAll("- Deleting a non-secondary item");
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