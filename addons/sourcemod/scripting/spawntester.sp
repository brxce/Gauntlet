#pragma semicolon 1

#define DEBUG 1
#define DEBUG_DETAIL 0

#define WAVE_SIZE_HARDLIMIT 20
#define MAX_SPAWN_RANGE 750
#define SI_HARDLIMIT 2

// functions
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define TEAM_CLASS(%1) (%1 == ZC_SMOKER ? "smoker" : (%1 == ZC_BOOMER ? "boomer" : (%1 == ZC_HUNTER ? "hunter" :(%1 == ZC_SPITTER ? "spitter" : (%1 == ZC_JOCKEY ? "jockey" : (%1 == ZC_CHARGER ? "charger" : (%1 == ZC_WITCH ? "witch" : (%1 == ZC_TANK ? "tank" : "None"))))))))

// timer
#define KICKDELAY 0.1
#define SPAWN_ATTEMPT_INTERVAL 0.5

#include <sourcemod>
#include <sdktools>
#include <l4d2util>

// Special infected classes
enum ZombieClass {
	ZC_NONE = 0, 
	ZC_SMOKER, 
	ZC_BOOMER, 
	ZC_HUNTER, 
	ZC_SPITTER, 
	ZC_JOCKEY, 
	ZC_CHARGER, 
	ZC_WITCH, 
	ZC_TANK, 
	ZC_NOTINFECTED
};

enum SpawnDirection {
	ANYWHERE = 0,
	BEHIND,
	IT,
	SPECIALS_IN_FRONT,
	SPECIALS_ANYWHERE,
	FAR_AWAY,
	ABOVE	
};

// Custom SI limits (not the vanilla cvars)
new Handle:hCvarMaxSpecials;
new Handle:hCvarSmokerLimit;
new Handle:hCvarBoomerLimit;
new Handle:hCvarHunterLimit;
new Handle:hCvarSpitterLimit;
new Handle:hCvarJockeyLimit;
new Handle:hCvarChargerLimit;
new g_ClassSpawnVolume[9]; // population of each SI class; '8' for tank is the highest index

public Plugin:myinfo = 
{
	name = "Spawn Tester",
	author = "Breezy",
	description = "Test for Special Infected Wave Spawner",
	version = "1.0",
	url = ""
};

// SetConVarBounds may be unnecessary
// don't check IsPlayerAlive and possibly neither IsClientInKickQueue?
// g_ClassSpawnVolume being incremented?
// 3 is the magic number for >= hard_limit; i.e. >= 3 or > 2
// IsClassLimitReached condition should be || not &&

public OnPluginStart() {
	SetConVarInt(FindConVar("z_safe_spawn_range"), 100);
	SetConVarInt(FindConVar("z_spawn_safety_range"), 100);
	SetConVarInt(FindConVar("z_finale_spawn_safety_range"), 100);
	SetConVarInt(FindConVar("z_spawn_range"), MAX_SPAWN_RANGE);
	SetConVarBool(FindConVar("director_no_specials"), true); // Disable Director spawning specials naturally
	SetConVarInt(FindConVar("z_discard_range"), GetConVarInt(hCvarSpawnMaxDist) + 500 ); // Discard Zombies farther away than this
	
	// Appears to be ineffective; setting PreferredSpecialDirection through 'script' console command appears effective: e.g. ScriptCommand(client, "g_ModeScript.DirectorOptions.PreferredSpecialDirection<-4") - this uses the same enumerations for the direction parameter
	// hCvarSpawnDirection = FindConVar("z_debug_spawn_set"); // 0=Anywhere, 1=Behind, 2=IT, 3=Specials in front, 4=Specials anywhere, 5=Far Away, 6=Above
	// SetConVarInt(hCvarSpawnDirection, SPECIALS_ANYWHERE); // Does not appear to have an effect on the "z_spawn_old" command used in this plugin
	
	// Custom class limits
	hCvarMaxSpecials 	= CreateConVar("siws_max_specials", 	"7", "Maximum Specials alive at any time");
	HookConVarChange(hCvarMaxSpecials, ConVarChanged:OnCvarChange);
	hCvarSmokerLimit 	= CreateConVar("siws_smoker_limit", 	"0", "Maximum smokers alive at any time");
	hCvarBoomerLimit 	= CreateConVar("siws_boomer_limit", 	"0", "Maximum boomers alive at any time");
	hCvarHunterLimit 	= CreateConVar("siws_hunter_limit", 	"7", "Maximum hunters alive at any time");
	hCvarSpitterLimit	= CreateConVar("siws_spitter_limit", 	"0", "Maximum spitters alive at any time");
	hCvarJockeyLimit 	= CreateConVar("siws_jockey_limit", 	"0", "Maximum jockeys alive at any time");
	hCvarChargerLimit 	= CreateConVar("siws_charger_limit", 	"0", "Maximum chargers alive at any time");
	
	// Monitoring spawns
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Pre);
	
	// Spawn wave command
	RegConsoleCmd("sm_spawn", Cmd_Spawn, "Spawns a wave");
}

