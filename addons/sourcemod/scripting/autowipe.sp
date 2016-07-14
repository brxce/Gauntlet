#pragma semicolon 1
#define AS_DEBUG 0
#define GRACETIME 7.0
#define TEAM_SURVIVOR 2
#include <sourcemod>
#include<left4downtown>

// This plugin was created because of a Hard12 bug where one ore more survivors were not taking damage while pinned
// by special infected. If the whole team is immobilised, they get a grace period before they are AutoWiped.
public Plugin:myinfo = {
	name = "AutoWipe",
	author = "Breezy",
	description = "Wipes the team if they are simultaneously incapped/pinned for a period of time",
	version = "1.0"
};

new bool:g_bCanAllowNewAutowipe = false; // start true to prevent autowipe being activated at round start

public OnPluginStart() {
	// Disabling autowipe
	HookEvent("map_transition", EventHook:DisableAutoWipe, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", EventHook:DisableAutoWipe, EventHookMode_PostNoCopy);
}

public DisableAutoWipe() {
	g_bCanAllowNewAutowipe = false; // prevents autowipe from being called until next map
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	g_bCanAllowNewAutowipe = true;
}

public OnGameFrame() {
	// activate AutoWipe if necessary
	if (g_bCanAllowNewAutowipe) {
		if (IsTeamImmobilised()) {
			PrintToChatAll("[AW] Initiating an AutoWipe...");
			CreateTimer(GRACETIME, Timer_AutoWipe, _, TIMER_FLAG_NO_MAPCHANGE);
			g_bCanAllowNewAutowipe = false;
		}
	} 
}

public Action:Timer_AutoWipe(Handle:timer) {
	if (IsTeamImmobilised()) {
		WipeSurvivors();
		PrintToChatAll("[AW] AutoWiped survivors!");	
		return Plugin_Stop;
	} else {
		PrintToChatAll("[AW] ...AutoWipe cancelled!");
		g_bCanAllowNewAutowipe = true;	
		return Plugin_Stop;
	}
}

WipeSurvivors() { //incap everyone
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			SetEntProp(client, Prop_Send, "m_isIncapacitated", true);
		}
	}
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

bool:IsTeamImmobilised() {
	//Check if there is still an upright survivor
	new bool:bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsPinned(client) && !IsIncapacitated(client) ) {		
				bIsTeamImmobilised = false;				
						#if AS_DEBUG
							decl String:ClientName[32];
							GetClientName(client, ClientName, sizeof(ClientName));
							LogMessage("IsTeamImmobilised() -> %s is mobile, team not immobilised: \x05", ClientName);
						#endif
				break;
			} 
		} 
	}
	return bIsTeamImmobilised;
}

bool:IsPinned(client) {
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true; // smoker
		if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true; // hunter
		if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true; // charger
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

bool:IsIncapacitated(client) {
	new bool:bIsIncapped = false;
	if ( IsSurvivor(client) ) {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}

bool:IsSurvivor(client) {
	return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool:IsValidClient(client) { 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}  
