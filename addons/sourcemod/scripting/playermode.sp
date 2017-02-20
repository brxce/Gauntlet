#pragma semicolon 1
#define DEBUG 0

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include "includes/hardcoop_util.sp"

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
	// Initialise
	switch( GetConVarInt(FindConVar("survivor_limit")) ) {
		case 1: OnePlayerMode();
		case 2: TwoPlayerMode();
		case 3: ThreePlayerMode();
		case 4: FourPlayerMode();
		default: FourPlayerMode();
	}
	SetConVarBool( FindConVar("l4d_ready_enabled"), true );
	SetConVarString( FindConVar("l4d_ready_cfg_name"), "Gauntlet" );
}

public OnPluginEnd() {
	SetConVarBool( FindConVar("l4d_ready_enabled"), false );
	// Survivors
	ResetConVar( FindConVar("survivor_limit") );
	ResetConVar( FindConVar("confogl_pills_limit") );
	ResetConVar( FindConVar("survivor_ledge_grab_health") );
	ResetConVar( FindConVar("survivor_max_incapacitated_count") );
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
			new iNumPlayerSurvivors;
			for( new i = 1; i < MaxClients; i++ ) {
				if( IsSurvivor(i) && !IsFakeClient(i) ) {
					iPlayerSurvivors[iNumPlayerSurvivors] = i;
					iNumPlayerSurvivors++;
				}
			}
			DisplayBuiltinVote( hPlayerModeVote, iPlayerSurvivors, iNumPlayerSurvivors, 20 );
		} else {
			PrintToChat( client, "This playermode is already active" );
		}
	} 
}

