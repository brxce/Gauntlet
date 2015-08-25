#pragma semicolon 1
#include <sourcemod>
#define HUNTER 3
#define START 0
#define STOP 1

public Plugin:myinfo = {
	name = "Hunter lunge tracking",
	author = "Breezy",
	description = "Prints hunter lunge vectors",
	version = "1.0"
};

new g_bHasAnnounced[MAXPLAYERS][2];
new Handle:hCvarCrouchPounceDelay;
new Handle:hCvarLungeInterval;
new bool:g_bShouldTrackLunge = false;
new bool:g_bShouldNullifyLunge = false;

public OnPluginStart() {
	// "z_pounce_crouch_delay"
	hCvarCrouchPounceDelay = FindConVar("z_pounce_crouch_delay");
	// "z_lunge_interval"
	hCvarLungeInterval = FindConVar("z_lunge_interval");	
	// lunge vector
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre);
	// resetting client cache
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	// custom console commands
	RegConsoleCmd("sm_togglelungetracking", ToggleLungeTracking);
	RegConsoleCmd("sm_togglelungenullify", ToggleLungeNullify);
}

public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if ((zombieClass == HUNTER) && (GetClientTeam(client) == 3)) {
		new hunter = client;
		g_bHasAnnounced[hunter][START] = false;
		g_bHasAnnounced[hunter][STOP] = false;
	}
	return Plugin_Continue;
}

public Action:ToggleLungeTracking(client, args) {
	g_bShouldTrackLunge = !g_bShouldTrackLunge;
	// disable lunge nullification if tracking is being turned off
	if (!g_bShouldTrackLunge) {
		SetConVarFloat(hCvarCrouchPounceDelay, 1.0);
		SetConVarFloat(hCvarLungeInterval, 0.1);
	}
}

public Action:ToggleLungeNullify(client, args) {
	g_bShouldNullifyLunge = !g_bShouldNullifyLunge;
	if (g_bShouldNullifyLunge) {
		SetConVarFloat(hCvarCrouchPounceDelay, 0.0);
		SetConVarFloat(hCvarLungeInterval, 0.0);
	} else {
		// turn off rapid pouncing
		SetConVarFloat(hCvarCrouchPounceDelay, 1.0);
		SetConVarFloat(hCvarLungeInterval, 0.1);
	}
}

public OnPluginEnd() {
	ResetConVar(hCvarCrouchPounceDelay);
	ResetConVar(hCvarLungeInterval);
}

public Action:OnAbilityUse(Handle:event, String:name[], bool:dontBroadcast) {
	if (g_bShouldTrackLunge) {
		new String:abilityName[32];
		GetEventString(event, "ability", abilityName, sizeof(abilityName));
		// if a hunter is about to pounce
		if (StrEqual(abilityName, "ability_lunge")) { 
			// get the vector of the lunge
			new abilityUser = GetClientOfUserId(GetEventInt(event, "userid"));
			new entLunge = GetEntPropEnt(abilityUser, Prop_Send, "m_customAbility");
			new Float:lungeVector[3];
			GetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", lungeVector);
			// Print
			decl String:Name[32];
			GetClientName(abilityUser, Name, sizeof(Name));
			PrintToChatAll("\x04%s lunged", Name);
			for (new i = 0; i < 3; i++) {
				PrintToChatAll("lungeVector[%i]: %f", i, lungeVector[i]);
			}
			new Float:nullLunge[] = {0.0, 0.0, 0.0};  
			SetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", nullLunge);
			return Plugin_Changed;
		}
	}	
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	//Proceed if this player is a hunter
	if( (zombieClass == HUNTER) && (GetClientTeam(client) == 3) ) {
		new hunter = client;
		new bool:bIsAttemptingToPounce = bool:GetEntProp(hunter, Prop_Send, "m_isAttemptingToPounce");
		if(bIsAttemptingToPounce) {
			if (!g_bHasAnnounced[hunter][START]) {
				PrintToChatAll("m_isAttemptingToPounce: %b", bIsAttemptingToPounce);
				g_bHasAnnounced[hunter][STOP] = false;
				g_bHasAnnounced[hunter][START] = true;
			}
		} else {
			if (!g_bHasAnnounced[hunter][STOP]) {
				PrintToChatAll("m_isAttemptingToPounce: %b", bIsAttemptingToPounce);
				g_bHasAnnounced[hunter][START] = false;
				g_bHasAnnounced[hunter][STOP] = true;
			}
		}
	}
}
