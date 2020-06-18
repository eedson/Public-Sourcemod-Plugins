#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "CodingCow - E-Slut - GlockTop - Quack"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <emitsoundany>
#include <smlib>

public Plugin myinfo = 
{
	name = "Hidden:CSGO",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define PREFIX  "\x01 [\x02Hidden\x01]"
#define DMG_FALL   (1 << 5)
int precache_laser;

enum PlayerClass
{
    Attacker,
    Support,
    Tracker,
    Trapper,
};


/* Player Class Booleans */
bool isHidden[MAXPLAYERS + 1];
PlayerClass class[MAXPLAYERS + 1];

bool cooldown[MAXPLAYERS + 1];
bool tracked[MAXPLAYERS + 1];
bool trapped[MAXPLAYERS + 1];
bool canChicken[MAXPLAYERS + 1];
int chickenCharge[MAXPLAYERS + 1];
int chicken_parent[2];
bool chicken_death;

/* Trapper Variables */
bool canTrap[MAXPLAYERS + 1];
float trapLocation[MAXPLAYERS + 1][3];

public void OnPluginStart()
{
	RegConsoleCmd("sm_class", MenuClass, "Changes the users class");
	RegConsoleCmd("buyammo2", setHidden);
	RegConsoleCmd("buyammo1", RandomSound);
	
	/* Hidden Sounds */
	RegConsoleCmd("sm_coming", soundComing);
	RegConsoleCmd("sm_seeyou", soundSeeyou);
	RegConsoleCmd("sm_overhere", soundOverhere);
	RegConsoleCmd("sm_lookup", soundLookup);
	RegConsoleCmd("sm_imhere", soundImhere);
	
	HookEvent("round_start",Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	
	CreateTimer(0.05, stamina, _, TIMER_REPEAT);
	CreateTimer(0.05, hud, _, TIMER_REPEAT);
	CreateTimer(0.05, checkTraps, _, TIMER_REPEAT);
}


public OnMapStart()
{
	// Sounds
	PrecacheSoundAny("hidden/pigstab.mp3");
	AddFileToDownloadsTable("sound/hidden/pigstab.mp3");
	PrecacheSoundAny("hidden/seeyou.mp3");
	AddFileToDownloadsTable("sound/hidden/seeyou.mp3");
	PrecacheSoundAny("hidden/coming.mp3");
	AddFileToDownloadsTable("sound/hidden/coming.mp3");
	PrecacheSoundAny("hidden/imhere.mp3");
	AddFileToDownloadsTable("sound/hidden/imhere.mp3");
	PrecacheSoundAny("hidden/lookup.mp3");
	AddFileToDownloadsTable("sound/hidden/lookup.mp3");
	PrecacheSoundAny("hidden/overhere.mp3");
	AddFileToDownloadsTable("sound/hidden/overhere.mp3");
	PrecacheSoundAny("hidden/chickenBlaster.mp3");
	AddFileToDownloadsTable("sound/hidden/chickenBlaster.mp3");
	PrecacheSoundAny("hidden/chickenBlasterCooldown.mp3");
	AddFileToDownloadsTable("sound/hidden/chickenBlasterCooldown.mp3");
	PrecacheSoundAny("hidden/chickenBlasterHit.mp3");
	AddFileToDownloadsTable("sound/hidden/chickenBlasterHit.mp3");
	
	// Laser
	precache_laser = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public void OnClientPutInServer(int client)
{
	/* Hook Damage */
	SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
	
	class[client] = Attacker;
	isHidden[client] = false;
	
	CreateTimer(4.0, welcome, client);
}

public Action welcome(Handle timer, int client)
{
	if(IsValidClient(client))
	{
		PrintToChat(client, "%s \x04Welcome to \x02Hidden\x01:\x04CSGO", PREFIX);
		PrintToChat(client, "%s \x04Type \x0E!class \x04to choose your class.", PREFIX);
	}
	CloseHandle(timer);
	timer = INVALID_HANDLE;
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
	isHidden[client] = false;
	class[client] = Attacker;
}

public Action MenuClass(int client, int args)
{
	char className[64];
	GetCmdArg(1, className, sizeof(className));
	
	if(strlen(className) > 0)
	{
		if (StrEqual(className, "Attacker", false))
		{
			SetAttacker(client);
		}
		else if (StrEqual(className, "Support", false))
		{
			SetSupport(client);
		}
		else if (StrEqual(className, "Tracker", false))
		{
			SetTracker(client);
		}
		else if (StrEqual(className, "Trapper", false))
		{
			SetTrapper(client);
		}
		else
		{
			PrintToChat(client, "%s \x0E%s \x04is not a valid class.", PREFIX, className);
		}
	}
	else
	{
		Menu menu = new Menu(MenuHandler1);
		menu.SetTitle("Hidden Classes");
		menu.AddItem("Attacker", "Attacker");
		menu.AddItem("Support", "Support");
		menu.AddItem("Tracker", "Tracker");
		menu.AddItem("Trapper", "Trapper");
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
 
	return Plugin_Handled;
}

/* Set Classes */
void SetAttacker(int client)
{
	class[client] = Attacker;
	PrintToChat(client,"%s \x04You have became a \x0EAttacker", PREFIX);
}

void SetSupport(int client)
{
	class[client] = Support;
	PrintToChat(client,"%s \x04You have became a \x0ESupport", PREFIX);
}

void SetTracker(int client)
{
	class[client] = Tracker;
	PrintToChat(client,"%s \x04You have became a \x0ETracker", PREFIX);
}

void SetTrapper(int client)
{
	class[client] = Trapper;
	PrintToChat(client,"%s \x04You have became a \x0ETrapper", PREFIX);
}

public Action setHidden(int client, int args)
{
	isHidden[client] = true;
	ServerCommand("mp_restartgame 1");
}

public Action RandomSound(int client, int args)
{
	if(isHidden[client])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		
		int a = GetRandomInt(1, 5);
		
		switch(a)
		{
			case 1:
			{
				EmitSoundToAllAny("hidden/coming.mp3", client, _, _, _, _, _, _, _, vec);
			}
			case 2:
			{
				EmitSoundToAllAny("hidden/lookup.mp3", client, _, _, _, _, _, _, _, vec);
			}
			case 3:
			{
				EmitSoundToAllAny("hidden/overhere.mp3", client, _, _, _, _, _, _, _, vec);
			}
			case 4:
			{
				EmitSoundToAllAny("hidden/imhere.mp3", client, _, _, _, _, _, _, _, vec);
			}
			case 5:
			{
				EmitSoundToAllAny("hidden/seeyou.mp3", client, _, _, _, _, _, _, _, vec);
			}
		}
		
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action stamina(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(isHidden[i] && IsPlayerAlive(i) && GetClientArmor(i) < 100)
			{
				SetClientArmor(i, GetClientArmor(i) + 1);
			}
			else if(!isHidden[i] && IsPlayerAlive(i) && GetClientArmor(i) > 0)
			{
				SetClientArmor(i, 0);
			}
		}
	}
}

public Action hud(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(isHidden[i] && IsPlayerAlive(i))
			{	
				char info[128];
				
				Format(info, sizeof(info), "Stamina = %i", GetClientArmor(i));

				//hud_message(int client, char[] channel, char[] color, char[] color2, char[] effect, char[] fadein, char[] fadeout, char[] fxtime, char[] holdtime, char[] message, char[] spawnflags, char[] x, char[] y) 
				if(canChicken[i])
				{
					hud_message(i, "4", "255 255 255", "255 0 0", "0", "0", "0", "0", "0.5", "Chicken Blaster = 1", "0", "0", ".88");
				}
				hud_message(i, "5", "255 255 255", "255 0 0", "0", "0", "0", "0", "0.5", info, "0", "0", ".9");
				
				if(tracked[i])
				{
					hud_message(i, "6", "255 0 0", "255 0 0", "0", "0", "0", "0", "0.5", "TRACKED", "0", "-1", ".88");
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	char sWeapon[32];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));
	
	if (StrContains(sWeapon, "knife", false) && GetEntityMoveType(client) != MOVETYPE_NONE && IsClientInGame(client) && isHidden[client] && !cooldown[client] && GetClientButtons(client) & IN_ATTACK)
	{
		if(GetClientArmor(client) >= 30)
		{
			float EyeAngles[3], Push[3], vec[3];
		
			GetClientEyeAngles(client, EyeAngles);
			GetClientAbsOrigin(client, vec);
	
			Push[0] = (950.0 * Cosine(DegToRad(EyeAngles[1])));
			Push[1] = (950.0 * Sine(DegToRad(EyeAngles[1])));
			Push[2] = (-950.0 * Sine(DegToRad(EyeAngles[0])));
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Push);
			EmitSoundToAllAny("hidden/pigstab.mp3", client, SNDCHAN_AUTO, _, _, _, _, _, _, vec);
			cooldown[client] = true;
			CreateTimer(1.0, cooldownChange, client);
			SetClientArmor(client, GetClientArmor(client) - 30);
		}
	}
	
	if(isHidden[client] && !tracked[client] && (GetClientButtons(client) & IN_FORWARD || GetClientButtons(client) & IN_MOVELEFT || GetClientButtons(client) & IN_MOVERIGHT || GetClientButtons(client) & IN_BACK))
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 255, 255, 255, 17);
	}
	else if(isHidden[client] && !tracked[client])
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 255, 255, 255, 4);
	}
	
	if(isHidden[client] && canChicken[client] && GetClientButtons(client) & IN_USE)
	{
		if(chickenCharge[client] == 0)
		{
			float vec[3];
			GetClientAbsOrigin(client, vec);
			EmitSoundToAllAny("hidden/chickenBlaster.mp3", client, _, _, _, _, _, _, _, vec);
		}
		
		chickenCharge[client]++;
		
		// 64 * 3 | 3 second charge //
		if(chickenCharge[client] >= 192)
		{
			beam(client);
			canChicken[client] = false;
		}
	}
	else if(chickenCharge[client] > 0 && canChicken[client])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		EmitSoundToAllAny("hidden/chickenBlasterCooldown.mp3", client, _, _, _, _, _, _, _, vec);
		chickenCharge[client] = 0;
	}
	else
	{
		chickenCharge[client] = 0;
	}
	
	if(class[client] == Trapper && canTrap[client] && !isHidden[client] && GetClientButtons(client) & IN_USE)
	{
		float trap_pos[3];
		GetClientAbsOrigin(client, trap_pos);
		
		trapLocation[client] = trap_pos;
		canTrap[client] = false;
		PrintToChat(client, "%s \x0ETrap \x04has been set!", PREFIX);
	}
	
	return Plugin_Continue;
}

