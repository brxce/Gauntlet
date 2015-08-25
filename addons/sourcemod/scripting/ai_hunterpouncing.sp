#pragma semicolon 1
#include <sourcemod>
#define ZC_HUNTER 3
#define INFECTED_TEAM 3

public Plugin:myinfo = {
	name = "AI: Hunter Pouncing",
	author = "Breezy",
	description = "Modifies hunter lunge patterns",
	version = "1.0"
};
new Handle:hCvarHunterPounceMaxLoftAngle; // vanilla cvar
// vanilla cvar
new Handle:hCvarLungeInterval;
new Float:g_fLungeInterval;
// Distance at which hunter begins pouncing fast; prevents hunters getting stuck in a room while pounce spamming
new Handle:hCvarFastPounceProximity;
new g_iFastPounceProximity;
new bool:bHasQueuedLunge[MAXPLAYERS];
new bool:bCanLunge[MAXPLAYERS];

public OnPluginStart() {
	// "z_lunge_interval"
	hCvarLungeInterval = FindConVar("z_lunge_interval");
	HookConVarChange(hCvarLungeInterval, OnConVarChange);
	g_fLungeInterval = GetConVarFloat(hCvarLungeInterval);
	// "hunter_pounce_max_loft_angle"
	hCvarHunterPounceMaxLoftAngle = FindConVar("hunter_pounce_max_loft_angle");
	SetConVarInt(hCvarHunterPounceMaxLoftAngle, 0);
	// "ai_fast_pounce_proximity"
	hCvarFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "500", "Pounce ASAP");
	HookConVarChange(hCvarFastPounceProximity, OnConVarChange);
	g_iFastPounceProximity = GetConVarInt(hCvarFastPounceProximity);
	// Allow pouncing on newly spawned hunters
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
}

// update if cvar changes
public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if (convar == hCvarLungeInterval) g_fLungeInterval = GetConVarFloat(hCvarLungeInterval);
	if (convar == hCvarFastPounceProximity)	g_iFastPounceProximity = GetConVarInt(hCvarFastPounceProximity);
}

public OnPluginEnd() {
	ResetConVar(hCvarHunterPounceMaxLoftAngle);
}

public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotHunter(client)) {
		bHasQueuedLunge[client] = false;
		bCanLunge[client] = true;
	}
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	//Proceed if this player is a hunter
	if(IsBotHunter(client)) {
		new hunter = client;
		new flags = GetEntityFlags(hunter);
		//Proceed if the hunter is crouching 
		if(flags & FL_DUCKING) {
			//If hunter is grounded, determine if it should pounce
			if (flags & FL_ONGROUND) {
				// Start fast pouncing if close enough to survivors
				new iSurvivorsProximity = GetSurvivorProximity(hunter);
				if (iSurvivorsProximity < g_iFastPounceProximity) {
					buttons &= ~IN_ATTACK; // release attack button; precautionary
					// Queue a pounce/lunge
					if (!bHasQueuedLunge[hunter]) { // check lunge interval timer has not already been initiated
						bCanLunge[hunter] = false;
						bHasQueuedLunge[hunter] = true; // block duplicate lunge interval timers
						CreateTimer(g_fLungeInterval, Timer_LungeInterval, any:hunter, TIMER_FLAG_NO_MAPCHANGE);
					} else if (bCanLunge[hunter]) { // end of lunge interval; lunge!
						buttons |= IN_ATTACK; 
						bHasQueuedLunge[hunter] = false; // unblock lunge interval timer
					} // else lunge queue is being processed
				}				
			} 
		}
	}
	return Plugin_Changed;
}

// After the given interval, hunter is allowed to pounce/lunge
public Action:Timer_LungeInterval(Handle:timer, any:client) {
	bCanLunge[client] = true;
}

bool:IsBotHunter(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (GetClientTeam(client) == INFECTED_TEAM) {
		new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == ZC_HUNTER) {
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