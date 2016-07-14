#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>

#define DEBUG 0

#define INFECTED_TEAM 3
#define ZC_HUNTER 3
#define POSITIVE 0
#define NEGATIVE 1
#define X 0
#define Y 1
#define Z 2
#define STRAIGHT_POUNCE_PROXIMITY 100

public Plugin:myinfo = {
	name = "AI: Hunter Pouncing",
	author = "Breezy, High Cookie, Standalone, Newteee",
	description = "Modifies AI hunter lunge patterns",
	version = "1.0"
};

// Vanilla Cvars
new Handle:hCvarHunterCommittedAttackRange;
new Handle:hCvarHunterPounceReadyRange;
new Handle:hCvarHunterLeapAwayGiveUpRange; 
new Handle:hCvarHunterPounceMaxLoftAngle; 
new Handle:hCvarLungeInterval; 

new Handle:hCvarPounceAngleMean;
new Handle:hCvarPounceAngleStd; // standard deviation
// Distance at which hunter begins pouncing fast
new Handle:hCvarFastPounceProximity; 
new g_iFastPounceProximity;

new bool:bHasQueuedLunge[MAXPLAYERS];
new bool:bCanLunge[MAXPLAYERS];
new bool:bHasBeenShoved[MAXPLAYERS];

public OnPluginStart() {
	// CONSOLE VARIABLES:		
	hCvarHunterCommittedAttackRange = FindConVar("hunter_committed_attack_range"); // range at which hunter is committed to attack	
	hCvarHunterPounceReadyRange = FindConVar("hunter_pounce_ready_range"); // range at which hunter prepares pounce	
	hCvarHunterLeapAwayGiveUpRange = FindConVar("hunter_leap_away_give_up_range"); // range at which shooting a non-committed hunter will cause it to leap away	
	hCvarLungeInterval = FindConVar("z_lunge_interval"); // cooldown on lunges
	hCvarHunterPounceMaxLoftAngle = FindConVar("hunter_pounce_max_loft_angle"); // maximum vertical angle hunters can pounce
	
	// proximity to nearest survivor when plugin starts to force hunters to lunge ASAP
	hCvarFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "1000", "At what distance to start pouncing fast");
	HookConVarChange(hCvarFastPounceProximity, OnConVarChange);
	g_iFastPounceProximity = GetConVarInt(hCvarFastPounceProximity);
	
	// Pounce angle
	hCvarPounceAngleMean = CreateConVar( "ai_pounce_angle_mean", "20", "Mean angle produced by Gaussian RNG" );
	hCvarPounceAngleStd = CreateConVar( "ai_pounce_angle_std", "30", "One standard deviation from mean as produced by Gaussian RNG" );
	
	// EVENT HOOKS:
	HookEvent("player_spawn", InitialiseSpawnedHunters, EventHookMode_Pre); // Allow fast pouncing on newly spawned hunters
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre); // Zig zag pouncing
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
	SetAggressiveHunterCvars();
}

public Action:InitialiseSpawnedHunters(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotHunter(client)) {
		new botHunter = client;
		bHasQueuedLunge[botHunter] = false;
		bCanLunge[botHunter] = true;
		bHasBeenShoved[botHunter] = false;
	}
}

// Update internally when a hooked cvar changes
public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_iFastPounceProximity = GetConVarInt(hCvarFastPounceProximity);
}

public OnPluginEnd() {
	ResetHunterCvars();
}

SetAggressiveHunterCvars() {
	SetCheatConVarInt(hCvarHunterCommittedAttackRange, 10000);
	SetCheatConVarInt(hCvarHunterPounceReadyRange, 500);
	SetCheatConVarInt(hCvarHunterLeapAwayGiveUpRange, 0); 
	SetCheatConVarInt(hCvarHunterPounceMaxLoftAngle, 0);
}

ResetHunterCvars() {
	ResetConVar(hCvarHunterCommittedAttackRange);
	ResetConVar(hCvarHunterPounceReadyRange);
	ResetConVar(hCvarHunterLeapAwayGiveUpRange);
	ResetConVar(hCvarHunterPounceMaxLoftAngle);
}