public Action cooldownChange(Handle timer, int client)
{
	if(IsValidClient(client))
	{
		cooldown[client] = false;
	}
	CloseHandle(timer);
	timer = INVALID_HANDLE;
}

public Action checkTraps(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && class[i] == Trapper)
		{
			for (int p = 1; p <= MaxClients; p++)
			{
				if(IsValidClient(p) && isHidden[p] && !trapped[p])
				{
					float pVec[3];
					GetClientAbsOrigin(p, pVec);
					float distance = GetVectorDistance(pVec, trapLocation[i]);
					
					if(distance <= 100)
					{
						trapLocation[i] =  { -10000.0, -10000.0, -10000.0 };
						PrintToChat(i, "%s \x02Hidden \x04has entered your trap!", PREFIX);
						IgniteEntity(p, 5.0);
						trapped[p] = true;
						
						CreateTimer(5.0, resetTrapped, p);
					}
				}
			}
		}
	}
}

public Action resetTrapped(Handle timer, int client)
{
	trapped[client] = false;
	CloseHandle(timer);
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(!isHidden[i] && GetClientTeam(i) != CS_TEAM_CT)
			{
				ChangeClientTeam(i, CS_TEAM_CT);
			}
			else if(isHidden[i])
			{
				ChangeClientTeam(i, CS_TEAM_T);
			}
			
			trapLocation[i] =  { -10000.0, -10000.0, -10000.0 };
		}
	}

}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        if (isHidden[client])
        {
			PrintToChat(client, "%s \x04You are now the \x02Hidden", PREFIX);
			SetEntityModel(client, "models/player/kodua/clot/clot.mdl");
			SetEntityRenderMode(client, RENDER_TRANSCOLOR);
			SetEntityRenderColor(client, 255, 255, 255, 17);
			StripWeapons(client);
			GivePlayerItem(client, "weapon_knife");
			GivePlayerItem(client, "weapon_hegrenade");
			FakeClientCommand(client, "use weapon_knife");
			canChicken[client] = true;
			
			SDKHookEx(client, SDKHook_PostThinkPost, OnPostThinkPost);
			
			int knife = GetPlayerWeaponSlot(client, 2);
			SetWorldModel(knife, 0);
			
			int grenade = GetPlayerWeaponSlot(client, 3);
			SetWorldModel(grenade, 0);
			
			CS_SetClientClanTag(client, "[Hidden]");
			SetClientArmor(client, 100);
		}
		else if (class[client] == Attacker)
		{
			PrintToChat(client, "%s \x04You have spawned in as an \x0EAttacker", PREFIX);
			SetEntityRenderMode(client, RENDER_NORMAL); 
			StripWeapons(client);
			GivePlayerItem(client, "weapon_ak47");
			GivePlayerItem(client, "weapon_deagle");
			GivePlayerItem(client, "weapon_knife");
			FakeClientCommand(client, "use weapon_ak47");
			CS_SetClientClanTag(client, "[Attacker]");
		}
		else if (class[client] == Support)
		{
			PrintToChat(client, "%s \x04You have spawned in as an \x0ESupport", PREFIX);
			SetEntityRenderMode(client, RENDER_NORMAL); 
			StripWeapons(client);
			GivePlayerItem(client, "weapon_p90");
			GivePlayerItem(client, "weapon_p250");
			GivePlayerItem(client, "weapon_knife");
			GivePlayerItem(client, "weapon_healthshot");
			FakeClientCommand(client, "use weapon_p90");
			CS_SetClientClanTag(client, "[Support]");
		}
		else if (class[client] == Tracker)
		{
			PrintToChat(client, "%s \x04You have spawned in as an \x0ETracker", PREFIX);
			SetEntityRenderMode(client, RENDER_NORMAL); 
			StripWeapons(client);
			GivePlayerItem(client, "weapon_ssg08");
			GivePlayerItem(client, "weapon_usp_silencer");
			GivePlayerItem(client, "weapon_knife");
			FakeClientCommand(client, "use weapon_ssg08");
			CS_SetClientClanTag(client, "[Tracker]");
		}
		else if (class[client] == Trapper)
		{
			PrintToChat(client, "%s \x04You have spawned in as an \x0ETrapper", PREFIX);
			SetEntityRenderMode(client, RENDER_NORMAL); 
			StripWeapons(client);
			GivePlayerItem(client, "weapon_nova");
			GivePlayerItem(client, "weapon_tec9");
			GivePlayerItem(client, "weapon_knife");
			FakeClientCommand(client, "use weapon_nova");
			CS_SetClientClanTag(client, "[Trapper]");
			
			canTrap[client] = true;
		}
		
		CreateTimer(1.0, showHud, client);
    }
}

