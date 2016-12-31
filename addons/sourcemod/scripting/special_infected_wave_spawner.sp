#pragma semicolon 1
#define DEBUG 0

#define MAX_SPAWN_RANGE 750
#define TANK_RUSH_FLOW_TOLERANCE 1000.0
#define UNINITIALISED -1

// timer
#define KICKDELAY 0.1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_direct>
#include <left4downtown>
#include <colors>
#include <smlib>
#include "includes/hardcoop_util.sp"
#include "modules/SIWS_Limits.sp"
#include "modules/SIWS_Spawner.sp"

/*
    Bibliography: 
    "[L4D2] SI Coop Limit Bypass" by "MI 5"
    "Zombo Manager" by "CanadaRox"  
    "Current" by "CanadaRox"
    "L4D2 Auto Infected Spawner" by "Tordecybombo, FuzzOne - miniupdate, TacKLER - miniupdate again",
*/

// Anti-baiting
new Float:g_fSaferoomExitFlow;
new Float:g_fBaitTolerance;
new Float:g_fBaitThresholdFlow;

// Flags
new bool:g_bIsRoundActive; // left saferoom
new bool:g_bHasPassedBaitThreshold; // start spawning
new bool:g_bIsSpawnerActive; // cooldown between waves

// Interval(seconds) between waves of SI
new Handle:hCvarWaveInterval;

// Tank
new Float:g_fTankRushThreshold;
new bool:g_bIsTankInPlay;

// Tank support
new Handle:hCvarTankSupportHealthPercent; // at what percent of tank health will his support wave spawn

// Grace peroid
new Handle:hCvarIncapAllowance;

// server_namer.smx compatability;
new Handle:hCvarReadyUpEnabled;
new Handle:hCvarConfigName;

public Plugin:myinfo = 
{
    name = "Special Infected Wave Spawner", 
    author = "Breezy", 
    description = "Spawns SI in waves", 
    version = "2.0", 
    url = ""
};

public OnPluginStart() {
	// Initialise modules
	Limits_OnModuleStart();
	Spawner_OnModuleStart();
	
	// Vanilla cvars
	SetConVarInt(FindConVar("z_safe_spawn_range"), 100);
	SetConVarInt(FindConVar("z_spawn_safety_range"), 100);
	SetConVarInt(FindConVar("z_finale_spawn_safety_range"), 100);
	SetConVarInt(FindConVar("z_spawn_range"), MAX_SPAWN_RANGE);
	SetConVarBool(FindConVar("director_no_specials"), true); // Disable Director spawning specials naturally
	SetConVarInt(FindConVar("z_discard_range"), GetConVarInt(FindConVar("z_spawn_range")) + 500 ); // Discard Zombies farther away than this
	
	// Compatibility with server_namer.smx
	hCvarReadyUpEnabled = CreateConVar("l4d_ready_enabled", "1", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	hCvarConfigName = CreateConVar("l4d_ready_cfg_name", "Hard Coop", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	SetConVarBool(hCvarReadyUpEnabled, true); // remove compilation warnings for unused symbols
	SetConVarString(hCvarConfigName, "Hard Coop"); // remove compilation warnings for unused symbols
	
	// Wave interval
	hCvarWaveInterval = CreateConVar("siws_wave_interval", "25", "Interval in seconds between special infected waves");

	// Tank support
	hCvarTankSupportHealthPercent = CreateConVar("siws_tank_support_health_percent", "75", "SI support wave spawns upon tank health falling below this percent");
	
	// Grace period allowance per survivor
	hCvarIncapAllowance = CreateConVar("incap_allowance", "5", "Extra grace period extension(sec) to wave interval per incapped survivor");

    // Game event hooks
    // - resetting at the end of rounds
	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);

	// Console commands
	RegConsoleCmd("sm_waveinterval", Cmd_SetWaveInterval, "Set the interval between waves");
	RegConsoleCmd("sm_supportpercent", Cmd_SetTankSupportHealthPercent, "Set the percentage of tank health at which support wave will spawn");
}

public OnPluginEnd() {
    // Reset convars
    ResetConVar(FindConVar("z_safe_spawn_range"));
    ResetConVar(FindConVar("z_spawn_safety_range"));
    ResetConVar(FindConVar("z_spawn_range"));
    ResetConVar(FindConVar("director_no_specials"));
    ResetConVar(FindConVar("z_discard_range"));
}

/***********************************************************************************************************************************************************************************

                                                                                PER ROUND
                                                                    
***********************************************************************************************************************************************************************************/

// Calculate bait threshold flow distance
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
    SetSpawnDirection(SPECIALS_ANYWHERE);
    SetLimits();
    PrintSettings();
    
    //Initialise
    g_bIsRoundActive = true;
    g_bHasPassedBaitThreshold = false;
    g_bIsSpawnerActive = false;
    g_bIsTankInPlay = false;
    g_fTankRushThreshold = 0.0;
    
    // Get the flow of the saferoom exit held by the farthest survivor 
    new Float:flow = 0.0;
    decl Float:tmp_flow;
    decl Float:origin[3];
    decl Address:pNavArea;
    GetClientAbsOrigin(client, origin);
    pNavArea = L4D2Direct_GetTerrorNavArea(origin);
    if (pNavArea != Address_Null) {
        tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
        g_fSaferoomExitFlow = MAX(flow, tmp_flow);
    }
    
    // Generate a flow distance when survivors will be attacked for the first time
    g_fBaitTolerance = GetRandomFloat(100.0, 150.0);
    g_fBaitThresholdFlow = g_fSaferoomExitFlow + g_fBaitTolerance;
}