/***********************************************************************************************************************************************************************************

																	POUNCING AT AN ANGLE TO SURVIVORS

***********************************************************************************************************************************************************************************/

// Detect and alter bot hunter pounces
public Action:OnAbilityUse(Handle:event, String:name[], bool:dontBroadcast) {
	new String:abilityName[32];
	GetEventString(event, "ability", abilityName, sizeof(abilityName));
	if (StrEqual(abilityName, "ability_lunge")) { 
		new hunter = GetClientOfUserId(GetEventInt(event, "userid"));
		if (IsBotHunter(hunter)) {		
			bHasBeenShoved[hunter] = false;
			
			// Get the hunter's lunge entity
			new entLunge = GetEntPropEnt(hunter, Prop_Send, "m_customAbility");	
			
			// get the vector from the lunge entity
			new Float:lungeVector[3];
			GetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", lungeVector);
			
			// if survivor is not too close, set a new vector that's angled slightly to the original
			if (GetSurvivorProximity(hunter) > STRAIGHT_POUNCE_PROXIMITY) {						
				AngleLunge( entLunge, GaussianRNG() );
				LimitLungeVerticality( entLunge, 7.5 );
				return Plugin_Changed;
			}			
		}		
	}
	return Plugin_Continue;
}

// Lunge modification
AngleLunge( lungeEntity, Float:turnAngle ) {	
	// Get the original lunge's vector
	new Float:lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	new Float:x = lungeVector[X];
	new Float:y = lungeVector[Y];
	new Float:z = lungeVector[Z];
    
    // Create a new vector of the desired angle from the original
	turnAngle = DegToRad(turnAngle); // convert angle to radian form
	new Float:forcedLunge[3];
	forcedLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle); 
	forcedLunge[Y] = x * Sine(turnAngle)   + y * Cosine(turnAngle);
	forcedLunge[Z] = z;
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", forcedLunge);
}

// Stop pounces being too high
LimitLungeVerticality( lungeEntity, Float:vertAngle ) {
	// Get the original lunge's vector
	new Float:lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	new Float:x = lungeVector[X];
	new Float:y = lungeVector[Y];
	new Float:z = lungeVector[Z];
	
	vertAngle = DegToRad(vertAngle);	
	new Float:flatLunge[3];
	// First rotation
	flatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	flatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	// Second rotation
	flatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	flatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", flatLunge);
}


/* 
	Thanks to Newteee:
	Function to generate Gaussian Random Number with a specified mean and std
	Uses Polar Form of the Box-Muller transformation
*/
stock Float:GaussianRNG() {	 
	// mean and std (set here)
	new Float:mean = float( GetConVarInt(hCvarPounceAngleMean) );
	new Float:std = float( GetConVarInt(hCvarPounceAngleStd) );
	
	// Randomising positive/negative
	new Float:chanceToken = GetRandomFloat( 0.0, 1.0 );
	new signBit;	
	if( chanceToken >= 0.5 ) {
		signBit = POSITIVE;
	} else {
		signBit = NEGATIVE;
	}	   
	
	new Float:x1;
	new Float:x2;
	new Float:w;
	// Box-Muller algorithm
	do {
	    // Generate random number
	    new Float:random1 = GetRandomFloat( 0.0, 1.0 );	// Random number between 0 and 1
	    new Float:random2 = GetRandomFloat( 0.0, 1.0 );	// Random number between 0 and 1
	 
	    x1 = FloatMul(2.0, random1) - 1.0;
	    x2 = FloatMul(2.0, random2) - 1.0;
	    w = FloatMul(x1, x1) + FloatMul(x2, x2);
	 
	} while( w >= 1.0 );	 
	static Float:e = 2.71828;
	w = SquareRoot( FloatMul( -2.0, FloatDiv( Logarithm(w, e), w ) )  ); 

	// Random normal variable
	new Float:y1 = FloatMul(x1, w);
	new Float:y2 = FloatMul(x2, w);
	 
	// Random gaussian variable with std and mean
	new Float:z1 = FloatMul(y1, std) + mean;
	new Float:z2 = FloatMul(y2, std) - mean;
	
	#if DEBUG	
		if( signBit == NEGATIVE )PrintToChatAll("Angle: %f", z1);
		else PrintToChatAll("Angle: %f", z2);
	#endif
	
	// Output z1 or z2 depending on sign
	if( signBit == NEGATIVE )return z1;
	else return z2;
}

