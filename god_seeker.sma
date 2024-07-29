#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <xs>

#define PLUGIN "God Seeker"
#define VERSION "2.0"
#define AUTHOR "karaulov"

#define ADMIN_ACCESS_LEVEL ADMIN_ALL

new const INVISIBLED_MODEL_PATH[] = "models/player/gsfp_vip/gsfp_vip.mdl";
new const INVISIBLED_MODEL_NAME[] = "gsfp_vip";


new bool:g_bGodSeekerActivated[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerDisableSounds[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerDisableUsername[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerDisableDamage[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerKnifeTeleport[MAX_PLAYERS + 1] = false;
new bool:g_bBlockShadowMsg = false;

new g_pCommonTr;

//new g_iModelInvis = 0;
new g_iMsgShadow;
new g_iShadowSprite;
new g_iBadClients[MAX_PLAYERS + 1] = {0, ...};
new g_iGodSeekerInvisMode[MAX_PLAYERS + 1] = 0;

new Float:g_fLastUpdateMinModels[MAX_PLAYERS + 1] = {0.0, ...};

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
	RegisterHookChain(RH_SV_StartSound, "SV_StartSound_Pre");
	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "AddItem");
	RegisterHookChain(RG_BuyWeaponByWeaponID, "BuyWeaponByWeaponID");
	RegisterHookChain(RG_PlayerBlind, "PlayerBlind");
	RegisterHookChain(RG_CBasePlayer_Spawn, "Player_Spawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_PostThink, "CBasePlayer_PostThink_Post", .post = true);

	register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
	register_message(get_user_msgid("StatusValue"), "message_statusvalue");

	g_iMsgShadow = get_user_msgid("ShadowIdx");

	g_pCommonTr = create_tr2();
}

public plugin_end()
{
	free_tr2(g_pCommonTr);
}

public enable_shadow(id)
{
	if (g_bBlockShadowMsg)
	{
		set_msg_block(g_iMsgShadow, BLOCK_NOT);
	}
	message_begin(MSG_ONE_UNRELIABLE, g_iMsgShadow, _, id);
	write_long(g_iShadowSprite);
	message_end();
	if (g_bBlockShadowMsg)
	{
		set_msg_block(g_iMsgShadow, BLOCK_SET);
	}
}

public disable_shadow(id)
{ 
	if (g_bBlockShadowMsg)
	{
		set_msg_block(g_iMsgShadow, BLOCK_NOT);
	}
	message_begin ( MSG_ONE_UNRELIABLE, g_iMsgShadow, _, id );
	write_long ( 0 );
	message_end ();
	if (g_bBlockShadowMsg)
	{
		set_msg_block(g_iMsgShadow, BLOCK_SET);
	}
}

public disable_shadow_all()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if (is_user_connected(i))
			disable_shadow(i);
	}
}

public enable_shadow_all()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if (is_user_connected(i))
			enable_shadow(i);
	}
}

public plugin_precache( )
{
	g_iShadowSprite = precache_model("sprites/shadow_circle.spr");
	/*g_iModelInvis = */
	precache_model(INVISIBLED_MODEL_PATH);
}


