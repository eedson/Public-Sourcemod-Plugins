#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "CodingCow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <emitsoundany>
#include "cash/stocks.sp"

public Plugin myinfo = 
{
	name = "Weed",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

bool canWeed[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_weed", doWeed, ADMFLAG_BAN);
	RegConsoleCmd("sm_weedcow", cowWeed);
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

public void OnClientPutInServer(int client)
{
	canWeed[client] = true;
}

public OnMapStart()
{
	PrecacheSoundAny("weed.mp3");
	PrecacheSoundAny("weed2.mp3");
	AddFileToDownloadsTable("sound/weed.mp3");
	AddFileToDownloadsTable("sound/weed2.mp3");
}

public Action cowWeed(int client, int args)
{
	char steamid[128];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if(IsValidClient(client) && StrEqual(steamid, "STEAM_1:1:47500411"))
	{
		weed(client);
	}
	
	return Plugin_Handled;
}

public Action doWeed(int client, int args)
{
	if(IsValidClient(client) && canWeed[client])
	{
		weed(client);
		
		canWeed[client] = false;
		CreateTimer(60.0, doToggle, client);
	}
	else if(!canWeed[client])
	{
		PrintToChat(client, "[\x06Drugs\x01] Bruh you just ripped a fatty chill for a sec.");
	}
	
	return Plugin_Handled;
}

public Action doToggle(Handle timer, int client)
{
	canWeed[client] = true;
	
	delete timer;
}

public void weed(int client)
{
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	
	int iEnt = CreateEntityByName("env_particlesmokegrenade");
	
	if (iEnt != -1 && IsValidEntity(iEnt))
	{
		SetEntProp(iEnt, Prop_Send, "m_CurrentStage", 1);
		SetEntPropFloat(iEnt, Prop_Send, "m_FadeStartTime", 1.5);
		SetEntPropFloat(iEnt, Prop_Send, "m_FadeEndTime", 20.0);
	
		if (DispatchSpawn(iEnt))
		{
			ActivateEntity(iEnt);
			TeleportEntity(iEnt, clientPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	PrintToChatAll("[\x06Drugs\x01]\x04%N \x01Just Blazed The Dankest \x06Weed", client);
	
	switch(GetRandomInt(1, 2)) 
	{ 
		case 1: 
		{ 
		    EmitSoundToAllAny("weed.mp3", client, _, _, _, _, _, _, _, clientPos);
		} 
		case 2: 
		{ 
		    EmitSoundToAllAny("weed2.mp3", client, _, _, _, _, _, _, _, clientPos);
		} 
	}
}

public Action Command_Say(int client, const char[] command, argc)
{
	char sText[192]; 
	GetCmdArgString(sText, sizeof(sText));

	if(StrEqual(sText, "!weed") || StrEqual(sText, "!weedcow"))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}