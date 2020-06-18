#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "cow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "chicken players",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_chicken", doChicken, ADMFLAG_BAN);
}

public Action doChicken(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_chicken <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg) );
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_IMMUNITY,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0 && IsPlayerAlive(client))
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		makeChicken(client, target_list[i]);
	}
	
	return Plugin_Handled;
}

public Action makeChicken(int client, int target)
{
	if(IsValidClient(client) && IsValidClient(target))
	{
		float vec[3];
		
		GetClientAbsOrigin(target, vec);
		
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
			Format(sBuffer, sizeof(sBuffer), "%N", target);
			DispatchKeyValue(chicken, "targetname", sBuffer);
			
			SetVariantString("!activator");
			AcceptEntityInput(target, "SetParent", chicken);
			
			SetEntityMoveType(target, MOVETYPE_NONE);
			SetEntityRenderMode(target, RENDER_NONE);
			
			StripWeapons(target);
		}
		
	}
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}

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