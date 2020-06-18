#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "cow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include "include/pug.inc"

public Plugin myinfo = 
{
	name = "OPEN STATS",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define PREFIX  "[\x04OPEN\x01]"

/* Datbase Handle */
Handle db;

/* Stats Variables */
float damageDone[MAXPLAYERS + 1];
float rws[MAXPLAYERS + 1];
int adr[MAXPLAYERS + 1];
int rounds[MAXPLAYERS + 1];

bool fullGame[MAXPLAYERS + 1];

bool planted[MAXPLAYERS + 1];
bool defused[MAXPLAYERS + 1];
bool specialWin = false;


/* Total Damage for Round */
float Tdamage;
float CTdamage;

/* Match Stats */
int kills[MAXPLAYERS + 1];
int deaths[MAXPLAYERS + 1];

bool gotKill[MAXPLAYERS + 1];
int rounds_with_kills[MAXPLAYERS + 1];

int killCount[MAXPLAYERS + 1];
int zero_kills[MAXPLAYERS + 1];
int one_kills[MAXPLAYERS + 1];
int two_kills[MAXPLAYERS + 1];
int three_kills[MAXPLAYERS + 1];
int four_kills[MAXPLAYERS + 1];
int five_kills[MAXPLAYERS + 1];

bool openingKill;
int opening_kills[MAXPLAYERS + 1];
int opening_deaths[MAXPLAYERS + 1];
int wins_1v1[MAXPLAYERS + 1];
int losses_1v1[MAXPLAYERS + 1];
int wins_1v2[MAXPLAYERS + 1];
int wins_1v3[MAXPLAYERS + 1];
int wins_1v4[MAXPLAYERS + 1];
int wins_1v5[MAXPLAYERS + 1];


/* Sourcemod Functions */
public void OnPluginStart()
{
	/* Connect to Database */
	DataBaseConnect();
	
	/* Client Commands */
	RegConsoleCmd("sm_stats", getStats);
	
	RegAdminCmd("sm_tdmg", tDamage, ADMFLAG_BAN);
	RegAdminCmd("sm_ctdmg", ctDamage, ADMFLAG_BAN);
	
	/* Hook Events */
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent( "bomb_planted", Event_BombPlanted );
	HookEvent( "bomb_defused", Event_BombDefused );
	HookEvent("player_death", PlayerDeath);
}

public void OnClientPutInServer(int client)
{
	/* Hook Damage for stats */
	SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
	
	/* Set Stats Variables to Default */
	damageDone[client] = 0.0;
	rws[client] = 0.0;
	adr[client] = 0;
	rounds[client] = 0;
	fullGame[client] = false;
	planted[client] = false;
	defused[client] = false;
	
	/* Set Match Variables to Default */
	kills[client] = 0;
	deaths[client] = 0;
	gotKill[client] = false;
	rounds_with_kills[client] = 0;
	zero_kills[client] = 0;
	one_kills[client] = 0;
	two_kills[client] = 0;
	three_kills[client] = 0;
	four_kills[client] = 0;
	five_kills[client] = 0;
	opening_kills[client] = 0;
	opening_deaths[client] = 0;
	wins_1v1[client] = 0;
	losses_1v1[client] = 0;
	wins_1v2[client] = 0;
	wins_1v3[client] = 0;
	wins_1v4[client] = 0;
	wins_1v5[client] = 0;
	
	/* Query Database and check if client exists */
	char steamid64[64];
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
	int userID = GetClientUserId(client);
	char query[300];
	Format(query, sizeof(query), "SELECT * FROM PLAYERS WHERE steamid = '%s'", steamid64);
	SQL_TQuery(db, CheckFail, query, userID);
}

public OnClientDisconnect(int client)
{
	/* Set Stats Variables to Default */
	damageDone[client] = 0.0;
	rws[client] = 0.0;
	adr[client] = 0;
	rounds[client] = 0;
	fullGame[client] = false;
	planted[client] = false;
	defused[client] = false;
	
	/* Set Match Variables to Default */
	kills[client] = 0;
	deaths[client] = 0;
	gotKill[client] = false;
	rounds_with_kills[client] = 0;
	zero_kills[client] = 0;
	one_kills[client] = 0;
	two_kills[client] = 0;
	three_kills[client] = 0;
	four_kills[client] = 0;
	five_kills[client] = 0;
	opening_kills[client] = 0;
	opening_deaths[client] = 0;
	wins_1v1[client] = 0;
	losses_1v1[client] = 0;
	wins_1v2[client] = 0;
	wins_1v3[client] = 0;
	wins_1v4[client] = 0;
	wins_1v5[client] = 0;
}

/* Client Command Callbacks */
public Action getStats(int client, int args)
{
	char steamid64[64];
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
	
	int userID = GetClientUserId(client);
	
	char query[500];
	Format(query, sizeof(query), "SELECT * FROM PLAYERS WHERE steamid = '%s'", steamid64);
	SQL_TQuery(db, CheckStats, query, userID);
	
	return Plugin_Handled;
}

public Action tDamage(int client, int args)
{
	PrintToChat(client, "%i", Tdamage);
	return Plugin_Handled;
}
public Action ctDamage(int client, int args)
{
	PrintToChat(client, "%i", CTdamage);
	return Plugin_Handled;
}

/* Timer Callbacks */
public Action doPrint(Handle timer, int client)
{
	PrintToChat(client, "%s Stats Successfully Loaded!", PREFIX);
	CloseHandle(timer);
}

/* Hook Event Callbacks */
public Action Event_BombPlanted(Handle event, char[] name, bool dontBroadcast)
{
	int id = GetClientOfUserId( GetEventInt( event, "userid" ) );
	planted[id] = true;
	specialWin = true;
}

public Action Event_BombDefused(Handle event, char[] name, bool dontBroadcast)
{
	int id = GetClientOfUserId( GetEventInt( event, "userid" ) );
	defused[id] = true;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])  
{
	if(IsValidClient(attacker) && IsValidClient(victim) && victim != attacker && GetClientTeam(victim) != GetClientTeam(attacker) && pug_IsLive())
	{
		int health = GetClientHealth(victim);
		//PrintToChatAll("%i on player %N", health, victim);
		if(damage > health)
		{
			damage = float(health);
			//PrintToChatAll("%i damage was done to %N from attacker %N", damage, victim, attacker);
		}
		
		damageDone[attacker] = damageDone[attacker] + damage;
		
		int team = GetClientTeam(attacker);
		if(team == 2)
		{
			Tdamage = Tdamage + damage;
		}
		else if(team == 3)
		{
			CTdamage = CTdamage + damage;
		}
	}
}