public Action showHud(Handle timer, int client)
{
	//hud_message(int client, char[] channel, char[] color, char[] color2, char[] effect, char[] fadein, char[] fadeout, char[] fxtime, char[] holdtime, char[] message, char[] spawnflags, char[] x, char[] y) 
	if(IsValidClient(client))
	{
		if(isHidden[client])
		{
			hud_message_one(client, "1", "255 0 0", "255 0 0", "1", "2", "2", "0", "10", "Hidden", "0", "0", "0");
			hud_message_one(client, "2", "255 255 255", "255 0 0", "1", "2", "2", "0", "10", "LeftClick - Boost", "0", "0", "0.05");
			hud_message_one(client, "3", "255 255 255", "255 0 0", "1", "2", "2", "0", "10", "USE - Chicken Blaster", "0", "0", "0.1");
			hud_message_one(client, "4", "255 255 255", "255 0 0", "1", "2", "2", "0", "10", "Comma - Hidden Taunts", "0", "0", "0.15");
		}
		else if(class[client] == Attacker)
		{
			hud_message_one(client, "1", "0 255 0", "255 0 0", "1", "2", "2", "0", "10", "Attacker", "0", "0", "0");
			hud_message_one(client, "2", "255 255 255", "255 0 0", "1", "2", "2", "0", "10", "Ability - Fire Deagle", "0", "0", "0.05");
		}
		else if(class[client] == Support)
		{
			hud_message_one(client, "1", "0 255 0", "255 0 0", "1", "2", "2", "0", "10", "Support", "0", "0", "0");
			hud_message_one(client, "2", "255 255 255", "255 0 0", "1", "2", "2", "0", "10", "Ability - MedShot", "0", "0", "0.05");
		}
		else if(class[client] == Tracker)
		{
			hud_message_one(client, "1", "0 255 0", "255 0 0", "1", "2", "2", "0", "10", "Tracker", "0", "0", "0");
			hud_message_one(client, "2", "255 255 255", "255 0 0", "1", "2", "2", "0", "10", "Ability - Tracking Darts", "0", "0", "0.05");
		}
		else if(class[client] == Trapper)
		{
			hud_message_one(client, "1", "0 255 0", "255 0 0", "1", "2", "2", "0", "10", "Trapper", "0", "0", "0");
			hud_message_one(client, "2", "255 255 255", "255 0 0", "1", "2", "2", "0", "10", "Ability - FreezeTrap (USE Key)", "0", "0", "0.05");
		}
	}
	CloseHandle(timer);
}

