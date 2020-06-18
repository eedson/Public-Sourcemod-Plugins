#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "cow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>

public Plugin myinfo = 
{
	name = "Murder",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define PREFIX  "[\x0CMURDER\x01]"

bool isBystander[MAXPLAYERS + 1];
bool isBystanderWeapon[MAXPLAYERS + 1];
bool isMurder[MAXPLAYERS + 1];

bool cooldown = false;

public void OnPluginStart()
{
	// Hook Events //
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	
	//CreateTimer(1.0, checkWin, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	// Set Client Defaults //
	isBystander[client] = false;
	isBystanderWeapon[client] = false;
	isMurder[client] = false;
	
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponPickUp);
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	// Set Client Defaults //
	isBystander[client] = false;
	isBystanderWeapon[client] = false;
	isMurder[client] = false;
	
	if(IsClientInGame(client))
	{
		SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponPickUp);
		SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int playerCount = GetClientCount(true);
	
	if(playerCount < 1)
	{
		return Plugin_Continue;
	}
	else if(playerCount < 2)
	{
		PrintToChatAll("%s \x04There needs to be at least \x022 \x0EPlayers \x04to play!", PREFIX);
		ServerCommand("mp_restartgame 10");
		return Plugin_Continue;
	}
	else
	{
		// Choose Player Roles //
		int murder = GetRandomPlayer();
		int bystanderweapon = GetRandomPlayer();
		
		while(!IsClientInGame(murder))
		{
			murder = GetRandomPlayer();
		}
		
		while(murder == bystanderweapon)
		{
			bystanderweapon = GetRandomPlayer();
		}
		
		for (int client = 1; client <= MaxClients; client++)
		{
		    if (client == murder)
		    {
		        isMurder[client] = true;
		        isBystanderWeapon[client] = false;
		        isBystander[client] = false;
		    }
		    else if (client == bystanderweapon)
		    {
		   		isBystanderWeapon[client] = true;
		   		isMurder[client] = false;
		   		isBystander[client] = false;
		  	}
		    else
		    {
		    	isBystander[client] = true;
		        isMurder[client] = false;
		        isBystanderWeapon[client] = false;
		    }
		}
	}
	
	ServerCommand("mp_teammates_are_enemies 1");
	
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
	    if (IsValidClient(i))
	    {
			// Set Client Defaults //
			isBystander[i] = false;
			isBystanderWeapon[i] = false;
			isMurder[i] = false;
		}
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client_id = GetEventInt(event, "userid");
	int client = GetClientOfUserId(client_id);
	
	SendConVarValue(client, FindConVar("mp_playercashawards"), "0");
	SendConVarValue(client, FindConVar("mp_teamcashawards"), "0");
	
	PrintToChat(client, "%s \x01Choosing Role...", PREFIX);
    
	CreateTimer(1.0, SelectRoles, client);
}

