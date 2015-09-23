#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>

#define ZC_JOCKEY 5 //zombie class
#define INFECTED_TEAM 3

// Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"

public Plugin:myinfo = {
	name = "AI: Jockey Behaviour",
	author = "Breezy",
	description = "Force AI jockeys to hop while approaching survivors and applies stumble to jockey lands",
	version = "1.0"
};

new Handle:hCvarJockeyLeapRange; // vanilla cvar

new Handle:hCvarHopActivationProximity; // custom cvar
new g_iHopActivationProximity;

new bool:bDoNormalJump[MAXPLAYERS]; // used to alternate pounces and normal jumps
new bool:bHasBeenShoved[MAXPLAYERS]; // shoved jockeys will stop hopping

new Handle:hCvarJockeyStumbleRadius; // stumble radius of jockey ride

public OnPluginStart() {
	// CONSOLE VARIABLES
	// jockeys will move to attack survivors within this range
	hCvarJockeyLeapRange = FindConVar("z_jockey_leap_range");
	SetConVarInt(hCvarJockeyLeapRange, 1000); 
	HookConVarChange(hCvarJockeyLeapRange, OnCvarChange);
	
	// proximity when plugin will start forcing jockeys to hop
	hCvarHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "How close a jockey will approach before it starts hopping");
	g_iHopActivationProximity = GetConVarInt(hCvarHopActivationProximity);
	HookConVarChange(hCvarHopActivationProximity, OnCvarChange);
	
	// EVENT HOOKS:
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre); 
	HookEvent("player_shoved", OnPlayerShoved, EventHookMode_Pre);
	HookEvent("player_jump", OnPlayerJump, EventHookMode_Pre);
	
	// Stumble
	HookEvent("jockey_ride", OnJockeyRide, EventHookMode_Pre); 
	hCvarJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50", "Stumble radius of a jockey landing a ride");
}

//Update convars if they have been changed midgame
public OnCvarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_iHopActivationProximity = GetConVarInt(hCvarHopActivationProximity);		
}


/***********************************************************************************************************************************************************************************

																		JOCKEY STUMBLE

***********************************************************************************************************************************************************************************/

public OnJockeyRide(Handle:event, const String:name[], bool:dontBroadcast) {	
	if (IsCoop()) {
		new attacker = GetClientOfUserId(GetEventInt(event, "userid"));  
		new victim = GetClientOfUserId(GetEventInt(event, "victim"));  
		if(attacker > 0 && victim > 0) {
			StumbleBystanders(attacker, victim);
		} 
	}	
}

StumbleBystanders(attacker, victim) {
	decl Float:attackerPos[3];
	decl Float:pos[3];
	decl Float:dir[3];
	GetClientAbsOrigin(attacker, attackerPos);
	new radius = GetConVarInt(hCvarJockeyStumbleRadius);
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && IsPlayerAlive(i) && i!=victim && i!=attacker) {
			GetClientAbsOrigin(i, pos);
			SubtractVectors(pos, attackerPos, dir);
			if(GetVectorLength(dir) <= float(radius)) {
				NormalizeVector(dir, dir); 
				L4D_StaggerPlayer(i, attacker, dir);
			}
		}
	}
}

/***********************************************************************************************************************************************************************************

																	DEACTIVATING HOP DURING SHOVES

***********************************************************************************************************************************************************************************/

// Enable hopping on spawned jockeys
public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotJockey(client)) {
		bHasBeenShoved[client] = false;
	}	
}

// Disable hopping when shoved
public Action:OnPlayerShoved(Handle:event, String:name[], bool:dontBroadcast) {
	new shovedPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotJockey(shovedPlayer)) {
		bHasBeenShoved[shovedPlayer] = true;
	}
}

// Re-enabling hopping when shoved jockey leaps again naturally
public Action:OnPlayerJump(Handle:event, String:name[], bool:dontBroadcast) {
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotJockey(player)) {
		bHasBeenShoved[player] = false;
	}
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	// Proceed for jockey bots
	if(IsBotJockey(client)) {
		new jockey = client;			
		new iSurvivorsProximity = GetSurvivorProximity(jockey);
		new bool:bHasLOS = bool:GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats"); // line of sight to any survivor
		
		// Start hopping if within range	
		if ( bHasLOS && (iSurvivorsProximity < g_iHopActivationProximity) ){
			
			// Force them to hop 
			new flags = GetEntityFlags(jockey);
			buttons |= IN_FORWARD;
			
			// Alternate normal jump and pounces if jockey has not been shoved
			if( !bHasBeenShoved[client] && (flags & FL_ONGROUND)) {
				if (bDoNormalJump[jockey]) {
					buttons |= IN_JUMP; // normal jump
				} else {
					buttons |= IN_ATTACK; // pounce leap
				}
				bDoNormalJump[jockey] = !bDoNormalJump[jockey];
			} 
			
			else { // midair, release buttons
				buttons &= ~IN_JUMP;
				buttons &= ~IN_ATTACK;
			}		
			
		} 
	}
	return Plugin_Changed;
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

bool:IsBotJockey(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	
	// Check if player is on the infected team, a jockey, and a bot
	new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (GetClientTeam(client) == INFECTED_TEAM) {
		if (zombieClass == ZC_JOCKEY) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}
  
GetSurvivorProximity(referenceClient) {
	// Get the reference's position for comparison against survivors' position
	new Float:referencePosition[3];
	GetEntPropVector(referenceClient, Prop_Send, "m_vecOrigin", referencePosition);
	
	// Find the proximity of the closest survivor
	new iClosestAbsDisplacement = -1; // closest absolute displacement
	for (new client = 1; client < MaxClients; client++) {
		if (IsValidClient(client) && IsSurvivor(client)) {				
			new Float:survivorPosition[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", survivorPosition);
			new iAbsDisplacement = RoundToNearest(GetVectorDistance(referencePosition, survivorPosition));
			
			// Get displacement between this survivor and the reference
			if (iClosestAbsDisplacement == -1) {
				iClosestAbsDisplacement = iAbsDisplacement; // Start with the absolute displacement to the first survivor found
			} else if (iAbsDisplacement < iClosestAbsDisplacement) { // this is the closest survivor so far
				iClosestAbsDisplacement = iAbsDisplacement;
			}	
		}
	}
	// return the proximity of the closest survivor
	return iClosestAbsDisplacement;
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}

bool:IsCoop() {
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	return (!StrEqual(GameName, "versus", false) && !StrEqual(GameName, "scavenge", false));
}