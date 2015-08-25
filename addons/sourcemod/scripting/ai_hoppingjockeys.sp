#pragma semicolon 1
#include <sourcemod>
#define ZC_JOCKEY 5 //zombie class
#define INFECTED_TEAM 3

public Plugin:myinfo = {
	name = "AI: Hopping Jockeys",
	author = "Breezy",
	description = "Force AI jockeys to hop while approaching survivors",
	version = "1.0"
};

new Handle:hCvarHopActivationProximity;
new g_iHopActivationProximity;
new bool:bDoNormalJump[MAXPLAYERS]; // used to alternate pounces and normal jumps

public OnPluginStart() {
	hCvarHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "How close a jockey will approach before it starts hopping");
	g_iHopActivationProximity = GetConVarInt(hCvarHopActivationProximity);
	HookConVarChange(hCvarHopActivationProximity, OnCvarChange);
}

//Update convars if they have been changed midgame
public OnCvarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if (!StrEqual(oldValue, newValue)) g_iHopActivationProximity = GetConVarInt(hCvarHopActivationProximity);		
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	// Proceed for jockey bots
	if(IsJockeyBot(client)) {
		new jockey = client;
		// Start hopping if within range		
		new iSurvivorsProximity = GetSurvivorProximity(jockey);
		if (iSurvivorsProximity < g_iHopActivationProximity) {
			// Force them to hop 
			new flags = GetEntityFlags(jockey);
			buttons |= IN_FORWARD;
			// Alternate normal jump and pounces
			if(flags & FL_ONGROUND) {
				if (bDoNormalJump[jockey]) {
					buttons |= IN_JUMP; // normal jump
				} else {
					buttons |= IN_ATTACK; // pounce leap
				}
				bDoNormalJump[jockey] = !bDoNormalJump[jockey];
			}
		} else { // midair, release buttons
			buttons &= ~IN_JUMP;
			buttons &= ~IN_ATTACK;
		}		
	}
	return Plugin_Changed;
}

bool:IsJockeyBot(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a jockey, and a bot
	new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (GetClientTeam(client) == INFECTED_TEAM) {
		if (zombieClass == ZC_JOCKEY) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
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