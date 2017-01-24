#pragma semicolon 1

new Handle:hCvarTongueDelay;
new Handle:hCvarSmokerHealth;
new Handle:hCvarChokeDamageInterrupt;

public Smoker_OnModuleStart() {
	 // Smoker health
    hCvarSmokerHealth = FindConVar("z_gas_health");
    HookConVarChange(hCvarSmokerHealth, ConVarChanged:OnSmokerHealthChanged); 
    
    // Damage required to kill a smoker that is pulling someone
    hCvarChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); 
    SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth)); // default 50
    HookConVarChange(hCvarChokeDamageInterrupt, ConVarChanged:OnTongueCvarChange);    
    // Delay before smoker shoots its tongue
    hCvarTongueDelay = FindConVar("smoker_tongue_delay"); 
    SetConVarFloat(hCvarTongueDelay, 0.5); // default 1.5
    HookConVarChange(hCvarTongueDelay, ConVarChanged:OnTongueCvarChange);
}

public Smoker_OnModuleEnd() {
	ResetConVar(hCvarChokeDamageInterrupt);
	ResetConVar(hCvarTongueDelay);
}

// Game tries to reset these cvars
public OnTongueCvarChange() {
	SetConVarFloat(hCvarTongueDelay, 0.5);	
	SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
}

// Update choke damage interrupt to match smoker max health
public Action:OnSmokerHealthChanged() {
	SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
}