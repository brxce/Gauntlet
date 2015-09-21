#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>

#define EMPTY_SLOT -1
#define TEAM_SURVIVOR 2

//Reference: 'Hard 12 manager' by Standalone and High Cookie

public Plugin:myinfo =
{
	name = "Pills Only",
	author = "Breezy",
	description = "Maps only contain scavenged pills and an initial set granted when leaving saferoom",
	version = "1.0",
	url = ""
};

/***********************************************************************************************************************************************************************************

																				ITEM FILTERING
																	
***********************************************************************************************************************************************************************************/

new const NUM_ITEMS = 5
new String:undesiredItems[][] =  {"first_aid_kit", "adrenaline", "molotov", "pipe_bomb", "vomitjar"};

// Detect when an entity is about to be spawned, then pass onto SpawnPost SDKHOOK
public OnEntityCreated(entity, const String:classname[]) {
	if(IsValidEntity(entity)) {
		for (new i = 0; i < NUM_ITEMS; i++) {
			if(StrContains(classname, undesiredItems[i], false) != -1) {
				SDKHook(entity, SDKHook_SpawnPost, DestroyEntitySpawn);
			}
		}			
	}   
}

public DestroyEntitySpawn(entity) {
	AcceptEntityInput(entity, "kill");
}

/***********************************************************************************************************************************************************************************

																				STARTING PILLS
																	
***********************************************************************************************************************************************************************************/

public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	DistributePills();
}

public DistributePills() {
	// iterate though all clients
	for (new client = 1; client <= MaxClients; client++) { 
		//check player is a survivor
		if (IsSurvivor(client)) {
			// check pills slot is empty
			if (GetPlayerWeaponSlot(client, 5) == EMPTY_SLOT) { 
				GiveItem(client, "pain_pills"); 
			}								
		}
	}
}

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/

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
