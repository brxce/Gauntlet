#pragma semicolon 1

#define DEBUG_SPAWNER 1

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define NONE 3

#define KICKDELAY 0.1
#define PI 3.14159265359
#define NATURAL_SI_LIMIT 2

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <l4d2_direct>
#include "includes/hardcoop_util.sp"

new Handle:hCvarSpawnSearchHeight;
new Handle:hCvarSpawnProximity;
new g_AllSurvivors[MAXPLAYERS]; // who knows what crazy configs people might put together
new laserCache;

new g_DummyForInfectedBot[MAXPLAYERS];

public Plugin:myinfo = 
{
	name = "Spawn Command",
	author = "Rurouni, Epilimic, Breezy",
	description = "Generate an SI spawn within a specified radius around survivors",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	RegConsoleCmd("sm_spawn", Cmd_Spawn, "Spawn an SI");
	hCvarSpawnSearchHeight = CreateConVar("spawn_search_height", "25", "Attempts to find a valid spawn location will move down from this height relative to a survivor");
	hCvarSpawnProximity = CreateConVar("spawn_proximity", "600", "Proximity to a survivor within which to generate spawns");
	laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
	
	HookEvent("player_connect", OnPlayerConnect, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawnPost, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeathPost, EventHookMode_PostNoCopy);
}	

/***********************************************************************************************************************************************************************************

																	CRAZY TELEPORT SPAWNS
																	
***********************************************************************************************************************************************************************************/
public Action:Cmd_Spawn( client, args ) {
	AttemptSpawnAuto( ZC_HUNTER );
	AttemptSpawnAuto( ZC_HUNTER );
}

