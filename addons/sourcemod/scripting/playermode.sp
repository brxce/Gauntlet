#pragma semicolon 1
#define DEBUG 0
#define CVARS_PATH "configs/playermode_cvars.txt"

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <nativevotes>
#include "includes/hardcoop_util.sp"

new Handle:hCvarMaxSurvivors;

int g_iPlayerMode = 4;

public Plugin:myinfo = 
{
	name = "Player Mode",
	author = "breezy",
	description = "Allows survivors to change the team limit and adapts gameplay cvars to these changes",
	version = "2.0",
	url = ""
};

public OnPluginStart() {
	hCvarMaxSurvivors = CreateConVar( "pm_max_survivors", "8", "Maximum number of survivors allowed in the game" );
	RegConsoleCmd( "sm_playermode", Cmd_PlayerMode, "Change the number of survivors and adapt appropriately" );
	
	decl String:sGameFolder[128];
	GetGameFolderName( sGameFolder, sizeof(sGameFolder) );
	if( !StrEqual(sGameFolder, "left4dead2", false) ) {
		SetFailState("Plugin supports Left 4 dead 2 only!");
	} 
}

public OnPluginEnd() {
	ResetConVar( FindConVar("survivor_limit") );
	if ( FindConVar("confogl_pills_limit") != INVALID_HANDLE ) 
	{
		ResetConVar(FindConVar("confogl_pills_limit"));	
	}
}

public Action Cmd_PlayerMode(int client, int args) {	
	if( IsSurvivor(client) || IsGenericAdmin(client) ) {
		if( args == 1 ) {
			new String:sValue[32]; 
			GetCmdArg(1, sValue, sizeof(sValue));
			new iValue = StringToInt(sValue);
			if( iValue > 0 && iValue <= GetConVarInt(hCvarMaxSurvivors) ) 
			{
				if (!NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
				{
					ReplyToCommand(client, "Game does not support Custom Yes/No votes.");
					return Plugin_Handled;
				}
				
				if (!NativeVotes_IsNewVoteAllowed())
				{
					new seconds = NativeVotes_CheckVoteDelay();
					ReplyToCommand(client, "Vote is not allowed for %d more seconds", seconds);
				}
				
				new Handle:vote = NativeVotes_Create(YesNoHandler, NativeVotesType_Custom_YesNo);
				g_iPlayerMode = iValue;
				NativeVotes_SetInitiator(vote, client);
				char voteStimulus[64];
				Format(voteStimulus, sizeof(voteStimulus), "Change to %d player mode?", iValue);
				NativeVotes_SetDetails(vote, voteStimulus);
				NativeVotes_DisplayToAll(vote, 30);
			} else {
				ReplyToCommand( client, "Command restricted to values from 1 to %d", GetConVarInt(hCvarMaxSurvivors) );
			}
		} else {
			ReplyToCommand( client, "Usage: playermode <value> [ 1 <= value <= %d", GetConVarInt(hCvarMaxSurvivors) );
		}
	} else {
		ReplyToCommand(client, "You do not have access to this command");
	}
	return Plugin_Handled;
}

public YesNoHandler(Handle:vote, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else
			{
				char msgVoteSuccess[64];
				Format(msgVoteSuccess, sizeof(msgVoteSuccess), "Changing to %d playermode!", g_iPlayerMode);
				NativeVotes_DisplayPass(vote, msgVoteSuccess);
				SetConVarInt(FindConVar("survivor_limit"), g_iPlayerMode);
				if ( FindConVar("confogl_pills_limit")  != INVALID_HANDLE )
				{
					SetConVarInt(FindConVar("confogl_pills_limit"), g_iPlayerMode);	
				}
			}
		}
	}
}

/**************************************************************************************

Fallback using vanilla sourcemod functions - still missing implementation of MenuAction_End
									
**************************************************************************************

public Action Cmd_PlayerMode(int client, int args) {	
	if( IsSurvivor(client) || IsGenericAdmin(client) ) {
		if( args == 1 ) {
			new String:sValue[32]; 
			GetCmdArg(1, sValue, sizeof(sValue));
			new iValue = StringToInt(sValue);
			if( iValue > 0 && iValue <= GetConVarInt(hCvarMaxSurvivors) ) {
				g_iVoteNumbers = 0; // may have been previous vote
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

PlayerModeVote(int client, int playermode)
{
	// Display vote menu
	Menu MenuVote = new Menu(MenuHandler_VotePlayermode, MENU_ACTIONS_ALL);
	MenuVote.SetTitle("Vote playermode", LANG_SERVER);
	char sPlayermode[8];
	Format(sPlayermode, sizeof(sPlayermode), "Playermode %d", playermode);
	MenuVote.AddItem("desiredplayermode", sPlayermode);
	MenuVote.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_VotePlayermode(Menu VoteMenu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Start:
		{
			PrintToServer("Displaying menu");
		}
		// How the menu should look for each client
		case MenuAction_Display: // param1 is the client
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "Vote for playermode"); 
			
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
			PrintToServer("Client %d was sent menu with panel %x", param1, param2);
		}
		case MenuAction_Select: // param1 is the client, param2 is the item number to use for GetMenuItem
		{
			char info[32];
			VoteMenu.GetItem(param2, info, sizeof(info)); 
			if (StrEqual(info, "desiredplayermode"))
			{
				++g_iVoteNumbers;
			}
			else
			{
				PrintToServer("Client %d voted against the proposed playermode", param1);
			}
		}
		case MenuAction_DrawItem: // param1 is the client, param2 is the item number for use with GetMenuItem
		{
			int style;
			char info[32];
			VoteMenu.GetItem(param2, info, sizeof(info), style);
			return style;
		}
		case MenuAction_Cancel: // param1 is the client, param2 is the MenuCancel reason
		{
			PrintToServer("Client %d's menu was cancelled for reason %d", param1, param2);
		}
		case MenuAction_End: // param1 is the MenuEnd reason - if MenuCancel -> param2 is MenuCancel reason
		{
			int numPlayerSurvivors = 0;
			for ( int i = 1; i < MAXPLAYERS + 1; ++i )
			{
				if ( IsValidClient(i) && L4D2_Team:GetClientTeam(i) == L4D2Team_Survivor && !IsFakeClient(i) ) 
				{
					++numPlayerSurvivors;
				}
			}
			
			if ( (g_iVoteNumbers * 2) >= numPlayerSurvivors )
			{
				PrintToServer("Playermode vote successful!");
				
				//**********************************************************************************************************************
				//
				// Set playermode here
				//
				//************************************************************************************************************************
			}
			else
			{
				PrintToServer("Playermode vote failed!");
			}
			delete VoteMenu;
		}
	}
	return 0;
}

*/