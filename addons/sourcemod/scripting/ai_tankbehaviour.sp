#pragma semicolon 1

#define DEBUG
#define INFECTED_TEAM 3
#define ZC_TANK 8
#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "AI: Tank Behaviour",
	author = PLUGIN_AUTHOR,
	description = "Blocks AI tanks from throwing rocks",
	version = PLUGIN_VERSION,
	url = ""
};

/***********************************************************************************************************************************************************************************

																				BLOCK ROCK THROWS
																	
***********************************************************************************************************************************************************************************/

// because AI tanks are dumb
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if (IsBotTank(client)) {	
		buttons &= ~IN_ATTACK2;
		return Plugin_Changed;
	} 
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																				BUNNY HOPS
																	
***********************************************************************************************************************************************************************************/



/* bhops
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	//Proceed if this player is a tank
	if(IsBotTank(client)) {
		new tank = client;
		// Start fast pouncing if close enough to survivors
		new iSurvivorsProximity = GetSurvivorProximity(tank);
		new bool:bHasLOS = bool:GetEntProp(tank, Prop_Send, "m_hasVisibleThreats"); //Line of sight to survivors
		if (bHasLOS && (iSurvivorsProximity < BHOP_PROXIMITY) ) {
			new flags = GetEntityFlags(tank); 		
			if (flags & FL_ONGROUND) {
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
			} else {
				buttons &= ~IN_DUCK;
				buttons &= ~IN_JUMP;
			}					
		}		 
	}
	return Plugin_Changed;
}
*/

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/

bool:IsBotTank(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (GetClientTeam(client) == INFECTED_TEAM) {
		new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == ZC_TANK) {
			if(IsFakeClient(client)) { // is a bot
				return true;
			}
		}
	}
	return false; // otherwise
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
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
			} else if (iAbsDisplacement < iClosestAbsDisplacement) { 
				iClosestAbsDisplacement = iAbsDisplacement; // closest survivor so far
			}			
		}
	}
	// return the closest survivor's proximity
	return iClosestAbsDisplacement;
}