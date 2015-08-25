#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <nextmap> // ForceChangeLevel()
#include <smlib>
#define MISSIONS_PATH "missions"
#define DELAY_FORCEMAP 6.5
#define MS_DEBUG 0
#define VOTE_YES 0
#define VOTE_NO 1
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

new Handle:hCVarCanVoteRetry;
public OnPluginStart() {
	// Make sure the 'missions' folder exists
	if (!DirExists(MISSIONS_PATH)) {
		SetFailState("Missions directory does not exist on this server.  Map Skipper cannot continue operation");
	}
	hCVarCanVoteRetry = CreateConVar("enable_vote_retry", "0", "Is voting to retry a map enabled");
	HookEvent("mission_lost", EventHook:OnMissionLost, EventHookMode_PostNoCopy);	
}

public OnMissionLost() {
	if (GetNextMapName()) {
		DoRetryMap = false; // reset
		if (bool:GetConVarInt(hCVarCanVoteRetry)) {
			DoVoteRetry();
		}
		CreateTimer(DELAY_FORCEMAP, Timer_ForceNextMap, TIMER_FLAG_NO_MAPCHANGE);
	}	
}

public Action:Timer_ForceNextMap(Handle:timer) {
	if (NextMap[0] == EOS) { // empty
		LogMessage("No valid next map found");
		return Plugin_Handled;
	} else if (!DoRetryMap){
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
				LogMessage("Could not find coop path in missions file %s", full_path);
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
 
DoVoteRetry() {
	if (IsVoteInProgress()) return;
	new Handle:hVoteRetry_Menu = CreateMenu(Handle_VoteMenu);
	//SetVoteResultCallback(hVoteRetry_Menu, VoteHandler:Manage_VoteResults);
	SetMenuTitle(hVoteRetry_Menu, "Try again?");
	AddMenuItem(hVoteRetry_Menu, "yes", "Yes");
	AddMenuItem(hVoteRetry_Menu, "no", "No");
	SetMenuExitButton(hVoteRetry_Menu, false);
	VoteMenuToAll(hVoteRetry_Menu, 6);
}

/*
public Manage_VoteResults (Handle:voteMenu, numVotes, numClients, const clientInfo[][2], numItems, const itemInfo[][2]) {
	// yea or nay?
	PrintToChatAll("numVotes: %i", numVotes);
	PrintToChatAll("numClients: %i", numClients);
	PrintToChatAll("numItems: %i", numItems);
	new yeaVotes = itemInfo[VOTE_YES][VOTEINFO_ITEM_VOTES];
	new nayVotes = itemInfo[VOTE_NO][VOTEINFO_ITEM_VOTES];
	if (yeaVotes >= nayVotes) { // Majority 'yes' or equal 'yes' & 'no'
		Client_PrintToChatAll(true, "{G}Vote Retry PASSED! {N}({B}%i {N}yes, {B}%i {N}no)", yeaVotes, nayVotes);
		DoRetryMap = true;
	} else {
		Client_PrintToChatAll(true, "{O}Vote Retry FAILED! {N}({B}%i {N}yes, {B}%i {N}no)", yeaVotes, nayVotes);
	}
} 
*/

public Handle_VoteMenu(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu); 
	} else if (action == MenuAction_Select) {
		new voter = param1;
		new String:voterName[32];
		GetClientName(voter, voterName, sizeof(voterName));
		if (param2 == 0) {
			Client_PrintToChatAll(true, "{O}'{B}%s{O}' {N}voted {G}yes!", voterName);
		} else if (param2 == 1){
			Client_PrintToChatAll(true, "{O}'{B}%s{O}' {N}voted {O}no!", voterName);
		} else {
			Client_PrintToChatAll(true, "{O}'{B}%s{O}' {N}selected an invalid vote option");
		}
	} else if (action == MenuAction_VoteEnd) {
		if (param1 == 0) {
			Client_PrintToChatAll(true, "{G}Vote Retry PASSED!");
			DoRetryMap = true;
		} else {
			Client_PrintToChatAll(true, "{O}Vote Retry FAILED!");
		}
	}
}
