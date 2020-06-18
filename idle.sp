#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Cow | Napkil"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <emitsoundany>

public Plugin myinfo = 
{
	name = "idle",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define PREFIX  "[\x0CINJ3CTOR\x01]"

// ### HANDLES ### //
Handle db;
Handle OnlineTimers[MAXPLAYERS+1];
bool nameChange[MAXPLAYERS + 1];


// ### SOURCEMOD HOOKS AND CALLS ### //
public void OnPluginStart()
{
	DataBaseConnect();
	RegConsoleCmd("sm_info", DoInfo);
	RegConsoleCmd("sm_menu", Menu_Test1);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public OnMapStart()
{
	PrecacheSoundAny("root/root_welcome.mp3");
	AddFileToDownloadsTable("sound/root/root_welcome.mp3");
	PrecacheSoundAny("root/root_loaded.mp3");
	AddFileToDownloadsTable("sound/root/root_loaded.mp3");
	PrecacheSoundAny("root/root_name.mp3");
	AddFileToDownloadsTable("sound/root/root_name.mp3");
}

public Action DoInfo(int client, int args)
{
	char username[128], steamid64[64], IPaddress[70], EscapedUsername[128 * 2 + 1];
	GetClientName(client, username, sizeof(username));
	SQL_EscapeString(db, username, EscapedUsername, 128 * 2 + 1);
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
	GetClientIP(client, IPaddress, sizeof(IPaddress));
	
	PrintToChat(client, "%s | %s | %s", username, steamid64, IPaddress);
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{

    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsValidClient(client))
    {
        SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
        CreateTimer(1.0, showMenu, client);
    }
}

public Action showMenu(Handle timer, int client)
{
	if(IsValidClient(client))
	{
		Menu_Test1(client, 0);
	}
	CloseHandle(timer);
}

public void OnClientPutInServer(int client)
{
	CreateTimer(1.0, loadPoints, client);
	CreateTimer(5.0, pointsLoaded, client);
	CreateTimer(1.0, showPoints, client, TIMER_REPEAT);
	
	nameChange[client] = true;
	
	char steamid64[64];
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
		
	int userID = GetClientUserId(client);
	
	//Main player database
	char query2[300];
	Format(query2, sizeof(query2), "SELECT * FROM POINTS WHERE steamid = '%s'", steamid64);
	SQL_TQuery(db, CheckFail, query2, userID);
}

public void OnClientDisconnect(int client)
{
	nameChange[client] = false;
	
	//Kill online timer
	if (OnlineTimers[client] != null)
	{
		KillTimer(OnlineTimers[client]);
		OnlineTimers[client] = null;
	}	
}

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
			//Count online time
			OnlineTimers[client] = CreateTimer(60.0, OnlineTimeAdd, client, TIMER_REPEAT);
		}
		
	} else {
		if(!IsFakeClient(client))
		{
			//Count online time
			OnlineTimers[client] = CreateTimer(60.0, OnlineTimeAdd, client, TIMER_REPEAT);
		}
	}
}

public Action loadPoints(Handle timer, int client)
{
	PrintToChat(client, "%s \x04Loading Points...", PREFIX);
	//EmitSoundToClientAny(client, "root/root_welcome.mp3");
	ClientCommand(client, "play */root/root_welcome.mp3");
	CloseHandle(timer);
}

public Action pointsLoaded(Handle timer, int client)
{
	PrintToChat(client, "%s \x04Points Loaded!", PREFIX);
	//EmitSoundToClientAny(client, "root/root_loaded.mp3");
	ClientCommand(client, "play */root/root_loaded.mp3");
	CloseHandle(timer);
}

public Action showPoints(Handle timer, int client)
{
	if(IsValidClient(client))
	{
	char steamid64[64];
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
		
	int userID = GetClientUserId(client);
		
	//Main player database
	char query[300];
	Format(query, sizeof(query), "SELECT points FROM POINTS WHERE steamid = '%s'", steamid64);
	SQL_TQuery(db, printPoints, query, userID);
	}
	else
	{
		delete timer;
	}
}

public void printPoints(Handle owner, Handle hndl, const char[] error, any userID)
{
	char client_name[16];
	int client = GetClientOfUserId(userID);
	
	GetClientName(client, client_name, sizeof(client_name));
	
	if(client < 1)
		return;

	if(!SQL_FetchRow(hndl))
	{
		PrintToChat(client, " \x02NO DATABASE CONNECTION!");
	} else {
		int pointCount = SQL_FetchInt(hndl, 0);
		float convert = float(pointCount)/25000;
		PrintHintText(client, "<font color='#005ce6' size='20'>POINTS: <font color='#ffffff'>%i</font> | <font color='#ffffff' size='19'>%s\n	    <font color='#1f7a1f' size='19'>$%f\n<font color='#ffffff' size='18'>WWW.ROOT-INJ3CTOR.COM", pointCount, client_name, convert);
	}
}

public MenuHandler1(Handle menu, MenuAction:action, param1, param2)
{
    /* If an option was selected, tell the client about the item. */
    if (action == MenuAction_Select)
    {
        char info[32];
        bool found = GetMenuItem(menu, param2, info, sizeof(info));
        PrintToConsole(param1, "You selected item: %d (found? %d info: %s)", param2, found, info);
        
        // MENU CALLBACKS //
        if(StrEqual(info, "move"))
		{
			SetEntityMoveType(param1, MOVETYPE_WALK);
		}
    }
    /* If the menu was cancelled, print a message to the server about it. */
    else if (action == MenuAction_Cancel)
    {
        PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
    }
    /* If the menu has ended, destroy it */
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}
 
