#pragma semicolon 1

#define BOUNDINGBOX_INFLATION_OFFSET 3

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define WHITE 3

#define PI 3.14159265359

#include <l4d2_direct>

new Handle:hCvarEnableSpawnPositioner;
new Handle:hCvarSpawnSearchAttemptLimit;
new Handle:hCvarSpawnSearchHeight;
new Handle:hCvarSpawnProximity;

new g_AllSurvivors[MAXPLAYERS]; // who knows what crazy configs people might put together

new laserCache;

/*
 * Bibliography
 * - Epilimic's witch spawner code
 * - "Player-Teleport by Dr. HyperKiLLeR" (sm_gotoRevA.smx)
 */
 
SpawnPositioner_OnModuleStart() {
	hCvarEnableSpawnPositioner = CreateConVar( "spawnpositioner_mode", "1", "0 = disabled, 1 = enabled" );
	HookConVarChange( hCvarEnableSpawnPositioner, ConVarChanged:SpawnPositionerMode );
	hCvarSpawnSearchAttemptLimit = CreateConVar( "spawn_search_attempt_limit", "50", "Max attempts to make per SI spawn to find an acceptable location to which to relocate them" );
	hCvarSpawnSearchHeight = CreateConVar("spawn_search_height", "50", "Attempts to find a valid spawn location will move down from this height relative to a survivor");
	hCvarSpawnProximity = CreateConVar("spawn_proximity", "800", "Proximity to a survivor within which to generate spawns");
	HookEvent("player_spawn", OnPlayerSpawnPost, EventHookMode_PostNoCopy);
}

public SpawnPositionerMode() {
	if( GetConVarBool(hCvarEnableSpawnPositioner) ) {
		ResetConVar( FindConVar("z_spawn_range") ); // default value is 1500
	} else {
		SetConVarInt( FindConVar("z_spawn_range"), 750 ); // spawn SI closer as they are not being repositioned
	}
}

public OnPlayerSpawnPost(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if( GetConVarBool(hCvarEnableSpawnPositioner) && IsBotInfected(client) ) {
    	CreateTimer(0.3, Timer_PositionSI, client, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:Timer_PositionSI(Handle:timer, any:client) {
	new Float:survivorPos[3];
	new Float:rayEnd[3];
	new Float:spawnPos[3] = {-1.0, -1.0, -1.0};
	for( new i = 0; i < GetConVarInt(hCvarSpawnSearchAttemptLimit); i++ ) {
		// Generate a random position around a random survivor
		new Float:spawnSearchAngle = GetRandomFloat(0.0, 2.0 * PI);
		new lastSurvivorIndex = CacheSurvivors(); 
		new randomSurvivorIndex = GetRandomInt(0, lastSurvivorIndex);	
		new survivor = g_AllSurvivors[randomSurvivorIndex];	
		// Fire a ray at a random angle around a random survivor to a configured height and distance	
		GetClientAbsOrigin(survivor, survivorPos); 
		rayEnd[0] = survivorPos[0] + Sine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximity);
		rayEnd[1] = survivorPos[1] + Cosine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximity);
		rayEnd[2] = survivorPos[2] + GetConVarInt(hCvarSpawnSearchHeight);
		spawnPos = rayEnd;
		for( new j = 0; j < 2 * GetConVarInt(hCvarSpawnSearchHeight); j += 10 ) { // TraceRay probably a better idea here
			spawnPos[2] -= 10;
			if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, client) && GetSurvivorProximity(spawnPos) < GetConVarInt(hCvarSpawnProximity) ) {
				TeleportEntity( client, spawnPos, NULL_VECTOR, NULL_VECTOR ); 
	
					#if DEBUG_POSITIONER
						DrawBeam( survivorPos, rayEnd, VALID_MESH );
						DrawBeam( rayEnd, spawnPos, WHITE ) ;   
						SetEntityMoveType(client, MOVETYPE_NONE);
					#endif
				
				return Plugin_Handled; // reposition success
			}
		}
	}
	
	new String:clientName[32];
	GetClientName(client, clientName, sizeof(clientName));
	LogMessage("[SS] Failed to find a valid position for %s after %d attempts", clientName, GetConVarInt(hCvarSpawnSearchAttemptLimit) );  
		
	return Plugin_Handled;
}

stock bool:IsPlayerStuck(Float:pos[3], client) {
	new Float:mins[3];
	new Float:maxs[3];
	
	GetEntPropVector(client, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", maxs);
	
	// inflate the sizes just a little bit
	for( new i = 0; i < sizeof(mins); i++ ) {
	    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
	    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
	}
	
	TR_TraceHullFilter(pos, pos, mins, maxs, MASK_ALL, TraceEntityFilterPlayer, client);
	return TR_DidHit();
}  

// filter out players, since we can't get stuck on them
public bool:TraceEntityFilterPlayer(entity, contentsMask) {
    return entity <= 0 || entity > MaxClients;
}  

/***********************************************************************************************************************************************************************************

                                                                      UTILITY	
                                                                    
***********************************************************************************************************************************************************************************/
	
/** @return: the last array index of g_AllSurvivors holding a valid survivor */
stock CacheSurvivors() {
	new j = 0;
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		if( IsSurvivor(i) ) {
		    g_AllSurvivors[j] = i;
		    j++;
		}
	}
	return (j - 1);
}

stock bool:IsOnValidMesh(Float:pos[3]) {
	new Address:pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null) { 
		return true;
	} else {
		return false;
	}
}

stock DrawBeam( Float:startPos[3], Float:endPos[3], spawnResult ) {
	laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
	new Color[4][4]; 
	Color[VALID_MESH] = {0, 255, 0, 50}; // green
	Color[INVALID_MESH] = {255, 0, 0, 50}; // red
	Color[SPAWN_FAIL] = {255, 140, 0, 50}; // orange
	Color[WHITE] = {255, 255, 255, 50}; // white
	TE_SetupBeamPoints(startPos, endPos, laserCache, 0, 1, 1, 5.0, 5.0, 5.0, 4, 0.0, Color[spawnResult], 0);
	TE_SendToAll(); 
}