public Action SelectRoles(Handle timer, int client)
{
	if (IsValidClient(client))
	{
	    if(isMurder[client])
	    {
			StripWeapons(client);
			GivePlayerItem(client, "weapon_knife");
			GivePlayerItem(client, "weapon_flashbang");
			//PrintHintText(client, "<font color='#ffffff' size='20'>You are the <font color='#ad0000'>Murderer!");
			int flash = GetPlayerWeaponSlot(client, 2);
			

			PrintToChat(client, "%s \x0EYou are the \x02Murderer\x0E!", PREFIX);
	  	}
	  	else if(isBystanderWeapon[client])
	  	{
			StripWeapons(client);
			GivePlayerItem(client, "weapon_deagle");
			int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
			SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
			SetEntProp(weapon, Prop_Send, "m_iClip1", 1);
			//PrintHintText(client, "<font color='#ffffff' size='20'>You are the <font color='#249e00'>Armed Bystander!");
			PrintToChat(client, "%s \x0EYou are the \x04Armed Bystander\x0E!", PREFIX);
	 	}
	 	else
	 	{
	 		StripWeapons(client);
	 		//PrintHintText(client, "<font color='#ffffff' size='20'>You are a <font color='#249e00'>Bystander!");
	 		PrintToChat(client, "%s \x0EYou are a \x01Bystander\x0E!", PREFIX);
		}
	}
   	CloseHandle(timer);
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])  
{
	if(IsValidClient(attacker) && IsValidClient(victim) && victim != attacker)
	{
		char sWeapon[32];
		GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, "weapon_deagle"))
		{
		    damage = 2000.0;
		    return Plugin_Changed;
		}
		else if(StrEqual(sWeapon, "weapon_knife"))
		{
		    damage = 2000.0;
		    return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerDeath(Handle hEvent, char[] strName, bool bBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(IsValidClient(victim))
	{
		SetEventBroadcast(hEvent, true);
	}

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(IsValidClient(attacker))
	{
		SetEventBroadcast(hEvent, true);
	}
	
	int bystanders = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if(isBystander[i] || isBystanderWeapon[i] && IsPlayerAlive(i))
			{
				bystanders++;
			}
		}
	}
	
	if(attacker != victim)
	{
		if(isMurder[attacker] && bystanders > 0)
		{
			PrintToChat(attacker, "%s \x02%i \x01Bystanders Remain!", PREFIX, bystanders);
			PrintToChat(victim, "%s \x02You Were Killed by the \x0EMurderer\x02!", PREFIX);
		}
		
		if(isBystander[attacker] || isBystanderWeapon[attacker])
		{
			if(isBystander[victim] || isBystanderWeapon[victim])
			{
				PrintToChat(attacker, "%s \x02You Killed a \x0EBystander\x02!", PREFIX);
				PrintToChat(victim, "%s \x02You Were Killed by a \x0EBystander \x01(\x0C%N\x01)\x02!", PREFIX, attacker);
			}
			else if(isMurder[victim])
			{
				PrintToChat(attacker, "%s \x04You Killed the \x02Murderer\x04!", PREFIX);
				PrintToChat(victim, "%s \x02You Were Killed by a \x0EBystander \x01(\x0C%N\x01)\x02!", PREFIX, attacker);
			}
		}
	}
		
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(client, &buttons, &impulse, float vel[3], float angles[3], &weapon)
{ 
	if ((buttons & IN_ATTACK) == IN_ATTACK) 
	{
		char classname[64];
		GetClientWeapon(client, classname, 64);
		if(StrEqual(classname, "weapon_deagle"))
		{
			CreateTimer(0.01, dropDeagle, client);
		}
	}
}

public Action dropDeagle(Handle timer, int client)
{
	if(IsValidClient(client))
	{
		FakeClientCommand(client, "use weapon_deagle");
		FakeClientCommand(client, "drop");
		cooldown = true;
		CreateTimer(5.0, cooldownToggle);
		CloseHandle(timer);
	}
}

public Action cooldownToggle(Handle timer)
{
	cooldown = false;
	CloseHandle(timer);
}

public Action OnWeaponPickUp(int client, int weapon)
{
	char sWeapon[32];  
	GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));  
      
	if(StrEqual(sWeapon, "weapon_deagle") && cooldown)  
	{  
		return Plugin_Handled;
	}
	else if(StrEqual(sWeapon, "weapon_deagle") && isMurder[client])
	{
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action OnWeaponEquip(int client, int weapon)  
{
	if(IsValidClient(client, true) && IsValidEntity(weapon))
	{
		char sWeapon[32];  
		GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));  
		  
		if(StrEqual(sWeapon, "weapon_deagle"))
		{
			CreateTimer(0.01, setAmmo, client);
			PrintToChat(client, "%s \x04You have picked up the gun!", PREFIX);
		}
	}
	return Plugin_Continue;  
}

public Action setAmmo(Handle timer, int client)
{
	if(IsValidClient(client, true))
	{
		int deagle = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		SetEntProp(deagle, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
		SetEntProp(deagle, Prop_Send, "m_iClip1", 1);
	}
	CloseHandle(timer);
}

/*public Action checkWin(Handle timer)
{
	int bystanders = 0;
	int murder = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, true))
		{
			if(isBystander[i] || isBystanderWeapon[i])
			{
				bystanders++;
			}
			else
			{
				murder++;
			}
		}
	}
	
	if(murder == 0)
	{
		PrintToChatAll("%s \x04Bystanders \x0Ehave \x0CWon\x0E!", PREFIX);
	}
	else if(bystanders == 0)
	{
		PrintToChatAll("%s \x02Murderer \x0Ehas \x0CWon\x0E!", PREFIX);
	}
}*/

StripWeapons(target)
{
	int weapon = -1;
	for (new i = 0; i <= 5; i++)
	{
	    if ((weapon = GetPlayerWeaponSlot(target, i)) != -1)
	    {
	        RemovePlayerItem(target, weapon);
	    }
	}
}

stock GetRandomPlayer() {

    int clients[MAXPLAYERS + 1];
    int clientCount;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            clients[clientCount++] = i;
        }
    }
    return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock bool IsValidClient(client, bool nobots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
    {
        return false; 
    }
    return IsClientInGame(client); 
}  


