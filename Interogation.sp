#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "CodingCow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include "cash/stocks.sp"

public Plugin myinfo = 
{
	name = "Interogation",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_question", doQuestion, ADMFLAG_BAN);
}

public Action doQuestion(int client, int args)
{
	if(IsValidClient(client))
	{
		if(args < 1)
		{
			ReplyToCommand(client, "[SM] Usage: sm_question <#userid|name>");
			return Plugin_Handled;
		}
		
		char arg[128];
		GetCmdArg(1, arg, sizeof(arg));
		
		if(FindTarget(client, arg, true, false) != -1)
		{
			int target = FindTarget(client, arg, true, false);
			
			if(IsValidClient(target) && target != client)
			{
				float client_pos[3];
				
				client_pos[0] = -930.76;
				client_pos[1] = -2780.55;
				client_pos[2] = 189.00;
				
				TeleportEntity(client, client_pos, NULL_VECTOR, NULL_VECTOR);
				
				float target_pos[3];
				
				target_pos[0] = -1265.29;
				target_pos[1] = -2785.83;
				target_pos[2] = 189.00;
				
				TeleportEntity(target, target_pos, NULL_VECTOR, NULL_VECTOR);
				
				SetHudTextParams(-1.0, 0.35, 8.0, 255, 0, 0, 255);
				ShowHudText(target, 1, "You are being questioned by an admin!");
			}
			else if(target == client)
			{
				PrintToChat(client, "[\x02Question\x01] You cannot question yourself...");
			}
		}
	}

	return Plugin_Handled;
}
