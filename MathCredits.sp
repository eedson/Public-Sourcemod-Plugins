#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "CodingCow"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <store>

public Plugin myinfo = 
{
	name = "MathCredits",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

bool listen;
int answer;

public void OnPluginStart()
{
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	
	CreateTimer(240.0, doMath);
}

public Action doMath(Handle timer)
{
	int num1 = GetRandomInt(1, 200);
	int num2 = GetRandomInt(1, 200);
	
	int type = GetRandomInt(1, 4);
	
	if(type == 1)
	{
		answer = num1 + num2;
		
		PrintToChatAll("[\x0EMath\x01] What is the \x0Esum \x01of \x04%i \x01and \x04%i\x01?", num1, num2);
	}
	else if(type == 2)
	{
		answer = num1 - num2;
		
		PrintToChatAll("[\x0EMath\x01] What is the \x0Edifference \x01of \x04%i \x01and \x04%i\x01?", num1, num2);
	}
	else if(type == 3)
	{
		answer = num1 * num2;
		
		PrintToChatAll("[\x0EMath\x01] What is the \x0Eproduct \x01of \x04%i \x01and \x04%i\x01?", num1, num2);
	}
	else if(type == 4)
	{
		while(num1 % num2 != 0)
		{
			num1 = GetRandomInt(1, 1000);
		}
		
		answer = (num1 / num2);
		
		PrintToChatAll("[\x0EMath\x01] What is the \x0Equotient \x01of \x04%i \x01and \x04%i\x01 rounded to the nearest whole number?", num1, num2);
	}
	
	listen = true;
	
	CreateTimer(30.0, setListen);
}

public Action setListen(Handle timer)
{
	if(listen)
	{
		listen = false;
		
		PrintToChatAll("[\x0EMath\x01] Time has ran out the anwser is \x04%i\x01!", answer);
		
		CreateTimer(240.0, doMath);
	}
}

public Action Command_Say(int client, int args)
{
	if(listen)
	{
		char text[255], answer_text[128];
		GetCmdArgString(text, sizeof(text));
		StripQuotes(text);
		
		IntToString(answer, answer_text, sizeof(answer_text));
		
		if(StrEqual(text, answer_text))
		{
	    	PrintToChatAll(" \x0C[\x0EMath\x0C] \x0E%N \x0Chas given the correct anwser of \x0E%i \x0Cand was awarded \x0E5 \x0Ccredits", client, answer);
	    	
	    	Store_SetClientCredits(client, Store_GetClientCredits(client) + 5);
	    	
	    	listen = false;
	    	
	    	CreateTimer(240.0, doMath);
	  	}
   	}
	
	return Plugin_Continue;
}