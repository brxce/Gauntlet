#pragma semicolon 1

#define DEBUG
#define MAX_HEALTH 100
#define	NO_TEMP_HEALTH 0.0
#define SECONDARY_SLOT 1
#define EMPTY_SLOT -1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "includes/hardcoop_util.sp"

new Handle:hCvarLeechThreshold;
new Handle:hCvarLeechPercent;
new Handle:hCvarLeechChance;
new Handle:hCvarCommonLeechAmount;
new Handle:hCvarSurvivorRespawnHealth;

new bool:should_leech = true;

public Plugin:myinfo = 
{
	name = "Health Management",
	author = "breezy",
	description = "Providing alternative health sources to survivor team",
	version = "",
	url = ""
};

public OnPluginStart() {
	hCvarLeechThreshold = CreateConVar("leech_threshold", "50", "Below this health level (inc. temp health), survivors are able to leech");
	hCvarLeechPercent = CreateConVar("leech_percent", "0.1", "Percentage of dealt dmg leeched as health");
	hCvarLeechChance = CreateConVar("leech_chance", "0.5", "Percentage chance of leeching occurring"); // not in use
	hCvarCommonLeechAmount = CreateConVar("leech_common_ammount", "1", "Health leeched, pending 'leech_chance', from killing a common");
	HookEvent("revive_success", OnReviveSuccess, EventHookMode_PostNoCopy);
	HookEvent("infected_death", Event_OnCommonKilled);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	RegConsoleCmd("sm_leech", Cmd_ToggleLeech, "Toggle health leeching");
	// Reset health upon respawning
	hCvarSurvivorRespawnHealth = FindConVar("z_survivor_respawn_health");
	SetConVarInt(hCvarSurvivorRespawnHealth, 100);
	HookConVarChange(hCvarSurvivorRespawnHealth, ConVarChanged:OnRespawnHealthChanged);
	HookEvent("map_transition", EventHook:ResetSurvivors, EventHookMode_PostNoCopy); // finishing a map
	HookEvent("round_freeze_end", EventHook:ResetSurvivors, EventHookMode_PostNoCopy); // restarting map after a wipe 
}
	
public OnPluginEnd() {
	ResetConVar(hCvarSurvivorRespawnHealth);
}

/***********************************************************************************************************************************************************************************

                                                 						EVENT HOOKS
                                                                    
***********************************************************************************************************************************************************************************/

public OnRespawnHealthChanged() {
	SetConVarInt(hCvarSurvivorRespawnHealth, 100);
}

 //restoring health of survivors respawning with 50 health from a death in the previous map
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	RestoreHealth();
	DistributePills();
}


// Leech health from special infected
public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victimId = GetEventInt(event, "userid");
    new victim = GetClientOfUserId(victimId);
    
    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    
    new damageDone = GetEventInt(event, "dmg_health");
    
    // no world damage or flukes or whatevs, no bot attackers, no infected-to-infected damage
    if (should_leech && victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker))
    {
        if (GetClientTeam(attacker) == _:L4D2Team_Survivor && GetClientTeam(victim) == _:L4D2Team_Infected)
        {
           new currentHealth = GetPermHealth(attacker);
           new leechedHealth = RoundToFloor(FloatMul(GetConVarFloat(hCvarLeechPercent), float(damageDone)));
           new newHealth = currentHealth + leechedHealth;
           if ( currentHealth < GetConVarInt(hCvarLeechThreshold) && newHealth < MAX_HEALTH )
           {
           		SetEntityHealth(attacker, newHealth);
           }
           PrintToChatAll("%d damage dealt to SI %d. Restoring %d health", damageDone, victim, leechedHealth);
        }
    }
}

// Leech health from common infected
public Action:Event_OnCommonKilled(Handle:event, const String:name[], bool:dontBroadcast) 
{ 
	new attackerId = GetEventInt(event, "attacker");
	new attacker = GetClientOfUserId(attackerId);
	
	if (attackerId && IsSurvivor(attacker) && IsPlayerAlive(attacker))
	{
		new currentHealth = GetPermHealth(attacker);
		new newHealth = currentHealth + GetConVarInt(hCvarCommonLeechAmount);
		if ( currentHealth < GetConVarInt(hCvarLeechThreshold) && newHealth < MAX_HEALTH ) {
			SetEntityHealth(attacker, newHealth);
		} 		
	} 
}

public Action:OnReviveSuccess( Handle:event, const String:eventName[], bool:dontBroadcast ) {
	new revived = GetClientOfUserId( GetEventInt(event, "subject") );
	if( IsSurvivor(revived) && IsPlayerAlive(revived) ) {
		GiveItem( revived, "pain_pills" );
	}
}

/***********************************************************************************************************************************************************************************

                                                 						UTILITY & CMDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_ToggleLeech(client, args) {
	if ( IsSurvivor(client) && IsPlayerAlive(client) ) { 
		should_leech = !should_leech;
		if ( should_leech ) {
			PrintToChatAll("Health leeching enabled.");
		} else {
			PrintToChatAll("Health leeching disabled.");
		}
	}
}

public RestoreHealth() {
	for (new client = 1; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
			GiveItem(client, "health");
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", NO_TEMP_HEALTH);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
		}
	}
}

public ResetSurvivors() {
	RestoreHealth();
	ResetInventory();
}

public ResetInventory() {
	for (new client = 0; client <= MaxClients; client++) {
		if ( IsSurvivor(client) ) {
			// Reset survivor inventories so they only hold dual pistols
			for (new i = 0; i < 5; i++) { 
				DeleteInventoryItem(client, i);		
			}	
			GiveItem(client, "pistol");
		}
	}		
}

GetPermHealth(client) {
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

public DistributePills() {
	// iterate though all clients
	for (new client = 1; client <= MaxClients; client++) { 
		//check player is a survivor
		if (IsSurvivor(client)) {
			// check pills slot is empty
			if (GetPlayerWeaponSlot(client, 5) == EMPTY_SLOT) { 
				GiveItem(client, "pain_pills"); 
			}								
		}
	}
}

GiveItem(client, String:itemName[]) {
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", itemName);
	SetCommandFlags("give", flags);
}

DeleteInventoryItem(client, slot) {
	new item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) {
		RemovePlayerItem(client, item);
	}	
}

bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}