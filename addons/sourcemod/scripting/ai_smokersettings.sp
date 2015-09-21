#pragma semicolon 1

#define DEBUG 1

#define PLUGIN_AUTHOR "Breezy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>

new Handle:hCvarTongueDelay;
new Handle:hCvarSmokerHealth;
new Handle:hCvarChokeDamageInterrupt;
new Handle:hCvarChokeDamage;

public Plugin:myinfo = 
{
	name = "AI: Smoker Settings",
	author = PLUGIN_AUTHOR,
	description = "Adjusts AI smokers to inflict and receive damage like players",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart() {
	// Smoker health
	hCvarSmokerHealth = FindConVar("z_gas_health");
	HookConVarChange(hCvarSmokerHealth, ConVarChanged:OnSmokerHealthChanged); 
	// Damage required to kill a smoker using its tongue
	hCvarChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); // default 50
	SetCheatConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
	// Delay before smoker shoots its tongue
	hCvarTongueDelay = FindConVar("smoker_tongue_delay"); // default 1.5
	SetCheatConVarFloat(hCvarTongueDelay, 1.0);
	// Damage done by choke
	hCvarChokeDamage = FindConVar("tongue_choke_damage_amount"); // default 10
	SetCheatConVarInt(hCvarChokeDamage, 4);
}

// Update choke damage interrupt to match smoker max health
public Action:OnSmokerHealthChanged() {
	SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
}

public OnPluginEnd() {
	ResetConVar(hCvarChokeDamageInterrupt);
	ResetConVar(hCvarTongueDelay);
	ResetConVar(hCvarChokeDamage);
}

SetCheatConVarInt(Handle:hCvarHandle, value) {
	// unset cheat flag
	new cvarFlags = GetConVarFlags(hCvarHandle);
	SetConVarFlags(hCvarHandle, cvarFlags ^ FCVAR_CHEAT);
	// set new value
	SetConVarInt(hCvarHandle, value);
	// reset cheat flag
	SetConVarFlags(hCvarHandle, cvarFlags);
}

SetCheatConVarFloat(Handle:hCvarHandle, Float:value) {
	// unset cheat flag
	new cvarFlags = GetConVarFlags(hCvarHandle);
	SetConVarFlags(hCvarHandle, cvarFlags ^ FCVAR_CHEAT);
	// set new value
	SetConVarFloat(hCvarHandle, value);
	// reset cheat flag
	SetConVarFlags(hCvarHandle, cvarFlags);
}
