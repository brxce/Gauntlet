#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	
}

// smoker_escape_range? 
// boomer_exposed_time_tolerance 100000

// kill smokers, spitters and boomers if they have not had continuous survivor los for a certain period of time
