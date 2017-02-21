#pragma semicolon 1
#define AUTOSLAYER_DEBUG 0

#include <sourcemod>
#include <left4downtown>
#include <smlib>
#include "includes/hardcoop_util.sp"

new bool:g_bIsAutoSlayerActive = true; // start true to prevent AutoSlayer being activated after round end or before round start
new Handle:hCvarGracePeriod;
new Handle:hCvarTeamClearDelay;
new Handle:hCvarAutoSlayerMode;
new Handle:hCvarSlayAllInfected;
new Handle:hAutoSlayerTimer;

// This plugin was created because of a Hard12 bug where a survivor fails to take damage while pinned
// by special infected. If the whole team is immobilised, they get a grace period before they are AutoSlayerd.
public Plugin:myinfo = {
	name = "AutoSlayer",
	author = "Breezy",
	description = "Slays configured team if survivors are simultaneously incapped/pinned",
	version = "2.0"
};

public OnPluginStart() {
	// Cvar
	hCvarAutoSlayerMode = CreateConVar("autoslayer_mode", "1", "On all survivors incapacitated/pinned : -1 = Slay survivors, 0 = OFF, 1 = Slay infected");
	hCvarGracePeriod = CreateConVar("autoslayer_graceperiod", "7.0", "Time(sec) before pinned/incapacitated survivor team is slayed by 'slay survivors' AutoSlayer mode", FCVAR_PLUGIN, true, 0.0 );
	hCvarTeamClearDelay = CreateConVar( "autoslayer_teamclear_delay", "3.0", "Time(sec) before survivor team is cleared by 'slay infected' AutoSlayer mode", FCVAR_PLUGIN, true, 0.0 );
	hCvarSlayAllInfected = CreateConVar( "autoslayer_slay_all_infected", "1", "0 = only infected pinning survivors are slayed, 1 = all infected are slayed" );
	HookConVarChange(hCvarAutoSlayerMode, ConVarChanged:OnAutoSlayerModeChange);
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

public OnAutoSlayerModeChange() {
	CloseHandle(hAutoSlayerTimer);
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
	if( GetConVarInt(hCvarAutoSlayerMode) != 0 && !g_bIsAutoSlayerActive && IsTeamImmobilised() && !IsTeamWiped() ) { 
		g_bIsAutoSlayerActive = true;
		Client_PrintToChatAll(true, "[AS] {O}Initiating AutoSlayer...");
		if( GetConVarInt(hCvarAutoSlayerMode) < 0 ) { // Slay survivors
			hAutoSlayerTimer = CreateTimer( 1.0, Timer_SlaySurvivors, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT );
		} else { // Slay infected
			CreateTimer( GetConVarFloat(hCvarTeamClearDelay), Timer_SlaySpecialInfected, _, TIMER_FLAG_NO_MAPCHANGE );
		}
	} else { // AutoSlayer mode 0
		return; // AutoSlayer is switched off
	}
}

public Action:Timer_SlaySurvivors(Handle:timer) {
	static secondsPassed = 0;
	new countdown = RoundToNearest(GetConVarFloat(hCvarGracePeriod)) - secondsPassed;
	// Check for survivors being cleared during the countdown
	if( !IsTeamImmobilised() ) {
		Client_PrintToChatAll(true, "[AS] ...AutoSlayer {G}cancelled!");	
		g_bIsAutoSlayerActive = false;
		secondsPassed = 0;
		return Plugin_Stop;
	} 		
	// Countdown ended
	if( countdown <= 0 ) {
		g_bIsAutoSlayerActive = false;
		if( IsTeamImmobilised() && !IsTeamWiped() ) { // do not slay if already wiped
			SlaySurvivors();
			Client_PrintToChatAll(true, "[AS] {N}AutoSlayed {O}survivors!");	
		} else {
			Client_PrintToChatAll(true, "[AS] ...AutoSlayer {G}cancelled!");
		}
		secondsPassed = 0;
		return Plugin_Stop;
	} 
	Client_PrintToChatAll(true, "[AS] %d...", countdown);	
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

public Action:Timer_SlaySpecialInfected(Handle:timer) {
	Client_PrintToChatAll( true, "[AS] AutoSlayed {G}special infected");
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) ) {
			if( IsPinningASurvivor(i) ) {
				ForcePlayerSuicide(i);
			} else {
				if( GetConVarBool(hCvarSlayAllInfected) && !IsTank(i) ) {
					ForcePlayerSuicide(i);
				} 
			}
		}
	}
	g_bIsAutoSlayerActive = false;
}

bool:IsPinningASurvivor(client) {
	new bool:isPinning = false;
	if( IsBotInfected(client) && IsPlayerAlive(client) ) {
		if( GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 ) isPinning = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 ) isPinning = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 ) isPinning = true; // charger carrying
		if( GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 ) isPinning = true; // charger pounding
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 ) isPinning = true; // jockey
	}
	return isPinning;
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