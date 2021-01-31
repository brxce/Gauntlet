#pragma semicolon 1
#define DEBUG 0
#define CVARS_PATH "configs/playermode_cvars.txt"

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include "includes/hardcoop_util.sp"

new Handle:g_hCvarKV = INVALID_HANDLE;

new Handle:hCvarMaxSurvivors;
new Handle:hPlayerModeVote;
new g_iDesiredPlayerMode;

public Plugin:myinfo = 
{
	name = "Player Mode",
	author = "breezy",
	description = "Allows survivors to change the team limit and adapts gameplay cvars to these changes",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	hCvarMaxSurvivors = CreateConVar( "pm_max_survivors", "8", "Maximum number of survivors allowed in the game" );
	RegConsoleCmd( "sm_playermode", Cmd_PlayerMode, "Change the number of survivors and adapt appropriately" );
	
	decl String:sGameFolder[128];
	GetGameFolderName( sGameFolder, sizeof(sGameFolder) );
	if( !StrEqual(sGameFolder, "left4dead2", false) ) {
		SetFailState("Plugin supports Left 4 dead 2 only!");
	} else {
		g_hCvarKV = CreateKeyValues("Cvars");
		BuildPath( Path_SM, sGameFolder, PLATFORM_MAX_PATH, CVARS_PATH );
		if( !FileToKeyValues(g_hCvarKV, sGameFolder) ) {
			SetFailState("Couldn't load playermode_cvars.txt!");
		}
	}
	LoadCvars( GetConVarInt(FindConVar("survivor_limit")) );
}

public OnPluginEnd() {
	SetConVarBool( FindConVar("l4d_ready_enabled"), false );
	// Survivors
	ResetConVar( FindConVar("survivor_limit") );
	ResetConVar( FindConVar("confogl_pills_limit") );
	// Common
	ResetConVar( FindConVar("z_common_limit") );
	ResetConVar( FindConVar("z_mob_spawn_min_size") );
	ResetConVar( FindConVar("z_mob_spawn_max_size") );
	ResetConVar( FindConVar("z_mega_mob_size") );
	// SI
	ResetConVar( FindConVar("z_tank_health") );
	ResetConVar( FindConVar("z_jockey_ride_damage") );
	ResetConVar( FindConVar("z_pounce_damage") );
	ResetConVar( FindConVar("z_pounce_damage_delay") );
	// Autoslayer
	ResetConVar( FindConVar("autoslayer_teamclear_delay") );
	ResetConVar( FindConVar("autoslayer_slay_all_infected") );
}

public Action:Cmd_PlayerMode( client, args ) {
	if( IsSurvivor(client) || IsGenericAdmin(client) ) {
		if( args == 1 ) {
			new String:sValue[32]; 
			GetCmdArg(1, sValue, sizeof(sValue));
			new iValue = StringToInt(sValue);
			if( iValue > 0 && iValue <= GetConVarInt(hCvarMaxSurvivors) ) {
				PlayerModeVote( client, iValue );
			} else {
				ReplyToCommand( client, "Command restricted to values from 1 to %d", GetConVarInt(hCvarMaxSurvivors) );
			}
		} else {
			ReplyToCommand( client, "Usage: playermode <value> [ 1 <= value <= %d", GetConVarInt(hCvarMaxSurvivors) );
		}
	} else {
		ReplyToCommand(client, "You do not have access to this command");
	}
}

PlayerModeVote( client, playerMode ) {
	if( !IsBuiltinVoteInProgress() ) {
		if( playerMode != GetConVarInt(FindConVar("survivor_limit")) ) {
			hPlayerModeVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
			g_iDesiredPlayerMode = playerMode;
			new String:voteText[32];
			Format( voteText, sizeof(voteText), "Switch to %d player?", playerMode );
			SetBuiltinVoteArgument(hPlayerModeVote, voteText );
			SetBuiltinVoteInitiator( hPlayerModeVote, client );
			SetBuiltinVoteResultCallback( hPlayerModeVote, VoteResultHandler);
			new iPlayerSurvivors[MaxClients];
			new iNumPlayerSurvivors = 0;
			for( new i = 1; i < MaxClients; i++ ) {
				if( IsSurvivor(i) && !IsFakeClient(i) ) {
					iPlayerSurvivors[iNumPlayerSurvivors] = i;
					iNumPlayerSurvivors++;
				}
			}
			DisplayBuiltinVote( hPlayerModeVote, iPlayerSurvivors, iNumPlayerSurvivors, 20 );
			FakeClientCommand( client, "Vote Yes" );
		} else {
			PrintToChat( client, "This playermode is already active" );
		}
	} 
}

public Action:VoteResultHandler( Handle:vote, int numVotes, int numClients, int clientInfo[][2], int numItems, int itemInfo[][2] ) {
	new bool:votePassed = false;
	for( new i = 0; i < numItems; i++ ) {
		if( itemInfo[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES ) {
			if( itemInfo[i][BUILTINVOTEINFO_ITEM_VOTES] > (numClients / 2) ) {
				if( g_iDesiredPlayerMode > GetConVarInt(FindConVar("survivor_limit")) ) {
					votePassed = true;
				} else {
					new numPlayerSurvivors = 0;
					for( new j = 1; j < MaxClients; j++ ) {
						if( IsSurvivor(j) && !IsFakeClient(j) ) {
							numPlayerSurvivors++;
						}
					}
					if( g_iDesiredPlayerMode >= numPlayerSurvivors ) {
						votePassed = true;
					} else {
						PrintToChatAll("Too many players to reduce survivor limit");
					}
				}
			}
		}
	}
	if( votePassed ) {
		LoadCvars( g_iDesiredPlayerMode );
		DisplayBuiltinVotePass(vote, "Changing player mode...");
	} else {
		DisplayBuiltinVoteFail(vote);
	}
}

LoadCvars( playerMode ) {
	LogMessage( "Loading cvars for playermode %d", playerMode );
	KvRewind( g_hCvarKV );
	new String:sPlayerMode[16];
	Format( sPlayerMode, sizeof(sPlayerMode), "%d", playerMode );
	if( KvJumpToKey(g_hCvarKV, sPlayerMode) ) {
		if( KvGotoFirstSubKey( g_hCvarKV ) ){
			do {
				new String:sCvarName[64];
				KvGetSectionName( g_hCvarKV, sCvarName, sizeof(sCvarName) );
				new String:sCvarType[64];
				KvGetString( g_hCvarKV, "type", sCvarType, sizeof(sCvarType) );
				// Set cvar according to type
				if( StrEqual(
					sCvarType, "int", false) ) {
					SetConVarInt( FindConVar(sCvarName), KvGetNum(g_hCvarKV, "value", -1) );
				} else if( StrEqual(sCvarType, "float", false) ) {
					SetConVarFloat( FindConVar(sCvarName), KvGetFloat(g_hCvarKV, "value", -1.0) );
				} else if( StrEqual(sCvarType, "string", false) ) {
					new String:stringValue[128];
					KvGetString( g_hCvarKV, "value", stringValue, sizeof(stringValue), "Invalid String" );
					SetConVarString( FindConVar(sCvarName), stringValue );
				} else {
					LogError( "Invalid cvar type %s given for %s", sCvarType, sCvarName );
				}

			} while( KvGotoNextKey(g_hCvarKV, true) );
		} else {
			PrintToChatAll("No integer cvar settings listed");
		}
	} else {
		PrintToChatAll( "No configs for player mode %d were found", playerMode );
		LogError("No configs for playermode %d were found", playerMode);
	}
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2) {
	switch (action) {
		case BuiltinVoteAction_End: {
			hPlayerModeVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}