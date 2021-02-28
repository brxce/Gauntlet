#include <navmesh>
#include <profiler>
#include "includes/hardcoop_util.sp"

#define DEBUG_NAVMESH 1

#define CNAVAREA_ARRAYSIZE 512 // guesstimating this is overkill, unless a much wider accepted spawn range is used
#define CNAVAREA_MEMORYSIZE 1024 // could be much smaller; staying on the safe side out of ignorance
#define MAX_SPAWN_NAVMESH_DIST 700.0 // thinking this should be low to minimise spawning on the other side chain link walls
#define CNAVAREA_MAXID 9999999

/*
/	CNavArea IDs appear to move into the six digits, whereas the CNavArea area indices move into the four digits
*/

int g_iPathLaserModelIndex = -1;

float g_flTrackNavAreaThinkRate = 0.1;
float g_flTrackNavAreaNextThink = 0.0;

static const int DefaultAreaColor[] = { 255, 0, 0, 255 };
static const int FocusedAreaColor[] = { 255, 255, 0, 255 };
			

bool g_bPlayerTrackNavArea[MAXPLAYERS + 1] = { false, ... };
Handle g_hPlayerTrackNavAreaInfoHudSync = null;

NavMesh_OnModuleStart()
{
	RegAdminCmd("sm_testnav", Command_Show, ADMFLAG_CHEATS, "");
	
	g_hPlayerTrackNavAreaInfoHudSync = CreateHudSynchronizer();	
}

NavMesh_OnModuleEnd()
{	
}

NavMesh_OnMapStart()
{
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");

	g_flTrackNavAreaNextThink = 0.0;	
}	


/***********************************************************************************************************************************************************************************

                                                 									CMDs
                                                                    
***********************************************************************************************************************************************************************************/