public show_seeker_menu(id)
{
	if (ADMIN_ACCESS_LEVEL != ADMIN_ALL && get_user_flags(id) & ADMIN_ACCESS_LEVEL == 0)
	{
		return PLUGIN_CONTINUE;
	}

	if (!g_bGodSeekerActivated[id])
	{
		client_print(id, print_chat, "Рeжим God Seeker oтключeн.");
		return PLUGIN_HANDLED;
	}
	
	new tmpmenuitem[128];
	
	format(tmpmenuitem,127,"[God Seeker] Нacтpoйкa aнтивх:");
		
	new vmenu = menu_create(tmpmenuitem, "seeker_menu")

	format(tmpmenuitem,127,"\wНeвидимocть [\r%s\w]", 
	g_iGodSeekerInvisMode[id] == 0 ? "ОТКЛЮЧЕНА" :
	(g_iGodSeekerInvisMode[id] == 1 ? "НЕВИДИМОСТЬ 1" : 
	(g_iGodSeekerInvisMode[id] == 2 ? "НЕВИДИМОСТЬ 2" : 
	(g_iGodSeekerInvisMode[id] == 3 ? "НЕВИДИМОСТЬ 3" : 
	(g_iGodSeekerInvisMode[id] == 4 ? "НЕВИДИМОСТЬ 4" : 
	(g_iGodSeekerInvisMode[id] == 5 ? "ПРОЗРАЧНАЯ МОДЕЛЬ" 
	: "ОТКЛЮЧЕНА" ))))));
	menu_additem(vmenu, tmpmenuitem,"1")
	format(tmpmenuitem,127,"\wЗвуки [\r%s\w]", g_bGodSeekerDisableSounds[id] ? "НЕ СЛЫШНЫ" : "СЛЫШНЫ");
	menu_additem(vmenu, tmpmenuitem,"2")
	format(tmpmenuitem,127,"\wНикнeйм [\r%s\w]", g_bGodSeekerDisableUsername[id] ? "НЕВИДИМЫЙ" : "ОТОБРАЖАТЬ");
	menu_additem(vmenu, tmpmenuitem,"3")
	format(tmpmenuitem,127,"\wУpoн [\r%s\w]", g_bGodSeekerDisableDamage[id] ? "БЕССМЕРТНЫЙ" : "ПОЛУЧАТЬ");
	menu_additem(vmenu, tmpmenuitem,"4")
	format(tmpmenuitem,127,"\wТeлeпopт нoжoм [\r%s\w]", g_bGodSeekerKnifeTeleport[id] ? "АКТИВИРОВАН" : "ОТКЛЮЧЕН");
	menu_additem(vmenu, tmpmenuitem,"5")
	format(tmpmenuitem,127,"\wВыключить");
	menu_additem(vmenu, tmpmenuitem,"6")


	
	menu_setprop(vmenu, MPROP_NEXTNAME, "\yСлeдующий cпиcoк")
	menu_setprop(vmenu, MPROP_BACKNAME, "\yПpeдыдущий cпиcoк")
	menu_setprop(vmenu, MPROP_EXITNAME, "\rВыйти из God Seeker мeню")
	menu_setprop(vmenu, MPROP_EXIT,MEXIT_ALL)
	
		
	menu_display(id,vmenu,0)
	return PLUGIN_HANDLED
}

public seeker_menu(id, vmenu, item) 
{
	if(item == MENU_EXIT || !is_user_connected(id) || !is_user_alive(id)) 
	{
		menu_destroy(vmenu)
		return PLUGIN_HANDLED
	}
	
	new data[6], iName[64], access, callback
	menu_item_getinfo(vmenu, item, access, data, 5, iName, 63, callback)
	     
	new key = str_to_num(data)
	switch(key) 
	{	
		case 1:
		{
			rg_remove_all_items(id);
			rg_reset_user_model(id, true);
			if (g_iGodSeekerInvisMode[id] == 1)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 2! Внимание тебя видно в дыму!")
				
				rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 1)
				g_iGodSeekerInvisMode[id] = 2;
				rg_give_item(id, "weapon_knife");
			}
			else if (g_iGodSeekerInvisMode[id] == 2)
			{	
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 3!")
				
				rg_set_rendering(id, kRenderFxNone, 1, 1, 1, kRenderTransTexture, 1)
				g_iGodSeekerInvisMode[id] = 3;
				rg_give_item(id, "weapon_knife");
			}
			else if (g_iGodSeekerInvisMode[id] == 3)
			{
				rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 4!")
				g_iGodSeekerInvisMode[id] = 4;
				rg_give_item(id, "weapon_knife");
			}
			else if (g_iGodSeekerInvisMode[id] == 4)
			{
				rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
				rg_set_user_model(id, INVISIBLED_MODEL_NAME, true);

				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 5!")
				g_iGodSeekerInvisMode[id] = 5;

				for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
				{
					if (is_user_connected(iPlayer) && floatabs(get_gametime() - g_fLastUpdateMinModels[iPlayer]) > 2.0)
					{
						g_iBadClients[iPlayer] = 2;
						query_client_cvar(iPlayer, "cl_minmodels", "cl_minmodels_callback");
						g_fLastUpdateMinModels[iPlayer] = get_gametime();
					}
				}
				
				remove_task(1);
				set_task(2.0, "print_bad_users", 1);
			}
			else if (g_iGodSeekerInvisMode[id] == 5)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти oтключeн!")
				rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
				g_iGodSeekerInvisMode[id] = 0;
				rg_give_item(id, "weapon_knife");
			}
			else 
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 1!")
				rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 0)
				g_iGodSeekerInvisMode[id] = 1;
				rg_give_item(id, "weapon_knife");
			}
			
			
			show_seeker_menu(id);
		}
		case 2:
		{
			g_bGodSeekerDisableSounds[id] = !g_bGodSeekerDisableSounds[id];
			show_seeker_menu(id);
		}
		case 3:
		{
			g_bGodSeekerDisableUsername[id] = !g_bGodSeekerDisableUsername[id];
			show_seeker_menu(id);
		}
		case 4:
		{
			g_bGodSeekerDisableDamage[id] = !g_bGodSeekerDisableDamage[id];
			show_seeker_menu(id);
		}
		case 5:
		{
			g_bGodSeekerKnifeTeleport[id] = !g_bGodSeekerKnifeTeleport[id];
			show_seeker_menu(id);
		}
		case 6:
		{
			disable_god_seeker(id);
			rg_give_item(id, "weapon_knife");
		}
	}
	menu_destroy(vmenu)
	return PLUGIN_HANDLED
}

