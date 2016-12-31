#pragma semicolon 1
#define AUTOSLAYER_DEBUG 0

#include <sourcemod>
#include <left4downtown>
#include <smlib>
#include "includes/hardcoop_util.sp"

new bool:g_bIsAutoSlayerActive = true; // start true to prevent AutoSlayer being activated after round end or before round start
new handle:hCvarGracePeriod;

// This plugin was created because of a Hard12 bug where a survivor fails to take damage while pinned
// by special infected. If the whole team is immobilised, they get a grace period before they are AutoSlayerd.
public Plugin:myinfo = {
	name = "AutoSlayer",
	author = "Breezy",
	description = "Slays the team if they are simultaneously incapped/pinned for a period of time",
	version = "1.0"
};

public OnPluginStart() {
	// Cvar
	hCvarGracePeriod = CreateConVar("autoslayer_graceperiod", "7", "Time(sec) pinned/incapacitated survivor team is allowed to pistol clear before an AutoSlayer is executed");
	// Event hooks
	HookEvent("player_incapacitated", EventHook:OnPlayerImmobilised, EventHookMode_PostNoCopy);
	HookEvent("choke_start", EventHook:OnPlayerImmobilised, EventHookMode_PostNoCopy);
	HookEvent("lunge_pounce", EventHook:OnPlayerImmobilised, EventHookMode_PostNoCopy);
	HookEvent("charger_pummel_start", EventHook:OnPlayerImmobilised, EventHookMode_PostNoCopy); 
	HookEvent("jockey_ride", EventHook:OnPlayerImmobilised, EventHookMode_PostNoCopy);	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	// Prevent AutoSlayer activating between maps
	HookEvent("map_transition", EventHook:PreventAutoSlayer, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", EventHook:PreventAutoSlayer, EventHookMode_PostNoCopy);
}

public PreventAutoSlayer() {
	g_bIsAutoSlayerActive = true;
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	g_bIsAutoSlayerActive = false;
}

public OnPlayerImmobilised() {
	AutoSlayer();
}

public OnPlayerDeath(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	if( IsSurvivor(client) ) {
		AutoSlayer();
	}
}

AutoSlayer() {
	if( !g_bIsAutoSlayerActive && IsTeamImmobilised() && !IsTeamWiped() ) {
		Client_PrintToChatAll(true, "{O}[AS] {N}Initiating AutoSlayer...");
		new gracePeriod = GetConVarInt(hCvarGracePeriod);
		CreateTimer( 1.0, Timer_AutoSlayer, gracePeriod, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT );
		g_bIsAutoSlayerActive = true;
	} 
}

public Action:Timer_AutoSlayer(Handle:timer, any:iGracePeriod) {
	static secondsPassed = 0;
	new countdown = iGracePeriod - secondsPassed;
	// Check for survivors being cleared during the countdown
	if( !IsTeamImmobilised() ) {
		Client_PrintToChatAll(true, "{O}[AS] {N}...AutoSlayer cancelled!");	
		g_bIsAutoSlayerActive = false;
		secondsPassed = 0;
		return Plugin_Stop;
	} 		
	// Countdown ended
	if( countdown <= 0 ) {
		g_bIsAutoSlayerActive = false;
		if( IsTeamImmobilised() && !IsTeamWiped() ) { // do not slay if already wiped
			SlaySurvivors();
			Client_PrintToChatAll(true, "{O}[AS] {N}AutoSlayed survivors!");	
		} else {
			Client_PrintToChatAll(true, "{O}[AS] {N}...AutoSlayer cancelled!");
		}
		secondsPassed = 0;
		return Plugin_Stop;
	} 
	Client_PrintToChatAll(true, "{O}[AS] {N}%d...", countdown);	
	secondsPassed++;
	return Plugin_Continue;
}

SlaySurvivors() { //incap everyone
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			ForcePlayerSuicide(client);
		}
	}
}

/**
 * @return: true if all survivors are either incapacitated or pinned
**/
bool:IsTeamImmobilised() {
	// If any survivor is found to be alive and neither pinned nor incapacitated the team is not immobilised.
	new bool:bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsPinned(client) && !IsIncapacitated(client) ) {		
				bIsTeamImmobilised = false;				
				break;
			} 
		} 
	}
	return bIsTeamImmobilised;
}

/**
 * @return: true if all survivors are either incapacitated
**/
bool:IsTeamWiped() {
	new bool:bIsTeamWiped = true;
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsIncapacitated(client) ) {		
				bIsTeamWiped = false;				
				break;
			} 
		} 
	}
	return bIsTeamWiped;
}