public Action Command_Show(int client,int args)
{
	if (!NavMesh_Exists()) return Plugin_Handled;

	if ( args < 1 ) 
	{
		ReplyToCommand(client, "Usage: sm_navmesh_show <0/1>");
		return Plugin_Handled;
	}

	char sArg[16];
	GetCmdArg(1, sArg, sizeof(sArg));
	//g_bPlayerTrackNavArea[client] = (StringToInt(sArg) != 0);
	//Spawn_NavMesh_Direct(client); // manual spawn
	ShowProximateSpawns(client);
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                 								AUTOMATIC SPAWNING
                                                                    
***********************************************************************************************************************************************************************************/

stock void ShowProximateSpawns ( int viewingClient )
{
	ArrayList ProximateSpawns;
	ProximateSpawns = new ArrayList();
	
	/*
	 * Collate all spawn areas near survivors
	 */
	int countFoundSpawnAreas = 0;
	for ( int thisClient = 1; thisClient <= MAXPLAYERS; ++thisClient )
	{
		if ( IsSurvivor(thisClient) && IsPlayerAlive(thisClient) )
		{
			float posThisSurvivor[3]; // Need this survivor's coordinates to start search
			char nameThisSurvivor[32]; 
			GetClientName(thisClient, nameThisSurvivor, sizeof(nameThisSurvivor)); 
			if ( GetClientAbsOrigin(thisClient, posThisSurvivor) )
			{
				CNavArea areaThisSurvivor = NavMesh_GetNearestArea(posThisSurvivor); // Identify closest navmesh tile from their coordinates
				if ( areaThisSurvivor != INVALID_NAV_AREA )
				{
					ArrayStack hereProximates = new ArrayStack(); // Get nearby navmesh tiles
					NavMesh_CollectSurroundingAreas(hereProximates, areaThisSurvivor); 
					while ( !hereProximates.Empty )
					{
						CNavArea area = INVALID_NAV_AREA; // for each discovered tile, check we have not seen it before 
						PopStackCell(hereProximates, area); 
						if ( area != INVALID_NAV_AREA && ProximateSpawns.FindValue(area) == -1 )
						{
							++countFoundSpawnAreas;
							if ( CheckSpawnConditions(area) ) // check each tile meets our spawn conditions
							{
								int indexArea = view_as<int>(NavMesh_FindAreaByID(view_as<int>(area.ID)));
								ProximateSpawns.Push(indexArea); // save this tile
							} 
						} 
					}
					delete hereProximates;
				}
				else 
				{
					LogError("[ SS2_NavMesh ] - No CNavArea found near %s required to search for proximate spawn areas", nameThisSurvivor);
				}
			} 
			else 
			{
				LogError("[ SS2_NavMesh ] - Unable to obtain coordinates for survivor %s", nameThisSurvivor);
			}
		}
	}
	PrintToServer("Found %d spawns near survivors, of which %d met spawn conditions", countFoundSpawnAreas, ProximateSpawns.Length);
	/*
	 * Test spawn
	 */	 
	if ( ProximateSpawns.Length == 0 )
	{
		LogError("[ SS2_NavMesh ] - Failed to find any proximate spawns");
	} 
	else {	
		for ( int spawnClass = 1; spawnClass < 7; ++spawnClass )
		{
			if (spawnClass == 2 || spawnClass == 4) continue; // skip support SI for testing lol
			int spawnIndex = GetRandomInt(0, ProximateSpawns.Length - 1);	
			int indexRandomSpawn = ProximateSpawns.Get(spawnIndex);
			float posRandomSpawn[3]; 
			if ( NavMeshArea_GetCenter(indexRandomSpawn, posRandomSpawn) ) // returns true if successful
			{
				TriggerSpawn( L4D2_Infected:spawnClass, posRandomSpawn, NULL_VECTOR);
			}
			else
			{
				LogError("[ SS2_NavMesh ] - Failed to spawn at NavMesh index %d; cannot determine mesh center coordinates", indexRandomSpawn);
			}	
		}
	}
	delete ProximateSpawns;
}

// TODO: CheckSpawnConditions() - add check for against IsPlayerStuck() when spawned into this position
bool CheckSpawnConditions(CNavArea spawn)
{
	bool shouldSpawn = false;
	
	if ( !IsSpawnStuck(spawn) )
	{
		int shortestPath = -1; // Find shortest path cost to any member of the survivor team
		for ( int thisClient = 1; thisClient <= MAXPLAYERS; ++thisClient )
		{
			if ( IsSurvivor(thisClient) && IsPlayerAlive(thisClient) )
			{	
				float posThisSurvivor[3];			
				GetClientAbsOrigin(thisClient, posThisSurvivor);
				CNavArea areaThisSurvivor = NavMesh_GetNearestArea(posThisSurvivor); 
				int indexAreaThisSurvivor = view_as<int>(NavMesh_FindAreaByID(view_as<int>(areaThisSurvivor.ID)));
				bool didBuildPath = NavMesh_BuildPath(spawn, areaThisSurvivor, posThisSurvivor, GauntletPathCost); 
				if ( didBuildPath )
				{
					// TODO: hoping the cost is for the path built in NavMesh_BuildPath
					int pathCost = NavMeshArea_GetTotalCost(indexAreaThisSurvivor); 
					if ( pathCost < shortestPath || shortestPath == -1 )
					{
						shortestPath = pathCost; // update the shortest path found to survivors from this position
					}
				}
			}
		}
		// Return whether this shortest calculated path length is acceptable
		if ( shortestPath > GetConVarInt(hCvarSpawnProximityMin) && shortestPath < GetConVarInt(hCvarSpawnProximityMax) ) 
		{
			shouldSpawn = true;	
		}
	}
	return shouldSpawn;	
}

stock bool IsSpawnStuck( CNavArea spawnArea ) 
{
	// return false; // TODO: Find a way to perform this check; current iteration does not work
	bool isStuck = false;
	int indexSpawnArea = view_as<int>(NavMesh_FindAreaByID(view_as<int>(spawnArea.ID)));
	float posSpawnArea[3];
	if ( NavMeshArea_GetCenter(indexSpawnArea, posSpawnArea) ) // need coordinates to run collision check
	{
		/*
		 * Testing with DirectedInfectedSpawn SI appears to indicate all standard SI return the same mins and maxs values below
		 * We are inflating a bit here to reduce chance of being stuck
		 */
		float mins[3] = {-16.0, -16.0, 0.0};
		float maxs[3] = {16.0, 16.0, 71.0};		
		for( new i = 0; i < sizeof(mins); i++ ) 
		{
		    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
		    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
		}	
		TR_TraceHullFilter(posSpawnArea, posSpawnArea, mins, maxs, MASK_SOLID, TraceEntityFilterSolid); // collision check
		if ( TR_DidHit() )
		{
			isStuck = true;
		} 
		else 
		{
			//char readoutCoordinates[32];
			//Format(readoutCoordinates, sizeof(readoutCoordinates), "[%f, %f, %f]", posSpawnArea[0], posSpawnArea[1], posSpawnArea[2]);
			//LogError("[ SS2_NavMesh ] - Skipping spawn without space %s", readoutCoordinates);
		}
	} 
	else
	{
		LogError("[ SS2_NavMesh ] - Failed to find coordinates of nav mesh while checking for space to spawn: Nav mesh ID %d", indexSpawnArea);
	}
	return isStuck;
}  

public bool:TraceEntityFilterSolid(entity, contentsMask) 
{
	return entity > MaxClients;
}

int GauntletPathCost(CNavArea area, CNavArea from, CNavLadder ladder, any data)
{
	if (from == INVALID_NAV_AREA)
	{
		return 0;
	}
	else
	{
		int iDist = 0;
		if (ladder != INVALID_NAV_LADDER)
		{
			iDist = RoundFloat(FloatMul(ladder.Length, 10.0)); // addding 10x multiplier to discourage spawn spots that require climbing
		}
		else
		{
			float flAreaCenter[3]; float flFromAreaCenter[3];
			area.GetCenter(flAreaCenter);
			from.GetCenter(flFromAreaCenter);
			
			iDist = RoundFloat(GetVectorDistance(flAreaCenter, flFromAreaCenter));
		}
		
		int iCost = iDist + from.CostSoFar;
		int iAreaFlags = area.Attributes;
		if (iAreaFlags & NAV_MESH_CROUCH) iCost += 20; // default += (20)
		if (iAreaFlags & NAV_MESH_JUMP) iCost += (50 * iDist); // default +=(5 * iDist)
		return iCost;
	}
}

/***********************************************************************************************************************************************************************************

                                                 							MANUAL SPAWNING (for testing)
                                                                    
***********************************************************************************************************************************************************************************/

// Spawn spitters to demarcate the navmeshes with the allocated restrictions 
void Spawn_NavMesh_Direct(client)
{
	// determine centre of spawning area
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	CNavArea searchCentre = NavMesh_GetNearestArea(clientPos);
	// collate surrounding areas
	ArrayStack spawnAreas;
	spawnAreas = new ArrayStack(CNAVAREA_MEMORYSIZE);
	NavMesh_CollectSurroundingAreas(spawnAreas, searchCentre, MAX_SPAWN_NAVMESH_DIST, StepHeight, StepHeight); // keep low enough to prevent spawning on the other side of the wall in labyrinth map layouts	
	while (!IsStackEmpty(spawnAreas))
	{
		CNavArea thisArea = spawnAreas.Pop();
		if (thisArea != INVALID_NAV_AREA)
		{
			float posThisArea[3];
			int indexThisArea = view_as<int>(thisArea.ID);
			int travelCost = NavMeshArea_GetTotalCost(indexThisArea);
			if ( travelCost > 300 && travelCost < 650 ) // considering nav meshes within a specific range
			{
				CreateInfected("spitter", posThisArea, NULL_VECTOR);
			}
			DrawNavArea( client, thisArea, FocusedAreaColor, 3.0 );
		}
	}
	delete spawnAreas;
}

stock int GetDistance2D(float alpha[3], float beta[3])
{
	float distance = SquareRoot( Pow(alpha[COORD_X] - beta[COORD_X], 2.0) + Pow(alpha[COORD_Y] - beta[COORD_Y], 2.0) ); // Pythagoras
	return RoundToNearest(distance);
}

/***********************************************************************************************************************************************************************************

                                                 								DISPLAY SPAWN AREAS
                                                                    
***********************************************************************************************************************************************************************************/

public void OnGameFrame()
{
	EngineVersion engineVersion = GetEngineVersion();

	if ( GetGameTime() >= g_flTrackNavAreaNextThink )
	{
		g_flTrackNavAreaNextThink = GetGameTime() + g_flTrackNavAreaThinkRate;

		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			if ( g_bPlayerTrackNavArea[client] )
			{
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				CNavArea spawnCenter = NavMesh_GetNearestArea(clientPos);
				if (spawnCenter == INVALID_NAV_AREA)
					continue;
					
				// Display all nearby areas
				ArrayStack spawnAreas;
				spawnAreas = new ArrayStack(128);
				if (spawnAreas == INVALID_HANDLE) continue;
				NavMesh_CollectSurroundingAreas(spawnAreas, spawnCenter, 400.0, StepHeight, StepHeight);	
				int numAreas = 0;
				while (!spawnAreas.Empty)
				{
					CNavArea area = spawnAreas.Pop();
					if (area != INVALID_NAV_AREA)
					{
						DrawNavArea( client, area, FocusedAreaColor );
						++numAreas;
						
						#if DEBUG_NAVMESH
							PrintToChatAll("Displaying %d discovered nav sections", numAreas);
						#endif 
						
						ArrayList connections = new ArrayList();
						area.GetAdjacentList(NAV_DIR_COUNT, connections);
						ArrayList incomingConnections = new ArrayList();
						area.GetIncomingConnections(NAV_DIR_COUNT, incomingConnections);
						
						for (int i = 0; i < connections.Length; i++)
						{
							DrawNavArea(client, connections.Get(i), DefaultAreaColor);	
						}
		
						for (int i = 0; i < incomingConnections.Length; i++)
						{
						}
						switch (engineVersion)
						{
							case Engine_Left4Dead2:
							{
								PrintHintText(client, "ID: %d, # Connections: %d, # Incoming: %d", area.ID, connections.Length, incomingConnections.Length);
							}
							default:
							{
								SetHudTextParams(-1.0, 0.75, 0.2, 255, 255, 0, 150, 0, 0.0, 0.0, 0.0);
								ShowSyncHudText(client, g_hPlayerTrackNavAreaInfoHudSync, "ID: %d\n# Connections: %d\n# Incoming: %d\n", area.ID, connections.Length, incomingConnections.Length);
							}
						}
						delete connections;
						delete incomingConnections; 
					}
				}
				delete spawnAreas; 		
			}
		}
	}
}

void DrawNavArea( int client, CNavArea area, const int color[4], float duration=0.15 ) 
{
	if ( !IsClientInGame(client) || area == INVALID_NAV_AREA )
		return;

	float from[3], to[3];
	area.GetCorner( NAV_CORNER_NORTH_WEST, from );
	area.GetCorner( NAV_CORNER_NORTH_EAST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);

	area.GetCorner( NAV_CORNER_NORTH_EAST, from );
	area.GetCorner( NAV_CORNER_SOUTH_EAST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);

	area.GetCorner( NAV_CORNER_SOUTH_EAST, from );
	area.GetCorner( NAV_CORNER_SOUTH_WEST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);

	area.GetCorner( NAV_CORNER_SOUTH_WEST, from );
	area.GetCorner( NAV_CORNER_NORTH_WEST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);
}

public void OnClientDisconnect(int client)
{
	g_bPlayerTrackNavArea[client] = false;
}