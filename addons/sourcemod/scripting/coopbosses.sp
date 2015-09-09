#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <left4downtown>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

// Bibliograph: "current" by "CanadaRox"

public Plugin:myinfo = 
{
	name = "Coop Bosses",
	author = PLUGIN_AUTHOR,
	description = "Trys to spawn one tank every map; tank may spawn later than internal percent so there is no printout in chat",
	version = PLUGIN_VERSION,
	url = ""
};

new g_iTankPercent;
new g_bHasEncounteredTank = false;
new g_bIsRoundActive = false;
new Handle:hCvarDirectorNoBosses;

public OnPluginStart() {
	hCvarDirectorNoBosses = FindConVar("director_no_bosses");
	SetConVarBool(hCvarDirectorNoBosses, true);
	
	// Event hooks
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
}

public OnPluginEnd() {
	ResetConVar(hCvarDirectorNoBosses);
}

/* Precaching witch
public OnMapStart() {	
	if (!IsModelPrecached("models/infected/witch.mdl")) PrecacheModel("models/infected/witch.mdl");
	if (!IsModelPrecached("models/infected/witch_bride.mdl")) PrecacheModel("models/infected/witch_bride.mdl");
}
*/

// Announce boss percent
public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	g_bIsRoundActive = true;
	g_iTankPercent = GetRandomInt(20, 80);
}

public OnRoundOver() {
	g_bIsRoundActive = false;
	g_bHasEncounteredTank = false;
}

// Track on every game frame whether the survivor percent has reached the boss percent
public OnGameFrame() {
	// If survivors have left saferoom
	if (g_bIsRoundActive) {
		// If they have surpassed the boss percent
		new iMaxSurvivorCompletion = GetMaxSurvivorCompletion();
		if (iMaxSurvivorCompletion > g_iTankPercent) {
			// If they have not already fought the tank
			if (!g_bHasEncounteredTank) {			
				// spawn a tank with z_spawn_old (uses director to find a suitable location ahead of survivors)				
				new flags = GetCommandFlags("z_spawn_old");
				SetCommandFlags("z_spawn_old", flags ^ FCVAR_CHEAT);
				FakeClientCommand(1, "z_spawn_old tank auto");
				SetCommandFlags("z_spawn_old", flags);
				g_bHasEncounteredTank = true;
			} 
		}
	} 
}

// Get current survivor percent
stock GetMaxSurvivorCompletion() {
	new Float:flow = 0.0;
	decl Float:tmp_flow;
	decl Float:origin[3];
	decl Address:pNavArea;
	for (new client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) &&
			L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor)
		{
			GetClientAbsOrigin(client, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null)
			{
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = MAX(flow, tmp_flow);
			}
		}
	}
	return RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
}


