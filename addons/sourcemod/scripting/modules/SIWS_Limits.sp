#pragma semicolon 1
#define DEBUG_LIMITS 0

// Custom SI limits (not the vanilla cvars)
new Handle:hCvarSmokerLimit;
new Handle:hCvarBoomerLimit;
new Handle:hCvarHunterLimit;
new Handle:hCvarSpitterLimit;
new Handle:hCvarJockeyLimit;
new Handle:hCvarChargerLimit;

// Wave interval limits
new Handle:hCvarWaveSizeMinLimit;
new Handle:hCvarWaveSizeMaxLimit;
new Handle:hCvarWaveTimeMaxInterval;
new Handle:hCvarWaveTimeMinInterval;

new g_LimitCache[7] =  { UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED };

Limits_OnModuleStart() {
	// SI limits
	hCvarSmokerLimit    = CreateConVar("siws_smoker_limit",     "0", "Max smokers per spawn wave");
	HookConVarChange(hCvarSmokerLimit, ConVarChanged:OnCvarChange);
	hCvarBoomerLimit    = CreateConVar("siws_boomer_limit",     "0", "Max boomers per spawn wave");
	HookConVarChange(hCvarBoomerLimit, ConVarChanged:OnCvarChange);
	hCvarHunterLimit    = CreateConVar("siws_hunter_limit",     "0", "Max hunters per spawn wave");
	HookConVarChange(hCvarHunterLimit, ConVarChanged:OnCvarChange);
	hCvarSpitterLimit   = CreateConVar("siws_spitter_limit",    "0", "Max spitters per spawn wave");
	HookConVarChange(hCvarSpitterLimit, ConVarChanged:OnCvarChange);
	hCvarJockeyLimit    = CreateConVar("siws_jockey_limit",     "0", "Max jockeys per spawn wave");
	HookConVarChange(hCvarJockeyLimit, ConVarChanged:OnCvarChange);
	hCvarChargerLimit   = CreateConVar("siws_charger_limit",    "0", "Max chargers per spawn wave");
	HookConVarChange(hCvarChargerLimit, ConVarChanged:OnCvarChange);	
	// Maximum allowed SI limits and wave interval
	hCvarWaveSizeMinLimit = CreateConVar("siws_minlimit", "0", "Set the overall SI's minimum Limit");
	hCvarWaveSizeMaxLimit = CreateConVar("siws_maxlimit", "15", "Set the overall SI's maximum Limit"); // Server allowed maximum; intended for admins
	hCvarWaveTimeMinInterval = CreateConVar("siws_mininterval",    "0", "Set the minimum interval between waves");
	hCvarWaveTimeMaxInterval = CreateConVar("siws_maxinterval",    "60", "Set the maximum interval between waves");
	// Console commands
	RegConsoleCmd("sm_limit", Cmd_Limit, "Set individual or total SI limits");
	RegConsoleCmd("sm_printlimits", Cmd_PrintLimits, "Print already set Limits");
	RegConsoleCmd("sm_resetlimits", Cmd_ResetLimits, "Set all limits to 0");
}

// Make sure limit changes do not break the configured boundaries
public OnCvarChange(Handle:cvar, const String:oldVal[], const String:newVal[]) {  
	// Sum SI limits
	new smokerLimit = GetConVarInt(hCvarSmokerLimit);
	new boomerLimit = GetConVarInt(hCvarBoomerLimit);
	new hunterLimit = GetConVarInt(hCvarHunterLimit);
	new spitterLimit = GetConVarInt(hCvarSpitterLimit);
	new jockeyLimit = GetConVarInt(hCvarJockeyLimit);
	new chargerLimit = GetConVarInt(hCvarChargerLimit);    
	new limitsTotal = smokerLimit + boomerLimit + hunterLimit + spitterLimit + jockeyLimit + chargerLimit;
	// Revert change if sum of limits is outside configured boundaries
	new minAllowedWaveSize = GetConVarInt(hCvarWaveSizeMinLimit);
	new maxAllowedWaveSize = GetConVarInt(hCvarWaveSizeMaxLimit);
	if( limitsTotal < minAllowedWaveSize || limitsTotal > maxAllowedWaveSize ) {
		SetConVarInt(cvar, StringToInt(oldVal));
		PrintToChatAll("Limit change was reverted as total special infected limit must be between %d and %d", minAllowedWaveSize, maxAllowedWaveSize);
	} 				
}

