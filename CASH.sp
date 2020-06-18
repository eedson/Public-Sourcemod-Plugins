#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "CodingCow"
#define PLUGIN_VERSION "2.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <sourcebans>
#include "cash/stocks.sp"

public Plugin myinfo = 
{
	name = "CASH",
	author = PLUGIN_AUTHOR,
	description = "Cow Anti-Strafe Hack",
	version = PLUGIN_VERSION,
	url = "www.steamcommunity.com/id/codingcow"
};

/* Datbase Handle */
Handle db;

/* Client Variables */
int pStrafeCount[MAXPLAYERS + 1]; // Amount of Perfect Strafes in a row
bool turnRight[MAXPLAYERS + 1]; // Yaw Direction
int perfSidemove[MAXPLAYERS + 1]; // Amount of 1 Tick Perfect Sidemoves
float prev_sidemove[MAXPLAYERS + 1]; // Previous Tick's Sidemove

/* Used for getting teleport tick */
int g_iCmdNum[MAXPLAYERS + 1];
int g_iLastTeleportTick[MAXPLAYERS + 1];

/* Previous Tick's Input */
float prev_angles[MAXPLAYERS + 1];
int prev_buttons[MAXPLAYERS + 1];
int prev_mousedx[MAXPLAYERS + 1];

/* Client Settings */
float g_Sensitivity[MAXPLAYERS + 1];
float g_mYaw[MAXPLAYERS + 1];
int g_mCustomAccel[MAXPLAYERS + 1];

public void OnPluginStart()
{
	/* Connect to Database */
	CashDataBaseConnect();
	
	/* Commands */
	RegAdminCmd("sm_logs", getLogs, ADMFLAG_BAN);
	RegAdminCmd("sm_clearlogs", clearLogs, ADMFLAG_ROOT);
	
	CreateTimer(0.2, getSettings, _, TIMER_REPEAT);
	
	HookEntityOutput("trigger_teleport", "OnTrigger", teleTrigger);
}

public void OnClientPutInServer(int client)
{
	/* Set Defaults */
	pStrafeCount[client] = 0;
	turnRight[client] = true;
	perfSidemove[client] = 0;
	prev_sidemove[client] = 0.0;
	g_iCmdNum[client] = 0;
}

public void OnClientDisconnect(int client)
{
	/* Set Defaults */
	pStrafeCount[client] = 0;
	perfSidemove[client] = 0;
	prev_sidemove[client] = 0.0;
	g_iCmdNum[client] = 0;
}

/* Get Player Settings */
public Action getSettings(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			QueryClientConVar(i, "sensitivity", ConVarQueryFinished:ConVar_QueryClient, i);
			QueryClientConVar(i, "m_yaw", ConVarQueryFinished:ConVar_QueryClient, i);
			QueryClientConVar(i, "m_customaccel", ConVarQueryFinished:ConVar_QueryClient, i);
		}
	}
}

public ConVar_QueryClient(QueryCookie:cookie, int client, ConVarQueryResult:result, const char[] cvarName, const char[] cvarValue)
{
	if(IsValidClient(client))
	{
		if(result == ConVarQuery_Okay)
		{
			if(StrEqual("sensitivity", cvarName))
			{
				g_Sensitivity[client] = StringToFloat(cvarValue);
			}
			else if(StrEqual("m_yaw", cvarName))
			{
				g_mYaw[client] = StringToFloat(cvarValue);
			}
			else if(StrEqual("m_customaccel", cvarName))
			{
				g_mCustomAccel[client] = StringToInt(cvarValue);
			}
		}
	}      
}

/* Command Callbacks */
public Action getLogs(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_logs <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[128];
	GetCmdArg(1, arg, sizeof(arg));
	
	int target = FindTarget(client, arg, true, false);
	
	if(IsValidClient(target))
	{
		char steamid[64];
		GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid));
		int userID = GetClientUserId(client);
		char query[300];
		Format(query, sizeof(query), "SELECT * FROM log WHERE steamid = '%s'", steamid);
		SQL_TQuery(db, CheckLogs, query, userID);
	}
	
	return Plugin_Handled;
}

