#include <sourcemod>
#include <sdktools>
#include <left4downtown>

public Plugin:myinfo =
{
	name = "Drugged Coop",
	author = "Standalone; modified by Breezy",
	description = "Start maps in coop with pills",
	version = "1.0",
	url = ""
};

public Action:L4D_OnFirstSurvivorLeftSafeArea()
{
	DistributePills();
	return Plugin_Continue;
}

public DistributePills()
{
	for (new client = 1; client <= MaxClients; client++) //iterate though all clients
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2) //check player is a survivor
		{
			if (GetPlayerWeaponSlot(client, 5) == -1) //check pills slot is empty
			{
				GiveItem(client, "pain_pills"); 
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