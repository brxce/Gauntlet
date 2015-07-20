#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <readyup>

new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:sdkSetBuffer = INVALID_HANDLE;
new entStartDoor;

public Plugin:myinfo =
{
	name = "Hard 12 - Manager",
	author = "Standalone",
	description = "Manages some things to do with Hard Cookie's Hard 12.",
	version = "1.0",
	url = ""
};

public OnPluginStart()
{
	HookEvent("round_end", Event_RoundEnd);	

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

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("==== ROUND END");
}

GetEntitySafeRoomDoor(){
	decl String:sClassname[] = "prop_door_rotating_checkpoint";
	new door_start = -1;
	new index = -1;
	while((index = FindEntityByClassname(index, sClassname)) != -1){
		if(GetEntProp(index, Prop_Data, "m_bLocked") > 0){
			door_start = index;
		}
	}
	entStartDoor = door_start;
}

public OnRoundStart()
{
	GiveStartingItems();
	return Plugin_Continue;
}

/*
public Action:L4D_OnFirstSurvivorLeftSafeArea()
{
	if (IsInReady())
	{
		PrintToServer("==== Still in Ready mode");
		return Plugin_Handled;
	}
	GiveStartingItems();
	return Plugin_Continue;
}
*/

public GiveStartingItems()
{
	PrintToServer("==== Giving starting items");
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2)
		{
			if (GetPlayerWeaponSlot(client, 5) == -1) 
			{
				GiveItem(client, "pain_pills");
			}
			decl String:name[63]
			GetClientName(client, name, sizeof(name));
			PrintToServer("==== Giving %s health", name);
			
			GiveItem(client, "health");
			
			new Float:buffhp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
			if (buffhp > 0.0)
			{
				PrintToServer("==== Player %s has %f buffer HP", name, buffhp);
				SetTempHealth(client, 0.0);
				PrintToServer("==== Player %s has had buffer HP removed", name);
			}
		}
	}
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
