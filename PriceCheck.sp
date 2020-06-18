#pragma semicolon 1
#pragma dynamic 262144


#define DEBUG

#define PLUGIN_AUTHOR "CodingCow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <PTaH>
#include <csgoitems>
#include <SteamWorks>

public Plugin myinfo = 
{
	name = "PriceCheck",
	author = PLUGIN_AUTHOR,
	description = "Return weapon details",
	version = PLUGIN_VERSION,
	url = ""
};

bool canCheck[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_item", priceCheck);
	RegConsoleCmd("sm_info", priceCheck);
	RegConsoleCmd("buyammo2", priceCheck);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		canCheck[i] = true;
	}
}

public void OnClientPutInServer(int client)
{
	canCheck[client] = true;
}

public Action priceCheck(int client, int args)
{
	if(IsValidClient(client))
	{
		int weapon =  GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		
		if(IsValidEntity(weapon))
		{
			DisplayInfo(PTaH_GetEconItemViewFromWeapon(weapon), client);
		}
	}
	
	return Plugin_Handled;
}

void DisplayInfo(CEconItemView Item, int client)
{
	if(canCheck[client])
	{
		if(Item && Item.IsCustomItemView())
		{
			canCheck[client] = false;
			CreateTimer(5.0, cooldown, client);
			
			CEconItemDefinition ItemDefinition = Item.GetItemDefinition();
			int DefinitionIndex = ItemDefinition.GetDefinitionIndex();
			int StickerSlots = ItemDefinition.GetNumSupportedStickerSlots();
			int PaintKit = Item.GetCustomPaintKitIndex();
			float PaintKitWear = Item.GetCustomPaintKitWear();
			int PaintKitSeed = Item.GetCustomPaintKitSeed();
			int Quality = Item.GetQuality();
			int Rarity = Item.GetRarity();
			int StatTrak = Item.GetStatTrakKill();
			
			char weapon_name[32], skin_name[32], wear_name[32], rarity_name[32];
			
			CSGOItems_GetWeaponDisplayNameByDefIndex(DefinitionIndex, weapon_name, sizeof(weapon_name));
			CSGOItems_GetSkinDisplayNameBySkinNum(CSGOItems_GetSkinNumByDefIndex(PaintKit), skin_name, sizeof(skin_name));
			
			if(PaintKitWear <= 0.07)
			{
				Format(wear_name, sizeof(wear_name), "Factory New");
			}
			else if(PaintKitWear <= 0.15)
			{
				Format(wear_name, sizeof(wear_name), "Minimal Wear");
			}
			else if(PaintKitWear <= 0.37)
			{
				Format(wear_name, sizeof(wear_name), "Field-Tested");
			}
			else if(PaintKitWear <= 0.44)
			{
				Format(wear_name, sizeof(wear_name), "Well-Worn");
			}
			else if(PaintKitWear <= 1.00)
			{
				Format(wear_name, sizeof(wear_name), "Battle-Scarred");
			}
			
			if(Rarity == 1)
			{
				Format(rarity_name, sizeof(rarity_name), "Consumer Grade");
			}
			else if(Rarity == 2)
			{
				Format(rarity_name, sizeof(rarity_name), "Industrial Grade");
			}
			else if(Rarity == 3)
			{
				Format(rarity_name, sizeof(rarity_name), "Mil-Spec");
			}
			else if(Rarity == 4)
			{
				Format(rarity_name, sizeof(rarity_name), "Restricted");
			}
			else if(Rarity == 5)
			{
				Format(rarity_name, sizeof(rarity_name), "Classified");
			}
			else if(Rarity == 6)
			{
				Format(rarity_name, sizeof(rarity_name), "Covert");
			}
			else if(Rarity == 7)
			{
				Format(rarity_name, sizeof(rarity_name), "Exceedingly Rare ★");
			}
			
			if(StrContains(weapon_name, "Knife") != -1 || StrContains(weapon_name, "Karambit") != -1 || StrContains(weapon_name, "Shadow Daggers") != -1 || StrContains(weapon_name, "Bayonet") != -1)
			{
				if(StatTrak >= 1)
				{
					Format(weapon_name, sizeof(weapon_name), "★ StatTrak™ %s", weapon_name);
				}
				else
				{
					Format(weapon_name, sizeof(weapon_name), "★ %s", weapon_name);
				}
			}
			else
			{
				if(StatTrak >= 1)
				{
					Format(weapon_name, sizeof(weapon_name), "StatTrak™ %s", weapon_name);
				}
			}
			
			char name[128];
			
			if(StrEqual(skin_name, "Default"))
			{
				Format(name, sizeof(name), "%s", weapon_name);
			}
			else
			{
				Format(name, sizeof(name), "%s | %s (%s)", weapon_name, skin_name, wear_name);
			}
			
			DataPack data = new DataPack();
			data.WriteCell(client);
			data.WriteString(name);
			data.WriteString(rarity_name);
			data.WriteCell(PaintKitSeed);
			data.WriteFloat(PaintKitWear);
			data.Reset();
			
			Handle request = CreateRequest_OPSKINS(data);
			SteamWorks_SendHTTPRequest(request);
		}
		else
		{
			PrintToChat(client, "[\x02Item\x01] You don't have a Custom Item");
		}
	}
	else
	{
		PrintToChat(client, "[\x02Item\x01] Please wait before Price Checking again.");
	}
}

