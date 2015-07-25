#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <left4downtown>

public Plugin:myinfo =
{
	name = "Drugged Coop",
	author = "Standalone; modified by Breezy",
	description = "Start maps in coop with pills",
	version = "1.0",
	url = ""
};

public OnPluginStart()
{
}

public Action:L4D_OnFirstSurvivorLeftSafeArea()
{
	GivePills();
	return Plugin_Continue;
}

public OnMapEnd()
{
	//ConfiscateItems();
}

public GivePills()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2)
		{
			decl String:name[63]
			GetClientName(client, name, sizeof(name));
			
			if (GetPlayerWeaponSlot(client, 5) == -1) 
			{
				GiveItem(client, "pain_pills"); //pills
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