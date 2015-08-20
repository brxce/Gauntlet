#pragma semicolon 1
#define AS_DEBUG 1
#define GRACETIME 6.0
#include <sourcemod>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

public Plugin:myinfo = {
	name = "Autoslayer",
	author = "Breezy",
	description = "Slays the team if they are simultaneously incapped for a period of time",
	version = "1.0"
};

new bIsImmobilised[MAXPLAYERS];

//@TODO: on
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
}

public Action:OnPlayerImmobilised(Handle:event, const String:name[], bool:dontBroadcast) {
	new iImmobilisedSurvivor;
	if (StrEqual(name, "player_incapacitated") || StrEqual(name, "player_ledge_grab")) {
		iImmobilisedSurvivor = GetClientOfUserId(GetEventInt(event, "userid"));
	} else { // Pinned by SI
		iImmobilisedSurvivor = GetClientOfUserId(GetEventInt(event, "victim"));
	}	
	bIsImmobilised[iImmobilisedSurvivor] = true;
			#if AS_DEBUG
				decl String:ClientName[32];
				GetClientName(iImmobilisedSurvivor, ClientName, sizeof(ClientName));
				PrintToChatAll("\x04%s\x01: \x05%s", name, ClientName);
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
		if (!IsValidClient(iDeadPlayer) && IsSurvivor(iDeadPlayer)) return Plugin_Handled;
		iMobilisedSurvivor = iDeadPlayer;
		CheckTeamMobility();
	} else { // Cleared of SI pinning them
		iMobilisedSurvivor = GetClientOfUserId(GetEventInt(event, "victim"));
		if (!IsValidClient(iMobilisedSurvivor)) return Plugin_Handled; //pounce_end gets called when SI die from anything...
	}
	bIsImmobilised[iMobilisedSurvivor] = false;
			#if AS_DEBUG
				decl String:ClientName[32];
				GetClientName(iMobilisedSurvivor, ClientName, sizeof(ClientName));
				PrintToChatAll("\x04%s\x01: \x05%s", name, ClientName);
			#endif
	return Plugin_Continue;
}

public CheckTeamMobility() {
	if (IsTeamImmobilised()) {
				#if AS_DEBUG
					PrintToChatAll("\x03Initiating AUTOSLAYER...");
				#endif
		CreateTimer(GRACETIME, Timer_AutoslayTeam, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

bool:IsTeamImmobilised() {
	//Check if there is still an upright survivor
			#if AS_DEBUG
				PrintToChatAll("\x03Team mobility report:");
			#endif
	new bool:bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if (!bIsImmobilised[client]) {
				bIsTeamImmobilised = false;
				//break;
						#if AS_DEBUG
							decl String:ClientName[32];
							GetClientName(client, ClientName, sizeof(ClientName));
							PrintToChatAll("\x01- \x04Mobile: \x05%s", ClientName);
						#endif
			} else {
				#if AS_DEBUG
					decl String:ClientName[32];
					GetClientName(client, ClientName, sizeof(ClientName));
					PrintToChatAll("\x01- \x04IMMOBILISED: \x05%s", ClientName);
				#endif
			}
		}
	}
	return bIsTeamImmobilised;
}
public Action:Timer_AutoslayTeam(Handle:timer) {
	if (IsTeamImmobilised()) {
				#if AS_DEBUG
					PrintToChatAll("\x03AUTOSLAYING TEAM!");
				#endif
		SlaySurvivors();
		return Plugin_Continue;
	}
	#if AS_DEBUG
		PrintToChatAll("\x03AUTOSLAY cancelled!");
	#endif
	return Plugin_Continue;
}

SlaySurvivors() {
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			ForcePlayerSuicide(client);
		}
	}
}

stock bool:IsValidClient(client, bool:nobots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
    {
        return false; 
    }
    return IsClientInGame(client); 
}  
