#pragma semicolon 1;
#pragma tabsize 0;


#define PLUGIN_AUTHOR    "TTony"
#define PLUGIN_VERSION    "1.0 Chat-Processor"

#define MAXLENGTH_INPUT            128     
#define MAXLENGTH_NAME            64        
#define MAXLENGTH_MESSAGE        256        

#include <sourcemod> 
#include <cstrike> 
#include <clientprefs>
#include <vip_core>

#undef REQUIRE_PLUGIN
#include <chat-processor>
#define REQUIRE_PLUGIN

#include <multicolors>


Handle h_bEnable;
Handle g_hClientCookies;

char admin_Tags[100][256];
char admin_Flags[100][8];
char admin_Mode[100][32];
char admin_TagColors[100][32];
char admin_NameColors[100][32];
char admin_TextColors[100][32];
char admin_SteamIds[100][32];

char vip_Tags[100][256];
char vip_Flags[100][8];
char vip_Mode[100][32];
char vip_TagColors[100][32];
char vip_NameColors[100][32];
char vip_TextColors[100][32];
char vip_SteamIds[100][32];

char custom_Tags[100][256];
char custom_Flags[100][8];
char custom_Mode[100][32];
char custom_TagColors[100][32];
char custom_NameColors[100][32];
char custom_TextColors[100][32];
char custom_SteamIds[100][32];

char adminvip_Tags[100][256];
char adminvip_Flags[100][8];
char adminvip_Mode[100][32];
char adminvip_TagColors_first[100][32];
char adminvip_TagColors_second[100][32];
char adminvip_NameColors[100][32];
char adminvip_TextColors[100][32];
char adminvip_SteamIds[100][32];

char dns_Tags[100][256];
char dns_Mode[100][32];
char dns_TagColors[100][32];
char dns_NameColors[100][32];
char dns_TextColors[100][32];
char dns_ServerDns[100][32];

int admin_iTags = 0;
int vip_iTags = 0;
int custom_iTags = 0;
int adminvip_iTags = 0;
int dns_iTags = 0;

static const char g_sFeature[] = "VipTags";

public Plugin myinfo = 
{
    name = "[CSGO] Chat/Scoreboard Tag Menu", 
    author = PLUGIN_AUTHOR, 
    description = "An advanced chat & scoreboard tag menu for players", 
    version = PLUGIN_VERSION, 
    url = "https://github.com/PrdTTony"
};

public void OnPluginStart()
{
    LoadTranslations("TagMenu.phrases");
    
    h_bEnable = CreateConVar("sm_tagmenu_enable", "1", "Enable / Disable tag menu", _, true, 0.0, true, 1.0);
    
    RegConsoleCmd("sm_tag", Command_TagMenu);
    RegConsoleCmd("sm_tags", Command_TagMenu);
    RegConsoleCmd("sm_tagmenu", Command_TagMenu);
    
    RegAdminCmd("sm_reloadtags", Command_ReloadTags, ADMFLAG_GENERIC);
    
    HookEvent("player_spawn", Event_PlayerSetTag);
    HookEvent("player_team", Event_PlayerSetTag);
    
    g_hClientCookies = RegClientCookie("Tag_Menu", "A cookie for saving clients's tags", CookieAccess_Private);

    if (VIP_IsVIPLoaded())
	{
		VIP_OnVIPLoaded();
	}
    
    LoadTagsFromFile();
}

public VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_sFeature, BOOL);
}

public void OnAllPluginsLoaded()
{
    if(!LibraryExists("chat-processor"))
    {
        LogError("[TagMenu] Chat Processor(https://forums.alliedmods.net/showthread.php?t=286913) plugin not found! Chat function is disabled.");
    }
}

public Action Event_PlayerSetTag(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    SetClientTag(client);
    return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
    if (AreClientCookiesCached(client))
    {
        SetClientTag(client);
    }
}

public void OnClientSettingsChanged(int client)
{
    if (AreClientCookiesCached(client))
    {
        SetClientTag(client);
    }
}

public Action Command_TagMenu(int client, int args)
{
    if (GetConVarBool(h_bEnable))
        MainTagMenu(client);
    else
        CReplyToCommand(client, "%t", "TagMenu_Disabled");
    
    return Plugin_Handled;
}

