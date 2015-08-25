#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#define EMPTY_SLOT -1
#define TEAM_SURVIVOR 2

//Reference: 'Hard 12 manager' by Standalone and High Cookie

public Plugin:myinfo =
{
	name = "Starting Pills",
	author = "Breezy",
	description = "Start maps in coop with pills",
	version = "1.0",
	url = ""
};

public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	DistributePills();
}

public DistributePills() {
	for (new client = 1; client <= MaxClients; client++) {//iterate though all clients
		if (IsSurvivor(client)) {//check player is a survivor
			if (GetPlayerWeaponSlot(client, 5) == EMPTY_SLOT) {//check pills slot is empty
				GiveItem(client, "pain_pills"); 
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
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; // not a valid client
    else return IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR; 
}  