public Action PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(isHidden[client])
	{
		PrintToChatAll("%s \x02Hidden \x04Has Died!", PREFIX);
		swapHidden(client);
		swapPlayer(attacker);
		
		PrintToChatAll("%s \x0E%N \x04Has become the \x02Hidden", PREFIX, attacker);
	}
	else
	{
		char ClientName[64];
		GetClientName(client, ClientName, 64);
		PrintToChatAll("%s \x0E%s \x04Has Died!", PREFIX, ClientName);
	}
	
	if(chicken_death && client == chicken_parent[1])
	{
		chicken_death = false;
	}

	return Plugin_Handled;
}

void swapHidden(int client)
{
	ChangeClientTeam(client, CS_TEAM_CT);
	
	isHidden[client] = false;
}

void swapPlayer(int client)
{
	ChangeClientTeam(client, CS_TEAM_T);
	
	isHidden[client] = true;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])  
{
	if(IsValidClient(attacker) && IsValidClient(victim) && victim != attacker && GetClientTeam(victim) != GetClientTeam(attacker))
	{
		if(class[attacker] == Tracker && isHidden[victim])
		{
			char sWeapon[64];
			GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
			
			if(StrEqual(sWeapon, "weapon_ssg08", false))
			{
				PrintToChatAll("%s \x0E%N \x04has landed a \x02Tracking Dart!", PREFIX, attacker);
				SetEntPropFloat(victim, Prop_Send, "m_flDetectedByEnemySensorTime", GetGameTime() + 9999.0);
				tracked[victim] = true;
				CreateTimer(10.0, setInvisible, victim);
			}
		}
		else if(class[attacker] == Attacker && isHidden[victim])
		{
			char sWeapon[64];
			GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
			
			if(StrEqual(sWeapon, "weapon_deagle", false))
			{
				PrintToChatAll("%s \x0E%N \x04has landed a \x02Incendiary Shot!", PREFIX, attacker);
				IgniteEntity(victim, 5.0);
			}
		}
	}
	
	if (damagetype & DMG_FALL && isHidden[victim])
	{
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action setInvisible(Handle timer, int client)
{
	if(IsValidClient(client))
	{
		SetEntPropFloat(client, Prop_Send, "m_flDetectedByEnemySensorTime", 0.0);
		PrintToChat(client, "%s \x04You are no longer \x02Tracked", PREFIX);
		
		tracked[client] = false;
	}
	
	CloseHandle(timer);
	timer = INVALID_HANDLE;
}

/* Sound Commands */
public Action soundComing(int client, int args)
{
	if(isHidden[client])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		
		EmitSoundToAllAny("hidden/coming.mp3", client, _, _, _, _, _, _, _, vec);
	}
}

public Action soundSeeyou(int client, int args)
{
	if(isHidden[client])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		
		EmitSoundToAllAny("hidden/seeyou.mp3", client, _, _, _, _, _, _, _, vec);
	}
}

