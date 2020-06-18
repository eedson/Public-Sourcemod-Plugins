#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "cow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <emitsoundany>
#include "include/pug.inc"

public Plugin myinfo = 
{
	name = "pug",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define PREFIX  "[\x04OPEN\x01]"

/* Client Variables */
bool isReady[MAXPLAYERS + 1] = false;

/* Plugin Variables */
bool isLive = false;
bool knifeRound = false;
int livePlayers = 0;

/* handles */
Handle onPugStart = null;
Handle onPugEnd = null;

/* Plugin Natives */
public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int err_max)
{
	CreateNative("pug_IsLive", Native_IsLive);
	CreateNative("pug_IsPlayerReady", Native_IsPlayerReady);
	
	return APLRes_Success;
}

public int Native_IsLive(Handle plugin, int numParams)
{
	return isLive;
}

public int Native_IsPlayerReady(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (IsValidClient(client))
	{
		return isReady[client];
	}
	else
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	}
}




public void OnPluginStart()
{
	/* Create Forwards */
	onPugStart = CreateGlobalForward("pug_OnPugStart", ET_Ignore, Param_Cell);
	onPugEnd = CreateGlobalForward("pug_OnPugEnd", ET_Ignore, Param_Cell);
	
	/* Client Commands */
	RegConsoleCmd("sm_ready", doReady);
	
	/* Admin Commands */
	RegAdminCmd("sm_start", startMatch, ADMFLAG_BAN);
	RegAdminCmd("sm_end", endMatch, ADMFLAG_BAN);
	
	/* Timers */
	CreateTimer(1.0, doHint, _, TIMER_REPEAT);
	CreateTimer(5.0, checkScore, _, TIMER_REPEAT);
	CreateTimer(1.0, removeTag, _, TIMER_REPEAT);
	
	/* Hooked Events */
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
}

public void OnClientPutInServer(int client)
{
	/* Set Defaults */
	isReady[client] = false;
}

public void OnClientDisconnect(int client)
{
	/* Set Defaults */
	isReady[client] = false;
	if(!isLive)
	{
		livePlayers--;
	}
}

public OnMapStart()
{
	if(!isLive)
	{
		livePlayers = 0;
		ServerCommand("exec warmup.cfg");
		PrintToChatAll("%s \x02Server is now in \x04WARMUP\x02!", PREFIX);
	}
}

public void OnConfigsExecuted()
{
	PrecacheSoundAny("pug/ready.mp3");
	AddFileToDownloadsTable("sound/pug/ready.mp3");
}


public OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (strcmp(sArgs, ".ready", false) == 0)
	{
		if(!isLive)
		{
			if(!isReady[client] && !IsClientObserver(client))
			{
				PrintToChatAll("%s \x02%N \x01is now \x04Ready!", PREFIX, client);
				isReady[client] = true;
				EmitSoundToClientAny(client, "pug/ready.mp3");
			}
		}
	}
}

