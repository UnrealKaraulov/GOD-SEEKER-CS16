#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <xs>

#define PLUGIN "God Seeker"
#define VERSION "2.5"
#define AUTHOR "karaulov"

// Введите сюда требуемый уровень доступа из amxconst.inc
#define ADMIN_ACCESS_LEVEL ADMIN_BAN
// Раскомментируйте следующую строку что бы разрешить вход в software режиме
//#define ALLOW_SOFTWARE_MODE

new const INVISIBLED_MODEL_NAME[] = "gsfp_vip"; // невидимая модель вида models/player/%s/%s.mdl

#define BAD_STATE_PENDING 3
#define BAD_STATE_SOFWARE 2
#define BAD_STATE_MINMODELS 1
#define BAD_STATE_NONE 0

//new g_bMonitorMinModelsActive = false;

new bool:g_bGodSeekerActivated[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerDisableSounds[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerDisableUsername[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerDisableDamage[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerTeleport[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerHideFromBots[MAX_PLAYERS + 1] = {false,...};
new bool:g_bIsUserBot[MAX_PLAYERS + 1] = {false,...};

new g_pCommonTr;
new g_pMenuHandle[MAX_PLAYERS + 1] = {-1, ...};

new g_iMsgShadow;
new g_iShadowSprite;
new g_iBadClients[MAX_PLAYERS + 1] = {0, ...};
new g_iGodSeekerInvisMode[MAX_PLAYERS + 1] = 0;
new g_iPlayerAim[MAX_PLAYERS + 1] = {0, ...};
new g_iPlayerAttack[MAX_PLAYERS + 1] = {0, ...};

new Float:g_fLastUpdateMinModels[MAX_PLAYERS + 1] = {0.0, ...};

new g_sPlayerUsernames[MAX_PLAYERS + 1][64];
new g_sPlayerSteamIDs[MAX_PLAYERS + 1][64];


public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	create_cvar("god_seeker", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_clcmd("say /wh", "give_me_god");
	register_clcmd("say /god", "give_me_god");
	register_clcmd("say /antiwh", "give_me_god");
	register_clcmd("say /whmenu", "show_seeker_menu");
	register_clcmd("say /godmenu", "show_seeker_menu");
	
	RegisterHookChain(RG_CSGameRules_FPlayerCanTakeDamage, "CSGameRules_FPlayerCanTakeDmg", .post = false);
	RegisterHookChain(RH_SV_StartSound, "SV_StartSound_Pre", .post = false);
	RegisterHookChain(RG_PlayerBlind, "PlayerBlind", .post = false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "Player_Spawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Killed, "Player_Killed_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", .post = false);
	register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
	RegisterHookChain(RG_CBasePlayer_Observer_IsValidTarget, "CBasePlayer_Observer_IsValidTarget", false);

	register_message(get_user_msgid("StatusValue"), "message_statusvalue");

	g_iMsgShadow = get_user_msgid("ShadowIdx");

	g_pCommonTr = create_tr2();
}

public plugin_end()
{
	free_tr2(g_pCommonTr);
}

public plugin_precache()
{
	g_iShadowSprite = precache_model("sprites/shadow_circle.spr");
	/*g_iModelInvis = */
	new modelName[64];
	formatex(modelName, charsmax(modelName), "models/player/%s/%s.mdl", INVISIBLED_MODEL_NAME, INVISIBLED_MODEL_NAME);
	precache_model(modelName);
}

public client_putinserver(id)
{
	g_iBadClients[id] = BAD_STATE_PENDING;

	g_bGodSeekerActivated[id] = false;
	g_bGodSeekerTeleport[id] = true;
	g_bGodSeekerHideFromBots[id] = false;
	g_bGodSeekerDisableDamage[id] = true;
	g_bGodSeekerDisableSounds[id] = true;
	g_bGodSeekerDisableUsername[id] = true;
	g_iGodSeekerInvisMode[id] = 1;

	g_iPlayerAim[id] = g_iPlayerAttack[id] = 0;

	g_pMenuHandle[id] = -1;

	if (g_bGodSeekerActivated[id])
		disable_god_seeker(id);
		
	g_bIsUserBot[id] = is_user_bot(id) || is_user_hltv(id);
	
	if (!g_bIsUserBot[id])
	{
		query_client_cvar(id, "d_subdiv16", "d_subdiv16_callback");
	}

	get_user_name(id, g_sPlayerUsernames[id], charsmax(g_sPlayerUsernames[]));
	get_user_authid(id, g_sPlayerSteamIDs[id], charsmax(g_sPlayerSteamIDs[]));
}

public client_disconnected(id)
{
	g_iBadClients[id] = BAD_STATE_NONE;

	if (g_bGodSeekerActivated[id])
		disable_god_seeker(id);
}

public show_seeker_menu(id)
{
	if (ADMIN_ACCESS_LEVEL != ADMIN_ALL && get_user_flags(id) & ADMIN_ACCESS_LEVEL == 0)
	{
		return PLUGIN_CONTINUE;
	}

	if (!g_bGodSeekerActivated[id])
	{
		client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Рeжим God Seeker oтключeн!!",PLUGIN);
		return PLUGIN_HANDLED;
	}
	
	if (g_pMenuHandle[id] != -1)
	{
		menu_destroy(g_pMenuHandle[id]);
		g_pMenuHandle[id] = -1;
		show_menu(id, 0, "^n", 0);
		return PLUGIN_HANDLED;
	}

	new tmpmenuitem[128];
	format(tmpmenuitem,127,"[God Seeker] Нacтpoйкa aнтивх:");
		
	new vmenu = menu_create(tmpmenuitem, "seeker_menu");

	g_pMenuHandle[id] = vmenu;

	format(tmpmenuitem,127,"\wНeвидимocть [\r%s\w]", 
	g_iGodSeekerInvisMode[id] == 1 ? "ПРОЗРАЧНАЯ МОДЕЛЬ" : 
	(g_iGodSeekerInvisMode[id] == 2 ? "НЕВИДИМОСТЬ 1" : 
	(g_iGodSeekerInvisMode[id] == 3 ? "НЕВИДИМОСТЬ 2" : 
	(g_iGodSeekerInvisMode[id] == 4 ? "НЕВИДИМОСТЬ 3" : 
	(g_iGodSeekerInvisMode[id] == 5 ? "НЕВИДИМОСТЬ 4" 
	: "ОТКЛЮЧЕНА" )))));
	menu_additem(vmenu, tmpmenuitem,"1");
	format(tmpmenuitem,127,"\wЗвуки [\r%s\w]", g_bGodSeekerDisableSounds[id] ? "НЕ СЛЫШНЫ" : "СЛЫШНЫ");
	menu_additem(vmenu, tmpmenuitem,"2");
	format(tmpmenuitem,127,"\wНикнeйм [\r%s\w]", g_bGodSeekerDisableUsername[id] ? "НЕВИДИМЫЙ" : "ОТОБРАЖАТЬ");
	menu_additem(vmenu, tmpmenuitem,"3");
	format(tmpmenuitem,127,"\wУpoн [\r%s\w]", g_bGodSeekerDisableDamage[id] ? "БЕССМЕРТНЫЙ" : "ПОЛУЧАТЬ");
	menu_additem(vmenu, tmpmenuitem,"4");
	format(tmpmenuitem,127,"\wТeлeпopт атакой [\r%s\w]", g_bGodSeekerTeleport[id] ? "АКТИВИРОВАН" : "ОТКЛЮЧЕН");
	menu_additem(vmenu, tmpmenuitem,"5");
	format(tmpmenuitem,127,"\wСкрыть от ботов [\r%s\w]", g_bGodSeekerHideFromBots[id] ? "ДА" : "НЕТ");
	menu_additem(vmenu, tmpmenuitem,"6");
	format(tmpmenuitem,127,"\wВыключить");
	menu_additem(vmenu, tmpmenuitem,"7");


	
	menu_setprop(vmenu, MPROP_NEXTNAME, "\yСлeдующий cпиcoк");
	menu_setprop(vmenu, MPROP_BACKNAME, "\yПpeдыдущий cпиcoк");
	menu_setprop(vmenu, MPROP_EXITNAME, "\rВыйти из God Seeker мeню");
	menu_setprop(vmenu, MPROP_EXIT,MEXIT_ALL);
	
		
	menu_display(id,vmenu,0);
	return PLUGIN_HANDLED;
}

public seeker_menu(id, vmenu, item) 
{
	if(item == MENU_EXIT || !is_user_connected(id) || !is_user_alive(id)) 
	{
		menu_destroy(vmenu);
		g_pMenuHandle[id] = -1;
		return PLUGIN_HANDLED;
	}
	
	new data[6], iName[64], access, callback
	menu_item_getinfo(vmenu, item, access, data, 5, iName, 63, callback)
	     
	new key = str_to_num(data)
	switch(key) 
	{	
		case 1:
		{
			if (g_iGodSeekerInvisMode[id] == 1)
			{
				rg_reset_user_model(id, true);
				g_iGodSeekerInvisMode[id] = 2;
				client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Рeжим нeвидимocти %d! ^1Внимание тебя видно в дыму!",PLUGIN, g_iGodSeekerInvisMode[id]);
			}
			else if (g_iGodSeekerInvisMode[id] == 2)
			{	
				g_iGodSeekerInvisMode[id] = 3;
				client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Рeжим нeвидимocти %d! ^1Внимание тебя видно в дыму!",PLUGIN, g_iGodSeekerInvisMode[id]);
			}
			else if (g_iGodSeekerInvisMode[id] == 3)
			{
				g_iGodSeekerInvisMode[id] = 4;
				client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Рeжим нeвидимocти %d! ^1[Слабый]",PLUGIN, g_iGodSeekerInvisMode[id]);
			}
			else if (g_iGodSeekerInvisMode[id] == 4)
			{
				g_iGodSeekerInvisMode[id] = 5;
				client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Рeжим нeвидимocти %d! ^1[Слабый]",PLUGIN, g_iGodSeekerInvisMode[id]);
			}
			else 
			{
				g_iGodSeekerInvisMode[id] = 1;
				client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Рeжим нeвидимocти %d! [Прозрачная модель]",PLUGIN, g_iGodSeekerInvisMode[id]);
				rg_set_user_model(id, INVISIBLED_MODEL_NAME, true);

				for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
				{
					if (!g_bIsUserBot[iPlayer] && is_user_connected(iPlayer) && floatabs(get_gametime() - g_fLastUpdateMinModels[iPlayer]) > 2.0)
					{
						if (g_iBadClients[iPlayer] != BAD_STATE_PENDING && g_iBadClients[iPlayer] != BAD_STATE_SOFWARE)
						{
							g_iBadClients[iPlayer] = BAD_STATE_MINMODELS;
							query_client_cvar(iPlayer, "cl_minmodels", "cl_minmodels_callback");
						}
						g_fLastUpdateMinModels[iPlayer] = get_gametime();
					}
				}
				
				remove_task(1);
				set_task(2.0, "print_bad_users", 1);
			}
		}
		case 2:
		{
			g_bGodSeekerDisableSounds[id] = !g_bGodSeekerDisableSounds[id];
		}
		case 3:
		{
			g_bGodSeekerDisableUsername[id] = !g_bGodSeekerDisableUsername[id];
		}
		case 4:
		{
			g_bGodSeekerDisableDamage[id] = !g_bGodSeekerDisableDamage[id];
			set_entvar(id, var_takedamage, g_bGodSeekerDisableDamage[id] ? DAMAGE_NO : DAMAGE_YES);
		}
		case 5:
		{
			g_bGodSeekerTeleport[id] = !g_bGodSeekerTeleport[id];
		}
		case 6:
		{
			g_bGodSeekerHideFromBots[id] = !g_bGodSeekerHideFromBots[id];
			new flags = get_entvar(id, var_flags);
			
			if (g_bGodSeekerHideFromBots[id] && flags & FL_NOTARGET == 0)
			{
				flags += FL_NOTARGET;
				set_entvar(id, var_flags, flags);
			}
			else if (!g_bGodSeekerHideFromBots[id] && flags & FL_NOTARGET)
			{
				flags -= FL_NOTARGET;
				set_entvar(id, var_flags, flags);
			}
		}
		case 7:
		{
			disable_god_seeker(id);
			return PLUGIN_HANDLED;
		}
	}
	// menu_update()
	menu_destroy(vmenu);
	g_pMenuHandle[id] = -1;
	show_seeker_menu(id);
	return PLUGIN_HANDLED;
}

public give_me_god(id)
{
	if (ADMIN_ACCESS_LEVEL == ADMIN_ALL || get_user_flags(id) & ADMIN_ACCESS_LEVEL)
	{
		if (!g_bGodSeekerActivated[id])
		{
			if (!is_user_alive(id))
			{
				if (get_member(id, m_iTeam) == TEAM_CT || get_member(id, m_iTeam) == TEAM_TERRORIST)
				{
					rg_round_respawn(id);
				}
				else 
				{
					client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Войдите в игру для активации ^4God seeker^3.",PLUGIN);
					return PLUGIN_HANDLED;
				}
			}
			enable_god_seeker(id)
			show_seeker_menu(id);
		}
		else 
		{
			disable_god_seeker(id);
		}
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public enable_god_seeker(id)
{
	if (g_bGodSeekerActivated[id])
		return;

	log_to_file("god_seeker.log", "Админиcтpaтop %s [%s] aктивиpoвaл peжим God Seeker.", g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);
	server_print("Админиcтpaтop %s aктивиpoвaл peжим God Seeker.", g_sPlayerUsernames[id])

	client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Тeпepь ты в peжимe ^4God seeker^3. Нacтpoйки /godmenu",PLUGIN);
	print_bad_users(0);

	disable_shadow_all();
			
	g_bGodSeekerActivated[id] = true;

	new flags = get_entvar(id, var_flags);
			
	if (g_bGodSeekerHideFromBots[id] && flags & FL_NOTARGET == 0)
	{
		flags += FL_NOTARGET;
		set_entvar(id, var_flags, flags);
	}
	else if (!g_bGodSeekerHideFromBots[id] && flags & FL_NOTARGET)
	{
		flags -= FL_NOTARGET;
		set_entvar(id, var_flags, flags);
	}

	if (g_bGodSeekerDisableDamage[id])
		set_entvar(id, var_takedamage, DAMAGE_NO);

	if (g_iGodSeekerInvisMode[id] == 1)
		rg_set_user_model(id, INVISIBLED_MODEL_NAME, true);
}

public disable_god_seeker(id)
{
	if(is_user_connected(id))
	{
		if (g_bGodSeekerActivated[id])
		{
			client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Рeжим ^4God Seeker^3 oтключeн.",PLUGIN);
		}
	}

	if (g_bGodSeekerActivated[id])
	{
		log_to_file("god_seeker.log", "Админиcтpaтop %s [%s] дeактивиpoвaл peжим God Seeker.", g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);
		server_print("Админиcтpaтop %s дeактивиpoвaл peжим God Seeker.", g_sPlayerUsernames[id])
	}
	
	g_bGodSeekerActivated[id] = false;

	if (!get_godseekers())
	{
		enable_shadow_all();
	}

	if (g_pMenuHandle[id] != -1)
	{
		menu_destroy(g_pMenuHandle[id]);
		g_pMenuHandle[id] = -1;
		show_menu(id, 0, "^n", 0);
	}

	
	set_entvar(id, var_takedamage, DAMAGE_YES);
	rg_reset_user_model(id, true); 
}

public print_bad_users(id)
{
	for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (is_user_connected(iPlayer) && g_bGodSeekerActivated[iPlayer])
		{
			for(new pid = 1; pid <= MaxClients;pid++)
			{
				if (iPlayer != pid && !g_bIsUserBot[pid])
				{
					if (g_iBadClients[pid] == BAD_STATE_PENDING)
					{
						client_print_color(iPlayer, print_team_blue, "^1[^4%s^1]^3 Игpoк %s мoжeт видeть вac в peжимe ^"ПРОЗРАЧНАЯ МОДЕЛЬ^"",PLUGIN, g_sPlayerUsernames[pid]);
					}
					else if (g_iBadClients[pid] == BAD_STATE_SOFWARE)
					{
						client_print_color(iPlayer, print_team_blue, "^1[^4%s^1]^3 Игpoк %s может слегка видeть вac в peжимe ^"НЕВИДИМОСТЬ 1 и 2^"",PLUGIN, g_sPlayerUsernames[pid]);
					}
				}
			}
		}
	}
}

public d_subdiv16_callback(id, const cvar[], const value[])
{
	if (is_user_connected(id))
	{
		if(equal(value, "Bad CVAR request"))
		{
			g_iBadClients[id] = BAD_STATE_MINMODELS;
			return;
		}
#if !defined(ALLOW_SOFTWARE_MODE)
		rh_drop_client(id, "Software mode");
#endif
		g_iBadClients[id] = BAD_STATE_SOFWARE;
	}
}

public cl_minmodels_callback(id, const cvar[], const value[])
{
	if (is_user_connected(id) && g_iBadClients[id] == BAD_STATE_MINMODELS)
	{
		if(equal(value, "Bad CVAR request"))
		{
			g_iBadClients[id] = BAD_STATE_PENDING;
			return;
		}
		if (strtof(value) == 0.0)
		{
			g_iBadClients[id] = BAD_STATE_NONE;
		}
		else 
		{
			g_iBadClients[id] = BAD_STATE_MINMODELS;
		}
	}
}

public CBasePlayer_PreThink(id)
{
	if (id > MaxClients || g_bIsUserBot[id])
		return HC_CONTINUE;
	
	new btn = get_entvar(id,var_button);
	if(g_bGodSeekerActivated[id])
	{
		if (g_bGodSeekerTeleport[id])
		{
			new iActiveItem = get_member(id, m_pActiveItem);
			if(!iActiveItem || is_nullent(iActiveItem))
			{
				return HC_CONTINUE;
			}

			new btnold = get_entvar(id,var_oldbuttons);
			if(btn & IN_ATTACK || btn & IN_ATTACK2)
			{
				if ((btn & IN_ATTACK && btnold & IN_ATTACK == 0)
					|| (btn & IN_ATTACK2 && btnold & IN_ATTACK2 == 0))
				{
					if (is_bad_aiming(id))
					{
						client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Ты нe хoчeшь тудa тeлeпopтиpoвaтьcя!!",PLUGIN);
					}
					else 
					{
						static Float:TeleportPoint[3];
						if (get_teleport_point(id,TeleportPoint))
						{
							teleportPlayer(id,TeleportPoint);
							client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Ты пepeмecтилcя к цeли!",PLUGIN);
						}
						else 
						{
							client_print_color(id, print_team_blue, "^1[^4%s^1]^3 Ты нe хoчeшь тудa тeлeпopтиpoвaтьcя!!",PLUGIN);
						}
					}
				}
				set_member(id, m_flNextAttack, 0.35);
				set_member(iActiveItem, m_Weapon_flNextSecondaryAttack, 0.35);
				set_member(iActiveItem, m_Weapon_flNextPrimaryAttack, 0.35);
			}
		}
	}
	else if (btn & IN_ATTACK == 0)
	{
		g_iPlayerAttack[id] = 0;
	}
	
	return HC_CONTINUE;
}

public Player_Spawn_Post(id)
{
	if (g_bGodSeekerActivated[id])
	{
		disable_god_seeker(id);
	}
	
	return HC_CONTINUE;
}

public Player_Killed_Post(const id, pevAttacker, iGib)
{
	new numTeam1 = 0;
	new numTeam2 = 0;

	for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (iPlayer != id && is_user_connected(iPlayer))
		{
			if (g_bGodSeekerActivated[iPlayer])
				continue;

			if (!is_user_alive(iPlayer))
				continue;

			if (get_member(iPlayer, m_iTeam) == TEAM_CT)
				numTeam1++;
			else if (get_member(iPlayer, m_iTeam) == TEAM_TERRORIST)
				numTeam2++;
		}
	}

	if (numTeam1 == 0 || numTeam2 == 0)
	{
		for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (g_bGodSeekerActivated[iPlayer])
			{
				disable_god_seeker(iPlayer);
				client_print_color(iPlayer, print_team_blue, "^1[^4%s^1]^3 Недостаточно игроков!",PLUGIN);
			}
		}
	}

	if (g_bGodSeekerActivated[id])
	{
		disable_god_seeker(id);
	}
	
	return HC_CONTINUE;
}

public CBasePlayer_Observer_IsValidTarget(const id, iPlayerIndex, bool:bSameTeam)
{
	if (g_bGodSeekerActivated[iPlayerIndex])
	{
		SetHookChainArg(2, ATYPE_INTEGER, 0);
	}
	return HC_CONTINUE;
}

public AddToFullPack_Post(es_handle, e, ent, host, hostflags, bool:player, pSet) 
{
	if(!player || host > MaxClients || ent > MaxClients || !g_bGodSeekerActivated[ent])
		return;

	if (g_iGodSeekerInvisMode[ent] == 5)
	{
		new effects = get_es(es_handle, ES_Effects);
		if (effects & EF_NODRAW == 0)
			set_es(es_handle, ES_Effects, effects | EF_NODRAW);
	}
	else if (g_iGodSeekerInvisMode[ent] == 4)
	{
		set_es(es_handle, ES_RenderMode, kRenderTransTexture);
		set_es(es_handle, ES_RenderAmt, 0);
		set_es(es_handle, ES_RenderColor, {1,1,1});
	}
	else if (g_iGodSeekerInvisMode[ent] == 3)
	{
		set_es(es_handle, ES_RenderMode, kRenderTransColor);
		set_es(es_handle, ES_RenderAmt, 1);
		set_es(es_handle, ES_RenderColor, {1,1,1});
	}
	else if (g_iGodSeekerInvisMode[ent] == 2)
	{
		set_es(es_handle, ES_RenderMode, kRenderTransTexture);
		set_es(es_handle, ES_RenderAmt, 1);
		set_es(es_handle, ES_RenderColor, {255,255,255});
	}
	else if (g_iGodSeekerInvisMode[ent] == 1)
	{
		if (g_iBadClients[host] > 0)
		{
			set_es(es_handle, ES_RenderMode, kRenderTransTexture);
			set_es(es_handle, ES_RenderAmt, 0);
			set_es(es_handle, ES_RenderColor, {1,1,1});
		}
		else 
		{
			set_es(es_handle, ES_WeaponModel, 0);
		}
	}
}

public CSGameRules_FPlayerCanTakeDmg(const pPlayer, const pAttacker)
{
	if(pAttacker > MaxClients || pAttacker == 0)
	{
		SetHookChainReturn(ATYPE_INTEGER, false);
		return HC_SUPERCEDE;
	}

	if(g_bGodSeekerActivated[pPlayer] && g_bGodSeekerDisableDamage[pPlayer])
	{
		if (pPlayer != pAttacker && g_iPlayerAttack[pAttacker] != pPlayer && !g_bIsUserBot[pAttacker])
		{
			client_print_color(pPlayer, print_team_blue, "^1[^4%s^1]^3 Игрок ^4%s^3 [^1%s^3] атакует тебя!",PLUGIN, g_sPlayerUsernames[pAttacker], g_sPlayerSteamIDs[pAttacker]);
			g_iPlayerAttack[pAttacker] = pPlayer;
		}
		SetHookChainReturn(ATYPE_INTEGER, false);
		return HC_SUPERCEDE;
	}
	else 
	{
		g_iPlayerAttack[pAttacker] = pPlayer;
		return HC_CONTINUE;
	}
}

public SV_StartSound_Pre(const iRecipients, const iEntity, const iChannel, const szSample[], const flVolume, Float:flAttenuation, const fFlags, const iPitch)
{
	if (iEntity > 0 && iEntity <= MaxClients && g_bGodSeekerActivated[iEntity] && g_bGodSeekerDisableSounds[iEntity])
	{
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public PlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha, Float:color[3])
{
	if (is_user_alive(index) && g_bGodSeekerActivated[index])
	{	
		client_print_color(index, print_team_blue, "^1[^4%s^1]^3 Ты в peжимe ^4GOD SEEKER^3 пo этoму тeбя нe ocлeпилo!",PLUGIN);
		set_member(index, m_blindAlpha, 0);
		set_member(index, m_blindStartTime, 0.0);
		set_member(index, m_blindHoldTime, 0.0);
		SetHookChainArg(4, ATYPE_FLOAT, 0.5);
		SetHookChainArg(5, ATYPE_FLOAT, 0.5);
		SetHookChainArg(6, ATYPE_INTEGER, 80);
		color[0] = 255.0;
		color[1] = 255.0;
		color[2] = 0.0;
	}
	return HC_CONTINUE;
}

public message_statusvalue(msg_id, msg_dest, id)
{
	if (id > MaxClients || g_bIsUserBot[id])
		return;

	new targetid = get_msg_arg_int(2);
	if (get_msg_arg_int(1) == 2 && g_bGodSeekerActivated[targetid] && g_bGodSeekerDisableUsername[targetid])
	{
		set_msg_arg_int(1, get_msg_argtype(1), 1);
		set_msg_arg_int(2, get_msg_argtype(2), 0);
		if (g_iPlayerAim[id] != targetid)
		{
			client_print_color(targetid, print_team_blue, "^1[^4%s^1]^3 Игрок ^4%s^3 [^1%s^3] прицелился в тебя!", PLUGIN, g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);
			g_iPlayerAim[id] = targetid;
		}
	}
	else 
	{
		g_iPlayerAim[id] = 0;
	}
}

public get_godseekers()
{
	new godseekers = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(g_bGodSeekerActivated[i])
		{
			godseekers++;
		}
	}

	return godseekers;
}

public enable_shadow(id, bool:enable)
{
	message_begin(MSG_ONE, g_iMsgShadow, _, id);
	write_long(enable ? g_iShadowSprite : 0);
	message_end();
}

public disable_shadow_all()
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if (!g_bIsUserBot[id] && is_user_connected(id))
			enable_shadow(id, false);
	}
	set_msg_block(g_iMsgShadow, BLOCK_SET);
}

public enable_shadow_all()
{
	set_msg_block(g_iMsgShadow, BLOCK_NOT);
	for(new id = 1; id <= MaxClients; id++)
	{
		if (!g_bIsUserBot[id] && is_user_connected(id))
			enable_shadow(id, true);
	}
}

stock teleportPlayer(id, Float:TeleportPoint[3])
{
	new Float:pOrigin[3];
	get_entvar(id, var_origin, pOrigin);
	set_entvar(id, var_origin, TeleportPoint);
	new Float:pLook[3];
	get_entvar(id, var_angles, pLook);
	pLook[1]+=180.0;
	set_entvar(id, var_angles, pLook);
	set_entvar(id, var_fixangle, 1);
	set_entvar(id, var_velocity,Float:{0.0,0.0,0.0});
	unstuck_player(id);
}

stock bool:get_teleport_point(iPlayer, Float:newTeleportPoint[3])
{
	new iEyesOrigin[ 3 ];
	get_user_origin(iPlayer, iEyesOrigin, Origin_Eyes);
	
	new iEyesEndOrigin[ 3 ];
	get_user_origin(iPlayer, iEyesEndOrigin, Origin_AimEndEyes);
	
	new Float:vecEyesOrigin[ 3 ];
	IVecFVec(iEyesOrigin, vecEyesOrigin);
	
	new Float:vecEyesEndOrigin[ 3 ];
	IVecFVec(iEyesEndOrigin, vecEyesEndOrigin);
	
	new maxDistance = get_distance(iEyesOrigin,iEyesEndOrigin);
	if (maxDistance < 24)
	{
		return false;
	}
	
	new Float:vecDirection[ 3 ];
	velocity_by_aim(iPlayer, 24, vecDirection);
	
	new Float:vecAimOrigin[ 3 ];
	xs_vec_add(vecEyesOrigin, vecDirection, vecAimOrigin);

	xs_vec_copy(vecEyesOrigin, newTeleportPoint);
	
	new i = 24;
	while (i <= maxDistance) 
	{
		xs_vec_add(vecAimOrigin, vecDirection, vecAimOrigin);
		if(!is_hull_vacant(iPlayer, vecAimOrigin, HULL_HEAD, g_pCommonTr))
		{
			return true;
		}
		xs_vec_copy(vecAimOrigin, newTeleportPoint);
		i+=24
	}
	return false;
}


#define TSC_Vector_MA(%1,%2,%3,%4)	(%4[0] = %2[0] * %3 + %1[0], %4[1] = %2[1] * %3 + %1[1])

stock bool:is_hull_vacant(id, Float:origin[3], iHull, g_pCommonTr)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, iHull, id, g_pCommonTr);
	
	if (!get_tr2(g_pCommonTr, TR_StartSolid) && !get_tr2(g_pCommonTr, TR_AllSolid) && get_tr2(g_pCommonTr, TR_InOpen))
		return true;
	
	return false;
}

stock bool:unstuck_player(id)
{
	new pCommonTr = create_tr2();
	new bool:bSuccess = false;
	new Float:Origin[3];
	get_entvar(id, var_origin, Origin);
	
	new iHull, iSpawnPoint, i;
	iHull = (get_entvar(id, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
	
	// fast unstuck 
	if(!is_hull_vacant(id,Origin,iHull, pCommonTr))
	{
		Origin[2] -= 64.0;
	}
	else
	{
		engfunc(EngFunc_SetOrigin, id, Origin);
		free_tr2(pCommonTr);
		return true;
	}
	if(!is_hull_vacant(id,Origin,iHull, pCommonTr))
	{
		Origin[2] += 128.0;
	}
	else
	{
		engfunc(EngFunc_SetOrigin, id, Origin);
		free_tr2(pCommonTr);
		return true;
	}
	
	if(!is_hull_vacant(id,Origin,iHull, pCommonTr))
	{
		new const Float:RANDOM_OWN_PLACE[][3] =
		{
			{ -96.5,   0.0, 0.0 },
			{  96.5,   0.0, 0.0 },
			{   0.0, -96.5, 0.0 },
			{   0.0,  96.5, 0.0 },
			{ -96.5, -96.5, 0.0 },
			{ -96.5,  96.5, 0.0 },
			{  96.5,  96.5, 0.0 },
			{  96.5, -96.5, 0.0 }
		};
		
		new Float:flOrigin[3], Float:flOriginFinal[3], iSize;
		get_entvar(id, var_origin, flOrigin);
		iSize = sizeof(RANDOM_OWN_PLACE);
		
		iSpawnPoint = random_num(0, iSize - 1);
		
		for (i = iSpawnPoint + 1; /*no condition*/; i++)
		{
			if (i >= iSize)
				i = 0;
			
			flOriginFinal[0] = flOrigin[0] + RANDOM_OWN_PLACE[i][0];
			flOriginFinal[1] = flOrigin[1] + RANDOM_OWN_PLACE[i][1];
			flOriginFinal[2] = flOrigin[2];
			
			engfunc(EngFunc_TraceLine, flOrigin, flOriginFinal, IGNORE_MONSTERS, id, 0);
			
			new Float:flFraction;
			get_tr2(0, TR_flFraction, flFraction);
			if (flFraction < 1.0)
			{
				new Float:vTraceEnd[3], Float:vNormal[3];
				get_tr2(0, TR_vecEndPos, vTraceEnd);
				get_tr2(0, TR_vecPlaneNormal, vNormal);
				
				TSC_Vector_MA(vTraceEnd, vNormal, 32.5, flOriginFinal);
			}
			flOriginFinal[2] -= 35.0;
			
			new iZ = 0;
			do
			{
				if (is_hull_vacant(id, flOriginFinal, iHull, pCommonTr))
				{
					i = iSpawnPoint;
					engfunc(EngFunc_SetOrigin, id, flOriginFinal);
					bSuccess = true;
					break;
				}
				
				flOriginFinal[2] += 40.0;
			}
			while (++iZ <= 2)
			
			if (i == iSpawnPoint)
				break;
		}
	}
	else
	{
		engfunc(EngFunc_SetOrigin, id, Origin);
		free_tr2(pCommonTr);
		return true;
	}
	
	free_tr2(pCommonTr);
	return bSuccess;
}



stock bool:is_bad_aiming(id)
{
	new target[3]
	new Float:target_flt[3]

	get_user_origin(id, target, 3);
	
	IVecFVec(target,target_flt);

	if(engfunc(EngFunc_PointContents,target_flt) == CONTENTS_SKY)
		return true

	return false
}