#pragma semicolon 1
#define DEBUG_SPAWNER 0

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define NONE 3
#define PI 3.14159265359
/** 
 * Spawning above this number of SI requires the creation of temporary 'dummy' clients i.e. through usage of CreateFakeClient()
 * However these fake clients must be kicked straight afterwards, otherwise the extra SI spawned this way do not move or attack
*/
#define NATURAL_SI_LIMIT 2

#include <l4d2_direct>

// 'z_spawn_old' spawner
new Handle:hCvarSpawnAttemptInterval; // Spawn attempt interval
new g_ClassSpawnVolume[9]; // population of each SI class; '8' for tank is the highest index
// 'L4D2_SpawnSpecial' spawner
new Handle:hCvarSpawnSearchHeight;
new Handle:hCvarSpawnProximity;
new g_AllSurvivors[MAXPLAYERS]; // who knows what crazy configs people might put together
new laserCache;

public Spawner_OnModuleStart() {
	// Spawn attempt interval (for both spawner functions)
	hCvarSpawnAttemptInterval = CreateConVar(  
		"siws_spawn_attempt_interval",
		"0.5",
		"Interval between SI spawn attempts. Increase interval to reduce server load",
		FCVAR_NONE, true, 0.5, false
	);	
	// 'L4D2_SpawnSpecial' spawner
	hCvarSpawnSearchHeight = CreateConVar("spawn_search_height", "10", "Attempts to find a valid spawn location will move down from this height relative to a survivor");
	hCvarSpawnProximity = CreateConVar("spawn_proximity", "600", "Proximity to a survivor within which to generate spawns");
	// Monitoring spawns
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
}

/***********************************************************************************************************************************************************************************

                                                                        		WAVE SPAWNING	
                                                                    
***********************************************************************************************************************************************************************************/

// Initiate spawning for each SI class
SpawnWave() {
    
    #if DEBUG_SPAWNER
        new infectedBotCount = CountSpecialInfectedBots();
        Client_PrintToChatAll(true, "{O}SPAWNING WAVE {N}({G}%i {N}SI carryover)", infectedBotCount);
    #endif
    
    // reset cache
    for (new i = 0; i < 8; i++) {
        g_ClassSpawnVolume[i] = 0;
    }
    // Jockey and Charger meatshields first
    SpawnClassPopulation(ZC_JOCKEY);
    SpawnClassPopulation(ZC_CHARGER);
    SpawnClassPopulation(ZC_SPITTER);
    SpawnClassPopulation(ZC_SMOKER);
    SpawnClassPopulation(ZC_HUNTER);
    SpawnClassPopulation(ZC_BOOMER);
}

// Populate an SI class to its limit
SpawnClassPopulation(ZombieClass:targetClass) {
    CreateTimer( GetConVarFloat(hCvarSpawnAttemptInterval), Timer_SpawnSpecialInfected, any:targetClass, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_SpawnSpecialInfected(Handle:timer, any:targetClass) {
    // Make sure we are not spawning duplicate SI due to early deaths before full wave has spawned
    new iClassSpawnVolume = g_ClassSpawnVolume[_:targetClass];
    new iClassLimit = GetClassLimit(targetClass);
    new bool:hasSpawnedClassPopulation = (iClassSpawnVolume >= iClassLimit ? true:false);
    
    // Attempt spawn if needed
    if( IsClassLimitReached(targetClass) || hasSpawnedClassPopulation ) { // Limit for this SI class reached
        return Plugin_Stop;
    } else if( IsMaxSpecialInfectedLimitReached() ) { // Limit for total SI reached
    	return Plugin_Stop;
    	
			#if DEBUG            
				Client_PrintToChatAll(true, "{O}Server SI limit reached", TEAM_CLASS(targetClass));  
			#endif
			
    } else {  // No limits reached; spawn this SI
        AttemptSpawnAuto(targetClass);
        return Plugin_Continue;
    }

}

/***********************************************************************************************************************************************************************************

                                                            		'Z_SPAWN_OLD' SPAWNING	
                                                                    
***********************************************************************************************************************************************************************************/

stock AttemptSpawnAuto(ZombieClass:zombieClassNum) {
	 // Create a client if necessary to circumvent the 3 SI limit
    new iSpawnedSpecialsCount = CountSpecialInfectedBots();
    if (iSpawnedSpecialsCount >= NATURAL_SI_LIMIT) {
        new String:sBotName[32];
        Format(sBotName, sizeof(sBotName), "%s dummy", TEAM_CLASS(zombieClassNum));
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

/***********************************************************************************************************************************************************************************

                                                        		'L4D2_SPAWNSPECIAL'	SPAWNING
                                                                    
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
		// Create a client if necessary to circumvent the 3 SI limit
		new iSpawnedSpecialsCount = CountSpecialInfectedBots();
		if (iSpawnedSpecialsCount >= NATURAL_SI_LIMIT) {
		    new String:sBotName[32];
		    Format(sBotName, sizeof(sBotName), "%s dummy", TEAM_CLASS(zombieClassNum));
		    new bot = CreateFakeClient(sBotName); 
		    if (bot != 0) {
		        ChangeClientTeam(bot, _:L4D2Team_Infected);
		        CreateTimer(KICKDELAY, Timer_KickBot, bot, TIMER_FLAG_NO_MAPCHANGE);
		    }
		}
		new spawned = L4D2_SpawnSpecial(_:zombieClassNum, spawnPos, NULL_VECTOR); 
		
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

/*
 * @return the last array index of g_AllSurvivors holding a valid survivor
*/
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

/***********************************************************************************************************************************************************************************

                                                                            SPAWN TRACKING		
                                                                    
***********************************************************************************************************************************************************************************/

// Tracking SI population
public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsBotInfected(client)) {
        new infectedClass = GetEntProp(client, Prop_Send, "m_zombieClass");
        if( infectedClass > 0 && infectedClass < _:ZC_WITCH )g_ClassSpawnVolume[infectedClass]++;       
        
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
        new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
        if ( (zClass > 0) && (zClass < 9) ) {
            --g_ClassSpawnVolume[zClass];
            
             #if DEBUG_SPAWNER
	            new String:infectedName[32];
	            GetClientName(client, infectedName, sizeof(infectedName));
	            if (StrContains(infectedName, "dummy", false) == -1) {
	            	Client_PrintToChatAll(true, "- Bot %s {B}disconnected", infectedName);
	            } 
	        #endif
	        
        }       
    }
}