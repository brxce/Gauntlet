#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <left4downtown>

#define VLC_DEBUG 1

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
	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnMapEnd, EventHookMode_Pre);
}

public OnRoundStart()
{
	GiveHealth();
	return Plugin_Continue;
}

public OnMapEnd()
{
	ConfiscateItems();
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2)
		{
			GivePistol(client);
		}
	}
	
}

public GiveHealth()
{
	#if VLC_DEBUG
		PrintToChatAll("GiveHealth()");
	#endif
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2)
		{
			decl String:name[63]
			GetClientName(client, name, sizeof(name));
			#if VLC_DEBUG
				PrintToChatAll("Giving health");
			#endif
			GiveItem(client, "health"); //give full health			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0) //remove temp hp
			{
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1, 0);
			}
		}
	}
}

public ConfiscateItems()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)== 2)
		{
			for (new i = 0; i < 4, i++) { //clear all slots in player's inventory
				new equipment = GetPlayerWeaponSlot(client, i);
				AcceptEntityInput(equipment, "kill");
			}		
		}
	}		
}

public GivePistol(client)
{
	//Give one pistol
	new flagsgive = GetCommandFlags("give");
	SetCommandFlags("give", flagsgive & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give weapon_pistol");
	SetCommandFlags("give", flagsgive|FCVAR_CHEAT);
}