// Used to carry over between maps custom special infected class limits that override those set by the .cfg
// Sets the cvars to the values currently stored in the limit cache
SetLimits() {
    for( new i = 1; i < _:ZC_WITCH; ++i ) {
        if( g_LimitCache[i] != UNINITIALISED ) {
			switch( ZOMBIECLASS:i ) {
                case ZC_SMOKER:SetConVarInt(hCvarSmokerLimit, g_LimitCache[i]); 
                case ZC_BOOMER:SetConVarInt(hCvarBoomerLimit, g_LimitCache[i]);
                case ZC_HUNTER:SetConVarInt(hCvarHunterLimit, g_LimitCache[i]);
                case ZC_SPITTER:SetConVarInt(hCvarSpitterLimit, g_LimitCache[i]);
                case ZC_JOCKEY:SetConVarInt(hCvarJockeyLimit, g_LimitCache[i]);
                case ZC_CHARGER:SetConVarInt(hCvarChargerLimit, g_LimitCache[i]);
                default:break;
            }
        }
    }   
}

// Prints the limit for total special infected and each individual class
PrintSettings() {
	new String:limits[256];
	Client_PrintToChatAll(true, "Server SI limit{N}: {G}%d",   GetConVarInt(hCvarWaveSizeMaxLimit));
	Client_PrintToChatAll( true, "{O}Hunters {N}| {O}Smokers {N}| {O}Jockeys {N}| {O}Chargers {N}| {O}Boomers {N}| {O}Spitters{N}" );
	Format(limits, sizeof(limits), "{G}%d            {N}| {G}%d             {N}| {G}%d            {N}| {G}%d             {N}| {G}%d             {N}| {G}%d", 
	    GetConVarInt(hCvarHunterLimit),
	    GetConVarInt(hCvarSmokerLimit),
	    GetConVarInt(hCvarJockeyLimit),
	    GetConVarInt(hCvarChargerLimit),
	    GetConVarInt(hCvarBoomerLimit),
	    GetConVarInt(hCvarSpitterLimit) 
	);
	Client_PrintToChatAll(true, limits);
	Client_PrintToChatAll(true, "{O}Wave Interval: {G}%ds", GetConVarInt(FindConVar("siws_wave_interval")) );
}

/***********************************************************************************************************************************************************************************

                                                                               LIMIT CHECKING
                                                                    
***********************************************************************************************************************************************************************************/

//@return: true if the max number of special infected have spawned
bool:IsMaxSpecialInfectedLimitReached() {
    // Checking max specials limit
    new iMaxSpecials = GetConVarInt(FindConVar("siws_maxlimit"));
    new iSpawnedSpecialsCount = CountSpecialInfectedBots();
    return iSpawnedSpecialsCount < iMaxSpecials ? false : true;
}

//@return: true if the target SI class population limit has reached its limit
bool:IsClassLimitReached(ZombieClass:targetClass) {
    // Checking class limit
    new iClassLimit = GetClassLimit(targetClass);
    new iClassCount = CountSpecialInfectedClass(targetClass);
    return iClassCount < iClassLimit ? false : true;
}

// @return: true if either the class limit or total specials limit has been reached
GetClassLimit(ZombieClass:targetClass) {
    new iClassLimit;
    switch (targetClass) {
        case ZC_SMOKER:iClassLimit = GetConVarInt(hCvarSmokerLimit);
        case ZC_BOOMER:iClassLimit = GetConVarInt(hCvarBoomerLimit);
        case ZC_HUNTER:iClassLimit = GetConVarInt(hCvarHunterLimit);
        case ZC_SPITTER:iClassLimit = GetConVarInt(hCvarSpitterLimit);
        case ZC_JOCKEY:iClassLimit = GetConVarInt(hCvarJockeyLimit);
        case ZC_CHARGER:iClassLimit = GetConVarInt(hCvarChargerLimit);
        default:iClassLimit = 0;
    }
    return iClassLimit;
}

