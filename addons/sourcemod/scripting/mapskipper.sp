#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <nextmap> // ForceChangeLevel()
#include <smlib>
#define MISSIONS_PATH "missions"
#define DELAY_FORCEMAP 6.5
#define MS_DEBUG 0

/*
 * Bibliography
 * "[L4D/2] Campaign Manager" by Bigbuck
*/

new String:NextMap[256];
new bool:g_bCanRetry = false;
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
	hCvarEnableRetry = CreateConVar("enable_retry", "0", "Enable retry of a map if team wipes");
	g_bCanRetry = GetConVarBool(hCvarEnableRetry);
	RegConsoleCmd("sm_toggleretry", Cmd_ToggleRetry);
	HookEvent("mission_lost", EventHook:OnMissionLost, EventHookMode_PostNoCopy);	
}

public Action:Cmd_ToggleRetry(client, args) {
	g_bCanRetry = !g_bCanRetry;
	if (g_bCanRetry) {
		Client_PrintToChatAll(true, "Retry is {G}enabled!");
	} else {
		Client_PrintToChatAll(true, "Retry is {O}disabled!");
	}
}

public OnMissionLost() {
	if (GetNextMapName()) {
		CreateTimer(DELAY_FORCEMAP, Timer_ForceNextMap, TIMER_FLAG_NO_MAPCHANGE);
	}	
}

public Action:Timer_ForceNextMap(Handle:timer) {
	if (!g_bCanRetry){
		//Fire a map_transition event for static scoremod
		new Handle:event = CreateEvent("map_transition");
		FireEvent(event);
		LogMessage("Force changing map to %s", NextMap);
		ForceChangeLevel(NextMap, "Map Skipper");
		return Plugin_Handled;
	} else {
		return Plugin_Handled;
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
		new Handle: missions_kv = CreateKeyValues("mission"); // use "mission" as the structure's root node
		FileToKeyValues(missions_kv, full_path);
		#if MS_DEBUG
			LogMessage("Searching for current map in file: %s", full_path);
		#endif
	
		// Get to "coop" section to start looping
		KvJumpToKey(missions_kv, "modes", false);
		if(!KvJumpToKey(missions_kv, "coop", false)) {
			#if MS_DEBUG
				LogMessage("Could not find a coop section in missions file: %s", full_path);
			#endif
		} else { // check if the current map belongs to this mission file
			KvGotoFirstSubKey(missions_kv); // first map
			do { 
				new String:map_name[256];
				KvGetString(missions_kv, "map", map_name, sizeof(map_name));
				// If we have found the map name in this missions file, read in the next map
				if (StrEqual(map_name, current_map, false)) { // third parameter indicates case sensitivity
					if (KvGotoNextKey(missions_kv)) { // if finale is not being played
						KvGetString(missions_kv, "map", NextMap, sizeof(NextMap));
						LogMessage("Found next map: %s", NextMap); 
						CloseHandle(missions_kv); // Close the KV handle for the next loop
						CloseHandle(missions_dir); // Close the directory handle
						return true;
					}  else { 
						LogMessage("Finale being played, map skip will restart campaign");
						KvGoBack(missions_kv);
						KvGotoFirstSubKey(missions_kv);
						KvGetString(missions_kv, "map", NextMap, sizeof(NextMap));
						return true;
					}
				}
			} while (KvGotoNextKey(missions_kv));
		}
		CloseHandle(missions_kv); // Close the KV handle for this missions file
	}		
	LogMessage("The next map could not be found. No valid missions file?");
	CloseHandle(missions_dir); // Close the handle for this folder/directory
	return false; 
}