/* Hooked Event Callbacks */
public Action Event_PlayerTeam(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetEventInt(event, "team");
	if (!isLive && team == CS_TEAM_SPECTATOR)
	{
		isReady[client] = false;
		livePlayers--;
		return Plugin_Continue;
	}
	else
	{
		if(team == CS_TEAM_CT)
		{
			int playerCountCT = GetTeamClientCount(CS_TEAM_CT);
			if(playerCountCT == 5)
			{
				return Plugin_Handled;
			}
		}
		else if (team == CS_TEAM_T)
		{
			int playerCountT = GetTeamClientCount(CS_TEAM_T);
			if(playerCountT == 5)
			{
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public OnRoundStart(Handle event, char[] name, bool dontBroadcast) 
{
	if(isLive)
	{
		if(knifeRound)
		{
			
		}
		int ctScore = GetTeamScore(CS_TEAM_CT);
		int tScore = GetTeamScore(CS_TEAM_T);
		PrintToChatAll("%s Score is \x0CCT: \x04%i \x01and \x02T: \x04%i", PREFIX, ctScore, tScore);
	 }
}  

/* Command Callbacks */
public Action doReady(int client, int args)
{
	if(!isLive)
	{
		if(!isReady[client] && !IsClientObserver(client))
		{
			PrintToChatAll("%s \x02%N \x01is now \x04Ready!", PREFIX, client);
			isReady[client] = true;
			EmitSoundToClientAny(client, "pug/ready.mp3");
		}
	}
	return Plugin_Handled;
}

public Action startMatch(int client, int args)
{
	StartPug();
}

public Action endMatch(int client, int args)
{
	EndPug();
}

/* Timer Callbacks */
public Action checkScore(Handle timer)
{
	if(isLive)
	{
		int ctScore = GetTeamScore(CS_TEAM_CT);
		int tScore = GetTeamScore(CS_TEAM_T);
		
		int ctPlayers, tPlayers;
		
		for (new i=1; i<MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				int team = GetClientTeam(i);
				
				if(team == CS_TEAM_CT)
				{
					ctPlayers++;
				}
				else if(team == CS_TEAM_T)
				{
					tPlayers++;
				}
			}
		}
		
		if(ctPlayers < 3)
		{
			EndPug();
			PrintToChatAll("%s \x0ENOT ENOUGH PLAYERS ON CT TEAM\x02!", PREFIX);
			PrintToChatAll("%s \x02CT TEAM HAS \x04SURRENDERED\x02!", PREFIX);
			CreateTimer(10.0, nextMap);
		}
		else if(tPlayers < 3)
		{
			EndPug();
			PrintToChatAll("%s \x0ENOT ENOUGH PLAYERS ON T TEAM\x02!", PREFIX);
			PrintToChatAll("%s \x02T TEAM HAS \x04SURRENDERED\x02!", PREFIX);
			CreateTimer(10.0, nextMap);
		}
		
		if(ctScore == 16)
		{
			EndPug();
			PrintToChatAll("%s \x02CT TEAM HAS \x04WON\x02!", PREFIX);
			CreateTimer(10.0, nextMap);
	  	}
	  	else if(tScore == 16)
	  	{
	  		EndPug();
			PrintToChatAll("%s \x02T TEAM HAS \x04WON\x02!", PREFIX);
			CreateTimer(10.0, nextMap);
	 	}
	 	else if (ctScore == 15 && tScore == 15)
	 	{
	 		EndPug();
			PrintToChatAll("%s \x02The game is a \x04Draw\x02!", PREFIX);
			CreateTimer(10.0, nextMap);
		}
	}
}

public Action nextMap(Handle timer)
{
	char szNextMap[64];
	if (GetNextMap(szNextMap, sizeof(szNextMap)))
	{
		ForceChangeLevel(szNextMap, "Force change to nextmap");
	}
	CloseHandle(timer);
}

public Action removeTag(Handle timer)
{
	if(isLive)
	{
		for (new i=1; i<MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				CS_SetClientClanTag(i, " ");
			}
		}
	}
	ServerCommand("bot_kick");
}

public Action doHint(Handle timer)
{
	if(!isLive)
	{
		int readyPlayers = 0;
		int totalPlayers = 0;
		
		for (new i=1; i<MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				if(isReady[i])
				{
					readyPlayers++;
					CS_SetClientClanTag(i, "[READY]");
				}
		   		else
		   		{
		   			CS_SetClientClanTag(i, "[NOT READY]");
		   		}
				totalPlayers++;
			}	
		}
			
		livePlayers = readyPlayers;
		
		for (new i=1; i<MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				if(isReady[i])
				{
					PrintHintText(i,"	[<font color='#2FD30B'>OPEN</font>]\n   %i/%i players ready\n   You are <font color='#2FD30B'>Ready</font>!", readyPlayers, totalPlayers);
				}
				else
				{
					PrintHintText(i,"	[<font color='#2FD30B'>OPEN</font>]\n   %i/%i players ready\n   You are <font color='#DB0E0E'>Not Ready</font>!", readyPlayers, totalPlayers);
		   		}
		   	}
		}
		
		if (livePlayers == 10)
		{
			StartPug();
	  	}	
	}
}

void StartPug()
{
	isLive = true;
	ServerCommand("exec live.cfg");
	PrintToChatAll("%s \x02Server is now in \x04LIVE\x02!", PREFIX);
	
	for (new i=1; i<MaxClients; i++)
	{
		isReady[i] = false;
	}
	
	knifeRound = true;
	
	Call_StartForward(onPugStart);
	Call_Finish();
}

void EndPug()
{
	isLive = false;
	livePlayers = 0;
	ServerCommand("exec warmup.cfg");
	PrintToChatAll("%s \x02Server is now in \x04WARMUP\x02!", PREFIX);
	
	Call_StartForward(onPugEnd);
	Call_Finish();
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}

