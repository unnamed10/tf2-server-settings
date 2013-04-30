#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <smac>
#undef REQUIRE_PLUGIN
#include <updater>

/* Plugin Info */
public Plugin:myinfo =
{
	name = "SMAC ConVar Checker",
	author = "GoD-Tony, psychonic, Kigen",
	description = "Checks for players using exploitative cvars",
	version = SMAC_VERSION,
	url = SMAC_URL
};

/* Globals */
#define UPDATE_URL	"http://godtony.mooo.com/smac/smac_cvars.txt"

#define CELL_NAME	0
#define CELL_COMPTYPE	1
#define CELL_HANDLE	2
#define CELL_ACTION	3
#define CELL_VALUE	4
#define CELL_VALUE2	5
#define CELL_ALT	6
#define CELL_PRIORITY	7
#define CELL_CHANGED	8

#define ACTION_WARN	0 // Warn Admins
#define ACTION_MOTD	1 // Display MOTD with Alternate URL
#define ACTION_MUTE	2 // Mute the player.
#define ACTION_KICK	3 // Kick the player.
#define ACTION_BAN	4 // Ban the player.

#define COMP_EQUAL	0 // CVar should equal
#define COMP_GREATER	1 // CVar should be equal to or greater than
#define COMP_LESS	2 // CVar should be equal to or less than
#define COMP_BOUND	3 // CVar should be in-between two numbers.
#define COMP_STRING	4 // Cvar should string equal.
#define COMP_NONEXIST	5 // CVar shouldn't exist.

#define PRIORITY_NORMAL	0
#define PRIORITY_MEDIUM	1
#define PRIORITY_HIGH	3

// Array Index Documentation
// Arrays that come from g_hCVars are index like below.
// 1. CVar Name
// 2. Comparison Type
// 3. CVar Handle - If this is defined then the engine will ignore the Comparison Type and Values as this should be only for FCVAR_REPLICATED CVars.
// 4. Action Type - Determines what action the engine takes.
// 5. Value - The value that the cvar is expected to have.
// 6. Value 2 - Only used as the high bound for COMP_BOUND.
// 7. Important - Defines the importance of the CVar in the ordering of the checks.
// 8. Was Changed - Defines if this CVar was changed recently.

