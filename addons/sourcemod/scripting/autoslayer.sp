#pragma semicolon 1
#define AS_DEBUG 1
#define GRACETIME 6.0
#define TEAM_SURVIVOR 2
#include <sourcemod>
#include <sdktools_functions> // ForcePlayerSuicide()

public Plugin:myinfo = {
	name = "Autoslayer",
	author = "Breezy",
	description = "Slays the team if they are simultaneously incapped for a period of time",
	version = "1.0"
};

new bIsImmobilised[MAXPLAYERS];
new bool:g_bIsAutoslayerActive = false;

//@TODO SI clears by kill do not seem to consistently trigger the OnPlayerMobilise event hooks
public OnPluginStart() {
	//Incapacitated or pinned
	HookEvent("player_incapacitated", OnPlayerImmobilised, EventHookMode_Pre);
	HookEvent("player_ledge_grab", OnPlayerImmobilised, EventHookMode_Pre);
	HookEvent("choke_start", OnPlayerImmobilised, EventHookMode_Pre);
	HookEvent("lunge_pounce", OnPlayerImmobilised, EventHookMode_Pre);
	HookEvent("charger_pummel_start", OnPlayerImmobilised, EventHookMode_Pre);
	HookEvent("jockey_ride", OnPlayerImmobilised, EventHookMode_Pre);
	
	//Picked up, cleared from being pinned or died
	HookEvent("revive_success", OnPlayerMobilised, EventHookMode_Pre);
	HookEvent("choke_end", OnPlayerMobilised, EventHookMode_Pre);
	HookEvent("pounce_end", OnPlayerMobilised, EventHookMode_Pre);
	HookEvent("charger_pummel_end", OnPlayerMobilised, EventHookMode_Pre);
	HookEvent("jockey_ride_end", OnPlayerMobilised, EventHookMode_Pre);	
	HookEvent("player_death", OnPlayerMobilised, EventHookMode_Pre);
	
	//Resetting cache
	HookEvent("round_freeze_end", EventHook:OnRoundFreezeEnd, EventHookMode_PostNoCopy);
}

public Action:OnPlayerImmobilised(Handle:event, const String:name[], bool:dontBroadcast) {
	new iImmobilisedSurvivor;
	if (StrEqual(name, "player_incapacitated") || StrEqual(name, "player_ledge_grab")) {
		iImmobilisedSurvivor = GetClientOfUserId(GetEventInt(event, "userid"));
		if (!(iImmobilisedSurvivor)) return Plugin_Continue; // tank death fires "player_incapacitated" event
	} else { // Pinned by SI
		iImmobilisedSurvivor = GetClientOfUserId(GetEventInt(event, "victim"));
	}	
	bIsImmobilised[iImmobilisedSurvivor] = true;
			#if AS_DEBUG
				decl String:ClientName[32];
				GetClientName(iImmobilisedSurvivor, ClientName, sizeof(ClientName));
				LogMessage("\x03%s\x01: \x05%s", name, ClientName);
			#endif
	CheckTeamMobility();
	return Plugin_Continue;
}

public Action:OnPlayerMobilised(Handle:event, const String:name[], bool:dontBroadcast) {
	new iMobilisedSurvivor;
	if (StrEqual(name, "revive_success")) { // from incapped/ledge hanging
		iMobilisedSurvivor = GetClientOfUserId(GetEventInt(event, "subject"));
	} else if (StrEqual(name, "player_death")) {
		new iDeadPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
		if (!IsSurvivor(iDeadPlayer)) return Plugin_Continue;
		iMobilisedSurvivor = iDeadPlayer;
	} else { // Cleared of SI pinning them
		iMobilisedSurvivor = GetClientOfUserId(GetEventInt(event, "victim"));
		//pounce_end event is fired at unexpected times; make sure this occassion is relevant
		if (!IsValidClient(iMobilisedSurvivor)) return Plugin_Continue; 
	}
	//Check they have not been incapacited while previously immobilised
	if (!bool:GetEntProp(iMobilisedSurvivor, Prop_Send, "m_isIncapacitated", 1)) bIsImmobilised[iMobilisedSurvivor] = false;
			#if AS_DEBUG
				decl String:ClientName[32];
				GetClientName(iMobilisedSurvivor, ClientName, sizeof(ClientName));
				LogMessage("\x03%s\x01: \x05%s", name, ClientName);
			#endif
	CheckTeamMobility();
	return Plugin_Continue;
}

public CheckTeamMobility() {
	if (IsTeamImmobilised()) {
		if (!g_bIsAutoslayerActive) {
			PrintToChatAll("\x04[AS] \x03Initiating Autoslayer...");
			CreateTimer(GRACETIME, Timer_AutoslayTeam, _, TIMER_FLAG_NO_MAPCHANGE);
			g_bIsAutoslayerActive = true;
		}		
	}
}

public Action:Timer_AutoslayTeam(Handle:timer) {
	if (IsTeamImmobilised()) {
		SlaySurvivors();
		PrintToChatAll("\x04[AS] \x03Autoslayed survivors!");		
		return Plugin_Continue;
	} else {
		g_bIsAutoslayerActive = false;
		PrintToChatAll("\x04[AS] \x03...Autoslayer cancelled!");
	}
	return Plugin_Continue;
}

SlaySurvivors() {
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			ForcePlayerSuicide(client);
		}
	}
}

bool:IsTeamImmobilised() {
	//Check if there is still an upright survivor
			#if AS_DEBUG
				LogMessage("\x01Team mobility report:");
			#endif
	new bool:bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if (!bIsImmobilised[client]) {
				bIsTeamImmobilised = false;
						#if AS_DEBUG
							decl String:ClientName[32];
							GetClientName(client, ClientName, sizeof(ClientName));
							LogMessage("\x01- \x04Mobile: \x05%s", ClientName);
						#endif
			} else {
				#if AS_DEBUG
					decl String:ClientName[32];
					GetClientName(client, ClientName, sizeof(ClientName));
					LogMessage("\x01- \x04IMMOBILISED: \x05%s", ClientName);
				#endif
			}
		}
	}
			#if AS_DEBUG
				LogMessage(" ");
			#endif
	return bIsTeamImmobilised;
}

// Reset cache
public OnRoundFreezeEnd() {
	for (new client = 0; client < MaxClients; client++) {
		bIsImmobilised[client] = false;
	}
	g_bIsAutoslayerActive = false;
}

bool:IsSurvivor(client) {
	return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool:IsValidClient(client) { 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}  
