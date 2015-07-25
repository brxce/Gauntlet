#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <left4downtown>

new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:sdkSetBuffer = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "Versus like coop",
	author = "Standalone; modified by Breezy",
	description = "Start maps in coop with full health, pills and a single pistol",
	version = "1.0",
	url = ""
};

public OnPluginStart()
{
	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnMapEnd, EventHookMode_Pre);
	
	g_hGameConf = LoadGameConfigFile("l4d2customcmds");
	if(g_hGameConf == INVALID_HANDLE)
	{
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	}	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer_SetHealthBuffer");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkSetBuffer = EndPrepSDKCall();
	if(sdkSetBuffer == INVALID_HANDLE)
	{
		SetFailState("Unable to find the \"CTerrorPlayer::SetHealthBuffer(float)\" signature, check the file version!");
	}
}

public OnRoundStart()
{
	GiveHealth();
	return Plugin_Continue;
}

public Action:L4D_OnFirstSurvivorLeftSafeArea()
{
	GiveStartingItems();
	return Plugin_Continue;
}

public OnMapEnd()
{
	//ConfiscateItems();
}

public GiveHealth()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2)
		{
			decl String:name[63]
			GetClientName(client, name, sizeof(name));
			
			GiveItem(client, "health"); //give full health			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0) //remove temp hp
			{
				PrintToServer("==== Player %s has %f buffer HP", name, buffhp);
				SetTempHealth(client, 0.0); 
				PrintToServer("==== Player %s has had buffer HP removed", name);
			}
		}
	}
}

public GiveStartingItems()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2)
		{
			decl String:name[63]
			GetClientName(client, name, sizeof(name));
			
			if (GetPlayerWeaponSlot(client, 5) == -1) 
			{
				GiveItem(client, "pain_pills"); //pills
			}								
		}
	}
}

public ConfiscateItems()
{
	//Remove survivors' guns, melees and health items and give them a single pistol each 
}

GiveItem(client, String:Item[22])
{
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", Item);
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}

stock SetTempHealth(client, Float:amount)
{
	SDKCall(sdkSetBuffer, client, amount);
}