public Action Command_ReloadTags(int client, int args)
{
    LoadTagsFromFile();
    CReplyToCommand(client, "%t", "Tags_Reloaded");
    return Plugin_Handled;
}

void MainTagMenu(int iClient)
{   
    char sCookie[300];
    GetClientCookie(iClient, g_hClientCookies, sCookie, sizeof(sCookie));
    ReplaceString(sCookie, 256, ";", "_,_");
    char sCookies[3][256];
    ExplodeString(sCookie, "_,_", sCookies, 3, 256);

    
    Menu menu = new Menu(MainTagMenu_Handler);
    if(StrEqual(sCookies[2], "\0")){
        menu.SetTitle("➢ Custom Tags System™ \n‎ \n➢ Your tag: %s \n‎", sCookies[1]);
    } else {
        char new_title[100];
        Format(new_title, 100, "%s %s", sCookies[1], sCookies[2]);
        menu.SetTitle("➢ Custom Tags System™ \n‎ \n➢ Your tag: %s \n‎", new_title);
    }
    menu.AddItem("admintag", "➢ Tag De Admin");
    menu.AddItem("viptag", "➢ Tag De VIP", !VIP_IsClientVIP(iClient) && !VIP_IsClientFeatureUse(iClient, g_sFeature) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
    menu.AddItem("adminviptag", "➢ Tag De Admin + VIP", !VIP_IsClientVIP(iClient) || !VIP_IsClientFeatureUse(iClient, g_sFeature) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
    menu.AddItem("customtag", "➢ Tag Custom");
    char buffer[32];
    Format(buffer, sizeof(buffer), "➢ Tag DNS [%s]", dns_ServerDns[1]);
    menu.AddItem("dnstag", buffer, !HasDNS(iClient) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
    menu.AddItem("disabletag", "➢ Disable Tag");
    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MainTagMenu_Handler(Menu hMenu, MenuAction iAction, int iClient, int iParam2)
{
    switch(iAction)
	{
		case MenuAction_End:delete hMenu;

		case MenuAction_Select:
		{
			if(IsClientInGame(iClient))
			{
				char option[32];
				hMenu.GetItem(iParam2, option, sizeof(option));

				if (StrEqual(option, "viptag"))
				{	
					TagMenuVIP(iClient);
                }	
				if (StrEqual(option, "admintag"))
				{	
					TagMenuAdmin(iClient);				
                }	
				if (StrEqual(option, "adminviptag"))
				{	
					TagMenuAdminVip(iClient);
                }
                if (StrEqual(option, "customtag"))
				{	
					TagMenuCustom(iClient);
                }
                if (StrEqual(option, "dnstag"))
				{	
                    TagMenuDNS(iClient);
                }
                if (StrEqual(option, "disabletag"))
				{	
                    char sSteamID[32];
                    GetClientAuthId(iClient, AuthId_Engine, sSteamID, sizeof(sSteamID));
                    CS_SetClientClanTag(iClient, "");
                    SetAuthIdCookie(sSteamID, g_hClientCookies, "");
                    CPrintToChat(iClient, "{green}[Tags™] {default}You succesfully disabled your tag");
                    MainTagMenu(iClient);
                }

			}
			
		}
	}
    return 0;
}

public void TagMenuDNS(int client)
{   
    char sCookie[300];
    GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
    char sCookies[2][256];
    ExplodeString(sCookie, "_,_", sCookies, 2, 256);
    Menu menu = CreateMenu(MenuCallBack);
    menu.ExitBackButton = true;
    SetMenuTitle(menu, "➢ Custom Tags System™ \n‎ \n➢ Your tag: %s \n‎", sCookies[1]);
    
    
    char sDisableItem[128];
    Format(sDisableItem, sizeof(sDisableItem), "%t", "Item_Disable");
    AddMenuItem(menu, "0", sDisableItem);
    
    for (int i = 0; i < dns_iTags; i++)
    {
        char sInfo[300];
        Format(sInfo, sizeof(sInfo), "%s_,_%s", dns_Mode[i], dns_Tags[i]);
        
        if (HasDNS(client))
        {
            AddMenuItem(menu, sInfo, dns_Tags[i]);
        }
        else {
            AddMenuItem(menu, sInfo, dns_Tags[i], ITEMDRAW_DISABLED);
        }
        
    }
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void TagMenuCustom(int client)
{   
    char sCookie[300];
    GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
    char sCookies[2][256];
    ExplodeString(sCookie, "_,_", sCookies, 2, 256);
    Menu menu = CreateMenu(MenuCallBack);
    menu.ExitBackButton = true;
    SetMenuTitle(menu, "➢ Custom Tags System™ \n‎ \n➢ Your tag: %s \n‎", sCookies[1]);
    
    
    char sDisableItem[128];
    Format(sDisableItem, sizeof(sDisableItem), "%t", "Item_Disable");
    AddMenuItem(menu, "0", sDisableItem);
    
    for (int i = 0; i < custom_iTags; i++)
    {
        char sInfo[300];
        Format(sInfo, sizeof(sInfo), "%s_,_%s", custom_Mode[i], custom_Tags[i]);
        
        if (custom_Flags[i][0] == '\0')
        {
            if (custom_SteamIds[i][0] != '\0')
            {
                char sSteamID[32];
                GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
                if (StrEqual(custom_SteamIds[i], sSteamID))
                    AddMenuItem(menu, sInfo, custom_Tags[i]);
                else
                    AddMenuItem(menu, sInfo, custom_Tags[i], ITEMDRAW_DISABLED);
            }
            else
                AddMenuItem(menu, sInfo, custom_Tags[i]);
        }
        else
        {
            if (CheckCommandAccess(client, "", ReadFlagString(custom_Flags[i])))
            {
                AddMenuItem(menu, sInfo, custom_Tags[i]);
            }
            else
                AddMenuItem(menu, sInfo, custom_Tags[i], ITEMDRAW_DISABLED);
        }
    }
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void TagMenuVIP(int client)
{   
    char sCookie[300];
    GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
    char sCookies[2][256];
    ExplodeString(sCookie, "_,_", sCookies, 2, 256);
    Menu menu = CreateMenu(MenuCallBack);
    menu.ExitBackButton = true;
    SetMenuTitle(menu, "➢ Custom Tags System™ \n‎ \n➢ Your tag: %s \n‎", sCookies[1]);
    
    char sDisableItem[128];
    Format(sDisableItem, sizeof(sDisableItem), "%t", "Item_Disable");
    AddMenuItem(menu, "0", sDisableItem);
    
    for (int i = 0; i < vip_iTags; i++)
    {
        char sInfo[300];
        Format(sInfo, sizeof(sInfo), "%s_,_%s", vip_Mode[i], vip_Tags[i]);
        
        if (vip_Flags[i][0] == '\0')
        {
            if (vip_SteamIds[i][0] != '\0')
            {
                char sSteamID[32];
                GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
                if (StrEqual(vip_SteamIds[i], sSteamID))
                    AddMenuItem(menu, sInfo, vip_Tags[i]);
                else
                    AddMenuItem(menu, sInfo, vip_Tags[i], ITEMDRAW_DISABLED);
            }
            else
                AddMenuItem(menu, sInfo, vip_Tags[i]);
        }
        else
        {
            if (CheckCommandAccess(client, "", ReadFlagString(vip_Flags[i])))
            {
                AddMenuItem(menu, sInfo, vip_Tags[i]);
            }
            else
                AddMenuItem(menu, sInfo, vip_Tags[i], ITEMDRAW_DISABLED);
        }
    }
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void TagMenuAdmin(int client)
{   
    char sCookie[300];
    GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
    char sCookies[2][256];
    ExplodeString(sCookie, "_,_", sCookies, 2, 256);
    Menu menu = CreateMenu(MenuCallBack);
    menu.ExitBackButton = true;
    SetMenuTitle(menu, "➢ Custom Tags System™ \n‎ \n➢ Your tag: %s \n‎", sCookies[1]);
    
    char sDisableItem[128];
    Format(sDisableItem, sizeof(sDisableItem), "%t", "Item_Disable");
    AddMenuItem(menu, "0", sDisableItem);
    
    for (int i = 0; i < admin_iTags; i++)
    {
        char sInfo[300];
        Format(sInfo, sizeof(sInfo), "%s_,_%s", admin_Mode[i], admin_Tags[i]);
        
        if (admin_Flags[i][0] == '\0')
        {
            if (admin_SteamIds[i][0] != '\0')
            {
                char sSteamID[32];
                GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
                if (StrEqual(admin_SteamIds[i], sSteamID))
                    AddMenuItem(menu, sInfo, admin_Tags[i]);
                else
                    AddMenuItem(menu, sInfo, admin_Tags[i], ITEMDRAW_DISABLED);
            }
            else
                AddMenuItem(menu, sInfo, admin_Tags[i]);
        }
        else
        {
            if (CheckCommandAccess(client, "", ReadFlagString(admin_Flags[i])))
            {
                AddMenuItem(menu, sInfo, admin_Tags[i]);
            }
            else
                AddMenuItem(menu, sInfo, admin_Tags[i], ITEMDRAW_DISABLED);
        }
    }
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void TagMenuAdminVip(int client)
{   
    char sCookie[300];
    GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
    char sCookies[2][256];
    ExplodeString(sCookie, "_,_", sCookies, 2, 256);
    Menu menu = CreateMenu(MenuCallBack_AdminVip);
    menu.SetTitle("➢ Custom Tags System™ \n‎ \n➢ Your tag: %s \n‎", sCookies[1]);
    
    char sDisableItem[128];
    Format(sDisableItem, sizeof(sDisableItem), "%t", "Item_Disable");
    AddMenuItem(menu, "0", sDisableItem);
    
    for (int i = 0; i < adminvip_iTags; i++)
    {
        char sInfo[300];
        char new_tags[300];
        Format(new_tags, sizeof(new_tags), "%s", adminvip_Tags[i]);
        ReplaceString(new_tags, sizeof(new_tags), ";", "");
        Format(sInfo, sizeof(sInfo), "%s_,_%s", adminvip_Mode[i], adminvip_Tags[i]);
        
        if (adminvip_Flags[i][0] == '\0')
        {
            if (adminvip_SteamIds[i][0] != '\0')
            {
                char sSteamID[32];
                GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
                if (StrEqual(adminvip_SteamIds[i], sSteamID))
                    AddMenuItem(menu, sInfo, new_tags);
                else
                    AddMenuItem(menu, sInfo, new_tags, ITEMDRAW_DISABLED);
            }
            else
                AddMenuItem(menu, sInfo, new_tags);
        }
        else
        {
            if (CheckCommandAccess(client, "", ReadFlagString(adminvip_Flags[i])))
            {
                AddMenuItem(menu, sInfo, new_tags);
            }
            else
                AddMenuItem(menu, sInfo, new_tags, ITEMDRAW_DISABLED);
        }
    }
    menu.ExitBackButton = true;
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuCallBack_AdminVip(Handle menu, MenuAction action, int client, int itemNum)
{
    if (action == MenuAction_Select)
    {
        char sItem[256], sSteamID[64];
        GetMenuItem(menu, itemNum, sItem, sizeof(sItem));
        GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
        
        if (itemNum == 0)
        {
            CS_SetClientClanTag(client, "");
            SetAuthIdCookie(sSteamID, g_hClientCookies, "");
            CPrintToChat(client, "%t", "Tag_Disabled");
        }
        else
        {
            char sItems[3][256];
            ReplaceString(sItem, 256, ";", "_,_");
            ExplodeString(sItem, "_,_", sItems, 3, 256);
            
            if (StrEqual(sItems[0], "chat"))
            {
                SetAuthIdCookie(sSteamID, g_hClientCookies, sItem);
                CPrintToChat(client, "{green}[Tags™] {default}Your new tag {green}%s %s {default}has been enabled", sItems[1], sItems[2]);
            }
            else
            {   
                CS_SetClientClanTag(client, "");
                char new_tag[300];
                Format(new_tag, 300, "%s %s", sItems[1], sItems[2]);
                CS_SetClientClanTag(client, new_tag);
                SetAuthIdCookie(sSteamID, g_hClientCookies, sItem);
                CPrintToChat(client, "{green}[Tags™] {default}Your new tag {green}%s %s {default}has been enabled", sItems[1], sItems[2]);
                
            }
        }
        MainTagMenu(client);
    } else if (action == MenuAction_End){
        CloseHandle(menu);
    } else if (action == MenuAction_Cancel){
        MainTagMenu(client);
    }
    
    
    return 0;
}

public int MenuCallBack(Menu menu, MenuAction action, int client, int itemNum)
{
    if (action == MenuAction_Select)
    {
        char sItem[256], sSteamID[64];
        GetMenuItem(menu, itemNum, sItem, sizeof(sItem));
        GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
        
        if (itemNum == 0)
        {
            CS_SetClientClanTag(client, "");
            SetAuthIdCookie(sSteamID, g_hClientCookies, "");
            CPrintToChat(client, "%t", "Tag_Disabled");
        }
        else
        {
            char sItems[2][256];
            ExplodeString(sItem, "_,_", sItems, 2, 256);
            
            if (StrEqual(sItems[0], "chat"))
            {
                SetAuthIdCookie(sSteamID, g_hClientCookies, sItem);
                CPrintToChat(client, "%t", "ChatTag_Enabled", sItems[1]);
            }
            else
            {   
                CS_SetClientClanTag(client, "");
                CS_SetClientClanTag(client, sItems[1]);
                SetAuthIdCookie(sSteamID, g_hClientCookies, sItem);
                CPrintToChat(client, "%t", "Tag_Enabled", sItems[1]);                
            }
        }
        MainTagMenu(client);
    } else if (action == MenuAction_End){
        delete menu;
    } else if (action == MenuAction_Cancel){
        MainTagMenu(client);
    }
    return 0;
}

public Action CP_OnChatMessage(int &client, ArrayList recipients, char[] flagstring, char[] sName, char[] sMessage, bool &processcolors, bool &removecolors)
{
    if(GetConVarBool(h_bEnable) && (MaxClients >= client > 0))
    {
        if(sMessage[0] == '/' || sMessage[0] == '@')
        {
            return Plugin_Continue;
        }
        
        char sCookie[300];
        GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
        ReplaceString(sCookie, 256, ";", "_,_");
        
        if (sCookie[0] == '\0')
            return Plugin_Continue;
        
        char sCookies[3][256];
        ExplodeString(sCookie, "_,_", sCookies, 3, 256);
        
        if (StrEqual(sCookies[0], "scoreboard"))
            return Plugin_Continue;
        
        if(StrEqual(sCookies[2], "\0")){
            char sTagColor[32], sNameColor[32], sTextColor[32];
            FindTagColors(sCookies[1], sTagColor, sNameColor, sTextColor);
        
            Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", sTextColor, sMessage);
            Format(sName, MAXLENGTH_NAME, "%s%s %s%s", sTagColor, sCookies[1], sNameColor, sName);
        
        } else {
            char sTagColor[32], sTagColor2[32], sNameColor[32], sTextColor[32];
            char new_cookie[300];
            Format(new_cookie, 300, "%s;%s", sCookies[1], sCookies[2]);
            FindTagColors_AdminVip(new_cookie, sTagColor, sNameColor, sTextColor, sTagColor2);
        
            Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", sTextColor, sMessage);
            Format(sName, MAXLENGTH_NAME, "%s%s %s%s %s%s", sTagColor, sCookies[1], sTagColor2, sCookies[2], sNameColor, sName);
        }

        return Plugin_Changed;

    }

    return Plugin_Continue;
}

public void LoadTagsFromFile()
{   
    KeyValues kv = new KeyValues("TagMenu");
    if (FileToKeyValues(kv, "addons/sourcemod/configs/tagmenu.cfg"))
    {   
        admin_iTags = 0;
        vip_iTags = 0;
        custom_iTags = 0;
        adminvip_iTags = 0;
        dns_iTags = 0;

        if(kv.JumpToKey("ADMIN"))
        {
            if(kv.GotoFirstSubKey()){

                admin_iTags = 0;
                do
                {
                    kv.GetString("tag", admin_Tags[admin_iTags], 256);
                    kv.GetString("flag", admin_Flags[admin_iTags], 8);
                    kv.GetString("steamid", admin_SteamIds[admin_iTags], 32);
                    kv.GetString("tag_color", admin_TagColors[admin_iTags], 32, "{default}");
                    kv.GetString("name_color", admin_NameColors[admin_iTags], 32, "{teamcolor}");
                    kv.GetString("text_color", admin_TextColors[admin_iTags], 32, "{default}");
                    kv.GetString("mode", admin_Mode[admin_iTags], 32, "both");
                    admin_iTags++;
                    
                } while (kv.GotoNextKey());
            }
            kv.Rewind();
        }


        if(kv.JumpToKey("VIP"))
        {   
            if(kv.GotoFirstSubKey()){
                vip_iTags = 0;
                do
                {
                    kv.GetString("tag", vip_Tags[vip_iTags], 256);
                    kv.GetString("flag", vip_Flags[vip_iTags], 8);
                    kv.GetString("steamid", vip_SteamIds[vip_iTags], 32);
                    kv.GetString("tag_color", vip_TagColors[vip_iTags], 32, "{default}");
                    kv.GetString("name_color", vip_NameColors[vip_iTags], 32, "{teamcolor}");
                    kv.GetString("text_color", vip_TextColors[vip_iTags], 32, "{default}");
                    kv.GetString("mode", vip_Mode[vip_iTags], 32, "both");
                    vip_iTags++;
                    
                } while (kv.GotoNextKey());
            }
            kv.Rewind();
        }

        if(kv.JumpToKey("CUSTOM"))
        {
            if(kv.GotoFirstSubKey()){

                custom_iTags = 0;
                do
                {
                    kv.GetString("tag", custom_Tags[custom_iTags], 256);
                    kv.GetString("flag", custom_Flags[custom_iTags], 8);
                    kv.GetString("steamid", custom_SteamIds[custom_iTags], 32);
                    kv.GetString("tag_color", custom_TagColors[custom_iTags], 32, "{default}");
                    kv.GetString("name_color", custom_NameColors[custom_iTags], 32, "{teamcolor}");
                    kv.GetString("text_color", custom_TextColors[custom_iTags], 32, "{default}");
                    kv.GetString("mode", custom_Mode[custom_iTags], 32, "both");
                    custom_iTags++;
                    
                } while (kv.GotoNextKey());
            }
            kv.Rewind();
        }

        if(kv.JumpToKey("ADMINsiVIP"))
        {
            if(kv.GotoFirstSubKey()){

                adminvip_iTags = 0;
                do
                {
                    kv.GetString("tag", adminvip_Tags[adminvip_iTags], 256);
                    kv.GetString("flag", adminvip_Flags[adminvip_iTags], 8);
                    kv.GetString("steamid", adminvip_SteamIds[adminvip_iTags], 32);
                    kv.GetString("tag_color_first", adminvip_TagColors_first[adminvip_iTags], 32, "{default}");
                    kv.GetString("tag_color_second", adminvip_TagColors_second[adminvip_iTags], 32, "{default}");
                    kv.GetString("name_color", adminvip_NameColors[adminvip_iTags], 32, "{teamcolor}");
                    kv.GetString("text_color", adminvip_TextColors[adminvip_iTags], 32, "{default}");
                    kv.GetString("mode", adminvip_Mode[adminvip_iTags], 32, "both");
                    adminvip_iTags++;
                    
                } while (kv.GotoNextKey());
            }
            kv.Rewind();
        }       

        if(kv.JumpToKey("DNS"))
        {
            if(kv.GotoFirstSubKey()){

                dns_iTags = 0;
                do
                {
                    kv.GetString("tag", dns_Tags[dns_iTags], 256);
                    kv.GetString("tag_color", dns_TagColors[dns_iTags], 32, "{default}");
                    kv.GetString("name_color", dns_NameColors[dns_iTags], 32, "{teamcolor}");
                    kv.GetString("text_color", dns_TextColors[dns_iTags], 32, "{default}");
                    kv.GetString("mode", dns_Mode[dns_iTags], 32, "both");
                    kv.GetString("server_dns", dns_ServerDns[dns_iTags], 32);

                    dns_iTags++;
                    
                } while (kv.GotoNextKey());                                   
            }
            kv.Rewind();
        }
    }
    else
    {
        SetFailState("[TagMenu] Error in parsing file tagmenu.cfg.");
    }
    CloseHandle(kv);
}

public void SetClientTag(int client)
{
    if (client < 1 || client > MaxClients || !GetConVarBool(h_bEnable) || !IsClientConnected(client) || IsFakeClient(client))
        return;
    
    char sCookie[256];
    GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
    ReplaceString(sCookie, 256, ";", "_,_");

    if (sCookie[0] == '\0')
        return;
    
    char sCookies[3][256];
    ExplodeString(sCookie, "_,_", sCookies, 3, 256);
    
    
    if (!StrEqual(sCookies[0], "chat"))
    {   
        if(StrEqual(sCookies[2], "\0")){
            char sPlayerTag[64];
            CS_GetClientClanTag(client, sPlayerTag, sizeof(sPlayerTag));
            if (!StrEqual(sPlayerTag, sCookies[1]))
            {
                CS_SetClientClanTag(client, sCookies[1]);
            }
        } else {
            
            char sPlayerTag[64];
            CS_GetClientClanTag(client, sPlayerTag, sizeof(sPlayerTag));
            char new_tag[100];
            Format(new_tag, 100, "%s %s", sCookies[1], sCookies[2]);
            if (!StrEqual(sPlayerTag, new_tag))
            {
                CS_SetClientClanTag(client, new_tag);
            }
            
        }
    }
}

public void FindTagColors(char[] sTag, char[] sTagColor, char[] sNameColor, char[] sTextColor)
{
    for (int i = 0; i < admin_iTags + vip_iTags + custom_iTags + adminvip_iTags + dns_iTags; i++)
    {
        if (StrEqual(admin_Tags[i], sTag))
        {
            strcopy(sTagColor, 32, admin_TagColors[i]);
            strcopy(sNameColor, 32, admin_NameColors[i]);
            strcopy(sTextColor, 32, admin_TextColors[i]);
            break;

        } else if (StrEqual(vip_Tags[i], sTag))
        {
            strcopy(sTagColor, 32, vip_TagColors[i]);
            strcopy(sNameColor, 32, vip_NameColors[i]);
            strcopy(sTextColor, 32, vip_TextColors[i]);
            break;

        } else if (StrEqual(custom_Tags[i], sTag))
        {
            strcopy(sTagColor, 32, custom_TagColors[i]);
            strcopy(sNameColor, 32, custom_NameColors[i]);
            strcopy(sTextColor, 32, custom_TextColors[i]);
            break;
        } else if (StrEqual(dns_Tags[i], sTag))
        {
            strcopy(sTagColor, 32, dns_TagColors[i]);
            strcopy(sNameColor, 32, dns_NameColors[i]);
            strcopy(sTextColor, 32, dns_TextColors[i]);
            break;
        }
    }
}  

public void FindTagColors_AdminVip(char[] sTag, char[] sTagColor, char[] sNameColor, char[] sTextColor, char[] sTagColor2)
{
    for (int i = 0; i < adminvip_iTags; i++)
    {
        if (StrEqual(adminvip_Tags[i], sTag))
        {
            strcopy(sTagColor, 32, adminvip_TagColors_first[i]);
            strcopy(sNameColor, 32, adminvip_NameColors[i]);
            strcopy(sTextColor, 32, adminvip_TextColors[i]);
            strcopy(sTagColor2, 32, adminvip_TagColors_second[i]);
            break;
        } 
    }
}  

bool HasDNS(int client)
{
    char PlayerName[32];
    GetClientName(client, PlayerName, sizeof(PlayerName));
    if(StrContains(PlayerName, dns_ServerDns[1], false) > -1){
        return true;
    } else {
        return false;
    }
} 

public OnPluginEnd() 
{	
	VIP_UnregisterMe();
}