public Action clearLogs(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_clearlogs <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[128];
	GetCmdArg(1, arg, sizeof(arg));
	
	int target = FindTarget(client, arg, true, false);
	
	if(IsValidClient(target))
	{
		char steamid[64];
		GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid));
		int userID = GetClientUserId(client);
		char query[300];
		Format(query, sizeof(query), "DELETE FROM log WHERE steamid = '%s'", steamid);
		SQL_TQuery(db, OnRowInserted, query, userID);
		
		PrintToChat(client, "[\x02CASH\x01] %N's logs have been cleared.", target);
	}
	
	return Plugin_Handled;
}

/* Run Detection Methods */
public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mousedx[2])
{
	if(IsValidClient(client, false, false))
	{
		if(!(GetEntityFlags(client) & FL_ONGROUND))
		{	
			CheckPStrafeCount(client, mousedx[0], iButtons);
			
			CheckSilentStrafe(client, fVelocity[1]);
			
			//CheckOptiBehavior(client, fAngles[1], iButtons, mousedx[0]);
		}
		
		prev_angles[client] = fAngles[1];
		prev_buttons[client] = iButtons;
		prev_mousedx[client] = mousedx[0];
		g_iCmdNum[client]++;
	}
}

/* Detection Methods */

/* Check if client is using Perfect Strafe */
public void CheckPStrafeCount(int client, int mousedx, int iButtons)
{
	if(mousedx > 0 && turnRight[client])
	{
		if(!(prev_buttons[client] & IN_MOVERIGHT) && iButtons & IN_MOVERIGHT && !(iButtons & IN_MOVELEFT))
		{
			pStrafeCount[client]++;
			
			CheckPerfCount(client);
		}
		else
		{
			if(pStrafeCount[client] >= 10)
			{
				LogPlayer(client, "Consistant Perfect Strafe", pStrafeCount[client]);
			}
			
			pStrafeCount[client] = 0;
		}
		
		turnRight[client] = false;
	}
	else if(mousedx < 0 && !turnRight[client])
	{
		if(!(prev_buttons[client] & IN_MOVELEFT) && iButtons & IN_MOVELEFT && !(iButtons & IN_MOVERIGHT))
		{
			pStrafeCount[client]++;
			
			CheckPerfCount(client);
		}
		else
		{
			if(pStrafeCount[client] >= 10)
			{
				LogPlayer(client, "Consistant Perfect Strafe", pStrafeCount[client]);
			}
			
			pStrafeCount[client] = 0;
		}
		
		turnRight[client] = true;
	}
}

/* Check Amount of Consistant Perfect Strafes */
public void CheckPerfCount(int client)
{
	if(pStrafeCount[client] >= 15)
	{
		DetectPlayer(client, "Consistant Perfect Strafe", pStrafeCount[client]);
		
		pStrafeCount[client] = 0;
	}
}

/* Check for possible SilentStrafe */
public void CheckSilentStrafe(int client, float sidemove)
{
	if(sidemove > 0 && prev_sidemove[client] < 0)
	{
		perfSidemove[client]++;
		
		CheckSidemoveCount(client);
	}
	else if(sidemove < 0 && prev_sidemove[client] > 0)
	{
		perfSidemove[client]++;
		
		CheckSidemoveCount(client);
	}
	else
	{
		if(perfSidemove[client] >= 4)
		{
			LogPlayer(client, "Silent-Strafe", perfSidemove[client]);
		}
		
		perfSidemove[client] = 0;
	}
	
	prev_sidemove[client] = sidemove;
}

/* Check Sidemove Count */
public void CheckSidemoveCount(int client)
{
	if(perfSidemove[client] >= 10)
	{
		DetectPlayer(client, "Silent-Strafe", perfSidemove[client]);
		
		perfSidemove[client] = 0;
	}
}

/* Check for possible Optimizer */
public void CheckOptiBehavior(int client, float Angles, int iButtons, int mousedx)
{
	float delta = NormalizeAngle(Angles - prev_angles[client]);
	
	/* Check for super high sensitivity */
	if(GetClientVelocity(client, true, true, false) < 600.0)
	{
		return;
	}
	
	// Prevent incredibly high sensitivity from causing detections
	if(FloatAbs(delta) > 20.0 || FloatAbs(g_Sensitivity[client] * g_mYaw[client]) > 0.8)
	{
		return;
	}
	
	// Check for teleporting because teleporting can cause illegal turn values
	if(g_iCmdNum[client] - g_iLastTeleportTick[client] < 100)
	{
		return;
	}
	
	char message[128];
	Format(message, sizeof(message), "[\x02CASH\x01] %N \x01is \x0EOptimizing \x01(%f) (%i)!", client, delta, mousedx);
	
	if(mousedx > 0 && delta > 0 && mousedx >= 40)
	{
		PrintToAdmins(message, "b");
	}
	else if(mousedx <  0 && delta < 0 && mousedx <= -40)
	{
		PrintToAdmins(message, "b");
	}
}

