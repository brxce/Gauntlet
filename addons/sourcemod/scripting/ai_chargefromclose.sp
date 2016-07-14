#pragma semicolon 1
#include <sourcemod>
#define ZC_CHARGER 6 //zombie class
#define INFECTED_TEAM 3
#define MAX_CHARGE_PROXIMITY 400

public Plugin:myinfo = {
	name = "AI: Charge From Close",
	author = "Breezy",
	description = "Force AI chargers to get close to survivors before charging",
	version = "1.0"
};

// custom convar
new Handle:hCvarChargeProximity;
new g_iChargeProximity;

new bShouldCharge[MAXPLAYERS];

public OnPluginStart() {
	// "ai_charge_proximity"
	hCvarChargeProximity = CreateConVar("ai_charge_proximity", "300", "How close a charger will approach before charging");
	g_iChargeProximity = GetConVarInt(hCvarChargeProximity);
	HookConVarChange(hCvarChargeProximity, OnCvarChange);
	
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
}

//Update convars if they have been changed midgame
public OnCvarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if (!StrEqual(oldValue, newValue)) g_iChargeProximity = GetConVarInt(hCvarChargeProximity);		
}

/***********************************************************************************************************************************************************************************

																KEEP CHARGE ON COOLDOWN UNTIL WITHIN PROXIMITY

***********************************************************************************************************************************************************************************/

// Initiate spawned chargers
public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotCharger(client)) {
		bShouldCharge[client] = false;
	}	
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	// Proceed for charger bots
	if(IsBotCharger(client)) {
		new charger = client;	
		new iProximity = GetSurvivorProximity(charger);
		new chargeDistance = GetRandomInt(g_iChargeProximity, MAX_CHARGE_PROXIMITY);
		if (iProximity > chargeDistance) { // if charger has not yet approached within range
			if (!bShouldCharge[charger]) { // prevent charge until survivors are within the defined proximity				
				new chargeEntity = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
				if (chargeEntity > 0) {  // charger entity persists for a short while after death; check ability entity is valid
					SetEntPropFloat(chargeEntity, Prop_Send, "m_timestamp", GetGameTime() + 0.1); // keep extending cooldown period
				}		
			}				
		} else {
			bShouldCharge[charger] = true; // charger has been within proximity
		}
	}
	return Plugin_Changed;
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

bool:IsBotCharger(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a jockey, and a bot
	new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (GetClientTeam(client) == INFECTED_TEAM) {
		if (zombieClass == ZC_CHARGER) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; 
}
  
GetSurvivorProximity(referenceClient) {
	// Get the reference's position
	new Float:referencePosition[3];
	GetEntPropVector(referenceClient, Prop_Send, "m_vecOrigin", referencePosition);
	// Find the proximity of the closest survivor
	new iClosestAbsDisplacement = -1; // closest absolute displacement
	for (new client = 1; client < MaxClients; client++) {
		if (IsValidClient(client) && IsSurvivor(client)) {
			// Get displacement between this survivor and the reference
			new Float:survivorPosition[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", survivorPosition);
			new iAbsDisplacement = RoundToNearest(GetVectorDistance(referencePosition, survivorPosition));
			// Start with the absolute displacement to the first survivor found:
			if (iClosestAbsDisplacement == -1) {
				iClosestAbsDisplacement = iAbsDisplacement;
			} else if (iAbsDisplacement < iClosestAbsDisplacement) { // closest survivor so far
				iClosestAbsDisplacement = iAbsDisplacement;
			}			
		}
	}
	// return the closest survivor's proximity
	return iClosestAbsDisplacement;
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}