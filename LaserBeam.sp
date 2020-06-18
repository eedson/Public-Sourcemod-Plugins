#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "CodingCow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "LaserBeam",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

int precache_laser;
bool canBeam[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_beam", doBeam);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		canBeam[i] = true;
	}
}

public OnMapStart()
{
	// Laser
	precache_laser = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public Action doBeam(int client, int args)
{
	if(canBeam[client])
	{
		beam(client);
		canBeam[client] = false;
		CreateTimer(0.1, setBeam, client);
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (canBeam[client] && IsClientInGame(client) && GetClientButtons(client) & IN_USE)
	{
		beam(client);
		canBeam[client] = false;
		CreateTimer(0.1, setBeam, client);
	}
}

public Action setBeam(Handle timer, int client)
{
	canBeam[client] = true;
	CloseHandle(timer);
}

/* BeamTest */
public void beam(int client)
{
    float vAngles[3], vOrigin[3], AnglesVec[3], EndPoint[3], pos[3];

    float Distance = 9999999.0;

    GetClientEyeAngles(client,vAngles);
    GetClientEyePosition(client,vOrigin);
    GetAngleVectors(vAngles, AnglesVec, NULL_VECTOR, NULL_VECTOR);

    EndPoint[0] = vOrigin[0] + (AnglesVec[0]*Distance);
    EndPoint[1] = vOrigin[1] + (AnglesVec[1]*Distance);
    EndPoint[2] = vOrigin[2] + (AnglesVec[2]*Distance);

    Handle trace = TR_TraceRayFilterEx(vOrigin, EndPoint, MASK_SHOT, RayType_EndPoint, TraceEntityFilterPlayer, client);

    if (TR_DidHit(trace))
    {
		TR_GetEndPosition(pos, trace);
		
		int bomb = CreateEntityByName("info_particle_system");
		DispatchKeyValue(bomb, "start_active", "0");
		DispatchKeyValue(bomb, "effect_name", "explosion_c4_500");
		DispatchSpawn(bomb);
		TeleportEntity(bomb, pos, NULL_VECTOR, NULL_VECTOR);
		ActivateEntity(bomb);
		SetVariantString("!activator");
		AcceptEntityInput(bomb, "SetParent", bomb, bomb, 0);
		EmitAmbientSound("weapons/c4/c4_explode1.wav", NULL_VECTOR, bomb);
		CreateTimer(0.25, Timer_Run, bomb);
		
		int color[4];
		color[0]=255;color[1]=0;color[2]=0;color[3]=255;
		
		BeamEffect(vOrigin, pos, 0.5, 1.0, 1.0, color, 0.0, 0);
		
		CloseHandle(trace);
	}
}

public Action Timer_Run(Handle timer, any ent)
{
	if(ent > 0 && IsValidEntity(ent))
	{
		AcceptEntityInput(ent, "Start");
		CreateTimer(7.0, Timer_Die, ent);
	}
}

public Action Timer_Die(Handle timer, any ent)
{
	if(ent > 0 && IsValidEntity(ent))
	{
		if(IsValidEdict(ent))
		{
			AcceptEntityInput(ent, "Kill");
		}
	}
}

public bool TraceEntityFilterPlayer(entity, mask, any:data)
{
    return data != entity;
}

public BeamEffect(float startvec[3], float endvec[3], float life, float width, float endwidth, const color[4], float amplitude, speed)
{
	TE_SetupBeamPoints(startvec, endvec, precache_laser, 0, 0, 66, life, width, endwidth, 0, amplitude, color, speed);
	TE_SendToAll();
}
