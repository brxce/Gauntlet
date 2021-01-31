#pragma semicolon 1
#define AUTOSLAYER_DEBUG 0

#include <sourcemod>
#include <colors>
#include <sdktools>
#include <left4dhooks>
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
	// Cvars
	hCvarAutoSlayerMode = CreateConVar("autoslayer_mode", "1", "On all survivors incapacitated/pinned : -1 = Slay survivors, 0 = OFF, 1 = Slay infected");
	// This applies for "autoslayer_mode 1" (slay survivors)
	hCvarGracePeriod = CreateConVar("autoslayer_graceperiod", "7.0", "Time(sec) before pinned/incapacitated survivor team is slayed by 'slay survivors' AutoSlayer mode", FCVAR_PLUGIN, true, 0.0 );
	// These only applies for "autoslayer_mode -1" (slay infected when all survivors are pinned)
	hCvarSlayAllInfected = CreateConVar( "autoslayer_slay_all_infected", "1", "0 = only slays infected that are pinning survivors, 1 = all infected are slayed" );
	hCvarTeamClearDelay = CreateConVar( "autoslayer_teamclear_delay", "3.0", "Time(sec) before survivor team is cleared by 'slay infected' AutoSlayer mode", FCVAR_PLUGIN, true, 0.0 );
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

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax) 
{
	g_bIsAutoSlayerActive = false;
	return APLRes_Success;
}

public OnAutoSlayerModeChange() {
	if ( hAutoSlayerTimer != INVALID_HANDLE ) {
		CloseHandle(hAutoSlayerTimer);
	}
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

	new bool:bShouldTrigger = false;
	
	// Trigger when the whole survivor team is immobilised (pinned or dead), excluding situation when all have just died or a lone survivor has been pinned (outside of 1p mode)
	if( GetConVarInt(hCvarAutoSlayerMode) != 0 && !g_bIsAutoSlayerActive ) {
		if ( IsTeamImmobilised() && !IsTeamWiped() ) { // there is at least one survivor alive, but all standing survivors are pinned
			if ( GetConVarInt(hCvarAutoSlayerMode) < 0 ) { // Slay survivors
				bShouldTrigger = true;
				hAutoSlayerTimer = CreateTimer( 1.0, Timer_SlaySurvivors, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT );
			} else if ( GetConVarInt(hCvarAutoSlayerMode) > 0 ) {
				if ( IsLastStanding() ) { // if there are no other survivors standing, only follow through with autoslay infected if this is 1P mode (i.e. do not save last standing survivors)
					if ( GetConVarInt(FindConVar("survivor_limit")) == 1) {
						bShouldTrigger = true;
						CreateTimer( GetConVarFloat(hCvarTeamClearDelay), Timer_SlaySpecialInfected, _, TIMER_FLAG_NO_MAPCHANGE );
					} 
				} else { // multiple survivors, all alive and pinned
					bShouldTrigger = true;
					CreateTimer( GetConVarFloat(hCvarTeamClearDelay), Timer_SlaySpecialInfected, _, TIMER_FLAG_NO_MAPCHANGE );
				}
			}
		} 
	} 
	
	// Cvar activation and printout
	if ( bShouldTrigger ) {
		g_bIsAutoSlayerActive = true;
		CPrintToChatAll("{olive}[AS] {default}Initiating AutoSlayer...");
	}
}

public Action:Timer_SlaySurvivors(Handle:timer) {
	static secondsPassed = 0;
	new countdown = RoundToNearest(GetConVarFloat(hCvarGracePeriod)) - secondsPassed;
	// Check for survivors being cleared during the countdown
	if( !IsTeamImmobilised() ) {
		CPrintToChatAll("{olive}[AS] ...{blue}AutoSlayer cancelled!");	
		g_bIsAutoSlayerActive = false;
		secondsPassed = 0;
		return Plugin_Stop;
	} 		
	// Countdown ended
	if( countdown <= 0 ) {
		g_bIsAutoSlayerActive = false;
		if( IsTeamImmobilised() && !IsTeamWiped() ) { // do not slay if already wiped
			SlaySurvivors();
			CPrintToChatAll("{olive}[AS] {red}AutoSlayed survivors!");	
		} else {
			CPrintToChatAll("{olive}[AS] {default}...{blue}AutoSlayer cancelled!");
		}
		secondsPassed = 0;
		return Plugin_Stop;
	} 
	PrintToChatAll("[AS] %d...", countdown);	
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
	CPrintToChatAll("[AS] AutoSlayed {blue}special infected");
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

/**
 * @return: true if all survivors but one have died
**/
bool:IsLastStanding() {
	new num_survivors = GetConVarInt(FindConVar("survivor_limit"));
	new num_alive_survivors = 0;
	for ( new i = 0; i < MaxClients; ++i ) {
		if ( IsSurvivor(i) && !IsPlayerAlive(i) ) {
			++num_alive_survivors;	
		}
	}
	return (num_survivors - num_alive_survivors == 1 ? true : false ); 
}