/* Called when a player teleports */
public void teleTrigger(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator, false, false))
	{
		g_iLastTeleportTick[activator] = g_iCmdNum[activator];
	}
}

/* Called to Detect Player for certain cheat infraction */
public void DetectPlayer(int client, char[] reason, int count)
{
	char ban_message[256];
	Format(ban_message, sizeof(ban_message), "[CASH] %s (%i) Detected.", reason, count);
	
	SBBanPlayer(0, client, 0, ban_message);
	
	PrintToChatAll(" \x02-------------------------------------------");
	PrintToChatAll(" \x02CASH removed \x10%N \x02from the network.", client);
	PrintToChatAll(" \x02Reason: \x10%s (%i)", reason, count);
	PrintToChatAll(" \x02-------------------------------------------");
}

/* Called to Log Player for possible cheat infraction */
public void LogPlayer(int client, char[] reason, int count)
{
	char steamid[128], name[128];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	GetClientName(client, name, sizeof(name));
	
	char date[32];
	FormatTime(date, sizeof(date), "%m/%d/%Y", GetTime());

	char query[500];
	Format(query, sizeof(query), "INSERT INTO `log` (`name`, `steamid`, `detection`, `count`, `date`) VALUES ('%s', '%s', '%s', '%i', '%s')", name, steamid, reason, count, date);
	SQL_TQuery(db, OnRowInserted, query);
	
	char message[128];
	Format(message, sizeof(message), "[\x02CASH\x01] Logged \x04%s \x01%s (\x0E%i\x01)", name, reason, count);
	
	PrintToAdmins(message, "g");
}

/* Database Connection */
void CashDataBaseConnect() 
{
	char error[255];
	db = SQL_Connect("cash", false, error, sizeof(error));
	 
	if (db == INVALID_HANDLE) {
		PrintToServer("[CASH] Could not connect: %s\n TELL COW!", error);
	} else {
		PrintToServer("[CASH] Connection successful");
	}
	
	SQL_FastQuery(db, "SET NAMES \"UTF8\"");  
	
}

/* Database Callbacks */
public void OnRowInserted(Handle owner, Handle hndl, const char[] error, any userid) {
	
}

public void CheckLogs(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;

	if(!SQL_FetchRow(hndl))
	{
		PrintToChat(client, "[\x02CASH\x01] User has no previous logs.");
	} 
	else
	{
		int perfStrafeTotal, perfSidemoveTotal;
		
		PrintToChat(client, "[\x02CASH\x01] See console for output.");
		
		PrintToConsole(client, "--------------------------------------------");
		PrintToConsole(client, "%N's Detection Logs", client);
		PrintToConsole(client, "--------------------------------------------");
		do
		{
			char steamid[128], detection[128], date[32];
			SQL_FetchStringByName(hndl, "steamid", steamid, sizeof(steamid));
			SQL_FetchStringByName(hndl, "detection", detection, sizeof(detection));
			SQL_FetchStringByName(hndl, "date", date, sizeof(date));
			int count = SQL_FetchIntByName(hndl, "count");
			
			if(StrEqual(detection, "Consistant Perfect Strafe"))
			{
				PrintToConsole(client, "SteamID: %s | Detection: %s (%i) | %s", steamid, detection, count, date);
				perfStrafeTotal++;
			}
			else if(StrEqual(detection, "Silent-Strafe"))
			{
				PrintToConsole(client, "SteamID: %s | Detection: %s (%i) | %s", steamid, detection, count, date);
				perfSidemoveTotal++;
			}
		} while (SQL_FetchRow(hndl));
		PrintToConsole(client, "--------------------------------------------");
		PrintToConsole(client, "Total Detections");
		PrintToConsole(client, "• %i Consistant Perfect Strafes", perfStrafeTotal);
		PrintToConsole(client, "• %i Perfect SideMoves", perfSidemoveTotal);
	}
}