public Action soundOverhere(int client, int args)
{
	if(isHidden[client])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		
		EmitSoundToAllAny("hidden/overhere.mp3", client, _, _, _, _, _, _, _, vec);
	}
}

public Action soundLookup(int client, int args)
{
	if(isHidden[client])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		
		EmitSoundToAllAny("hidden/lookup.mp3", client, _, _, _, _, _, _, _, vec);
	}
}

public Action soundImhere(int client, int args)
{
	if(isHidden[client])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		
		EmitSoundToAllAny("hidden/imhere.mp3", client, _, _, _, _, _, _, _, vec);
	}
}

// ###### Class MENU ###### //
public int MenuHandler1(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		bool found = menu.GetItem(param2, info, sizeof(info));
		
		if(StrEqual(info, "Attacker"))
		{
			SetAttacker(client);
		}
		if(StrEqual(info, "Support"))
		{
			SetSupport(client);
		}
		if(StrEqual(info, "Tracker"))
		{
			SetTracker(client);
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/* Stocks */
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

stock SetClientArmor(int client, int armour)
{
    SetEntProp(client, Prop_Send, "m_ArmorValue", armour, 1);
    return 0;
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}

public OnPostThinkPost(client)
{
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}

stock void hud_message(int client, char[] channel, char[] color, char[] color2, char[] effect, char[] fadein, char[] fadeout, char[] fxtime, char[] holdtime, char[] message, char[] spawnflags, char[] x, char[] y) 
{ 
    int ent = CreateEntityByName("game_text"); 
    DispatchKeyValue(ent, "channel", channel); 
    DispatchKeyValue(ent, "color", color); 
    DispatchKeyValue(ent, "color2", color2); 
    DispatchKeyValue(ent, "effect", effect); 
    DispatchKeyValue(ent, "fadein", fadein); 
    DispatchKeyValue(ent, "fadeout", fadeout); 
    DispatchKeyValue(ent, "fxtime", fxtime);          
    DispatchKeyValue(ent, "holdtime", holdtime); 
    DispatchKeyValue(ent, "message", message); 
    DispatchKeyValue(ent, "spawnflags", spawnflags);//1 
    DispatchKeyValue(ent, "x", x); 
    DispatchKeyValue(ent, "y", y);          
    DispatchSpawn(ent); 
    SetVariantString("!activator"); 
    AcceptEntityInput(ent, "display", client);
    
    CreateTimer(0.05, killText, ent);
}

public Action killText(Handle timer, int ent)
{
	if(IsValidEntity(ent))
	{
		AcceptEntityInput(ent, "Kill");
	}
	CloseHandle(timer);
}

stock void hud_message_one(int client, char[] channel, char[] color, char[] color2, char[] effect, char[] fadein, char[] fadeout, char[] fxtime, char[] holdtime, char[] message, char[] spawnflags, char[] x, char[] y) 
{ 
    int ent = CreateEntityByName("game_text"); 
    DispatchKeyValue(ent, "channel", channel); 
    DispatchKeyValue(ent, "color", color); 
    DispatchKeyValue(ent, "color2", color2); 
    DispatchKeyValue(ent, "effect", effect); 
    DispatchKeyValue(ent, "fadein", fadein); 
    DispatchKeyValue(ent, "fadeout", fadeout); 
    DispatchKeyValue(ent, "fxtime", fxtime);          
    DispatchKeyValue(ent, "holdtime", holdtime); 
    DispatchKeyValue(ent, "message", message); 
    DispatchKeyValue(ent, "spawnflags", spawnflags);//1 
    DispatchKeyValue(ent, "x", x); 
    DispatchKeyValue(ent, "y", y);          
    DispatchSpawn(ent); 
    SetVariantString("!activator"); 
    AcceptEntityInput(ent, "display", client);
    
    CreateTimer(0.05, killText, ent);
}

/* BeamTest */
public void beam(int client)
{
    float vAngles[3], vOrigin[3], AnglesVec[3], EndPoint[3], pos[3];

    float Distance = 999999.0;

    GetClientEyeAngles(client,vAngles);
    GetClientEyePosition(client,vOrigin);
    GetAngleVectors(vAngles, AnglesVec, NULL_VECTOR, NULL_VECTOR);

    EndPoint[0] = vOrigin[0] + (AnglesVec[0]*Distance);
    EndPoint[1] = vOrigin[1] + (AnglesVec[1]*Distance);
    EndPoint[2] = vOrigin[2] + (AnglesVec[2]*Distance);

    Handle trace = TR_TraceRayFilterEx(vOrigin, EndPoint, MASK_SHOT, RayType_EndPoint, TraceEntityFilterPlayer, client);

    if (TR_DidHit(trace))
    {
        int Target = TR_GetEntityIndex(trace);
 
        if ((Target > 0) && (Target <= GetMaxClients()))
        {
			PrintToChatAll("%s \x0E%N \x04has been hit by the \x02Chicken Blaster", PREFIX, Target);
			
			float vec[3];
			GetClientAbsOrigin(Target, vec);
			EmitSoundToAllAny("hidden/chickenBlasterHit.mp3", Target, _, SNDLEVEL_AIRCRAFT, _, _, _, _, _, vec);
            
			if(IsValidClient(client) && IsValidClient(Target))
			{	
				int chicken = CreateEntityByName("chicken");
				
				if(IsValidEntity(chicken))
				{		
					DispatchKeyValue(chicken, "glowenabled", "0"); //Glowing (0-off, 1-on)
					DispatchKeyValue(chicken, "glowcolor", "255 255 255"); //Glowing color (R, G, B)
					DispatchKeyValue(chicken, "rendercolor", "255 255 255"); //Chickens model color (R, G, B)
					DispatchKeyValue(chicken, "modelscale", "1.0"); //Chickens model scale (0.5 smaller, 1.5 bigger chicken, min: 0.1, max: -)
					DispatchKeyValue(chicken, "skin", "0"); //Chickens model skin(default white 0, brown is 1)
					
					DispatchSpawn(chicken);
					
					TeleportEntity(chicken, vec, NULL_VECTOR, NULL_VECTOR);
					
					//Parent to player
					char sBuffer[120];
					Format(sBuffer, sizeof(sBuffer), "%N", Target);
					DispatchKeyValue(chicken, "targetname", sBuffer);
					
					SetVariantString("!activator");
					AcceptEntityInput(Target, "SetParent", chicken);
					
					SetEntityMoveType(Target, MOVETYPE_NONE);
					SetEntityRenderMode(Target, RENDER_NONE);
					
					StripWeapons(Target);
					
					chicken_death = true;
					chicken_parent[0] = chicken;
					chicken_parent[1] = Target;
				}
				
			}
        }
        else
        {
       		PrintToChat(client, "%s \x0EChicken Blaster \x04Missed!", PREFIX);
      	}
    }
    else
    {
   		PrintToChat(client, "%s \x0EChicken Blaster \x04Missed!", PREFIX);
  	}
    
    TR_GetEndPosition(pos, trace);
    
    int color[4];
    color[0]=255;color[1]=0;color[2]=0;color[3]=255;
    
    BeamEffect(vOrigin, pos, 0.5, 1.0, 1.0, color, 0.0, 0);

    CloseHandle(trace);
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

public OnEntityDestroyed(entity)
{
	if(entity == chicken_parent[0] && chicken_death)
	{
		ForcePlayerSuicide(chicken_parent[1]);
		AcceptEntityInput(entity,"KillHierarchy");
		chicken_death = false;
	}
}

stock void SetWorldModel(int weaponIndex, int modelIndex)
{
    // Get world index
    int worldIndex = GetEntPropEnt(weaponIndex, Prop_Send, "m_hWeaponWorldModel");
    
    // Verify that the entity is valid
    if(IsValidEdict(worldIndex))
    {
        // Set model for the entity
        SetEntProp(worldIndex, Prop_Send, "m_nModelIndex", modelIndex);
    }
}