public Action PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(client != attacker)
	{
		if(IsValidClient(client) && GetClientTeam(client) != GetClientTeam(attacker))
		{
			deaths[client]++;
			
			if(openingKill)
			{
				opening_deaths[client]++;
			}
		}
		if(IsValidClient(attacker))
		{
			if(GetClientTeam(client) != GetClientTeam(attacker))
			{
				kills[attacker]++;
				gotKill[attacker] = true;
				
				killCount[attacker]++;
				
				if(openingKill)
				{
					opening_deaths[attacker]++;
				}
			}
			else
			{
				kills[attacker]--;
				if(killCount[attacker] > 0)
				{
					killCount[attacker]--;
				}
			}
		}
		
		if(openingKill)
		{
			openingKill = false;
		}
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(pug_IsLive())
	{
		Tdamage = 0.0;
		CTdamage = 0.0;
		specialWin = false;
		
		openingKill = true;
		
		for (int i = 1; i <= MaxClients; i++)
		{
		    if (IsValidClient(i))
		    {
		    	damageDone[i] = 0.0;
		    	planted[i] = false;
		    	defused[i] = false;
		    	
		    	gotKill[i] = false;
		    	killCount[i] = 0;
		    }
		}
	}
	else
	{
		ServerCommand("mp_startmoney 64000");
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(pug_IsLive())
	{
		int WinningTeam = GetEventInt(event, "winner");
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				if(gotKill[i])
				{
					rounds_with_kills[i]++;
				}
				else
				{
					zero_kills[i]++;
				}
				
				if(killCount[i] == 1)
				{
					one_kills[i]++;
				}
				else if(killCount[i] == 2)
				{
					two_kills[i]++;
				}
				else if(killCount[i] == 3)
				{
					three_kills[i]++;
				}
				else if(killCount[i] == 4)
				{
					four_kills[i]++;
				}
				else if(killCount[i] == 5)
				{
					five_kills[i]++;
				}
				killCount[i] = 0;
			}
			
			if (IsValidClient(i) && GetClientTeam(i) == WinningTeam)
		    {
		    	if(specialWin)
		    	{
		    		if(WinningTeam == 2)
			    	{
			    		if(planted[i])
			    		{
			    			rws[i] = rws[i] + (damageDone[i] / Tdamage) * 100 + 30;
			    			rounds[i]++;
			    			//float round_rws = (damageDone[i] / Tdamage) * 100 + 30;
			    			//PrintToChat(i, "%s you have earned \x0E%.2f \x04RWS \x01this round!", PREFIX, round_rws);
			    		}
			    		else
			    		{
			    			rws[i] = rws[i] + (damageDone[i] / Tdamage) * 100 * 0.7;
			    			rounds[i]++;
			    			//float round_rws = (damageDone[i] / Tdamage) * 100 * 0.7;
			    			//PrintToChat(i, "%s you have earned \x0E%.2f \x04RWS \x01this round!", PREFIX, round_rws);
			    		}
			    	}
			    	else if(WinningTeam == 3)
			    	{
			    		if(defused[i])
			    		{
			    			rws[i] = rws[i] + (damageDone[i] / CTdamage) * 100 + 30;
			    			rounds[i]++;
			    			//float round_rws = (damageDone[i] / CTdamage) * 100 + 30;
			    			//PrintToChat(i, "%s you have earned \x0E%.2f \x04RWS \x01this round!", PREFIX, round_rws);
			    		}
			    		else
			    		{
			    			rws[i] = rws[i] + (damageDone[i] / CTdamage) * 100 * 0.7;
			    			rounds[i]++;
			    			//float round_rws = (damageDone[i] / CTdamage) * 100 * 0.7;
			    			//PrintToChat(i, "%s you have earned \x0E%.2f \x04RWS \x01this round!", PREFIX, round_rws);
			    		}
			   		}
		    	}
		    	else
		    	{
			    	if(WinningTeam == 2)
			    	{
			    		rws[i] = rws[i] + (damageDone[i] / Tdamage) * 100;
			    		rounds[i]++;
			    		
			    		//float round_rws = (damageDone[i] / Tdamage) * 100;
			    		//PrintToChat(i, "%s you have earned \x0E%.2f \x04RWS \x01this round!", PREFIX, round_rws);
			    	}
			    	else if(WinningTeam == 3)
			    	{
			    		rws[i] = rws[i] + (damageDone[i] / CTdamage) * 100;
			    		rounds[i]++;
			    		
			    		//float round_rws = (damageDone[i] / CTdamage) * 100;
			    		//PrintToChat(i, "%s you have earned \x0E%.2f \x04RWS \x01this round!", PREFIX, round_rws);
			   		}
			   	}
		    }
			else if (IsValidClient(i) && GetClientTeam(i) != WinningTeam)
		    {
		    	rws[i] = rws[i] + 0;
		    	rounds[i]++;
		  	}
		  	/* Set ADR */
			adr[i] = adr[i] +	RoundToZero(damageDone[i]);
		}
	}
}

