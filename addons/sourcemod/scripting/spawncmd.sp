#pragma semicolon 1

#define DEBUG 0
#define TEAM_CLASS(%1) (%1 == ZC_SMOKER ? "smoker" : (%1 == ZC_BOOMER ? "boomer" : (%1 == ZC_HUNTER ? "hunter" :(%1 == ZC_SPITTER ? "spitter" : (%1 == ZC_JOCKEY ? "jockey" : (%1 == ZC_CHARGER ? "charger" : (%1 == ZC_WITCH ? "witch" : (%1 == ZC_TANK ? "tank" : "None"))))))))

#include <sourcemod>
#include <sdktools>

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

public Plugin:myinfo = 
{
	name = "Custom Z_Spawn",
	author = "Breezy",
	description = "A custom z_spawn cmd",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	RegAdminCmd("sm_spawn", Adm_Spawn, ADMFLAG_ROOT, "Spawn a zombie");
}

public Action:Adm_Spawn(client, args) {
	// Check a valid number of arguments was entered
	if (args == 1) {
		
		// Read in the SI class
		new String:sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		
		// Smoker 
		if (StrEqual(sTargetClass, "smoker", false)) {
			SpawnZombie(ZC_SMOKER);
		} 
		// Boomer
		else if (StrEqual(sTargetClass, "boomer", false)) {
			SpawnZombie(ZC_BOOMER);
		} 
		// Hunter
		else if (StrEqual(sTargetClass, "hunter", false)) {
			SpawnZombie(ZC_HUNTER);		
		} 
		// Spitter 
		else if (StrEqual(sTargetClass, "spitter", false)) {
			SpawnZombie(ZC_SPITTER);		
		} 
		// Jockey
		else if (StrEqual(sTargetClass, "jockey", false)) {
			SpawnZombie(ZC_JOCKEY);	
		} 
		// Charger 
		else if (StrEqual(sTargetClass, "charger", false)) {
			SpawnZombie(ZC_CHARGER);		
		} 
		
		// An invalid class has been entered
		else {
			PrintToCmdUser(client, "<class> == max || smoker || boomer || hunter || spitter || jockey || charger");			
		}
		return Plugin_Handled;
	} 
	
	// Invalid command syntax
	else {
		PrintToCmdUser(client, "Usage: !spawn/sm_spawn <class> ");
		return Plugin_Handled;	
	}	
}

SpawnZombie(ZombieClass:targetClass) {
	
}