/***********************************************************************************************************************************************************************************

                                                                                COMMANDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_PrintLimits(client, args) {
	PrintSettings();
}

public Action:Cmd_ResetLimits(client, args) {
	if(L4D2_Team:GetClientTeam(client) != L4D2_Team:L4D2Team_Survivor) {
		PrintToChat(client, "Command only available to survivor team");
		return Plugin_Handled;
	} else {
		SetConVarInt(hCvarChargerLimit, 0);
		g_LimitCache[_:ZC_CHARGER] = 0;
		SetConVarInt(hCvarJockeyLimit, 0);
		g_LimitCache[_:ZC_JOCKEY] = 0;
		SetConVarInt(hCvarHunterLimit, 0);
		g_LimitCache[_:ZC_HUNTER] = 0;
		SetConVarInt(hCvarSmokerLimit, 0);
		g_LimitCache[_:ZC_SMOKER] = 0;
		SetConVarInt(hCvarSpitterLimit, 0);
		g_LimitCache[_:ZC_SPITTER] = 0;
		SetConVarInt(hCvarBoomerLimit, 0);
		g_LimitCache[_:ZC_BOOMER] = 0;
		Client_PrintToChatAll(true, "-> All limits have been set to {G}0");
		return Plugin_Changed;     
	}
}

public Action:Cmd_Limit(client, args) {
	if(L4D2_Team:GetClientTeam(client) != L4D2_Team: L4D2Team_Survivor && !IsGenericAdmin(client) ) {
		PrintToChat(client, "Command only available to survivor team");
	} else {
		if (args == 2) {
			// Read in the SI class
			new String:sTargetClass[32];
			GetCmdArg(1, sTargetClass, sizeof(sTargetClass));

			// Read in limit value 
			new String:sLimitValue[32];     
			GetCmdArg(2, sLimitValue, sizeof(sLimitValue));
			new iLimitValue = StringToInt(sLimitValue);      
			if( iLimitValue < 0 ) {
				PrintToChat(client, "Limit value must be >= 0");
				return Plugin_Handled;
			}
			
            // Apply limit value to appropriate class
			if(StrEqual(sTargetClass, "max", false)) {  // Max specials
				// Server SI limit restricted to admins
				if( CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false) ) {
					if(StrEqual(sTargetClass, "max", false)) {
						SetConVarInt(hCvarWaveSizeMaxLimit, iLimitValue);    
						g_LimitCache[_:ZC_NONE] = iLimitValue;
						Client_PrintToChatAll(true, "-> {O}Wave size server limit set to {G}%i", iLimitValue);
						return Plugin_Changed;
					}         
				} else {
					PrintToChat(client, "Only admins can change the server SI limit");
				}				           
			} else if (StrEqual(sTargetClass, "smoker", false)) {  // Smoker limit 
			        SetConVarInt(hCvarSmokerLimit, iLimitValue);
			        g_LimitCache[_:ZC_SMOKER] = iLimitValue;
			        Client_PrintToChatAll(true, "-> {O}Smoker {N}limit set to {G}%i", iLimitValue);
			        return Plugin_Changed;   
			} else if (StrEqual(sTargetClass, "boomer", false)) { // Boomer limit
			        SetConVarInt(hCvarBoomerLimit, iLimitValue);
			        g_LimitCache[_:ZC_BOOMER] = iLimitValue;
			        Client_PrintToChatAll(true, "-> {O}Boomer {N}limit set to {G}%i", iLimitValue);
			        return Plugin_Changed;  
			} else if (StrEqual(sTargetClass, "hunter", false)) { // Hunter limit
			        SetConVarInt(hCvarHunterLimit, iLimitValue);
			        g_LimitCache[_:ZC_HUNTER] = iLimitValue;
			        Client_PrintToChatAll(true, "-> {O}Hunter {N}limit set to {G}%i", iLimitValue);
			        return Plugin_Changed;        
			} else if (StrEqual(sTargetClass, "spitter", false)) { // Spitter limit 
			        SetConVarInt(hCvarSpitterLimit, iLimitValue);
			        g_LimitCache[_:ZC_SPITTER] = iLimitValue;
			        Client_PrintToChatAll(true, "-> {O}Spitter {N}limit set to {G}%i", iLimitValue);
			        return Plugin_Changed;    
			} else if (StrEqual(sTargetClass, "jockey", false)) {  // Jockey limit
			        SetConVarInt(hCvarJockeyLimit, iLimitValue);
			        g_LimitCache[_:ZC_JOCKEY] = iLimitValue;
			        Client_PrintToChatAll(true, "-> {O}Jockey {N}limit set to {G}%i", iLimitValue);
			        return Plugin_Changed;   
			} else if (StrEqual(sTargetClass, "charger", false)) { // Charger limit                   
			        SetConVarInt(hCvarChargerLimit, iLimitValue);
			        g_LimitCache[_:ZC_CHARGER] = iLimitValue;
			        Client_PrintToChatAll(true, "-> {O}Charger {N}limit set to {G}%i", iLimitValue);
			        return Plugin_Changed;                   
			} else { // Invalid class name
				Client_PrintToChat(client, true, "{O}%s {N}is an invalid SI class", sTargetClass);
			}           
		} else {  // Invalid command syntax
			Client_PrintToChat(client, true, "Set limit : {O}!limit/sm_limit {B}<class> <limit>");
			Client_PrintToChat(client, true, "{B}<class> {N}= max | smoker | boomer | hunter | spitter | jockey | charger");
			Client_PrintToChat(client, true, "{B}<limit>: {N}Greater than 0");
        }
	}
	return Plugin_Handled;  
}