/* PUG Callbacks */
public void pug_OnPugStart()
{
	Tdamage = 0.0;
	CTdamage = 0.0;
	specialWin = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
	    	damageDone[i] = 0.0;
	    	rws[i] = 0.0;
	    	adr[i] = 0;
	    	rounds[i] = 0;
	    	fullGame[i] = true;
	    	planted[i] = false;
	    	defused[i] = false;
	    	
	    	/* Set Match Variables to Default */
			kills[i] = 0;
			deaths[i] = 0;
			gotKill[i] = false;
			rounds_with_kills[i] = 0;
			killCount[i] = 0;
			zero_kills[i] = 0;
			one_kills[i] = 0;
			two_kills[i] = 0;
			three_kills[i] = 0;
			four_kills[i] = 0;
			five_kills[i] = 0;
			opening_kills[i] = 0;
			opening_deaths[i] = 0;
			wins_1v1[i] = 0;
			losses_1v1[i] = 0;
			wins_1v2[i] = 0;
			wins_1v3[i] = 0;
			wins_1v4[i] = 0;
			wins_1v5[i] = 0;
		}
	}
}
public void pug_OnPugEnd()
{		
	for (int i = 1; i <= MaxClients; i++)
	{
	    if (IsValidClient(i))
	    {	
			char steamid64[64];
			GetClientAuthId(i, AuthId_SteamID64, steamid64, sizeof(steamid64));
	    	
			int userID = GetClientUserId(i);
	    	
			float finish_rws = rws[i] / rounds[i];
			int finish_adr = adr[i] / rounds[i];
	    	
			PrintToChat(i, "%s You have finished the Match with \x0E%.2f \x04RWS \x01and \x0E%i \x04ADR", PREFIX, finish_rws, finish_adr);
			PrintToChat(i, "%s Saving Stats...", PREFIX);
			
			char query[500];
			Format(query, sizeof(query), "SELECT * FROM PLAYERS WHERE steamid = '%s'", steamid64);
			SQL_TQuery(db, FinishRWS, query, userID);
			
			/* MATCH STATS */
			char username[128], EscapedUsername[128 * 2 + 1];
			GetClientName(i, username, sizeof(username));
			SQL_EscapeString(db, username, EscapedUsername, 128 * 2 + 1);
			
			char query2[500];
			Format(query2, sizeof(query2), "INSERT INTO `MATCHES` (`steamid`, `username`, `kills`, `deaths`, `rounds_with_kills`, `0_kills`, `1_kills`, `2_kills`, `3_kills`, `4_kills`, `5_kills`, `opening_kills`, `opening_deaths`) VALUES ('%s', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i')", steamid64, EscapedUsername, kills[i], deaths[i], rounds_with_kills[i], zero_kills[i], one_kills[i], two_kills[i], three_kills[i], four_kills[i], five_kills[i], opening_kills[i], opening_deaths[i]);
			SQL_TQuery(db, FinishStats, query2, userID);
	    }
	}
}


