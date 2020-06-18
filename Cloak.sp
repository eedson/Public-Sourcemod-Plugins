#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "CodingCow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Cloak",
	author = PLUGIN_AUTHOR,
	description = "Enables admins to go invisible",
	version = PLUGIN_VERSION,
	url = ""
};

bool isCloak[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_cloak", doCloak, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
	ServerCommand("sv_disable_immunity_alpha 1");
}

public void OnClientPutInServer(int client)
{
	isCloak[client] = false;
}

public Action doCloak(int client, int args)
{
	if(isCloak[client])
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		
		PrintToChat(client, "[\x0CCloak\x01] You are now \x0CVisible");
		
		isCloak[client] = false;
	}
	else
	{
		float clientPos[3];
		GetClientAbsOrigin(client, clientPos);
		int iEnt = CreateEntityByName("env_particlesmokegrenade");
		if (iEnt != -1 && IsValidEntity(iEnt))
		{
			SetEntProp(iEnt, Prop_Send, "m_CurrentStage", 1);
			SetEntPropFloat(iEnt, Prop_Send, "m_FadeStartTime", 0);
			SetEntPropFloat(iEnt, Prop_Send, "m_FadeEndTime", 10.0);
		
			if (DispatchSpawn(iEnt))
			{
				ActivateEntity(iEnt);
				TeleportEntity(iEnt, clientPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
		
		SetEntityRenderMode(client, RENDER_NONE);
		
		PrintToChat(client, "[\x0CCloak\x01] You are now \x0CInvisible");
		
		isCloak[client] = true;
	}
	
	return Plugin_Handled;
}