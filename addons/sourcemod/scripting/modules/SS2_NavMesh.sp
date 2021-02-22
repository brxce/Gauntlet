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
	RegAdminCmd("sm_navmesh_show", Command_Show, ADMFLAG_CHEATS, "");
	
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
	// g_bPlayerTrackNavArea[client] = (StringToInt(sArg) != 0);
	SearchProximateNavMesh(client); // hijacking command to test navmesh searching function
	//Spawn_NavMesh_Direct(client); // manual spawn
	
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                 								AUTOMATIC SPAWNING
                                                                    
***********************************************************************************************************************************************************************************/

// Find a suitable spawn position for the desired SI class
void Spawn_NavMesh(L4D2_Infected:SIClass, int minSpawnProximity=400, int maxSpawnProximity=450) // default - spawn very close to survivors
{
	UpdateSpawnBounds();
	bool didSpawn = false;
	for( new i = 0; i < GetConVarInt(hCvarMaxSearchAttempts); i++ ) 
	{
		float searchPos[3];
		float survivorPos[3];
		int closestSurvivor;		
		// 'x' and 'y' for potential spawn point coordinates is selected with uniform RNG
		searchPos[COORD_X] = GetRandomFloat(spawnBounds[X_MIN], spawnBounds[X_MAX]);
		searchPos[COORD_Y] = GetRandomFloat(spawnBounds[Y_MIN], spawnBounds[Y_MAX]);
		// 'z' for potential spawn point coordinate is taken from the nearest survivor
		closestSurvivor = GetClosestSurvivor2D(searchPos[COORD_X], searchPos[COORD_Y]);
		if ( !IsValidClient(closestSurvivor) ) 
		{
			LogError("[SS2_NavMesh] Spawn_NavMesh() - Unable to find closest survivor to random coordinates [%f, %f]", searchPos[COORD_X], searchPos[COORD_Y]);
			continue;
		}
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		searchPos[COORD_Z] = survivorPos[COORD_Z];
		// Get the closest CNavArea to this random coordinate
		CNavArea spawnArea = NavMesh_GetNearestArea(searchPos);
		if ( spawnArea == INVALID_NAV_AREA )
		{
			LogError("[SS2_NavMesh] Spawn_NavMesh() - Unable to find a nav mesh tile to spawn near the generated coordinates [%f, %f, %f]", searchPos[0], searchPos[1], searchPos[2]);	
			continue;
		}
		
		if ( shouldSpawnHere(spawnArea, minSpawnProximity, maxSpawnProximity) )
		{
			// Spawn at the center coordinate of the closest CNavArea
			int iAreaIndex = NavMesh_FindAreaByID(spawnArea.ID);
			float navmeshArea_center[3];			
			NavMeshArea_GetCenter(iAreaIndex, navmeshArea_center);
			/* Appears to cause too much lag when spawning in waves
			if ( IsPlayerStuck(navmeshArea_center, GetRandomSurvivor()) )
			{
				LogError("[SS2_NavMesh] Spawn_NavMesh() - Ignored an acceptable spawn area as the infected would have been stuck");
				continue;
			} */
			TriggerSpawn(SIClass, navmeshArea_center, NULL_VECTOR);
			didSpawn = true;
			break;
		} 
	}
	if ( !didSpawn ) 
	{
		LogError("[SS2_NavMesh] Spawn_NavMesh() - Failed to find a valid spawn for SI class %d within %d distance of survivors", _:SIClass, GetConVarInt(hCvarSpawnProximityMax));
	}
}

bool shouldSpawnHere(CNavArea spawn, minSpawnProximity, maxSpawnProximity)
{
	bool shouldSpawn = false;
	// Find shortest path cost to any member of the survivor team
	int shortestPath = -1;
	for ( int i = 1; i <= MAXPLAYERS; ++i )
	{
		if ( IsSurvivor(i) && IsPlayerAlive(i) )
		{	
			float survivorPos[3];			
			GetClientAbsOrigin(i, survivorPos);
			CNavArea survivorArea = NavMesh_GetNearestArea(survivorPos);
			bool didBuildPath = NavMesh_BuildPath(spawn, survivorArea, survivorPos, GauntletPathCost); 
			if ( didBuildPath )
			{
				int pathCost = NavMeshArea_GetTotalCost(NavMesh_FindAreaByID(survivorArea.ID)); // TODO: hoping the cost is for the path built in NavMesh_BuildPath
				if ( pathCost < shortestPath || shortestPath == -1 )
				{
					shortestPath = pathCost;	
				}
			}
		}
	}
	// Return whether this shortest calculated path length is acceptable
	if ( shortestPath > minSpawnProximity && shortestPath < maxSpawnProximity ) // arbitrary for now
	{
		shouldSpawn = true;	
	}
	return shouldSpawn;	
}

public int GauntletPathCost(CNavArea area, CNavArea from, CNavLadder ladder, any data)
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

                                                 								DISPLAY NAVMESHES CLOSE TO SURVIVORS
                                                                    
***********************************************************************************************************************************************************************************/