// Tracking when SI spawn, and printing debug info if enabled
public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotInfected(client)) {	
		new infectedClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if( infectedClass > 0 && infectedClass < 7 )g_ClassSpawnVolume[infectedClass]++;
		// Print debug output
		#if DEBUG
			new String:infectedName[32];
			GetClientName(client, infectedName, sizeof(infectedName));
			if (StrContains(infectedName, "dummy", false) == -1) {
				PrintToChatAll("%s spawned", infectedName);
			} 
		#endif
	}
}

public OnPlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsBotInfected(client)) {		
		new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if ( (zClass > 0) && (zClass < 9) ) {
			--g_ClassSpawnVolume[zClass];
		}		
	}
}

public OnConfigsExecuted() {
	// Remove hard coded SI limit
	//SetConVarBounds(FindConVar("z_minion_limit"), ConVarBound_Upper, true, float(GetConVarInt(hCvarMaxSpecials)));
	//SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, true, float(GetConVarInt(hCvarMaxSpecials)));
}

// Update wave interval if it is changed mid-game
public OnCvarChange() {
	//SetConVarBounds(FindConVar("z_minion_limit"), ConVarBound_Upper, true, float(GetConVarInt(hCvarMaxSpecials)));
	//SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, true, float(GetConVarInt(hCvarMaxSpecials)));
}

public OnPluginEnd() {
	// Reset convars
	ResetConVar(FindConVar("z_safe_spawn_range"));
	ResetConVar(FindConVar("z_spawn_safety_range"));
	ResetConVar(FindConVar("z_spawn_range"));
	ResetConVar(FindConVar("director_no_specials"));
	ResetConVar(FindConVar("z_discard_range"));
	//SetConVarBounds(FindConVar("z_minion_limit"), ConVarBound_Upper, true, 3.0);
	//SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, true, 4.0);
}


/***********************************************************************************************************************************************************************************

																			WAVE SPAWNING
																	
***********************************************************************************************************************************************************************************/

public Action:Cmd_Spawn(client, args) {
	SetSpawnDirection(SPECIALS_ANYWHERE);
	SpawnWave();
	return Plugin_Handled;
}

// Initiate spawning for each SI class
SpawnWave() {
	
	#if DEBUG
		new infectedBotCount = CountSpecialInfectedBots();
		PrintToChatAll("\x04Spawning Wave \x01(%i SI carryover)", infectedBotCount);
	#endif
	
	// reset cache
	for (new i = 0; i < 8; i++) {
		g_ClassSpawnVolume[i] = 0;
	}
	SpawnClassPopulation(ZC_JOCKEY);
	SpawnClassPopulation(ZC_CHARGER);
	SpawnClassPopulation(ZC_SPITTER);
	SpawnClassPopulation(ZC_SMOKER);
	SpawnClassPopulation(ZC_HUNTER);
	SpawnClassPopulation(ZC_BOOMER);
}

