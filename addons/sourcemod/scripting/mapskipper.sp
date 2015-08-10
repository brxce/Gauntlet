#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <nextmap>
#define MISSIONS_PATH "missions"
#define DELAY_FORCEMAP 6.5
#define MS_DEBUG 0
/*
 * Bibliography
 * "[L4D/2] Campaign Manager" by Bigbuck
*/

new String:NextMap[256];
new bool:DoRetryMap = false;

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
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
}
public Event_MissionLost(Handle:hEvent, const String:name[], bool:dontBroadcast) {
	if (GetNextMapName()) {
		DoRetryMap = false; // reset
		DoVoteMenu();
		CreateTimer(DELAY_FORCEMAP, Timer_ForceNextMap, TIMER_FLAG_NO_MAPCHANGE);
	}	
}

public Action:Timer_ForceNextMap(Handle:timer) {
	if (NextMap[0] == EOS) { // empty
		LogMessage("No valid next map determined");
		return Plugin_Handled;
	} else if (!DoRetryMap){
		//Fire a map_transition event for static scoremod
		new Handle:event = CreateEvent("map_transition");
		FireEvent(event);
		ForceChangeLevel(NextMap, "Map Skipper");
		return Plugin_Handled;
	} else {
		return Plugin_Handled;
	}
}

bool:GetNextMapName() { // return true if the current map is not the finale
	// Open the missions directory
	new Handle: missions_dir = INVALID_HANDLE;
	missions_dir = OpenDirectory(MISSIONS_PATH);
	if (missions_dir == INVALID_HANDLE) {
		SetFailState("Cannot open missions directory");
	}

	// Setup strings
	new String: current_map[256]; //current map being played
	GetCurrentMap(current_map, sizeof(current_map));
	decl String: buffer[256];
	decl String: full_path[256];

	// Loop through all the mission text files
	while (ReadDirEntry(missions_dir, buffer, sizeof(buffer))) {
		// Skip folders and credits file
		if (DirExists(buffer) || StrEqual(buffer, "credits.txt", false)) {continue;}

		// Create the keyvalues structure from the current iteration's mission text file
		Format(full_path, sizeof(full_path), "%s/%s", MISSIONS_PATH, buffer); 
		new Handle: missions_kv = CreateKeyValues("mission"); //define "mission" as the root node
		FileToKeyValues(missions_kv, full_path);

		// Get to correct position so we can start our loop
		KvJumpToKey(missions_kv, "modes", false);
		if(!KvJumpToKey(missions_kv, "coop", false)) {
			LogMessage("Could not find coop path in missions file %s", full_path);
		} else { // check if the current map belongs to this mission file
			KvGotoFirstSubKey(missions_kv); // first map
			do { 
				new String:map_name[256];
				KvGetString(missions_kv, "map", map_name, sizeof(map_name));
				#if MS_DEBUG 
					LogMessage("Found map %s in %s", map_name, full_path); 
				#endif
				if (StrEqual(map_name, current_map, false)) { // third parameter indicates case sensitivity
					if (KvGotoNextKey(missions_kv)) { // if finale is not being played
						KvGetString(missions_kv, "map", NextMap, sizeof(NextMap));
						#if MS_DEBUG 
							LogMessage("Found next map: %s", NextMap); 
						#endif
						CloseHandle(missions_kv); // Close the KV handle for the next loop
						CloseHandle(missions_dir); // Close the directory handle
						return true;
					}  else { // finale; survivors will have to play from the first map again if they wipe
						KvGoBack(missions_kv);
						KvGotoFirstSubKey(missions_kv);
						KvGetString(missions_kv, "map", NextMap, sizeof(NextMap));
						return true;
					}
				}
			} while (KvGotoNextKey(missions_kv));
		}
		CloseHandle(missions_kv); // Close the KV handle for the next loop	
	}		
	CloseHandle(missions_dir); // Close the directory handle
	return false; // the next map could not be found; no valid missions file
}

public Handle_VoteMenu(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_End) {
		/* This is called after VoteEnd */
		CloseHandle(menu);
	} else if (action == MenuAction_VoteEnd) {
		/* 0=yes, 1=no */
		if (param1 == 0) {
			PrintToChatAll("Retry vote passed!");
			DoRetryMap = true;
		} else {
			PrintToChatAll("Retry vote failed!");
		}
	}
}
 
DoVoteMenu() {
	if (IsVoteInProgress()) {
		return;
	} 
	new Handle:menu = CreateMenu(Handle_VoteMenu);
	SetMenuTitle(menu, "Try again?");
	AddMenuItem(menu, "yes", "Yes");
	AddMenuItem(menu, "no", "No");
	SetMenuExitButton(menu, false);
	VoteMenuToAll(menu, 6);
}
