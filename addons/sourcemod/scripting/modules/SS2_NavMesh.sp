#include <navmesh>
#include <profiler>

#define DEBUG_NAVMESH 1

#define CNAVAREA_MEMORYSIZE 1024 // could be much smaller; staying on the safe side out of ignorance
#define MAX_SPAWN_NAVMESH_DIST 700.0 // thinking this should be low to minimise spawning on the other side chain link walls

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
	g_bPlayerTrackNavArea[client] = (StringToInt(sArg) != 0);
	Spawn_NavMesh_Direct(client);
	
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                 								AUTOMATIC SPAWNING
                                                                    
***********************************************************************************************************************************************************************************/

// Find a suitable spawn position for the desired SI class
void Spawn_NavMesh(L4D2_Infected:SIClass, int minProximity = 500, int maxProximity = 650)
{
	// Find the survivor at the front of the team
	int leadSurvivor = -1;
	float leadFlow = -1.0;
	for ( int i = 1; i <= MAXPLAYERS; ++i ) // iterate through all survivors that are alive
	{
		if ( IsSurvivor(i) && IsPlayerAlive(i) )
		{
			float flow = L4D2Direct_GetFlowDistance(i);
			if ( flow > leadFlow ) // we have the highest flow survivor found so far
			{
				leadFlow = flow;
				leadSurvivor = i;								
			}
		}
	}
	if ( leadSurvivor == -1 || leadFlow < 0.0 ) 
	{
		LogError("[SS2] NavMesh - Failed to determine what survivor has the highest flow distance");
		return;
	}	
	
	// Spawn around the survivor at the front of the team
	float leadPos[3];
	GetClientAbsOrigin(leadSurvivor, leadPos);
	CNavArea searchCentre = NavMesh_GetNearestArea(leadPos);
	if ( searchCentre == INVALID_NAV_AREA )
	{
		LogError("[SS2] NavMesh - Failed to find the closest valid CNavArea to the leading survivor");
		return;
	}	
	
	// Collect nearby navigation mesh sections into an ArrayList
	ArrayStack CNavArea_SpawnAreas;
	CNavArea_SpawnAreas = new ArrayStack(CNAVAREA_MEMORYSIZE); // <navmesh> native returns results in an ArrayStack
	NavMesh_CollectSurroundingAreas(CNavArea_SpawnAreas, searchCentre, MAX_SPAWN_NAVMESH_DIST, StepHeight, StepHeight); 
	
	// Find a spawn area that suffices proximity requirements to the survivor team
	bool didSpawn = false;
	while (!IsStackEmpty(CNavArea_SpawnAreas)) 
	{
		CNavArea area = CNavArea_SpawnAreas.Pop();
		if (area != INVALID_NAV_AREA)
		{
			int iAreaIndex;
			float areaPos[3];
			iAreaIndex = NavMesh_FindAreaByID(area.ID);
			
			NavMeshArea_GetCenter(iAreaIndex, areaPos);			
			if ( GetDistance2D(leadPos, areaPos) > minProximity && GetDistance2D(leadPos, areaPos) < maxProximity ) // satisfies distance parameters
			{
				TriggerSpawn(SIClass, areaPos, NULL_VECTOR);
				didSpawn = true;
				break;
			}
		}
	}
	if (!didSpawn) LogError("[SS2] NavMesh - No spawn found within the following distance range to survivors [%d] -> [%d]", minProximity, maxProximity);		
	
	delete CNavArea_SpawnAreas;
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
	// colalte surrounding areas
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
			NavMeshArea_GetCenter(iAreaIndex, areaPos);
			if ( GetDistance2D(clientPos, areaPos) > 200 && GetDistance2D(clientPos, areaPos) < 650 ) // considering nav meshes within a specific range
			{
				CreateInfected("spitter", areaPos, NULL_VECTOR);
			}
			DrawNavArea( client, area, FocusedAreaColor );
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