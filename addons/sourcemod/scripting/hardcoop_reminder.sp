#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <colors>
#include "includes/hardcoop_util.sp"

public Plugin:myinfo = 
{
	name = "Hardcoop Reminder",
	author = "Rurouni, Breezy",
	description = "Prints welcome message and period reminder messages to inform players of available commands",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	CreateTimer(250.0, Timer_Hint, _, TIMER_REPEAT);
	RegConsoleCmd("sm_gauntlethelp", Cmd_ShowHelp, "Display the help menu");
}

public OnClientPostAdminCheck(client) {
    CreateTimer(15.0, Timer_Welcome, client);
}

/***********************************************************************************************************************************************************************************

                                                                               SERVER MESSAGES
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_ShowHelp( client, args ) {
	if( IsValidClient(client) && !IsFakeClient(client) ) {
		ShowHelpMenu(client);
	}
}

public Action:Timer_Welcome(Handle:timer, any:client) {
	ShowHelpMenu(client);	
	return Plugin_Handled;
}

public ShowHelpMenu(client) {
	decl String:heading[255];
	decl String:limitcmd[255], String:weightcmd[255], String:timercmd[255];
	decl String:bosscmds[255], String:spawnmode[255];
	decl String:playerMode[255], String:joinSurvivors[255], String:spawnedDead[255], String:spawnedOutOfSaferoom[255];
	decl String:misc[255];
	
	new Handle:WelcomePanel = CreatePanel(INVALID_HANDLE);
	
	// Heading
	Format(heading, sizeof(heading), "=====+ GAUNTLET HELP (Any NumKey to close) +=====");
	SetPanelTitle(WelcomePanel, heading);
	DrawPanelText(WelcomePanel, "Fully customisable SI difficulty!");
	DrawPanelText(WelcomePanel, " \n");

	// SI commands
	Format(limitcmd, sizeof(limitcmd), "!limit < all | max | group | class > - SI limits");
	DrawPanelText(WelcomePanel, limitcmd);
	Format(weightcmd, sizeof(weightcmd), "!weight < all | class | reset > - SI weights");
	DrawPanelText(WelcomePanel, weightcmd);
	Format(timercmd, sizeof(timercmd), "!timer <constant> || !timer <min> <max>" );
	DrawPanelText(WelcomePanel, timercmd);
	// Boss commands
	Format(bosscmds, sizeof(bosscmds), "!toggletank, !witch < limit | period | mode >");
	DrawPanelText(WelcomePanel, bosscmds);
	// SpawnModes
	Format(spawnmode, sizeof(spawnmode), "!spawnmode <value> - (0=Vanilla, 1=Radial, 2=Grid)");
	DrawPanelText(WelcomePanel, spawnmode);
	DrawPanelText(WelcomePanel, " \n"); // empty line to separate sections
	
	// Survivor commands
	Format(playerMode, sizeof(playerMode), "!playermode <value> -> add or remove survivors");
	DrawPanelText(WelcomePanel, playerMode);
	Format(joinSurvivors, sizeof(joinSurvivors), "!join , !spectate -> survivor team");
	DrawPanelText(WelcomePanel, joinSurvivors);
	Format(spawnedDead, sizeof(spawnedDead), "!respawn -> respawn (spawned dead)");
	DrawPanelText(WelcomePanel, spawnedDead);	
	Format(spawnedOutOfSaferoom, sizeof(spawnedOutOfSaferoom), "!return -> teleport to saferoom (spawned out of the world)");
	DrawPanelText(WelcomePanel, spawnedOutOfSaferoom);
	DrawPanelText(WelcomePanel, " \n"); // empty line to separate sections
	
	// Miscellaneous commands
	Format(misc, sizeof(misc), "!pillpercent, !toggleretry, !give scout, !give awp");
	DrawPanelText(WelcomePanel, misc);
	DrawPanelText(WelcomePanel, " \n"); // empty line to separate sections
	
	SendPanelToClient(WelcomePanel, client, NullMenuHandler, 60);
	CloseHandle(WelcomePanel);
}

public Action:Timer_Hint(Handle:timer) {
	CPrintToChatAll("Press {olive}USE {default}and {olive}RELOAD {default}to show {blue}Spawner HUD {default}for 3s. Type {red}!gauntlethelp {default}to show command menu");
}

public NullMenuHandler(Handle:menu, MenuAction:action, param1, param2) {}