public give_me_god(id)
{
	if (ADMIN_ACCESS_LEVEL == ADMIN_ALL || get_user_flags(id) & ADMIN_ACCESS_LEVEL)
	{
		if (!g_bGodSeekerActivated[id])
		{
			rg_remove_all_items(id);
			if (g_iGodSeekerInvisMode[id] != 5)
				rg_give_item(id, "weapon_knife");
			enable_god_seeker(id)
			
			g_bGodSeekerActivated[id] = true;
		}
		else 
		{
			disable_god_seeker(id);
			rg_give_item(id, "weapon_knife");

			g_bGodSeekerActivated[id] = false;
		}
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public enable_god_seeker(id)
{
	new username[MAX_NAME_LENGTH]
	get_user_name(id, username, charsmax(username))
	log_to_file( "god_seeker.log", "Админиcтpaтop %s aктивиpoвaл peжим God Seeker.", username )
	server_print("Админиcтpaтop %s aктивиpoвaл peжим God Seeker.", username)

	client_print(id, print_chat, "[God seeker] Тeпepь ты в peжимe God seeker. Нacтpoйки /godmenu");
	print_bad_users(0);

	set_msg_block(g_iMsgShadow, BLOCK_SET);
	disable_shadow_all();

	if (g_iGodSeekerInvisMode[id] == 0)
		g_iGodSeekerInvisMode[id] = 1;
}

public disable_god_seeker(id)
{
	if(is_user_connected(id))
	{
		rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
		if (g_bGodSeekerActivated[id])
		{
			client_print(id, print_chat, "Рeжим God Seeker oтключeн.");
		}
	}
	
	g_bGodSeekerActivated[id] = false;

	if (!get_godseekers())
	{
		g_bBlockShadowMsg = false;
		enable_shadow_all();
		set_msg_block(g_iMsgShadow, BLOCK_NOT);
	}
}

public client_putinserver(id)
{
	g_iBadClients[id] = 2;

	g_bGodSeekerActivated[id] = true;
	g_bGodSeekerKnifeTeleport[id] = true;
	g_bGodSeekerDisableDamage[id] = true;
	g_bGodSeekerDisableSounds[id] = true;
	g_bGodSeekerDisableUsername[id] = true;
	g_iGodSeekerInvisMode[id] = 1;

	if (g_bGodSeekerActivated[id])
		disable_god_seeker(id)
		
	if (!is_user_bot(id) && !is_user_hltv(id))
	{
		query_client_cvar(id, "cl_minmodels", "cl_minmodels_callback");
	}
}

public client_disconnected(id)
{
	g_iBadClients[id] = 0;

	if (g_bGodSeekerActivated[id])
		disable_god_seeker(id)
}

public print_bad_users(id)
{
	for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (is_user_connected(iPlayer) && g_bGodSeekerActivated[iPlayer])
		{
			for(new pid = 1; pid <= MaxClients;pid++)
			{
				if (iPlayer != pid && is_user_connected(pid) && g_iBadClients[pid] > 0)
				{
					new name[MAX_NAME_LENGTH];
					get_user_name(pid,name,charsmax(name))
					client_print(iPlayer,print_console, "[God seeker] Игpoк %s мoжeт видeть вac в peжимe ^"ПРОЗРАЧНАЯ МОДЕЛЬ^"",name);
					client_print(iPlayer,print_chat, "[God seeker] Игpoк %s мoжeт видeть вac в peжимe ^"ПРОЗРАЧНАЯ МОДЕЛЬ^"",name);
				}
			}
		}
	}
}

public cl_minmodels_callback(id, const cvar[], const value[])
{
	if (is_user_connected(id))
	{
		if(equal(value, "Bad CVAR request"))
		{
			g_iBadClients[id] = 2;
			return;
		}
		if (strtof(value) == 0.0)
		{
			g_iBadClients[id] = 0;
		}
		else 
		{
			g_iBadClients[id] = 1;
		}
	}
}

public CBasePlayer_PreThink_Post(id)
{
	if(g_bGodSeekerActivated[id] && g_bGodSeekerKnifeTeleport[id])
	{
		new g_Flags = get_entvar(id,var_button);
		if(g_Flags & IN_ATTACK && get_user_weapon(id) == CSW_KNIFE)
		{
			if (is_bad_aiming(id))
			{
				client_print(id,print_chat, "[God seeker] Ты нe хoчeшь тудa тeлeпopтиpoвaтьcя!!");
			}
			else 
			{
				new Float:TeleportPoint[3];
				if (get_teleport_point(id,TeleportPoint))
				{
					teleportPlayer(id,TeleportPoint);
					client_print(id,print_chat, "[God seeker] Ты пepeмecтилcя к цeли!");
				}
				else 
				{
					client_print(id,print_chat, "[God seeker] Ты нe хoчeшь тудa тeлeпopтиpoвaтьcя!!");
				}
			}
			g_bGodSeekerKnifeTeleport[id] = false;
			set_task(0.5,"reenable_teleport",id);
		}
	}
}

public CBasePlayer_PostThink_Post(id)
{
	// FIXME: ReSemiclip module/plugin fix but slowest...
	if (g_bGodSeekerActivated[id])
	{
		if (g_iGodSeekerInvisMode[id] == 1)
		{
			rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 0);
		}
		else if (g_iGodSeekerInvisMode[id] == 2)
		{
			rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 1);
		}
		else if (g_iGodSeekerInvisMode[id] == 3)
		{
			rg_set_rendering(id, kRenderFxNone, 1, 1, 1, kRenderTransTexture, 1);
		}
	}
}