// Populate an SI class to its limit
SpawnClassPopulation(ZombieClass:targetClass) {
	CreateTimer(SPAWN_ATTEMPT_INTERVAL, Timer_SpawnSpecialInfected, any:targetClass, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_SpawnSpecialInfected(Handle:timer, any:targetClass) {
	// Make sure we are not spawning duplicate SI due to early deaths before full wave has spawned
	new iClassSpawnVolume = g_ClassSpawnVolume[_:targetClass];
	new iClassLimit = GetClassLimit(targetClass);
	new bool:hasSpawnedClassPopulation = (iClassSpawnVolume >= iClassLimit ? true:false);
	
	// Attempt spawn if needed
	if (!IsClassLimitReached(targetClass) && !hasSpawnedClassPopulation) {
		AttemptSpawn(targetClass);
		return Plugin_Continue;
	} else {
		#if DEBUG
			if( targetClass == ZC_HUNTER ) {
				new iHunterLimit = GetClassLimit(ZC_HUNTER);
				PrintToChatAll("\x04%s limit %i reached", TEAM_CLASS(targetClass), iHunterLimit);
			}			
		#endif
		return Plugin_Stop;
	}
}

// Attempt to spawn a special infected of a particular class
// ('attempt' because there is the occasional "could not find a spawn position in 5 tries" error)
AttemptSpawn(ZombieClass:zombieClassNum) {
	// Create a client if necessary to circumvent the hard coded SI limit
	new iSpawnedSpecialsCount = CountSpecialInfectedBots();
	if (iSpawnedSpecialsCount >= 3) {
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
	CheatCommand("z_spawn_old", zombieClassName, "auto");
}

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/

// Kick dummy bot 
public Action:Timer_KickBot(Handle:timer, any:client) {
	if (IsClientInGame(client) && (!IsClientInKickQueue(client))) {
		if( IsFakeClient(client) ) {
			if( IsSurvivor(client) ) {
				new String:kickedClientName[MAX_NAME_LENGTH];
				GetClientName(client, kickedClientName, sizeof(kickedClientName));
				PrintToChatAll("Kicking %s", kickedClientName);	
			} else {
				KickClient(client);		
			}
		}
	}
}

// Sets the spawn direction for SI, relative to the survivors
// Yet to test whether map specific scripts override this option, and if so, how to rewrite this script line
SetSpawnDirection(SpawnDirection:direction) {
	ScriptCommand("g_ModeScript.DirectorOptions.PreferredSpecialDirection<-%i", _:direction);	
}

// Executes vscript code through the "script" console command
ScriptCommand(const String:arguments[], any:...) {
	new String:vscriptCommand[PLATFORM_MAX_PATH];
	VFormat(vscriptCommand, sizeof(vscriptCommand), arguments, 2);	
	CheatCommand("script", vscriptCommand);
}

// Executes through a dummy client, without setting sv_cheats to 1, a console command marked as a cheat
CheatCommand(String:command[], String:argument1[] = "", String:argument2[] = "") {
	static commandDummy;
	new flags = GetCommandFlags(command);		
	if ( flags != INVALID_FCVAR_FLAGS ) {
		if ( !IsValidClient(commandDummy) || IsClientInKickQueue(commandDummy) ) { // Dummy may get kicked by SMAC_Antispam.smx
			commandDummy = CreateFakeClient("[SIWS] Command Dummy");
			ChangeClientTeam(commandDummy, _:L4D2Team_Spectator);
		}
		if ( IsValidClient(commandDummy) ) {
			new originalUserFlags = GetUserFlagBits(commandDummy);
			new originalCommandFlags = GetCommandFlags(command);			
			SetUserFlagBits(commandDummy, ADMFLAG_ROOT); 
			SetCommandFlags(command, originalCommandFlags ^ FCVAR_CHEAT);				
			FakeClientCommand(commandDummy, "%s %s %s", command, argument1, argument2);
			SetCommandFlags(command, originalCommandFlags);
			SetUserFlagBits(commandDummy, originalUserFlags);
		} else {
			LogError("Could not create a dummy client to execute cheat command");
		}	
	}
}

//@return: true if neither the target SI class population limit nor the number of spawned specials  have reached their limit
bool:IsClassLimitReached(ZombieClass:targetClass) {
	// Checking class limit
	new iClassLimit = GetClassLimit(targetClass);
	new iClassCount = CountSpecialInfectedClass(targetClass);
	// Checking max specials limit
	new iMaxSpecials = GetConVarInt(hCvarMaxSpecials);
	new iSpawnedSpecialsCount = CountSpecialInfectedBots();
	
	// If neither limit has been reached
	if (iClassCount < iClassLimit || iSpawnedSpecialsCount < iMaxSpecials) {
		return false;
	} else {
		return true;
	}
}

// @return: true if either the class limit or total specials limit has been reached
GetClassLimit(ZombieClass:targetClass) {
	new iClassLimit;
	switch (targetClass) {
		case ZC_SMOKER:iClassLimit = GetConVarInt(hCvarSmokerLimit);
		case ZC_BOOMER:iClassLimit = GetConVarInt(hCvarBoomerLimit);
		case ZC_HUNTER:iClassLimit = GetConVarInt(hCvarHunterLimit);
		case ZC_SPITTER:iClassLimit = GetConVarInt(hCvarSpitterLimit);
		case ZC_JOCKEY:iClassLimit = GetConVarInt(hCvarJockeyLimit);
		case ZC_CHARGER:iClassLimit = GetConVarInt(hCvarChargerLimit);
		default:iClassLimit = 0;
	}
	return iClassLimit;
}

// @return: the number of a particular special infected class alive in the game
stock CountSpecialInfectedClass(ZombieClass:targetClass) {
	new count = 0;
	for (new i = 1; i < MaxClients; i++) {
		if (IsBotInfected(i) && IsPlayerAlive(i)) {
			new playerClass = GetEntProp(i, Prop_Send, "m_zombieClass");
			if (playerClass == _:targetClass) {
				count++;
			}
		}
	}
	return count;
}

// @return: the total special infected bots alive in the game
stock CountSpecialInfectedBots() {
	new count = 0;
	for (new i = 1; i < MaxClients; i++) {
		if ( IsBotInfected(i) && IsPlayerAlive(i) && !IsClientInKickQueue(i) ) {
			count++;
		}
	}
	return count;
}

// @return: true if client is a bot infected
bool:IsBotInfected(client) {
	// Check the input is valid
	if (!IsValidClient(client))return false;
	
	// Check if player is a bot on the infected team
	if (IsInfected(client) && IsFakeClient(client)) {
		return true;
	}
	return false; // otherwise
}

// @return: true if client is valid
bool:IsValidClient(client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))return false;
	return true;
} 

// Archaic
/* Executes, without setting sv_cheats to 1, a console command marked as a cheat
CheatCommand(String:command[], String:argument1[], String:argument2[]) {
	new client = CreateFakeClient("[SIWS] Command Dummy");
	if (client > 0) {
		ChangeClientTeam(client, _:L4D2Team_Spectator);
		// Get user bits and command flags
		new userFlagsOriginal = GetUserFlagBits(client);
		new flagsOriginal = GetCommandFlags(command);
		
		// Set as Cheat
		SetUserFlagBits(client, ADMFLAG_ROOT);
		SetCommandFlags(command, flagsOriginal ^ FCVAR_CHEAT);
		
		// Execute command
		FakeClientCommand(client, "%s %s %s", command, argument1, argument2);
		CreateTimer(KICKDELAY, Timer_KickBot, client, TIMER_FLAG_NO_MAPCHANGE);
		
		// Reset user bits and command flags
		SetCommandFlags(command, flagsOriginal);
		SetUserFlagBits(client, userFlagsOriginal);
	} else {
		LogError("Could not create a dummy client to execute cheat command");
	}	
}
*/