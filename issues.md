# ISSUES
Baker's Dozen

//---------
///Bugs////
//---------------------------------------------------------------------------------------------------
[-] Pills
	- On any round following a wipe, pills are not given to survivors
[-] tank MVP % incorrect?
[-] playerstats rollover after wipe until successful map completion
[-] guns changing in the saferoom, or being put in twice (confoglcompmod vs campaign issue?)
[-] plugin load order might be incorrect or badly ordered 

//------------------
///Potential future features///
//---------------------------------------------------------------------------------------------------
[-] Decreased spawn radius cvar - might help with holdout finales
[-] Map skip option
[-] confogl_addcvar set_safe_spawn_range 0
[-] adjust Weapon capacity
[-] Consistent tank support timing
[-] Delay first hit of SI
[-] Fix Cookie's plugin
[-] Health bonus calculation upon completion of a map
[-] Accurate tank and witch percentage
[-] Confogl health items
[-] Start rounds like versus
	1:26 AM - High Cookie: AcceptEntityInput(entity, "kill");
	1:27 AM - High Cookie: that deletes the gun
	1:27 AM - High Cookie: new entity = GetPlayerWeaponSlot(client, 0);
	new flagsgive = GetCommandFlags("give");
	SetCommandFlags("give", flagsgive & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", weaponname);
	SetCommandFlags("give", flagsgive|FCVAR_CHEAT);
[-] Remove revive closest functionality
[-] hats: https://forums.alliedmods.net/showthread.php?p=1441080