/* Database Callbacks */
public void CheckFail(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;

	if(!SQL_FetchRow(hndl))
	{
		if(!IsFakeClient(client))
		{
			PutClientInDB(client);
		}
	} 
	/*else 
	{
		CreateTimer(3.0, doPrint, client);
	}*/
}

public void CheckStats(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;

	if(!SQL_FetchRow(hndl))
	{
		LogMessage("Client tried to check rws but was not found in database.");
	} 
	else 
	{
		float rws_print = SQL_FetchFloat(hndl, 2);
		int adr_print = SQL_FetchInt(hndl, 3);
		PrintToChat(client, "%s Your Average \x04RWS \x01this month is \x04%.2f", PREFIX, rws_print);
		PrintToChat(client, "%s Your Average \x04ADR \x01this month is \x04%i", PREFIX, adr_print);
	}
}

public void FinishRWS(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;

	if(!SQL_FetchRow(hndl))
	{
		LogMessage("Failed to find client in database at end of game");
	} 
	else 
	{
		if(fullGame[client])
		{
			char steamid64[64];
			GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
			
			int userID2 = GetClientUserId(client);
			
			/* Final Stats */
			float final_rws = rws[client] / rounds[client];
			float stored_rws = SQL_FetchFloat(hndl, 2);
			
			int final_adr = adr[client] / rounds[client];
			int stored_adr = SQL_FetchInt(hndl, 3);
			
			if(stored_rws == 0)
			{
				char query[500];
				Format(query, sizeof(query), "UPDATE PLAYERS SET rws = %.2f, adr = %i WHERE steamid = %s", final_rws, final_adr, steamid64);
				SQL_TQuery(db, FinishRWS2, query, userID2);
			}
			else
			{
				float finish_rws = (final_rws + stored_rws) / 2;
				int finish_adr = (final_adr + stored_adr) / 2;
				
				//Monitor database
				char query[500];
				Format(query, sizeof(query), "UPDATE PLAYERS SET rws = %.2f, adr = %i WHERE steamid = %s", finish_rws, finish_adr, steamid64);
				SQL_TQuery(db, FinishRWS2, query, userID2);
			}
			fullGame[client] = false;
		}
	}
}

