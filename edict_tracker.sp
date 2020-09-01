#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma newdecls required

#define LOG_NEXTFRAME

Handle g_detourOnEdictAllocated;
Handle g_detourOnEdictFreed;

Address g_serverPlugin;

public void OnPluginStart()
{
    GameData conf = new GameData("edict_tracker.games");    
    
    if (conf == null)
        SetFailState("Failed to load edict_tracker gamedata");
    
    StartPrepSDKCall(SDKCall_Static);
    
    if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CreateInterface"))
        SetFailState("Failed to get CreateInterface");
        
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    
    char iface[64];
    
    if (!conf.GetKeyValue("ServerPluginInterface", iface, sizeof(iface)))
        SetFailState("Failed to get serverplugin interface name");
    
    Handle call = EndPrepSDKCall();
    
    g_serverPlugin = SDKCall(call, iface, 0);
    
    delete call;
    
    if (!g_serverPlugin)
        SetFailState("Failed to get serverplugin ptr");
        
    if (!(g_detourOnEdictAllocated = DHookCreateFromConf(conf, "IServerPluginCallbacks::OnEdictAllocated")))
        SetFailState("Failed to setup detour for IServerPluginCallbacks::OnEdictAllocated");
        
    if (!(g_detourOnEdictFreed = DHookCreateFromConf(conf, "IServerPluginCallbacks::OnEdictFreed")))
        SetFailState("Failed to setup detour for IServerPluginCallbacks::OnEdictFreed");
        
    delete conf;
    
    DHookRaw(g_detourOnEdictAllocated, false, g_serverPlugin, _, Detour_OnEdictAllocated);
    DHookRaw(g_detourOnEdictFreed, false, g_serverPlugin, _, Detour_OnEdictFreed);
}

public MRESReturn Detour_OnEdictAllocated(Handle params)
{
    int edict = DHookGetParam(params, 1);
    
    LogMessage("OnEdictAllocated (%i)", edict);

#if defined LOG_NEXTFRAME
    RequestFrame(NextFrame_OnEdictAllocated, edict);
#endif
    
    return MRES_Ignored;
}

#if defined LOG_NEXTFRAME
void NextFrame_OnEdictAllocated(int edict)
{
    if (!IsValidEdict(edict))
        return;

    char classname[64];
    GetEdictClassname(edict, classname, sizeof(classname));

    LogMessage("OnEdictAllocated_NextFrame (%i | %s)", edict, classname);
}
#endif

public MRESReturn Detour_OnEdictFreed(Handle params)
{
    int edict = DHookGetParam(params, 1);

    LogMessage("OnEdictFreed (%i)", edict);

    return MRES_Ignored;
}