// Reset flags when survivors wipe or make it to the next map
public OnRoundOver() {
    g_bIsRoundActive = false;
    g_bHasPassedBaitThreshold = false;
    g_bIsSpawnerActive = false;
    g_bIsTankInPlay = false;
    g_fTankRushThreshold = 999999.0;
}

/***********************************************************************************************************************************************************************************

                                                                        WAVE TIMING
                                                                    
***********************************************************************************************************************************************************************************/

// Check every game frame whether a wave needs to be spawned
public OnGameFrame() {
    // If survivors have left saferoom
    if (g_bIsRoundActive) {
        // If survivors have progressed past a calculated map flow threshold
        if (g_bHasPassedBaitThreshold) {
            // Tank spawn will stop periodic waves spawning
            if (g_bIsTankInPlay) {
                if (GetFarthestSurvivorFlow() > g_fTankRushThreshold) { // allow SI to spawn in natural waves to discourage rushing past tank
                    g_bIsTankInPlay = false; 
                    g_bIsSpawnerActive = true;
                }
            } else {
            	// Spawn wave and create timer counting down to next wave
                if (g_bIsSpawnerActive) { 
                    SpawnWave(); // see modules/SIWS_Spawner.sp
                    g_bIsSpawnerActive = false;
                    CreateTimer(GetConVarFloat(hCvarWaveInterval), Timer_ActivateSpawner, _, TIMER_FLAG_NO_MAPCHANGE); 
                }
            }
        } else {  // Check if survivors have passed the flow threshold for spawning
            new Float:currentFlow = GetAverageSurvivorFlow();
            if (currentFlow > g_fBaitThresholdFlow) {
                g_bHasPassedBaitThreshold = true;
                g_bIsSpawnerActive = true;
            }
        }
    }
}