new Handle:g_hCVars = INVALID_HANDLE;
new Handle:g_hCVarIndex = INVALID_HANDLE;
new Handle:g_hCurrentQuery[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new Handle:g_hReplyTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new Handle:g_hPeriodicTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new String:g_sQueryResult[][] = {"Okay", "Not found", "Not valid", "Protected"};
new g_iCurrentIndex[MAXPLAYERS+1] = {0, ...};
new g_iRetryAttempts[MAXPLAYERS+1] = {0, ...};
new g_iSize = 0;
new bool:g_bMapStarted = false;

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bMapStarted = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("smac.phrases");
	
	decl Handle:f_hConCommand, String:f_sName[64], bool:f_bIsCommand, f_iFlags, Handle:f_hConVar;

	g_hCVars = CreateArray(64);
	g_hCVarIndex = CreateTrie();

	//- High Priority -//  Note: We kick them out before hand because we don't want to have to ban them.
	CVars_AddCVar("0penscript",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("aim_bot",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("aim_fov",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("bat_version", 		COMP_NONEXIST, 	ACTION_KICK, 	"0.0",	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("beetlesmod_version", 	COMP_NONEXIST,  ACTION_KICK, 	"0.0",  0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("est_version", 		COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("eventscripts_ver", 	COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("fm_attackmode",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("lua_open",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("Lua-Engine",		COMP_NONEXIST, 	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("mani_admin_plugin_version", COMP_NONEXIST, ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("ManiAdminHacker",	COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("ManiAdminTakeOver",	COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("metamod_version", 	COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("openscript",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("openscript_version",	COMP_NONEXIST,	ACTION_BAN, 	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("runnscript",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("SmAdminTakeover", 	COMP_NONEXIST, 	ACTION_BAN,	"0.0", 	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("sourcemod_version", 	COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("tb_enabled",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("zb_version", 		COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);

	//- Medium Priority -// Note: Now the client should be clean of any third party server side plugins.  Now we can start really checking.
	CVars_AddCVar("sv_cheats", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_MEDIUM);
	CVars_AddCVar("sv_consistency", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_MEDIUM);
	//CVars_AddCVar("sv_gravity", 		COMP_EQUAL, 	ACTION_BAN, 	"800.0", 0.0, 	PRIORITY_MEDIUM);
	CVars_AddCVar("r_drawothermodels", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_MEDIUM);

	//- Normal Priority -//
	CVars_AddCVar("cl_clock_correction", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("cl_leveloverview", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("cl_overdraw_test", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	
	// This doesn't exist on some mods.
	if ( SMAC_GetGameType() == Game_HL2CTF || SMAC_GetGameType() == Game_HIDDEN )
		CVars_AddCVar("cl_particles_show_bbox", COMP_NONEXIST, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	else
		CVars_AddCVar("cl_particles_show_bbox", COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	
	CVars_AddCVar("cl_phys_timescale", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("cl_showevents", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);

	if ( SMAC_GetGameType() == Game_INSMOD )
		CVars_AddCVar("fog_enable", 		COMP_EQUAL, 	ACTION_KICK, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	else
		CVars_AddCVar("fog_enable", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	
	// This doesn't exist on FoF
	if ( SMAC_GetGameType() == Game_FOF )
		CVars_AddCVar("host_timescale", 	COMP_NONEXIST, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	else
		CVars_AddCVar("host_timescale", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	
	CVars_AddCVar("mat_dxlevel", 		COMP_GREATER, 	ACTION_KICK, 	"80.0", 0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mat_fillrate", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mat_measurefillrate",	COMP_EQUAL,	ACTION_BAN,	"0.0", 	0.0,	PRIORITY_NORMAL);
	CVars_AddCVar("mat_proxy", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mat_showlowresimage",	COMP_EQUAL, 	ACTION_BAN,	"0.0",	0.0,	PRIORITY_NORMAL);
	CVars_AddCVar("mat_wireframe", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mem_force_flush", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("snd_show", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("snd_visualize", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_aspectratio", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_colorstaticprops", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_DispWalkable", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_DrawBeams", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawbrushmodels", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawclipbrushes", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawdecals", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawentities", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawmodelstatsoverlay",COMP_EQUAL,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawopaqueworld", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawparticles", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawrenderboxes", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawskybox",		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawtranslucentworld", COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_shadowwireframe", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_skybox", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_visocclusion", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("vcollide_wireframe", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);

	//- Replication Protection -//
	f_hConCommand = FindFirstConCommand(f_sName, sizeof(f_sName), f_bIsCommand, f_iFlags);
	if ( f_hConCommand == INVALID_HANDLE )
		SetFailState("Failed getting first ConVar");

	do
	{
		if ( f_bIsCommand )
			continue;
		
		if ( !(f_iFlags & FCVAR_REPLICATED) )
			continue;
		
		// SMAC will not always be the first to load and many plugins (mistakenly) put
		//  FCVAR_REPLICATED on their version cvar (in addition to FCVAR_PLUGIN)
		if ( f_iFlags & FCVAR_PLUGIN )
			continue;
		
		f_hConVar = FindConVar(f_sName);
		if ( f_hConVar == INVALID_HANDLE )
			continue;
		
		// ToDo: Check if replicate code is needed at all on L4D+ engines.
		if ((SMAC_GetGameType() == Game_L4D || SMAC_GetGameType() == Game_L4D2) && StrEqual(f_sName, "mp_gamemode"))
			continue;
		
		CVars_ReplicateConVar(f_hConVar);
		HookConVarChange(f_hConVar, CVars_Replicate);
		
	} while ( FindNextConCommand(f_hConCommand, f_sName, sizeof(f_sName), f_bIsCommand, f_iFlags));

	CloseHandle(f_hConCommand);

	//- Register Admin Commands -//
	RegAdminCmd("smac_addcvar",      CVars_CmdAddCVar,  ADMFLAG_ROOT,    "Adds a CVar to the check list.");
	RegAdminCmd("smac_removecvar",   CVars_CmdRemCVar,  ADMFLAG_ROOT,    "Removes a CVar from the check list.");
	RegAdminCmd("smac_cvars_status", CVars_CmdStatus,  ADMFLAG_GENERIC,  "Shows the status of all in-game clients.");
	
	// Start on all clients.
	if (g_bMapStarted)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsClientAuthorized(i))
			{
				OnClientPostAdminCheck(i);
			}
		}
	}

	// Updater.
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnClientPostAdminCheck(client)
{
	if ( !IsFakeClient(client) )
		g_hPeriodicTimer[client] = CreateTimer(0.1, CVars_PeriodicTimer, client);
}

public OnClientDisconnect(client)
{
	decl Handle:f_hTemp;
	
	g_iCurrentIndex[client] = 0;
	g_iRetryAttempts[client] = 0;

	f_hTemp = g_hPeriodicTimer[client];
	if ( f_hTemp != INVALID_HANDLE )
	{
		g_hPeriodicTimer[client] = INVALID_HANDLE;
		CloseHandle(f_hTemp);
	}
	f_hTemp = g_hReplyTimer[client];
	if ( f_hTemp != INVALID_HANDLE )
	{
		g_hReplyTimer[client] = INVALID_HANDLE;
		CloseHandle(f_hTemp);
	}
}

public OnMapStart()
{
	g_bMapStarted = true;
}

public OnMapEnd()
{
	g_bMapStarted = false;
}

//- Admin Commands -//

public Action:CVars_CmdStatus(client, args)
{
	if ( client && !IsClientInGame(client) )
		return Plugin_Handled;

	decl String:f_sAuth[MAX_AUTHID_LENGTH], String:f_sCVarName[64];
	new Handle:f_hTemp;

	for(new i=1;i<=MaxClients;i++)
	{
		if ( IsClientInGame(i) && !IsFakeClient(i) )
		{
			GetClientAuthString(i, f_sAuth, sizeof(f_sAuth));
			f_hTemp = g_hCurrentQuery[i];
			if ( f_hTemp == INVALID_HANDLE )
			{
				if ( g_hPeriodicTimer[i] == INVALID_HANDLE )
				{
					LogError("%N (%s) doesn't have a periodic timer running and no active queries.", i, f_sAuth);
					ReplyToCommand(client, "ERROR: %N (%s) didn't have a periodic timer running nor active queries.", i, f_sAuth);
					g_hPeriodicTimer[i] = CreateTimer(0.1, CVars_PeriodicTimer, i);
					continue;
				}
				ReplyToCommand(client, "%N (%s) is waiting for new query. Current Index: %d.", i, f_sAuth, g_iCurrentIndex[i]);
			}
			else
			{
				GetArrayString(f_hTemp, CELL_NAME, f_sCVarName, sizeof(f_sCVarName));
				ReplyToCommand(client, "%N (%s) has active query on %s. Current Index: %d. Retry Attempts: %d.", i, f_sAuth, f_sCVarName, g_iCurrentIndex[i], g_iRetryAttempts[i]);
			}
		}
	}
	return Plugin_Handled;
}

public Action:CVars_CmdAddCVar(client, args)
{
	if ( args != 4 && args != 5 )
	{
		ReplyToCommand(client, "Usage: smac_addcvar <cvar name> <comparison type> <action> <value> <value2 if bound>");
		return Plugin_Handled;
	}

	decl String:f_sCVarName[64], String:f_sTemp[64], f_iCompType, f_iAction, String:f_sValue[64], Float:f_fValue2;

	GetCmdArg(1, f_sCVarName, sizeof(f_sCVarName));
	
	if ( !CVars_IsValidName(f_sCVarName) )
	{
		ReplyToCommand(client, "The ConVar name \"%s\" is invalid and cannot be used.", f_sCVarName);
		return Plugin_Handled;
	}

	GetCmdArg(2, f_sTemp, sizeof(f_sTemp));

	if ( StrEqual(f_sTemp, "equal") )
		f_iCompType = COMP_EQUAL;
	else if ( StrEqual(f_sTemp, "greater") )
		f_iCompType = COMP_GREATER;
	else if ( StrEqual(f_sTemp, "less") )
		f_iCompType = COMP_LESS;
	else if ( StrEqual(f_sTemp, "between") )
		f_iCompType = COMP_BOUND;
	else if ( StrEqual(f_sTemp, "strequal") )
		f_iCompType = COMP_STRING;
	else if ( StrEqual(f_sTemp, "nonexist") )
		f_iCompType = COMP_NONEXIST;
	else
	{
		ReplyToCommand(client, "Unrecognized comparison type \"%s\", acceptable values: \"equal\", \"greater\", \"less\", \"between\", \"strequal\", or \"nonexist\".", f_sTemp);
		return Plugin_Handled;
	}
	
	if ( f_iCompType == COMP_BOUND && args < 5 )
	{
		ReplyToCommand(client, "Bound comparison type needs two values to compare with.");
		return Plugin_Handled;
	}

	GetCmdArg(3, f_sTemp, sizeof(f_sTemp));

	if ( StrEqual(f_sTemp, "warn") )
		f_iAction = ACTION_WARN;
	else if ( StrEqual(f_sTemp, "motd") )
		f_iAction = ACTION_MOTD;
	else if ( StrEqual(f_sTemp, "mute") )
		f_iAction = ACTION_MUTE;
	else if ( StrEqual(f_sTemp, "kick") )
		f_iAction = ACTION_KICK;
	else if ( StrEqual(f_sTemp, "ban") )
		f_iAction = ACTION_BAN;
	else
	{
		ReplyToCommand(client, "Unrecognized action type \"%s\", acceptable values: \"warn\", \"mute\", \"kick\", or \"ban\".", f_sTemp);
		return Plugin_Handled;
	}

	GetCmdArg(4, f_sValue, sizeof(f_sValue));

	if ( f_iCompType == COMP_BOUND )
	{
		GetCmdArg(5, f_sTemp, sizeof(f_sTemp));
		f_fValue2 = StringToFloat(f_sTemp);
	}

	if ( CVars_AddCVar(f_sCVarName, f_iCompType, f_iAction, f_sValue, f_fValue2, PRIORITY_NORMAL) )
	{
		if ( client )
		{
			SMAC_LogAction(client, "added convar %s to the check list.", f_sCVarName);
		}
		ReplyToCommand(client, "Successfully added ConVar %s to the check list.", f_sCVarName);
	}
	else
		ReplyToCommand(client, "Failed to add ConVar %s to the check list.", f_sCVarName);
	
	return Plugin_Handled;
}

public Action:CVars_CmdRemCVar(client, args)
{
	if ( args != 1 )
	{
		ReplyToCommand(client, "Usage: smac_removecvar <cvar name>");
		return Plugin_Handled;
	}

	decl String:f_sCVarName[64];

	GetCmdArg(1, f_sCVarName, sizeof(f_sCVarName));

	if ( CVars_RemoveCVar(f_sCVarName) )
	{
		if ( client )
		{
			SMAC_LogAction(client, "removed convar %s from the check list.", f_sCVarName);
		}
		else
			SMAC_Log("Console removed convar %s from the check list.", f_sCVarName);
		ReplyToCommand(client, "ConVar %s was successfully removed from the check list.", f_sCVarName);
	}
	else
		ReplyToCommand(client, "Unable to find ConVar %s in the check list.", f_sCVarName);
	
	return Plugin_Handled;
}

//- Timers -//

public Action:CVars_PeriodicTimer(Handle:timer, any:client)
{
	if ( g_hPeriodicTimer[client] == INVALID_HANDLE )
		return Plugin_Stop;

	g_hPeriodicTimer[client] = INVALID_HANDLE;

	if ( !IsClientConnected(client) )
		return Plugin_Stop;

	decl String:f_sName[64], Handle:f_hCVar, f_iIndex;

	if ( g_iSize < 1 )
	{
		PrintToServer("Nothing in convar list");
		CreateTimer(10.0, CVars_PeriodicTimer, client);
		return Plugin_Stop;
	}

	f_iIndex = g_iCurrentIndex[client]++;
	if ( f_iIndex >= g_iSize )
	{
		f_iIndex = 0;
		g_iCurrentIndex[client] = 1;
	}

	f_hCVar = GetArrayCell(g_hCVars, f_iIndex);

	if ( GetArrayCell(f_hCVar, CELL_CHANGED) == INVALID_HANDLE )
	{
		GetArrayString(f_hCVar, 0, f_sName, sizeof(f_sName));
		g_hCurrentQuery[client] = f_hCVar;
		QueryClientConVar(client, f_sName, CVars_QueryCallback, client);
		g_hReplyTimer[client] = CreateTimer(30.0, CVars_ReplyTimer, GetClientUserId(client)); // We'll wait 30 seconds for a reply.
	}
	else
		g_hPeriodicTimer[client] = CreateTimer(0.1, CVars_PeriodicTimer, client);
	return Plugin_Stop;
	
}

public Action:CVars_ReplyTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if ( !client || g_hReplyTimer[client] == INVALID_HANDLE )
		return Plugin_Stop;
	g_hReplyTimer[client] = INVALID_HANDLE;
	if ( !IsClientConnected(client) || g_hPeriodicTimer[client] != INVALID_HANDLE )
		return Plugin_Stop;

	if ( g_iRetryAttempts[client]++ > 3 )
		KickClient(client, "%t", "SMAC_FailedToReply");
	else
	{
		decl String:f_sName[64], Handle:f_hCVar;

		if ( g_iSize < 1 )
		{
			PrintToServer("Nothing in convar list");
			CreateTimer(10.0, CVars_PeriodicTimer, client);
			return Plugin_Stop;
		}

		f_hCVar = g_hCurrentQuery[client];

		if ( GetArrayCell(f_hCVar, CELL_CHANGED) == INVALID_HANDLE )
		{
			GetArrayString(f_hCVar, 0, f_sName, sizeof(f_sName));
			QueryClientConVar(client, f_sName, CVars_QueryCallback, client);
			g_hReplyTimer[client] = CreateTimer(15.0, CVars_ReplyTimer, GetClientUserId(client)); // We'll wait 15 seconds for a reply.
		}
		else
			g_hPeriodicTimer[client] = CreateTimer(0.1, CVars_PeriodicTimer, client);
	}

	return Plugin_Stop;
}

public Action:CVars_ReplicateTimer(Handle:timer, any:f_hConVar)
{
	decl String:f_sName[64];
	GetConVarName(f_hConVar, f_sName, sizeof(f_sName));
	if ( StrEqual(f_sName, "sv_cheats") && GetConVarInt(f_hConVar) != 0 )
		SetConVarInt(f_hConVar, 0);
	CVars_ReplicateConVar(f_hConVar);
	return Plugin_Stop;
}

public Action:CVars_ReplicateCheck(Handle:timer, any:f_hIndex)
{
	SetArrayCell(f_hIndex, CELL_CHANGED, INVALID_HANDLE);
	return Plugin_Stop;
}

//- ConVar Query Reply -//

public CVars_QueryCallback(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if ( !IsClientConnected(client) )
		return;

	decl String:f_sCVarName[64], Handle:f_hConVar, Handle:f_hTemp, String:f_sName[MAX_NAME_LENGTH], f_iCompType, f_iAction, String:f_sValue[64], Float:f_fValue2, String:f_sAlternative[128], f_iSize, bool:f_bContinue;

	// Get Client Info
	GetClientName(client, f_sName, sizeof(f_sName));

	if ( g_hPeriodicTimer[client] != INVALID_HANDLE )
		f_bContinue = false;
	else
		f_bContinue = true;

	f_hConVar = g_hCurrentQuery[client];

	// We weren't expecting a reply or convar we queried is no longer valid and we cannot find it.
	if ( f_hConVar == INVALID_HANDLE && !GetTrieValue(g_hCVarIndex, cvarName, f_hConVar) )
	{
		if ( g_hPeriodicTimer[client] == INVALID_HANDLE ) // Client doesn't have active query or a timer active for them?  Ballocks!
			g_hPeriodicTimer[client] = CreateTimer(GetRandomFloat(0.5, 2.0), CVars_PeriodicTimer, client);
		return;
	}

	GetArrayString(f_hConVar, CELL_NAME, f_sCVarName, sizeof(f_sCVarName));

	// Make sure this query replied correctly.
	if ( !StrEqual(cvarName, f_sCVarName) ) // CVar not expected.
	{
		if ( !GetTrieValue(g_hCVarIndex, cvarName, f_hConVar) ) // CVar doesn't exist in our list.
		{
			SMAC_LogAction(client, "was kicked for a corrupted return with convar name \"%s\" (expecting \"%s\") with value \"%s\".", cvarName, f_sCVarName, cvarValue);
			KickClient(client, "%t", "SMAC_ClientCorrupt");
			return;
		}
		else
			f_bContinue = false;

		GetArrayString(f_hConVar, CELL_NAME, f_sCVarName, sizeof(f_sCVarName));
	}

	f_iCompType = GetArrayCell(f_hConVar, CELL_COMPTYPE);
	f_iAction = GetArrayCell(f_hConVar, CELL_ACTION);

	if ( f_bContinue )
	{
		f_hTemp = g_hReplyTimer[client];
		g_hCurrentQuery[client] = INVALID_HANDLE;

		if ( f_hTemp != INVALID_HANDLE )
		{
			g_hReplyTimer[client] = INVALID_HANDLE;
			CloseHandle(f_hTemp);
			g_iRetryAttempts[client] = 0;
		}
	}

	// Check if it should exist.
	if ( f_iCompType == COMP_NONEXIST )
	{
		if ( result != ConVarQuery_NotFound && SMAC_CheatDetected(client) == Plugin_Continue )
		{
			SMAC_PrintAdminNotice("%t", "SMAC_HasPlugin", f_sName, f_sCVarName);
			
			switch(f_iAction)
			{
				case ACTION_MOTD:
				{
					GetArrayString(f_hConVar, CELL_ALT, f_sAlternative, sizeof(f_sAlternative));
					ShowMOTDPanel(client, "", f_sAlternative);
				}
				case ACTION_MUTE:
				{
					PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", f_sName);
					ServerCommand("sm_mute #%d", GetClientUserId(client));
				}
				case ACTION_KICK:
				{
					SMAC_LogAction(client, "was kicked for returning with plugin convar \"%s\" (value \"%s\", return %s).", cvarName, cvarValue, g_sQueryResult[result]);
					KickClient(client, "%t", "SMAC_RemovePlugins");
					return;
				}
				case ACTION_BAN:
				{
					SMAC_LogAction(client, "has convar \"%s\" (value \"%s\", return %s) when it shouldn't exist.", cvarName, cvarValue, g_sQueryResult[result]);
					SMAC_Ban(client, "ConVar %s violation", cvarName);
					
					return;
				}
			}
		}
		if ( f_bContinue )
			g_hPeriodicTimer[client] = CreateTimer(GetRandomFloat(1.0, 3.0), CVars_PeriodicTimer, client);
		return;
	}

	if ( result != ConVarQuery_Okay ) // ConVar should exist.
	{
		SMAC_LogAction(client, "returned query result \"%s\" (expected Okay) on convar \"%s\" (value \"%s\").", g_sQueryResult[result], cvarName, cvarValue);
		SMAC_Ban(client, "ConVar %s violation (bad query result)", cvarName);
		
		return;
	}

	// Check if the ConVar was recently changed.
	if ( GetArrayCell(f_hConVar, CELL_CHANGED) != INVALID_HANDLE )
	{
		g_hPeriodicTimer[client] = CreateTimer(GetRandomFloat(1.0, 3.0), CVars_PeriodicTimer, client);
		return;
	}

	f_hTemp = GetArrayCell(f_hConVar, CELL_HANDLE);
	if ( f_hTemp == INVALID_HANDLE || f_iCompType != COMP_EQUAL )
		GetArrayString(f_hConVar, CELL_VALUE, f_sValue, sizeof(f_sValue));
	else
		GetConVarString(f_hTemp, f_sValue, sizeof(f_sValue));

	if ( f_iCompType == COMP_BOUND )
		f_fValue2 = GetArrayCell(f_hConVar, CELL_VALUE2);

	if ( f_iCompType != COMP_STRING )
	{
		f_iSize = strlen(cvarValue);
		for(new i=0;i<f_iSize;i++)
		{
			if ( !IsCharNumeric(cvarValue[i]) && cvarValue[i] != '.' )
			{
				SMAC_LogAction(client, "was kicked for returning a corrupted value on %s (%s), value set at \"%s\" (expected \"%s\").", f_sCVarName, cvarName, cvarValue, f_sValue);
				KickClient(client, "%t", "SMAC_ClientCorrupt");
				return;
			}
		}
	}


	switch(f_iCompType)
	{
		case COMP_EQUAL:
			if ( StringToFloat(f_sValue) != StringToFloat(cvarValue) && SMAC_CheatDetected(client) == Plugin_Continue )
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotEqual", f_sName, f_sCVarName, cvarValue, f_sValue);
				
				switch(f_iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(f_hConVar, CELL_ALT, f_sAlternative, sizeof(f_sAlternative));
						ShowMOTDPanel(client, "", f_sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", f_sName);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be \"%s\".", cvarName, cvarValue, f_sValue);
						KickClient(client, "%t", "SMAC_ShouldEqual", cvarName, f_sValue, cvarValue);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should equal.", cvarName, cvarValue, f_sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						return;
					}
				}
			}
		case COMP_GREATER:
			if ( StringToFloat(f_sValue) > StringToFloat(cvarValue) && SMAC_CheatDetected(client) == Plugin_Continue )
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotGreater", f_sName, f_sCVarName, cvarValue, f_sValue);
				
				switch(f_iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(f_hConVar, CELL_ALT, f_sAlternative, sizeof(f_sAlternative));
						ShowMOTDPanel(client, "", f_sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", f_sName);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be greater than or equal to \"%s\".", cvarName, cvarValue, f_sValue);
						KickClient(client, "%t", "SMAC_ShouldBeGreater", cvarName, f_sValue, cvarValue);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should greater than or equal to.", cvarName, cvarValue, f_sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						return;
					}
				}
			}
		case COMP_LESS:
			if ( StringToFloat(f_sValue) < StringToFloat(cvarValue) && SMAC_CheatDetected(client) == Plugin_Continue )
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotLess", f_sName, f_sCVarName, cvarValue, f_sValue);
				
				switch(f_iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(f_hConVar, CELL_ALT, f_sAlternative, sizeof(f_sAlternative));
						ShowMOTDPanel(client, "", f_sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", f_sName);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be less than or equal to \"%s\".", cvarName, cvarValue, f_sValue);
						KickClient(client, "%t", "SMAC_ShouldBeLess", cvarName, f_sValue, cvarValue);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should be less than or equal to.", cvarName, cvarValue, f_sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						return;
					}
				}
			}
		case COMP_BOUND:
			if ( StringToFloat(cvarValue) < StringToFloat(f_sValue) || StringToFloat(cvarValue) > f_fValue2 && SMAC_CheatDetected(client) == Plugin_Continue )
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotBound", f_sName, f_sCVarName, cvarValue, f_sValue, f_fValue2);
				
				switch(f_iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(f_hConVar, CELL_ALT, f_sAlternative, sizeof(f_sAlternative));
						ShowMOTDPanel(client, "", f_sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", f_sName);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be between \"%s\" and \"%f\".", cvarName, cvarValue, f_sValue, f_fValue2);
						KickClient(client, "%t", "SMAC_ShouldBound", cvarName, f_sValue, f_fValue2, cvarValue);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" when it should be between \"%s\" and \"%f\".", cvarName, cvarValue, f_sValue, f_fValue2);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						return;
					}
				}
			}
		case COMP_STRING:
			if ( !StrEqual(f_sValue, cvarValue) && SMAC_CheatDetected(client) == Plugin_Continue )
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotEqual", f_sName, f_sCVarName, cvarValue, f_sValue);
				
				switch(f_iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(f_hConVar, CELL_ALT, f_sAlternative, sizeof(f_sAlternative));
						ShowMOTDPanel(client, "", f_sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", f_sName);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be \"%s\".", cvarName, cvarValue, f_sValue);
						KickClient(client, "%t", "SMAC_ShouldEqual", cvarName, f_sValue, cvarValue);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should equal.", cvarName, cvarValue, f_sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						return;
					}
				}
			}
	}
	
	if ( f_bContinue )
		g_hPeriodicTimer[client] = CreateTimer(GetRandomFloat(0.5, 2.0), CVars_PeriodicTimer, client);
	
}

//- Hook -//

public CVars_Replicate(Handle:convar, const String:oldvalue[], const String:newvalue[])
{
	decl String:f_sName[64], Handle:f_hCVarIndex, Handle:f_hTimer;
	GetConVarName(convar, f_sName, sizeof(f_sName));
	if ( GetTrieValue(g_hCVarIndex, f_sName, f_hCVarIndex) )
	{
		f_hTimer = GetArrayCell(f_hCVarIndex, CELL_CHANGED);
		if ( f_hTimer != INVALID_HANDLE )
			CloseHandle(f_hTimer);
		f_hTimer = CreateTimer(30.0, CVars_ReplicateCheck, f_hCVarIndex);
		SetArrayCell(f_hCVarIndex, CELL_CHANGED, f_hTimer);
	}
	// The delay is so that nothing interferes with the replication.
	CreateTimer(0.1, CVars_ReplicateTimer, convar);
}

//- Private Functions -//

stock bool:CVars_IsValidName(const String:f_sName[])
{
	if (f_sName[0] == '\0')
		return false;
	
	new len = strlen(f_sName);
	for (new i = 0; i < len; i++)
		if (!IsValidConVarChar(f_sName[i]))
			return false;

	return true;
}

bool:CVars_AddCVar(String:f_sName[], f_iComparisonType, f_iAction, const String:f_sValue[], Float:f_fValue2, f_iImportance, const String:f_sAlternative[] = "")
{
	new Handle:f_hConVar = INVALID_HANDLE, Handle:f_hArray;
	
	new c = 0;
	do
	{
		f_sName[c] = CharToLower(f_sName[c]);
	} while ( f_sName[c++] != '\0' );

	f_hConVar = FindConVar(f_sName);
	if ( f_hConVar != INVALID_HANDLE && (GetConVarFlags(f_hConVar) & FCVAR_REPLICATED) && ( f_iComparisonType == COMP_EQUAL || f_iComparisonType == COMP_STRING ) )
		f_iComparisonType = COMP_EQUAL;
	else
		f_hConVar = INVALID_HANDLE;

	if ( GetTrieValue(g_hCVarIndex, f_sName, f_hArray) ) // Check if CVar check already exists.
	{
		SetArrayString(f_hArray, CELL_NAME, f_sName);			// Name			0
		SetArrayCell(f_hArray, CELL_COMPTYPE, f_iComparisonType);	// Comparison Type	1
		SetArrayCell(f_hArray, CELL_HANDLE, f_hConVar);			// CVar Handle		2
		SetArrayCell(f_hArray, CELL_ACTION, f_iAction);			// Action Type		3
		SetArrayString(f_hArray, CELL_VALUE, f_sValue);			// Value		4
		SetArrayCell(f_hArray, CELL_VALUE2, f_fValue2);			// Value2		5
		SetArrayString(f_hArray, CELL_ALT, f_sAlternative);		// Alternative Info	6
		// We will not change the priority.
		// Nor will we change the "changed" cell either.
	}
	else
	{
		f_hArray = CreateArray(64);
		PushArrayString(f_hArray, f_sName);		// Name			0
		PushArrayCell(f_hArray, f_iComparisonType);	// Comparison Type	1
		PushArrayCell(f_hArray, f_hConVar);		// CVar Handle		2
		PushArrayCell(f_hArray, f_iAction);		// Action Type		3
		PushArrayString(f_hArray, f_sValue);		// Value		4
		PushArrayCell(f_hArray, f_fValue2);		// Value2		5
		PushArrayString(f_hArray, f_sAlternative);	// Alternative Info	6
		PushArrayCell(f_hArray, f_iImportance);		// Importance		7
		PushArrayCell(f_hArray, INVALID_HANDLE);	// Changed		8

		if ( !SetTrieValue(g_hCVarIndex, f_sName, f_hArray) )
		{
			CloseHandle(f_hArray);
			SMAC_Log("Unable to add convar to Trie link list %s.", f_sName);
			return false;
		}

		PushArrayCell(g_hCVars, f_hArray);
		g_iSize = GetArraySize(g_hCVars);

		if ( f_iImportance != PRIORITY_NORMAL && g_bMapStarted )
			CVars_CreateNewOrder();

	}

	return true;
}

stock bool:CVars_RemoveCVar(String:f_sName[])
{
	decl Handle:f_hConVar, f_iIndex;

	if ( !GetTrieValue(g_hCVarIndex, f_sName, f_hConVar) )
		return false;

	f_iIndex = FindValueInArray(g_hCVars, f_hConVar);
	if ( f_iIndex == -1 )
		return false;

	for(new i=0;i<=MaxClients;i++)
		if ( g_hCurrentQuery[i] == f_hConVar )
			g_hCurrentQuery[i] = INVALID_HANDLE;

	RemoveFromArray(g_hCVars, f_iIndex);
	RemoveFromTrie(g_hCVarIndex, f_sName);
	CloseHandle(f_hConVar);
	g_iSize = GetArraySize(g_hCVars);
	return true;
}

CVars_CreateNewOrder()
{
	new Handle:f_hOrder[g_iSize], f_iCurrent;
	new Handle:f_hPHigh, Handle:f_hPMedium, Handle:f_hPNormal, Handle:f_hCurrent;
	new f_iHigh, f_iMedium, f_iNormal, f_iTemp;

	f_hPHigh = CreateArray(64);
	f_hPMedium = CreateArray(64);
	f_hPNormal = CreateArray(64);

	// Get priorities.
	for(new i=0;i<g_iSize;i++)
	{
		f_hCurrent = GetArrayCell(g_hCVars, i);
		f_iTemp = GetArrayCell(f_hCurrent, CELL_PRIORITY);
		if ( f_iTemp == PRIORITY_NORMAL )
			PushArrayCell(f_hPNormal, f_hCurrent);
		else if ( f_iTemp == PRIORITY_MEDIUM )
			PushArrayCell(f_hPMedium, f_hCurrent);
		else if ( f_iTemp == PRIORITY_HIGH )
			PushArrayCell(f_hPHigh, f_hCurrent);
	}

	f_iHigh = GetArraySize(f_hPHigh)-1;
	f_iMedium = GetArraySize(f_hPMedium)-1;
	f_iNormal = GetArraySize(f_hPNormal)-1;

	// Start randomizing!
	while ( f_iHigh > -1 )
	{
		f_iTemp = GetRandomInt(0, f_iHigh);
		f_hOrder[f_iCurrent++] = GetArrayCell(f_hPHigh, f_iTemp);
		RemoveFromArray(f_hPHigh, f_iTemp);
		f_iHigh--;
	}

	while ( f_iMedium > -1 )
	{
		f_iTemp = GetRandomInt(0, f_iMedium);
		f_hOrder[f_iCurrent++] = GetArrayCell(f_hPMedium, f_iTemp);
		RemoveFromArray(f_hPMedium, f_iTemp);
		f_iMedium--;
	}

	while ( f_iNormal > -1 )
	{
		f_iTemp = GetRandomInt(0, f_iNormal);
		f_hOrder[f_iCurrent++] = GetArrayCell(f_hPNormal, f_iTemp);
		RemoveFromArray(f_hPNormal, f_iTemp);
		f_iNormal--;
	}

	ClearArray(g_hCVars);

	for(new i=0;i<g_iSize;i++)
		PushArrayCell(g_hCVars, f_hOrder[i]);

	CloseHandle(f_hPHigh);
	CloseHandle(f_hPMedium);
	CloseHandle(f_hPNormal);
}

CVars_ReplicateConVar(Handle:f_hConVar)
{
	decl String:f_sValue[64];
	GetConVarString(f_hConVar, f_sValue, sizeof(f_sValue));
	
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			SendConVarValue(i, f_hConVar, f_sValue);
}