public VoteResultHandler( Handle:vote, numVotes, numClients, const clientInfo[][2], numItems, const itemInfo[][2] ) {
	new bool:votePassed = false;
	for( new i = 0; i < numItems; i++ ) {
		if( itemInfo[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES ) {
			if( itemInfo[i][BUILTINVOTEINFO_ITEM_VOTES] > (numClients / 2) ) {
				if( g_iDesiredPlayerMode > GetConVarInt(FindConVar("survivor_limit")) ) {
					switch( g_iDesiredPlayerMode ) {
						case 2: TwoPlayerMode();
						case 3: ThreePlayerMode();
						case 4: FourPlayerMode();
						default: {
							FourPlayerMode();
							SetConVarInt( FindConVar("survivor_limit"), g_iDesiredPlayerMode );
						}
					} 
					DisplayBuiltinVotePass(vote, "Changing player mode...");
					votePassed = true;
				} else {
					new numPlayerSurvivors = 0;
					for( new j = 1; j < MaxClients; j++ ) {
						if( IsSurvivor(j) && !IsFakeClient(j) ) {
							numPlayerSurvivors++;
						}
					}
					if( numPlayerSurvivors <= g_iDesiredPlayerMode ) {
						switch( g_iDesiredPlayerMode ) {
							case 1: OnePlayerMode();
							case 2: TwoPlayerMode();
							case 3: ThreePlayerMode();
							case 4: FourPlayerMode();
							default: FourPlayerMode();
						}
						DisplayBuiltinVotePass(vote, "Changing player mode...");
						votePassed = true;
					} else {
						PrintToChatAll("Too many players to reduce survivor limit");
					}
				}
			}
		}
	}
	if( !votePassed ) {
		DisplayBuiltinVoteFail(vote);
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

OnePlayerMode() {
	// Survivors
	SetConVarInt( FindConVar("survivor_limit"), 1 );
	SetConVarInt( FindConVar("confogl_pills_limit"), 2 );
	// Common and SI
	SetCommonCvars( 5, 3, 3, 5 );
	SetSICvars( 1500, 10, 10, 0.1 );
	SetSIQuantities( 4, 2, 0, 0, 4, 0, 0, 0 );
	SetConVarBool( FindConVar("flow_tank_enable"), false );
	// Autoslayer
	SetConVarFloat( FindConVar("autoslayer_teamclear_delay"), 0.1 );
	SetConVarBool( FindConVar("autoslayer_slay_all_infected"), false );
}

TwoPlayerMode() {
	// Survivors
	SetConVarInt( FindConVar("survivor_limit"), 2 );
	SetConVarInt( FindConVar("confogl_pills_limit"), 4 );
	ResetConVar( FindConVar("survivor_ledge_grab_health") );
	ResetConVar( FindConVar("survivor_max_incapacitated_count") );
	// Common and SI
	SetCommonCvars( 10, 3, 3, 8 );
	SetSICvars( 3000, 1, 2, 1.0 );
	SetSIQuantities( 5, 3, 1, 0, 2, 0, 1, 2 );
	SetConVarBool( FindConVar("flow_tank_enable"), false );
	// Autoslayer
	SetConVarFloat( FindConVar("autoslayer_teamclear_delay"), 3.0 );
	SetConVarBool( FindConVar("autoslayer_slay_all_infected"), true );
}

ThreePlayerMode() {
	// Survivors
	SetConVarInt( FindConVar("survivor_limit"), 3 );
	SetConVarInt( FindConVar("confogl_pills_limit"), 6 );
	ResetConVar( FindConVar("survivor_ledge_grab_health") );
	ResetConVar( FindConVar("survivor_max_incapacitated_count") );
	// Common and SI
	SetCommonCvars( 15, 10, 10, 12 );
	SetSICvars( 4500, 1, 2, 1.0 );
	SetSIQuantities( 6, 4, 2, 2, 4, 0, 1, 2 );
	SetConVarBool( FindConVar("flow_tank_enable"), true );
	// Autoslayer
	SetConVarFloat( FindConVar("autoslayer_teamclear_delay"), 3.0 );
	SetConVarBool( FindConVar("autoslayer_slay_all_infected"), true );
}

FourPlayerMode() {
	// Survivors
	SetConVarInt( FindConVar("survivor_limit"), 4 );
	SetConVarInt( FindConVar("confogl_pills_limit"), 8 );
	ResetConVar( FindConVar("survivor_ledge_grab_health") );
	ResetConVar( FindConVar("survivor_max_incapacitated_count") );
	// Common and SI
	SetCommonCvars( 20, 13, 13, 15 );
	SetSICvars( 6000, 1, 2, 1.0 );
	SetSIQuantities( 8, 5, 2, 1, 5, 0, 2, 2 );
	SetConVarBool( FindConVar("flow_tank_enable"), true);
	// Autoslayer
	SetConVarFloat( FindConVar("autoslayer_teamclear_delay"), 3.0 );
	SetConVarBool( FindConVar("autoslayer_slay_all_infected"), true );
}

SetCommonCvars( commonLimit, mobMin, mobMax, megaMob ) {
	SetConVarInt( FindConVar("z_common_limit"), commonLimit );
	SetConVarInt( FindConVar("z_mob_spawn_min_size"), mobMin );
	SetConVarInt( FindConVar("z_mob_spawn_max_size"), mobMax );
	SetConVarInt( FindConVar("z_mega_mob_size"), megaMob );
}

SetSICvars( tankHealth, jockeyPounceDmg, hunterPounceDmg, Float:hunterDmgDelay ) {
	SetConVarInt( FindConVar("z_tank_health"), tankHealth );
	SetConVarInt( FindConVar("z_jockey_ride_damage"), jockeyPounceDmg );
	SetConVarInt( FindConVar("z_pounce_damage"), hunterPounceDmg );
	SetConVarFloat( FindConVar("z_pounce_damage_delay"), hunterDmgDelay );
}

SetSIQuantities( max, group, smoker, boomer, hunter, spitter, jockey, charger ) {
	SetConVarInt( FindConVar("ss_si_limit"), max );
	SetConVarInt( FindConVar("ss_spawn_size"), group );
	SetConVarInt( FindConVar("ss_smoker_limit"), smoker );
	SetConVarInt( FindConVar("ss_boomer_limit"), boomer );
	SetConVarInt( FindConVar("ss_hunter_limit"), hunter );
	SetConVarInt( FindConVar("ss_spitter_limit"), spitter );
	SetConVarInt( FindConVar("ss_jockey_limit"), jockey );
	SetConVarInt( FindConVar("ss_charger_limit"), charger );
}