#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <smlib>

public Plugin:myinfo = 
{
	name = "Hardcoop Reminder",
	author = "Rurouni, Breezy",
	description = "Prints welcome message and period reminder messages to inform players of available commands",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	CreateTimer(300.0, Timer_Hint, _, TIMER_REPEAT);
}

public OnClientPostAdminCheck(client) {
    CreateTimer(15.0, Timer_Welcome, client);
}

/***********************************************************************************************************************************************************************************

                                                                               SERVER MESSAGES
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Timer_Welcome(Handle:timer, any:client)
{
	decl String:message1[255], String:message2[255], String:message3[255], String:message4[255], String:message5[255], String:message6[255], String:message7[255];
	decl String:closepanel[255];
	
	new Handle:WelcomePanel = CreatePanel(INVALID_HANDLE);
	
	Format(message1, sizeof(message1), "=====+ Before You Start +=====");
	SetPanelTitle(WelcomePanel, message1);
	
	Format(message3, sizeof(message3), "Print Limits: !printlimits");
	DrawPanelText(WelcomePanel, message3);
	
	Format(message6, sizeof(message6), "All SI limits to 0: !resetlimits");
	DrawPanelText(WelcomePanel, message6);
	
	Format(message4, sizeof(message4), "SI limits: !limit <class> <limit>");
	DrawPanelText(WelcomePanel, message4);
	
	Format(message5, sizeof(message5), "Spawn frequency: !waveinterval <time(seconds)>");
	DrawPanelText(WelcomePanel, message5);
	
	Format(message2, sizeof(message2), "Skip to next map upon team death: !toggleretry");
	DrawPanelText(WelcomePanel, message2);
	
	Format( message7, sizeof(message7), "Server SI limit: %d", GetConVarInt(FindConVar("siws_maxlimit")) );
	DrawPanelText(WelcomePanel, message7);
	
	Format(closepanel, sizeof(closepanel), "Press '5' to close");
	DrawPanelText(WelcomePanel, closepanel);
	
	SendPanelToClient(WelcomePanel, client, NullMenuHandler, 60);
	CloseHandle(WelcomePanel);
	
	return Plugin_Handled;
}

public Action:Timer_Hint(Handle:timer) {
	Client_PrintToChatAll(true, "Join survivors: {O}!join");
	Client_PrintToChatAll(true, "Spawned dead: {O}!respawn");
	Client_PrintToChatAll(true, "Spawned out of saferoom: {O}!return");
	Client_PrintToChatAll(true, "Secondary pills: {O}!pillpercent {B}<%%map>");
	Client_PrintToChatAll(true, "Toggle mapskipper: {O}!toggleretry");
	Client_PrintToChatAll(true, "Print limits: {O}!printlimits");
	Client_PrintToChatAll(true, "All SI limits to {G}0: {O}!resetlimits");
	Client_PrintToChatAll(true, "Set limits: {O}!limit {B}<class> <limit>");
	Client_PrintToChatAll(true, "Wave Interval: {O}!waveinterval {B}<time(seconds)>");
}

public NullMenuHandler(Handle:menu, MenuAction:action, param1, param2) 
{
}