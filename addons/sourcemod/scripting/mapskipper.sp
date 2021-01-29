#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <nextmap> // ForceChangeLevel()
#include <colors>
#include <left4dhooks>

#define MISSIONS_PATH "missions"
#define DELAY_FORCEMAP 6.5
#define MS_DEBUG 0

/*
 * Bibliography
 * "[L4D/2] Campaign Manager" by Bigbuck
*/

new String:NextMap[256];

new bool:g_bIsFinale;

new bool:g_bCanRetry;
new Handle:hCvarEnableRetry;

public Plugin: myinfo = {
	name = "Map Skipper",
	author = "Breezy",
	description = "Skip to next map in coop when wiping",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	// Make sure the 'missions' folder exists
	if (!DirExists(MISSIONS_PATH)) {
		SetFailState("Missions directory does not exist on this server.  Map Skipper cannot continue operation");
	}
	hCvarEnableRetry = CreateConVar("enable_retry", "1", "Enable retry of a map if team wipes");
	g_bCanRetry = GetConVarBool(hCvarEnableRetry);
	RegConsoleCmd("sm_toggleretry", Cmd_ToggleRetry);
	HookEvent("mission_lost", EventHook:OnMissionLost, EventHookMode_PostNoCopy);	
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) {
   // PrintRetryOption();
}

public Action:Cmd_ToggleRetry(client, args) {
	g_bCanRetry = !g_bCanRetry;
	PrintRetryOption();
}

PrintRetryOption() {
    if (g_bCanRetry) {
    PrintToChatAll("Retry is {red}enabled{default}! Survivors will be allowed to retry map upon death");
	} else {
	CPrintToChatAll("Retry is {red}disabled{default}! Next map will be loaded upon death");
	}
}

public OnMissionLost() {
	if (GetNextMapName()) { 
		CreateTimer(DELAY_FORCEMAP, Timer_ForceNextMap, _, TIMER_FLAG_NO_MAPCHANGE);
	}	
}

public Action:Timer_ForceNextMap(Handle:timer) {
	if (!g_bCanRetry){
		//Fire a map_transition event for static scoremod
		new Handle:event = CreateEvent("map_transition");
		if (g_bIsFinale) {
			SetEventBool(event, "finale", true);
		}
		FireEvent(event);
		// Change level
		ForceChangeLevel(NextMap, "Map Skipper");
		LogMessage("Force changing map to %s", NextMap);
	} 
}

bool:GetNextMapName() { // returns true if the next map was found
	// Open the missions directory
	new Handle: missions_dir = INVALID_HANDLE;
	missions_dir = OpenDirectory(MISSIONS_PATH);
	if (missions_dir == INVALID_HANDLE) {
		SetFailState("Cannot open missions directory");
	}

	// Setup strings
	new String: current_map[256]; //current map being played
	GetCurrentMap(current_map, sizeof(current_map));
	LogMessage("Current map: %s", current_map);
	decl String: buffer[256];
	decl String: full_path[256];

	// Loop through all the mission text files
	while (ReadDirEntry(missions_dir, buffer, sizeof(buffer))) {
		// Skip folders and credits file
		if (DirExists(buffer) || StrEqual(buffer, "credits.txt", false)) {continue;}

		// Create a keyvalues structure from the current iteration's mission .txt
		Format(full_path, sizeof(full_path), "%s/%s", MISSIONS_PATH, buffer); 
		new Handle: missions_kv = CreateKeyValues("mission"); // find "mission" to use as the structure's root node
		FileToKeyValues(missions_kv, full_path);
		
				#if MS_DEBUG
					LogMessage("Searching for current map in file: %s", full_path);
				#endif
	
		// Get to "coop" section to start looping
		KvJumpToKey(missions_kv, "modes", false);
		
		// Check if a "coop" section exists
		if(KvJumpToKey(missions_kv, "coop", false)) { 			
		
			KvGotoFirstSubKey(missions_kv); // first map
			
			// Check the current maps against all the maps in this missions file
			do { 
				new String:map_name[256];
				KvGetString(missions_kv, "map", map_name, sizeof(map_name));
				
				// If we have found the map name in this missions file, read in the next map
				if (StrEqual(map_name, current_map, false)) { // third parameter indicates case sensitivity
					
					// If there is a map listed next, a finale is not being played
					if (KvGotoNextKey(missions_kv)) { 
						g_bIsFinale = false;
						// Get the next map's name
						KvGetString(missions_kv, "map", NextMap, sizeof(NextMap));	
						LogMessage("Found next map: %s", NextMap); 						
						// Close handles
						CloseHandle(missions_kv); 
						CloseHandle(missions_dir); 
						return true;
					} 
					
					// else a finale is being played
					else { 
						LogMessage("Finale being played, map skip will restart campaign");
						g_bIsFinale = true;
						// Loop back to the first map
						KvGoBack(missions_kv);
						KvGotoFirstSubKey(missions_kv);
						KvGetString(missions_kv, "map", NextMap, sizeof(NextMap));
						// Close handles
						CloseHandle(missions_kv); 
						CloseHandle(missions_dir); 
						return true;						
					}		
					
				} 
			} while (KvGotoNextKey(missions_kv));
		
		} else {
			#if MS_DEBUG
				LogMessage("Could not find a coop section in missions file: %s", full_path);	
			#endif			
		}
		
		CloseHandle(missions_kv); // Close the KV handle for this missions file
	}	
	
	LogMessage("The next map could not be found. No valid missions file?");
	CloseHandle(missions_dir); // Close the handle for this folder/directory
	return false; 
}