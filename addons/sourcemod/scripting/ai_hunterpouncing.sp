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

new Handle:hCvarLungeInterval;
new Handle:hCvarHunterPounceMaxLoftAngle;
new Float:g_fLungeInterval;
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
}

public OnPluginEnd() {
	ResetConVar(hCvarHunterPounceMaxLoftAngle);
}

// update if cvar changes
public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if (!StrEqual(oldValue, newValue)) g_fLungeInterval = GetConVarFloat(hCvarLungeInterval);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	//Proceed if this player is a hunter
	if(IsHunterBot(client)) {
		new flags = GetEntityFlags(client);
		//Proceed if the hunter is crouching 
		if(flags & FL_DUCKING) {
			//If hunter is grounded, determine if it should pounce
			if (flags & FL_ONGROUND) {
				buttons &= ~IN_ATTACK; // release attack button; precautionary
				// Queue a pounce/lunge
				if (!bHasQueuedLunge[client]) { // check lunge interval timer has not already been initiated
					bCanLunge[client] = false;
					bHasQueuedLunge[client] = true; // block duplicate lunge interval timers
					CreateTimer(g_fLungeInterval, Timer_LungeInterval, any:client, TIMER_FLAG_NO_MAPCHANGE);
				} else if (bCanLunge[client]) { // end of lunge interval; lunge!
					buttons |= IN_ATTACK; 
					bHasQueuedLunge[client] = false; // unblock lunge interval timer
				} // else lunge queue is being processed
			} /*else { // midair
				if (false) { // can wall pounce
					buttons |= IN_ATTACK; // wall pounce
				} else {
					buttons &= ~IN_ATTACK;
				}				
			}*/
		}
	}
	return Plugin_Changed;
}

// After the given interval, hunter is allowed to pounce/lunge
public Action:Timer_LungeInterval(Handle:timer, any:client) {
	bCanLunge[client] = true;
}

bool:IsHunterBot(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (GetClientTeam(client) == INFECTED_TEAM) {
		if (zombieClass == ZC_HUNTER) {
			if(IsFakeClient(client)) {
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