public Player_Spawn_Post( id )
{
	if (is_user_alive(id))
	{
		rg_set_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
		if (get_godseekers())
			disable_shadow(id)
		if (g_bGodSeekerActivated[id])
		{
			rg_remove_all_items(id);
			
			if (g_iGodSeekerInvisMode[id] != 5)
			{
				rg_give_item(id, "weapon_knife");
			}
		}
	}
}

public AddToFullPack_Post(es_handle, e, ent, host, hostflags, bool:player, pSet) 
{
	if(!player || host > MaxClients || ent > MaxClients || !g_bGodSeekerActivated[ent] )
		return;
	
	if (g_iGodSeekerInvisMode[ent] == 5)
	{
		if (g_iBadClients[host] > 0)
		{
			set_es(es_handle, ES_RenderFx, kRenderFxNone);
			set_es(es_handle, ES_RenderMode, kRenderTransTexture);
			set_es(es_handle, ES_RenderAmt, 2);
			set_es(es_handle, ES_RenderColor, {1,1,1});
		}
		else 
		{
			set_es(es_handle, ES_RenderFx, kRenderFxNone);
			set_es(es_handle, ES_RenderMode, kRenderNormal);
			set_es(es_handle, ES_RenderAmt, 254);
			set_es(es_handle, ES_RenderColor, {254,254,254});
		}
	}
	else if (g_iGodSeekerInvisMode[ent] == 4)
	{
		new effects = get_es(es_handle, ES_Effects);
		if (effects & EF_NODRAW == 0)
			set_es(es_handle, ES_Effects, effects | EF_NODRAW);
	}
}