public Action Menu_Test1(int client, int args)
{
	SetEntityMoveType(client, MOVETYPE_NONE);
	
	Handle menu = CreateMenu(MenuHandler1);
    SetMenuTitle(menu, "INJ3CTOR IDLE");
    AddMenuItem(menu, "test1", "As you Idle in this server you gain points that can be converted to real CASH!", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "test2", "If you add INJ3CTOR or INJECTOR to your name you recieve an extra 6 points!", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "test3", "To redeem your cash go to www.sidestrafeservers.com/idle", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "move", "Let me move!");
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 0);
 
    return Plugin_Handled;
}  



// ######## DATABASE CONNECTION AND STUFF ######## //
void DataBaseConnect() 
{

	char error[255];
	db = SQL_Connect("idle", false, error, sizeof(error));
	 
	if (db == INVALID_HANDLE) {
		PrintToServer("[IDLE] Could not connect: %s", error);
	} else {
		PrintToServer("[IDLE] Connection successful");
	}
	
	SQL_FastQuery(db, "SET NAMES \"UTF8\"");  
	
}

void PutClientInDB(int client)
{
	char username[128], steamid64[64], IPaddress[70], EscapedUsername[128 * 2 + 1];
	GetClientName(client, username, sizeof(username));
	SQL_EscapeString(db, username, EscapedUsername, 128 * 2 + 1);
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
	GetClientIP(client, IPaddress, sizeof(IPaddress));
	int userID = GetClientUserId(client);
	
	//Monitor database
	char query[500];
	Format(query, sizeof(query), "INSERT INTO `POINTS` (`username`, `steamid`, `ipaddress`) VALUES ('%s', '%s', '%s')", EscapedUsername, steamid64, IPaddress);
	SQL_TQuery(db, OnRowInserted, query);
	
	//Main player database
	char query2[300];
	Format(query2, sizeof(query2), "SELECT * FROM POINTS WHERE steamid = '%s'", steamid64);
	SQL_TQuery(db, T_SelectPlayerInDatabase, query2, userID);
}

public void T_SelectPlayerInDatabase(Handle owner, Handle hndl, const char[] error, any userID)
{
	int client = GetClientOfUserId(userID);
	
	if(client < 1)
		return;
		
	char username[128], steamid64[64], IPaddress[70], EscapedUsername[128 * 2 + 1];
	GetClientName(client, username, sizeof(username));
	SQL_EscapeString(db, username, EscapedUsername, 128 * 2 + 1);
	GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
	GetClientIP(client, IPaddress, sizeof(IPaddress));

	if(!SQL_FetchRow(hndl))
	{
		
		char query[300];
		Format(query, sizeof(query), "INSERT INTO `POINTS` (`username`, `steamid`, `ipaddress`) VALUES ('%s', '%s', '%s', '%s')", EscapedUsername, steamid64, IPaddress);
		SQL_TQuery(db, OnRowInserted, query);
		
	} else {
		
		char query[300];
		Format(query, sizeof(query), "UPDATE `POINTS` SET `username` = '%s', `ipaddress` = '%s' WHERE steamid = '%s'", EscapedUsername, IPaddress, steamid64);
		SQL_TQuery(db, OnRowInserted, query);
		
	}
}

public Action OnlineTimeAdd(Handle timer, any client)
{
	char client_name[32];
	
	GetClientName(client, client_name, sizeof(client_name));
	
	if(GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		if (StrContains(client_name, "INJ3CTOR", false) != -1 || StrContains(client_name, "INJECTOR", false) != -1)
		{
			char steamid64[64];
			GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
		
			char query[300], query2[300];
			Format(query, sizeof(query), "UPDATE `POINTS` SET time = time + 1 WHERE steamid = '%s'", steamid64);
			Format(query2, sizeof(query2), "UPDATE `POINTS` SET points = points + 16 WHERE steamid = '%s'", steamid64);
			SQL_TQuery(db, OnRowInserted, query);
			SQL_TQuery(db, OnRowInserted, query2);
			PrintToChat(client, "%s \x04+16 Points given to \x02%s", PREFIX, client_name);
			if(nameChange[client])
			{
				//EmitSoundToClientAny(client, "root/root_name.mp3");
				ClientCommand(client, "play */root/root_name.mp3");
				nameChange[client] = false;
			}
		}
		else
		{
			char steamid64[64];
			GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
		
			char query[300], query2[300];
			Format(query, sizeof(query), "UPDATE `POINTS` SET time = time + 1 WHERE steamid = '%s'", steamid64);
			Format(query2, sizeof(query2), "UPDATE `POINTS` SET points = points + 10 WHERE steamid = '%s'", steamid64);
			SQL_TQuery(db, OnRowInserted, query);
			SQL_TQuery(db, OnRowInserted, query2);
			PrintToChat(client, "%s \x04+10 Points given to \x02%s", PREFIX, client_name);
		}
	}
	
}

public OnRowInserted(Handle owner, Handle hndl, const char[] error, any userid) {
	
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}