stock void SearchProximateNavMesh(int client)
{
	ArrayList CNavAreaProximates; // final results
	CNavAreaProximates = new ArrayList(CNAVAREA_MEMORYSIZE, CNAVAREA_ARRAYSIZE);
	ArrayStack CNavAreaTraversal; // temp cache for DFS graph search
	CNavAreaTraversal = new ArrayStack(CNAVAREA_MEMORYSIZE);
	bool hasTraversed[CNAVAREA_MAXID]; // area ID
	for ( int i = 0; i < CNAVAREA_MAXID; ++i )
	{
		hasTraversed[i] = false;	
	}
	
	// Prepare search by identifying the nav meshes stood upon by the survivors
	for ( int i = 1; i <= MAXPLAYERS; ++i ) 
	{
		if ( IsSurvivor(i) && IsPlayerAlive(i) )
		{
			float clientPos[3];
			GetClientAbsOrigin(i, clientPos);
			CNavArea area = NavMesh_GetNearestArea(clientPos);
			if ( area != INVALID_NAV_AREA )
			{
				CNavAreaTraversal.Push(area); 
			}
		}
	}	
	
	// Unaware of any other search algorithms beside DFS when limited to Stack data structure
	int traversals = 0; 
	while (!CNavAreaTraversal.Empty)
	{
		// prevent infinite loop
		if ( traversals > 1000000 )
		{
			LogError("[ SS2_NavMesh - SearchProximateNavMesh() ] Possible infinite loop or doubling up on traversals");
			break;	
		} 
		else 
		{
			++traversals;
		}	
		
		CNavArea traverseArea = CNavAreaTraversal.Pop();
		int traverseID = view_as<int>(traverseArea.ID);
		// if any surrounding areas are within suitable distance, add to arraylist
		if ( traverseArea != INVALID_NAV_AREA && !hasTraversed[traverseID])
		{
			hasTraversed[traverseID] = true;	
			// get adjacent areas for each cardinal direction
			for ( int iNavDir = 0; iNavDir < NAV_DIR_COUNT; iNavDir++ )
			{
				ArrayStack adjacentAreas;
				adjacentAreas = NavMeshArea_GetAdjacentList(adjacentAreas, NavMesh_FindAreaByID(traverseID), iNavDir);
				while ( !IsStackEmpty(adjacentAreas) ) // 
				{
					CNavArea adjacent = adjacentAreas.Pop();
					int adjacentID = view_as<int>(adjacent.ID);
					if ( adjacent != INVALID_NAV_AREA && !hasTraversed[adjacentID] ) // prevent adding adjacent area twice
					{
						hasTraversed[adjacentID] = true;
						float areaPos[3];
						NavMeshArea_GetCenter(NavMesh_FindAreaByID(view_as<int>(adjacent.ID)), areaPos);
						float closestPos[3];
						int clientClosest = GetClosestSurvivor(areaPos);		
						if ( clientClosest == -1 )
						{
							LogError("[ SS2_NavMesh - SearchProximateNavMesh() ] Could not find closest survivor to area ID %d", view_as<int>(adjacent.ID) );
							return;
						}
						GetClientAbsOrigin(clientClosest, closestPos);
						float distToSurv = GetVectorDistance(areaPos, closestPos);
						if ( distToSurv < 650 ) // keep traversing from this area
						{
							CNavAreaTraversal.Push(adjacent);
							if ( distToSurv > 300 ) // distance spawn parameter met, add to spawn list
							{
								for ( int i = 0; i < CNavAreaProximates.Length; ++i )
								{
									if ( CNavAreaProximates.Get(i) == INVALID_NAV_AREA )
									{
										CNavAreaProximates.Set(i, adjacent);
									}
								}	
							}
						}
					}
				}	
				delete adjacentAreas;
			}
		}
	}
	
	// Display results and clean up memory
	int countDrawnAreas = 0;
	for ( int i = 0; i < CNavAreaProximates.Length; ++i )
	{
		CNavArea area = CNavAreaProximates.Get(i);
		if ( area != INVALID_NAV_AREA )
		{
			DrawNavArea( client, area, FocusedAreaColor, 3.0 );
			++countDrawnAreas;
		}
	}
	PrintToChatAll("Drew %d areas, discovered over %d traversals", countDrawnAreas, traversals);
	delete CNavAreaProximates;
	delete CNavAreaTraversal;
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
		CNavArea area = spawnAreas.Pop();
		if (area != INVALID_NAV_AREA)
		{
			float areaPos[3];
			int iAreaIndex = NavMesh_FindAreaByID(area.ID);
			int travelCost = NavMeshArea_GetTotalCost(iAreaIndex);
			if ( travelCost > 300 && travelCost < 650 ) // considering nav meshes within a specific range
			{
				CreateInfected("spitter", areaPos, NULL_VECTOR);
			}
			DrawNavArea( client, area, FocusedAreaColor, 3.0 );
		}
	}
	delete spawnAreas;
}

int GetDistance2D(float alpha[3], float beta[3])
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