/***********************************************************************************************************************************************************************************

																		FAST POUNCING

***********************************************************************************************************************************************************************************/

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	//Proceed if this player is a hunter
	if(IsBotHunter(client)) {
		new hunter = client;		
		if (!bHasBeenShoved[hunter]) {
			new flags = GetEntityFlags(hunter);
			//Proceed if the hunter is in a position to pounce
			if( (flags & FL_DUCKING) && (flags & FL_ONGROUND) ) {				
				new iSurvivorsProximity = GetSurvivorProximity(hunter);
				new bool:bHasLOS = bool:GetEntProp(hunter, Prop_Send, "m_hasVisibleThreats"); // Line of sight to survivors
				
				// Start fast pouncing if close enough to survivors
				if (bHasLOS && (iSurvivorsProximity < g_iFastPounceProximity) ) {
					buttons &= ~IN_ATTACK; // release attack button; precautionary
					
					// Queue a pounce/lunge
					if (!bHasQueuedLunge[hunter]) { // check lunge interval timer has not already been initiated
						bCanLunge[hunter] = false;
						bHasQueuedLunge[hunter] = true; // block duplicate lunge interval timers
						CreateTimer(GetConVarFloat(hCvarLungeInterval), Timer_LungeInterval, any:hunter, TIMER_FLAG_NO_MAPCHANGE);
					} else if (bCanLunge[hunter]) { // end of lunge interval; lunge!
						buttons |= IN_ATTACK;
						bHasQueuedLunge[hunter] = false; // unblock lunge interval timer
					} // else lunge queue is being processed
				}				
			}
		}		
	}
	return Plugin_Changed;
}

// After the given interval, hunter is allowed to pounce/lunge
public Action:Timer_LungeInterval(Handle:timer, any:client) {
	bCanLunge[client] = true;
}

// Disable fast pouncing when shoved
public Action:OnPlayerShoved(Handle:event, String:name[], bool:dontBroadcast) {
	new shovedPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotHunter(shovedPlayer)) {
		bHasBeenShoved[shovedPlayer] = true;
	}
}

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/

bool:IsBotHunter(client) {
	if (!IsValidClient(client)) return false; 	// Check the input is valid
	if (GetClientTeam(client) == INFECTED_TEAM) { 	// Check if player is on the infected team, a hunter, and a bot
		new zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == ZC_HUNTER) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}

GetSurvivorProximity(referenceClient) {
	// Get the reference's position
	new Float:referencePosition[3];
	GetEntPropVector(referenceClient, Prop_Send, "m_vecOrigin", referencePosition);
	// Find the proximity of the closest survivor
	new iClosestAbsDisplacement = -1; // closest absolute displacement
	for (new client = 1; client < MaxClients; client++) {
		if (IsValidClient(client) && IsSurvivor(client)) {
			// Get displacement between this survivor and the reference
			new Float:survivorPosition[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", survivorPosition);
			new iAbsDisplacement = RoundToNearest(GetVectorDistance(referencePosition, survivorPosition));
			// Start with the absolute displacement to the first survivor found:
			if (iClosestAbsDisplacement == -1) {
				iClosestAbsDisplacement = iAbsDisplacement;
			} else if (iAbsDisplacement < iClosestAbsDisplacement) { // closest survivor so far
				iClosestAbsDisplacement = iAbsDisplacement;
			}			
		}
	}
	// return the closest survivor's proximity
	return iClosestAbsDisplacement;
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

bool:IsValidClient(client) {
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}

bool:IsSurvivor(client) {
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}