stock AttemptSpawnAuto(ZombieClass:zombieClassNum) {
	 // Create a client if necessary to circumvent the 3 SI limit
    new iSpawnedSpecialsCount = CountSpecialInfectedBots();
    if (iSpawnedSpecialsCount >= NATURAL_SI_LIMIT) {
        new String:sBotName[32];
        Format(sBotName, sizeof(sBotName), "Dummy %s", TEAM_CLASS(zombieClassNum));
        new bot = CreateFakeClient(sBotName); 
        if (bot != 0) {
            ChangeClientTeam(bot, _:L4D2Team_Infected);
            CreateTimer(KICKDELAY, Timer_KickBot, bot, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
 	// Spawn with z_spawn_old using 'auto' parameter to let the Director find a spawn position  
    new String:zombieClassName[7];
    zombieClassName = TEAM_CLASS(zombieClassNum);
    CheatCommand("z_spawn_old", zombieClassName, "auto", true);
}

public OnPlayerSpawnPost(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    CreateTimer(0.2, Timer_MoveSI, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_MoveSI(Handle:timer, any:client) {
	new Float:survivorPos[3];
	if (IsBotInfected(client)) {   
		//SetEntityMoveType(client, MOVETYPE_NONE);
		new Float:spawnPos[3] = {-1.0, -1.0, -1.0};
		while( !IsOnValidMesh(spawnPos) ) {
			// Generate a random position around a random survivor
		new Float:spawnSearchAngle = GetRandomFloat(0.0, 2.0 * PI);
		new lastSurvivorIndex = CacheSurvivors(); 
		new randomSurvivorIndex = GetRandomInt(0, lastSurvivorIndex);	
		new survivor = g_AllSurvivors[randomSurvivorIndex];	
		// Generate at a configured height a random point close to a survivor			
		GetClientAbsOrigin(survivor, survivorPos); 
		spawnPos[0] = survivorPos[0] + Sine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximity);
		spawnPos[1] = survivorPos[1] + Cosine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximity);
		spawnPos[2] = survivorPos[2] + GetConVarInt(hCvarSpawnSearchHeight);
		}
		TeleportEntity( client, spawnPos, NULL_VECTOR, NULL_VECTOR );   
		DrawBeam(survivorPos, spawnPos, VALID_MESH);   		
	}
}

public OnPlayerDeathPost(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotInfected(client)) {
		CreateTimer(1.0, Timer_KickBot, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

/***********************************************************************************************************************************************************************************

																MANUAL SPAWN
																	
***********************************************************************************************************************************************************************************/
stock AttemptSpawnManual(ZombieClass:zombieClassNum) {
	// Generate a random position around a random survivor
	new Float:spawnSearchAngle = GetRandomFloat(0.0, 2.0 * PI);
	new lastSurvivorIndex = CacheSurvivors(); 
	new randomSurvivorIndex = GetRandomInt(0, lastSurvivorIndex);	
	new survivor = g_AllSurvivors[randomSurvivorIndex];	
	// Generate at a configured height a random point close to a survivor
	new Float:survivorPos[3];
	new Float:randomPoint[3];
	new Float:spawnPos[3];	
	GetClientAbsOrigin(survivor, survivorPos); 
	randomPoint[0] = survivorPos[0] + Sine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximity);
	randomPoint[1] = survivorPos[1] + Cosine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximity);
	randomPoint[2] = survivorPos[2] + GetConVarInt(hCvarSpawnSearchHeight);	
	// Find a point on the nav mesh below the random point 
	spawnPos = randomPoint;

	if( IsOnValidMesh(spawnPos) ) {
		new dummy;
		// Create a client if necessary to circumvent the 3 SI limit
		new iSpawnedSpecialsCount = CountSpecialInfectedBots();
		if (iSpawnedSpecialsCount >= NATURAL_SI_LIMIT) {
		    new String:sDummyName[32];
		    Format(sDummyName, sizeof(sDummyName), "Dummy %s", TEAM_CLASS(zombieClassNum));
		    dummy = CreateFakeClient(sDummyName); 
		    if (dummy != 0) {
		        ChangeClientTeam(dummy, _:L4D2Team_Infected);
		    }
		}
		new spawned = L4D2_SpawnSpecial(_:zombieClassNum, spawnPos, NULL_VECTOR); 
		if( IsValidClient(spawned) ) {
			g_DummyForInfectedBot[spawned] = dummy;
		} 
		
			#if DEBUG_SPAWNER
				if( IsBotInfected(spawned) ) {
					DrawBeam(survivorPos, spawnPos, VALID_MESH);
				} else {
					DrawBeam(survivorPos, spawnPos, SPAWN_FAIL);					
				}
			#endif
		
	} else {
	
			#if DEBUG_SPAWNER	
				DrawBeam(survivorPos, spawnPos, INVALID_MESH);				
			#endif
		
	}		
		
}

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
	Color[NONE] = {255, 255, 255, 50}; // white
	TE_SetupBeamPoints(startPos, endPos, laserCache, 0, 1, 1, 5.0, 5.0, 5.0, 4, 0.0, Color[spawnResult], 0);
	TE_SendToAll(); 
}

public Action:Timer_Slay(Handle:timer, any:client) {
	ForcePlayerSuicide(client);
}

/***********************************************************************************************************************************************************************************

                                                                            SPAWN TRACKING		
                                                                    
***********************************************************************************************************************************************************************************/

public OnPlayerConnect(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if( IsValidClient(client) ) {
    	new String:clientName[32];
    	GetClientName(client, clientName, sizeof(clientName));
    	Client_PrintToChatAll(true, "%s {B}connected", clientName);
    }
	    
}

// Tracking SI population
public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsBotInfected(client)) {   
     
	        #if DEBUG_SPAWNER
	            new String:infectedName[32];
	            GetClientName(client, infectedName, sizeof(infectedName));
	            if (StrContains(infectedName, "dummy", false) == -1) {
	                Client_PrintToChatAll(true, "- Bot %s {G}spawned", infectedName);
	            } 
	        #endif
	        
    }
}

// SI death debug printouts
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsBotInfected(client)) {

	        #if DEBUG_SPAWNER
	            new String:infectedName[32];
	            GetClientName(client, infectedName, sizeof(infectedName));
	            if (StrContains(infectedName, "dummy", false) == -1) {
	                Client_PrintToChatAll(true, "- Bot %s {O}died", infectedName);
	            } 
	        #endif
	        
    }
}

// Discount failed spawns from spawn tracking numbers
public OnPlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsBotInfected(client)) {       

             #if DEBUG_SPAWNER
	            new String:infectedName[32];
	            new String:reason[256];
	            GetClientName( client, infectedName, sizeof(infectedName) );
	            GetEventString( event, "reason", reason, sizeof(reason) );
	            if (StrContains(infectedName, "dummy", false) == -1) {
	            	Client_PrintToChatAll(true, "- Bot %s {B}disconnected{N}: %s", infectedName, reason);
	            } 
	        #endif
	             
    }
}