Handle CreateRequest_OPSKINS(DataPack data)
{
	char request_url[256];
	Format(request_url, sizeof(request_url), "http://www.codewars.hosted.nfoservers.com/pricecheck.php");
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	int client = data.ReadCell();
	char key[128];
	data.ReadString(key, sizeof(key));
	char rarity[128];
	data.ReadString(rarity, sizeof(rarity));
	int PaintKitSeed = data.ReadCell();
	float PaintKitWear = data.ReadFloat();
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "name", key);
	SteamWorks_SetHTTPRequestContextValue(request, data);
	SteamWorks_SetHTTPCallbacks(request, OPSKINS_OnHTTPResponse);
	return request;
}

public int OPSKINS_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack data)
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		delete request;
		delete data;
		return;
	}

	int iBufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, iBufferSize);
	
	char[] sBody = new char[iBufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, sBody, iBufferSize);
	
	float price = NormalizeMoney(StringToInt(sBody, 10));
	
	data.WriteFloat(price);
	data.Reset();
	
	GetSteamCommunityPrice(data);
	
	delete request;
}

public void GetSteamCommunityPrice(DataPack data)
{
	Handle request = CreateRequest_SCM(data);
	SteamWorks_SendHTTPRequest(request);
}

Handle CreateRequest_SCM(DataPack data)
{
	char request_url[256];
	Format(request_url, sizeof(request_url), "http://www.codewars.hosted.nfoservers.com/scmpricecheck.php");
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	int client = data.ReadCell();
	char key[128];
	data.ReadString(key, sizeof(key));
	data.Reset();
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "name", key);
	SteamWorks_SetHTTPRequestContextValue(request, data);
	SteamWorks_SetHTTPCallbacks(request, SCM_OnHTTPResponse);
	return request;
}

public int SCM_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack data)
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		delete request;
		delete data;
		return;
	}

	int iBufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, iBufferSize);
	
	char[] sBody = new char[iBufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, sBody, iBufferSize);
	
	int client = data.ReadCell();
	char name[128];
	data.ReadString(name, sizeof(name));
	char rarity[32];
	data.ReadString(rarity, sizeof(rarity));
	int PaintKitSeed = data.ReadCell();
	float PaintKitWear = data.ReadFloat();
	float Price = data.ReadFloat();
	delete data;
	
	SetHudTextParams(0.01, 0.07, 8.0, 255, 255, 255, 255);
	ShowHudText(client, 1, "%s", name);
	
	SetHudTextParams(0.01, 0.12, 8.0, 255, 255, 255, 255);
	ShowHudText(client, 2, "Rarity: %s", rarity);
	
	SetHudTextParams(0.01, 0.17, 8.0, 255, 255, 255, 255);
	ShowHudText(client, 3, "Pattern Index: %i", PaintKitSeed);
	
	SetHudTextParams(0.01, 0.22, 8.0, 255, 255, 255, 255);
	ShowHudText(client, 4, "Float: %f / %.4f%", PaintKitWear, PaintKitWear * 100);
	
	if(IsCharNumeric(sBody[1]))
	{
		SetHudTextParams(0.01, 0.27, 8.0, 255, 255, 255, 255);
		ShowHudText(client, 6, "Steam Price: %s", sBody);
	}
	else
	{
		SetHudTextParams(0.01, 0.27, 8.0, 255, 255, 255, 255);
		ShowHudText(client, 6, "Steam Price: N/A");
	}
	
	SetHudTextParams(0.01, 0.32, 8.0, 255, 255, 255, 255);
	ShowHudText(client, 5, "OPSKINS Price: $%.2f", Price);
	
	delete request;
}

public Action cooldown(Handle timer, int client)
{
	canCheck[client] = true;
	
	KillTimer(timer);
    timer = INVALID_HANDLE;
}

public float NormalizeMoney(int cents)
{
    float dollars = 0.0;
    
    dollars = cents/100.0;
    cents = cents - (dollars * 100.0);
	
    return dollars;
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}