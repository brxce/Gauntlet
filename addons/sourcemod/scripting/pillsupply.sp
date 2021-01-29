#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include "includes/hardcoop_util.sp"

#define DEBUG 0
#define EMPTY_SLOT -1

// Reference: 'Hard 12 manager' by Standalone and High Cookie
// "current" by "CanadaRox"

public Plugin:myinfo =
{
	name = "Pill Supply",
	author = "Breezy",
	description = "Supplies survivors a set of pills upon leaving saferoom and a supplementary set at a configured map percentage",
	version = "1.0",
	url = ""
};

public OnPluginStart() {	
	HookEvent( "revive_success", OnReviveSuccess, EventHookMode_PostNoCopy );
}


/***********************************************************************************************************************************************************************************

																				PER ROUND
																	
***********************************************************************************************************************************************************************************/

public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	DistributePills();
}

public Action:OnReviveSuccess( Handle:event, const String:eventName[], bool:dontBroadcast ) {
	new revived = GetClientOfUserId( GetEventInt(event, "subject") );
	if( IsSurvivor(revived) && IsPlayerAlive(revived) ) {
		GiveItem( revived, "pain_pills" );
	}
}

/***********************************************************************************************************************************************************************************

																				STARTING PILLS
																	
***********************************************************************************************************************************************************************************/

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

GiveItem(client, String:itemName[]) {
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", itemName);
	SetCommandFlags("give", flags);
}

/*
GiveItem(client, String:itemName[22]) {	
	new item = CreateEntityByName(itemName);
	new Float:clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);
	TeleportEntity(item, clientOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(item); 
	EquipPlayerWeapon(client, item);
}*/