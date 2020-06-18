#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "codingcow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <devzones>

public Plugin myinfo = 
{
	name = "DamageZone",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

bool doDamage[MAXPLAYERS + 1];

public void OnPluginStart()
{
	
}

public void OnClientPutInServer(int client)
{
	doDamage[client] = false;
	
	SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	doDamage[client] = false;
	
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
}

public int Zone_OnClientEntry(int client, char[] zone)
{
	if(StrEqual(zone, "damage"))
	{
		doDamage[client] = true;
	}
}

public int Zone_OnClientLeave(int client, char[] zone)
{
	if(StrEqual(zone, "damage"))
	{
		doDamage[client] = false;
	}
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])  
{
	if(IsValidClient(attacker) && IsValidClient(victim) && victim != attacker)
	{
		if(doDamage[attacker] && doDamage[victim])
		{
			return Plugin_Continue;
		}
		else
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}