#pragma semicolon 1
#include <sourcemod>
#define ZC_CHARGER 6 //zombie class
#define INFECTED_TEAM 3

public Plugin:myinfo = {
	name = "AI: Smarter Chargers",
	author = "Breezy",
	description = "Force AI chargers to get close to survivors before charging",
	version = "1.0"
};

new Handle:hCvarChargeInterval;
// custom convar
new Handle:hCvarChargeProximity;
new g_iChargeProximity;
// manually track charge cooldown
new canCharge[MAXPLAYERS]; 
new onCooldown[MAXPLAYERS];

public OnPluginStart() {
	// "z_charge_interval"
	hCvarChargeInterval = FindConVar("z_charge_interval");
	HookConVarChange(hCvarChargeInterval, OnCvarChange);
	// "ai_charge_proximity"
	hCvarChargeProximity = CreateConVar("ai_charge_proximity", "250", "How close a charger will approach before charging");
	g_iChargeProximity = GetConVarInt(hCvarChargeProximity);
	HookConVarChange(hCvarChargeProximity, OnCvarChange);
	
	// Allow charging on newly spawned chargers
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
}

public Action:OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isBotCharger(client)) {
		canCharge[client] = true;
	}
	return Plugin_Continue;
}

//Update convars if they have been changed midgame
public OnCvarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if (!StrEqual(oldValue, newValue)) g_iChargeProximity = GetConVarInt(hCvarChargeProximity);		
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	// Proceed for charger bots
	if(isBotCharger(client)) {
		new charger = client;
		// Check how close they are to the survivors
		new iClosestSurvivor = GetClosestSurvivor(charger);
		new Float:chargerPosition[3];
		new Float:survivorPosition[3];
		GetEntPropVector(charger, Prop_Send, "m_vecOrigin", chargerPosition);
		GetEntPropVector(iClosestSurvivor, Prop_Send, "m_vecOrigin", survivorPosition);
		new iProximity = RoundToNearest(GetVectorDistance(chargerPosition, survivorPosition));
		// allow charge if close enough to survivors
		if (iProximity < g_iChargeProximity) {
			// Check if ability is off cooldown
			if (canCharge[charger]) {
				SetChargeCooldown(charger, 0.0);
				canCharge[charger] = false;
				// Start the cooldown timer if it has not already been started
				if (!onCooldown[charger]) {
					new Float:fChargeInterval = float(GetConVarInt(hCvarChargeInterval));
					CreateTimer(fChargeInterval, Timer_ChargeInterval, any:charger, TIMER_FLAG_NO_MAPCHANGE);
					onCooldown[charger] = true;
				}				
			}
		} else {
			SetChargeCooldown(charger, 12.0); // keep charge on cooldown
		}
	}
	return Plugin_Changed;
}

SetChargeCooldown(client, Float:time) {
	if (isBotCharger(client)) {
		new ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
		if (ability > 0) {
			SetEntPropFloat(ability, Prop_Send, "m_duration", time);
			SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + time);
		}
	}
}

public Action:Timer_ChargeInterval(Handle:timer, any:charger) {
	onCooldown[charger] = false;
	canCharge[charger] = true;
}

bool:isBotCharger(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a jockey, and a bot
	new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (GetClientTeam(client) == INFECTED_TEAM) {
		if (zombieClass == ZC_CHARGER) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}
  
GetClosestSurvivor(me) {
	// Get the reference's position
	new Float:myPosition[3];
	GetEntPropVector(me, Prop_Send, "m_vecOrigin", myPosition);
	// Find the closest survivorPosition
	new iClosestSurvivor = -1;
	new iClosestAbsDisplacement = -1; // closest absolute displacement
	for (new client = 1; client < MaxClients; client++) {
		if (IsValidClient(client) && IsSurvivor(client)) {
			// Get displacement between this survivor and the reference
			new Float:survivorPosition[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", survivorPosition);
			new iAbsDisplacement = RoundToNearest(GetVectorDistance(myPosition, survivorPosition));
			// Start with the absolute displacement to the first survivor found:
			if (iClosestAbsDisplacement == -1) {
				iClosestSurvivor = client;
				iClosestAbsDisplacement = iAbsDisplacement;
			} else if (iAbsDisplacement < iClosestAbsDisplacement) { // closest survivor so far
				iClosestSurvivor = client;
				iClosestAbsDisplacement = iAbsDisplacement;
			}			
		}
	}
	return iClosestSurvivor;
}

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}