public CSGameRules_FPlayerCanTakeDmg(const pPlayer, const pAttacker)
{
	if(!is_user_connected(pAttacker))
		return HC_CONTINUE

	if(g_bGodSeekerActivated[pPlayer] && g_bGodSeekerDisableDamage[pPlayer])
	{
		SetHookChainReturn(ATYPE_INTEGER, false)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
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
		client_print_color(index, index, "^3Ты в peжимe ^4GOD SEEKER^3 пo этoму тeбя нe ocлeпилo!")
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
	return HC_CONTINUE
}

public AddItem(id, pItem)
{
	if (is_user_alive(id) && g_bGodSeekerActivated[id])
	{
		if ( get_member(pItem, m_iId) == WEAPON_KNIFE && g_iGodSeekerInvisMode[id] != 5)
		{
			return HC_CONTINUE;
		}
		SetHookChainReturn(ATYPE_INTEGER, 0);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public BuyWeaponByWeaponID(id, WeaponIdType:weaponID)
{
	if (is_user_alive(id) && g_bGodSeekerActivated[id])
	{
		SetHookChainArg(2,ATYPE_INTEGER,0)
		SetHookChainReturn(ATYPE_INTEGER,0)
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public reenable_teleport(id)
{
	if (g_bGodSeekerActivated[id])
		g_bGodSeekerKnifeTeleport[id] = true;
}

public message_statusvalue()
{
	new pid = get_msg_arg_int(2);
	if (get_msg_arg_int(1) == 2 && g_bGodSeekerActivated[pid] && g_bGodSeekerDisableUsername[pid])
	{
		set_msg_arg_int(1, get_msg_argtype(1), 1);
		set_msg_arg_int(2, get_msg_argtype(2), 0);
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
	unstuck_player( id );
}

stock bool:get_teleport_point(iPlayer, Float:newTeleportPoint[3])
{
	new iEyesOrigin[ 3 ];
	get_user_origin( iPlayer, iEyesOrigin, Origin_Eyes );
	
	new iEyesEndOrigin[ 3 ];
	get_user_origin( iPlayer, iEyesEndOrigin, Origin_AimEndEyes );
	
	new Float:vecEyesOrigin[ 3 ];
	IVecFVec( iEyesOrigin, vecEyesOrigin );
	
	new Float:vecEyesEndOrigin[ 3 ];
	IVecFVec( iEyesEndOrigin, vecEyesEndOrigin );
	
	new maxDistance = get_distance(iEyesOrigin,iEyesEndOrigin);
	if (maxDistance < 24)
	{
		return false;
	}
	
	new Float:vecDirection[ 3 ];
	velocity_by_aim( iPlayer, 24, vecDirection );
	
	new Float:vecAimOrigin[ 3 ];
	xs_vec_add( vecEyesOrigin, vecDirection, vecAimOrigin );

	xs_vec_copy(vecEyesOrigin, newTeleportPoint);
	
	new i = 24;
	while (i <= maxDistance) 
	{
		xs_vec_add( vecAimOrigin, vecDirection, vecAimOrigin );
		if(!is_hull_vacant(iPlayer, vecAimOrigin, HULL_HEAD, g_pCommonTr) )
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

stock rg_set_rendering(const id, const iRenderFx, const R, const G, const B, const iRenderMode, const iRenderAmount)
{
	if (is_nullent(id))
		return;

	new Float:flRenderColor[3];

	flRenderColor[0] = float(R);
	flRenderColor[1] = float(G);
	flRenderColor[2] = float(B);

	set_entvar(id, var_renderfx, iRenderFx);
	set_entvar(id, var_rendercolor, flRenderColor);
	set_entvar(id, var_rendermode, iRenderMode);
	set_entvar(id, var_renderamt, float(iRenderAmount));
}