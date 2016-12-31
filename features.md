#Features  

##Important Commands:
Prefix commands with '!' when entering into chat, prefix with "sm_" when entering into console  
> '!' styles are faster to type, 'sm_' styles are preferable when binding frequently used commands as they do not take up chat space  

* Scoremod info and commands: https://www.github.com/breezyplease/static-scoremod
* !current to print the percentage distance of the map currently covered by survivors
* !boss/!tank/!witch to print the percentage distance through map at which boss will spawn"
* !toggleretry to toggle skipping to the next map when wiping
* !join to join survivors from spec
* !return to return to saferoom if respawned out of world 
* !respawn to respawn in saferoom if respawned dead
* !limit <class> <value> to set the limit for an SI class 
* !waveinterval <value> to set the time in seconds between SI waves (default 30)
* !supportpercent <value> to set the percentage of tank's health at which his support wave will spawn (default 50)
* !pillpercent <value> to set the percentage of map completion upon which supplementary pills are granted to survivors

##Full plugin details list
Cvars may be entered into the 'halfbaked' or 'bakersdozen' .cfg files to auto load the configured setting
>###AI improvements
>>
 * **ai_aggressivespecials.smx**
   * special infected are aggressive upon spawn and do not ever run away  
 * **ai_targeting.smx**  
   * special infected are assigned health bonus target preferences  
 * **ai_smokersettings.smx**  
   * smokers attack faster and take damage like in versus
 * **ai_hunterpouncing.smx**  
   * hunters pounce as fast as players, in a zig zag pattern
   * (cvar) ai_fast_pounce_proximity "At what distance to start pouncing fast"; default 1000
 * **ai_jockeybehaviour.smx**  
   * jockeys alternate jumps and pounces, and cause stumble
   * (cvar) ai_hop_activation_proximity "How close a jockey will approach before it starts hopping"; default 500
   * (cvar) ai_jockey_stumble_radius"Stumble radius of a jockey landing a ride"; default 50
 * **ai_chargefromclose.smx**  
   * chargers only charge when they are close to survivors
   * (cvar) ai_charge_proximity "How close a charger will approach before charging"; default 500
 * **ai_tankbehaviour.smx**  
   * tanks do not throw rocks

>###Versus simulation
>>
 * **static_scoremod.smx**
   * distance points + health bonus (!scoring/sm_scoring for more info)
   * (cmd) !mapinfo
   * (cmd) !scoring
   * (cmd) !bonus/!health/!score
   * (cmd) !setscore
 * **survivor_reset.smx**
   * full health, single pistol at the start of every round
 * **pillsonly.smx**
   * only pills spawn on the map; each survivor is given a pill upon leaving saferoom
   * (cmd) !pillpercent <value>
 * **mapskipper.smx**  
   * Skips to next map when survivors wipe 
   * (cmd) !toggleretry cmd
   * (cvar) enable_retry cvar
 * **coopbosses.smx**  
   * spawns exactly one tank on every map, spawns one extra tank on finales
   * (cmd) !boss/!tank/!witch
 * **special_infected_wave_spawner** 
   * spawns infected in waves; creates custom cvars not related to versus 'limit' cvars
   * (cmd) !waveinterval <value>
   * (cmd) !limit <class> <value> 
   * (cmd) !limit reset (all limits to 0)
   * (cmd) !supportpercent <value>
   * (cvar) siws_wave_interval "Interval in seconds between special infected waves"; default 30
   * (cvar) siws_max_specials; default 6
   * (cvar) siws_smoker_limit; default 1
   * (cvar) siws_boomer_limit; default 1
   * (cvar) siws_hunter_limit; default 1
   * (cvar) siws_spitter_limit; default 1
   * (cvar) siws_jockey_limit; default 1
   * (cvar) siws_charger_limit; default 1
   * (cvar) siws_tank_support_health_percent "SI support wave spawns upon tank health falling below this percent"; default 50
   * (cvar) incap_allowance "Extra grace period extension(sec) to wave interval per incapped survivor"; default 5

>###Misc.
>>
 * **autowipe.smx**
   * wipes survivors after a period of time if they are all incapped/pinned
 * **survivormanagement.smx**
   * (cmd) !join
   * (cmd) !return
   * (cmd) !respawn
 * **l4d2_playstats_fixed.smx** 
   * prints then resets stats after wipes
 * **l4d_tank_damage_announce_fixed.smx**  
   * correct damage percents for coop tanks 