public void FinishRWS2(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;

	PrintToChat(client, "%s Stats Saved!", PREFIX);
	damageDone[client] = 0.0;
	rws[client] = 0.0;
	adr[client] = 0;
	rounds[client] = 0;
	fullGame[client] = true;
	planted[client] = false;
	defused[client] = false;
}

public void FinishStats(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;

	if(!SQL_FetchRow(hndl))
	{
		LogMessage("Failed to find client in database at end of game");
	} 
	else 
	{
		if(IsValidClient(client))
		{
	    	/* Set Match Variables to Default */
			kills[client] = 0;
			deaths[client] = 0;
			gotKill[client] = false;
			rounds_with_kills[client] = 0;
			zero_kills[client] = 0;
			one_kills[client] = 0;
			two_kills[client] = 0;
			three_kills[client] = 0;
			four_kills[client] = 0;
			five_kills[client] = 0;
			opening_kills[client] = 0;
			opening_deaths[client] = 0;
			wins_1v1[client] = 0;
			losses_1v1[client] = 0;
			wins_1v2[client] = 0;
			wins_1v3[client] = 0;
			wins_1v4[client] = 0;
			wins_1v5[client] = 0;
			
			fullGame[client] = false;
		}
	}
}

/* Database Connection */
void DataBaseConnect() 
{
	char error[255];
	db = SQL_Connect("pugstats", false, error, sizeof(error));
	 
	if (db == INVALID_HANDLE) {
		PrintToServer("[PugStats] Could not connect: %s\n TELL COW!", error);
	} else {
		PrintToServer("[PugStats] Connection successful");
	}
	
	SQL_FastQuery(db, "SET NAMES \"UTF8\"");  
	
}

void PutClientInDB(int client)
{
	char username[128], steamid64[64], EscapedUsername[128 * 2 + 1];
	GetClientName(client, username, sizeof(username));
	SQL_EscapeString(db, username, EscapedUsername, 128 * 2 + 1);
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
	int userID = GetClientUserId(client);
	
	//Monitor database
	char query[500];
	Format(query, sizeof(query), "INSERT INTO `PLAYERS` (`steamid`, `username`) VALUES ('%s', '%s')", steamid64, EscapedUsername);
	SQL_TQuery(db, OnRowInserted, query);
	
	//Main player database
	char query2[300];
	Format(query2, sizeof(query2), "SELECT * FROM PLAYERS WHERE steamid = '%s'", steamid64);
	SQL_TQuery(db, T_SelectPlayerInDatabase, query2, userID);
}

public void T_SelectPlayerInDatabase(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;
		
	char username[128], steamid64[64], EscapedUsername[128 * 2 + 1];
	GetClientName(client, username, sizeof(username));
	SQL_EscapeString(db, username, EscapedUsername, 128 * 2 + 1);
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));

	if(!SQL_FetchRow(hndl))
	{
		
		char query[300];
		Format(query, sizeof(query), "INSERT INTO `PLAYERS` (`username`, `steamid`) VALUES ('%s', '%s', '%s')", EscapedUsername, steamid64);
		SQL_TQuery(db, OnRowInserted, query);
		
	} else {
		
		char query[300];
		Format(query, sizeof(query), "UPDATE `PLAYERS` SET `username` = '%s', WHERE steamid = '%s'", EscapedUsername, steamid64);
		SQL_TQuery(db, OnRowInserted, query);
		
	}
}

public void OnRowInserted(Handle owner, Handle hndl, const char[] error, any userid) {
	
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}