// Allow spawning
public Action:Timer_ActivateSpawner(Handle:timer) {
	// Grant grace period before allowing a wave to spawn if there are incapacitated survivors
	new numIncappedSurvivors = 0;
	for (new client = 1; client <= MaxClients; client++ ) {
		if( IsClientInGame(client) && L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor ) {
			if( IsIncapacitated(client) && IsPlayerAlive(client) ) {
				if( !IsPinned(client) && IsClientInGame(client) ) {
					numIncappedSurvivors++;
				}				
			}
		}
	}
	new Float:fGracePeriod = float(numIncappedSurvivors * GetConVarInt(hCvarIncapAllowance));
	if( numIncappedSurvivors > 0 && numIncappedSurvivors < GetConVarInt(FindConVar("survivor_limit")) ) {
		Client_PrintToChatAll(true, "{G}%ds {O}grace period {N}was granted because of {G}%d {N}incapped survivor(s)", RoundToNearest(fGracePeriod), numIncappedSurvivors);
	}
	CreateTimer( fGracePeriod, Timer_GracePeriod, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action:Timer_GracePeriod(Handle:timer) {
	g_bIsSpawnerActive = true;
}

/***********************************************************************************************************************************************************************************

                                                                                TANK FIGHTS
                                                                    
***********************************************************************************************************************************************************************************/

public OnTankSpawn(tank) {
    SDKHook(tank, SDKHook_OnTakeDamage, OnTakeDamage);
    // Tanks stop periodic waves spawning
    g_bIsTankInPlay = true;
    g_fTankRushThreshold = GetFarthestSurvivorFlow() + TANK_RUSH_FLOW_TOLERANCE;
}

public OnTankDeath(tank) {
	SDKUnhook(tank, SDKHook_OnTakeDamage, OnTakeDamage);    
	// Account for the possibility of multiple tanks
	if( !IsTankInPlay() ) {
	    g_bIsTankInPlay = false;
	}
	// Re-enable period waves, grant recovery time to survivors
	g_bIsSpawnerActive = false;
	new Float:recoveryTime = GetConVarFloat(hCvarWaveInterval) / 2.0; 
	CreateTimer(recoveryTime, Timer_ActivateSpawner, _, TIMER_FLAG_NO_MAPCHANGE); 
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {    
    // Calculate tank health percent
    new Float:fTankMaxHealth = float(GetEntProp(victim, Prop_Send, "m_iMaxHealth"));
    new Float:fTankCurrentHealth = float(GetEntProp(victim, Prop_Send, "m_iHealth"));
    new Float:fTankHealthPercent = 100.0 * FloatDiv(fTankCurrentHealth, fTankMaxHealth);    
    // Check if health is below SI support wave percent
    new iTankHealthPercent = RoundToNearest(fTankHealthPercent);
    new iTankSupportHealthPercent = GetConVarInt(hCvarTankSupportHealthPercent);
    // Spawn a support wave at configured health percent
    if (iTankHealthPercent < iTankSupportHealthPercent) {
        #if DEBUG
            PrintToChatAll("Spawning tank's support wave");
        #endif
        SpawnWave();
        SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage); // 'victim' must be the tank since OnTakeDamage was hooked to the tank upon spawn
    }    
}

/***********************************************************************************************************************************************************************************

                                                                                COMMANDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_SetWaveInterval(client, args) {
    if (args == 1) {        
        // Read in argument
        new String:sIntervalValue[32]; 
        GetCmdArg(1, sIntervalValue, sizeof(sIntervalValue));
        new iIntervalValue = StringToInt(sIntervalValue);        
        // Valid interval length entered; apply setting
        new maxWaveInterval = GetConVarInt(hCvarWaveTimeMaxInterval);
        new minWaveInterval = GetConVarInt(hCvarWaveTimeMinInterval);
        if (iIntervalValue <= maxWaveInterval && iIntervalValue >= minWaveInterval) {
            SetConVarInt(hCvarWaveInterval, iIntervalValue);
            Client_PrintToChatAll(true, "-> {O}Interval {N}between special infected waves set to {G}%i", iIntervalValue);
        } else {  // Invalid value entered
            Client_PrintToChatAll(true, "Wave interval must be between {G}%ds {N}and {G}%ds", minWaveInterval, maxWaveInterval);
        }        
    } else { // Incorrect number of arguments
    	CPrintToChat(client, "Usage: {red}!waveinterval {blue}<time(seconds)>");
    }
}

public Action:Cmd_SetTankSupportHealthPercent(client, args) {
    if (args == 1) {    
        // Read in argument
        new String:sPercentValue[32]; 
        GetCmdArg(1, sPercentValue, sizeof(sPercentValue));
        new iPercentValue = StringToInt(sPercentValue);        
        // Valid percent value entered; apply setting
        if (iPercentValue < 100 && iPercentValue > 0) {
            SetConVarInt(hCvarTankSupportHealthPercent, iPercentValue);
            CPrintToChatAll("Support wave for tank will now spawn at %i%% health", iPercentValue);
        } else {    // Invalid value entered
            CPrintToChatAll("Percent value must be between 0 and 100, exclusive");
        }        
    } else {  // Incorrect number of arguments
        CPrintToChat(client, "Usage: !setsupportpercent <percent>");
    }
}


