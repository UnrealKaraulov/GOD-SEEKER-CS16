#include <amxmodx>
#include <engine>
#include <reapi>
#include <fakemeta>
#include <fun>
#include <hamsandwich>

// Если не используете то закомментировать! Но настоятельно рекомендую использовать именно эту функцию.
#tryinclude <custom_player_models>

#define ADMIN_ACCESS_LEVEL ADMIN_BAN

#define INVISIBLED_MODEL_PATH_CT "models/player/gsfp_vip/gsfp_vip.mdl"
#define INVISIBLED_MODEL_PATH_T "models/player/gsfp_vip/gsfp_vip.mdl"


new GOD_SEEKER_USERS = 0;
new GOD_SEEKER_DISABLE_VISIBILITY[MAX_PLAYERS + 1] = 0;
new bool:GOD_SEEKER_ENABLE[MAX_PLAYERS + 1] = false;
new bool:GOD_SEEKER_DISABLE_SOUNDS[MAX_PLAYERS + 1] = false;
new bool:GOD_SEEKER_DISABLE_AIMING[MAX_PLAYERS + 1] = false;
new bool:GOD_SEEKER_DISABLE_DAMAGE[MAX_PLAYERS + 1] = false;
new bool:GOD_SEEKER_ENABLE_TELEPORT[MAX_PLAYERS + 1] = false;
new bool:GOD_SEEKER_BAD_USERS[MAX_PLAYERS + 1] = {false, ...};


#define PLUGIN "God Seeker"
#define VERSION "1.7"
#define AUTHOR "karaulov"

new bool:g_MsgBlocked = false;
new g_MsgShadow
new g_iShadowSprite

new bool:g_bUsedCustomPlayerModelsApi = false;

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	//https://www.gametracker.com/search/?search_by=server_variable&search_by2=god_seeker&query=&loc=_all&sort=&order=
	//https://gs-monitor.com/?searchType=2&variableName=god_seeker&variableValue=&submit=&mode=
	create_cvar("god_seeker", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_clcmd("say /wh", "give_me_god")
	register_clcmd("say /god", "give_me_god")
	register_clcmd("say /antiwh", "give_me_god")
	register_clcmd("say /whmenu", "show_seeker_menu")
	register_clcmd("say /godmenu", "show_seeker_menu")
	
	RegisterHookChain(RG_CSGameRules_FPlayerCanTakeDamage, "CSGameRules_FPlayerCanTakeDmg", .post = false)
	RegisterHookChain(RH_SV_StartSound, "SV_StartSound_Pre");
	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "AddItem");
	RegisterHookChain(RG_BuyWeaponByWeaponID, "BuyWeaponByWeaponID");
	RegisterHookChain(RG_PlayerBlind, "PlayerBlind")
	
	register_message(get_user_msgid("StatusValue"), "message_statusvalue")
	RegisterHookChain(RG_CBasePlayer_Spawn, "Player_Spawn_Post", .post = true)
	
	g_MsgShadow = get_user_msgid ( "ShadowIdx" );
}

public AddToFullPack_Post(es_handle, e, ent, host, hostflags, bool: player, pSet) {
	if(!player || host > MAX_PLAYERS || ent > MAX_PLAYERS || GOD_SEEKER_DISABLE_VISIBILITY[ent] != 5 || !GOD_SEEKER_BAD_USERS[host] )
		return;
	
	set_es(es_handle, ES_RenderAmt, 1);
	set_es(es_handle, ES_RenderFx, kRenderFxNone);
	set_es(es_handle, ES_RenderMode, kRenderTransAlpha);
}

public PlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha, Float:color[3])
{
	if (is_user_alive(index) && GOD_SEEKER_ENABLE[index])
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
		//return HC_BREAK
	}
	return HC_CONTINUE
}

public AddItem(id, pItem)
{
	if (is_user_alive(id) && GOD_SEEKER_DISABLE_VISIBILITY[id] != 0)
	{
		if ( get_member(pItem, m_iId) == WEAPON_KNIFE && GOD_SEEKER_DISABLE_VISIBILITY[id] != 5)
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
	if (is_user_alive(id) && GOD_SEEKER_DISABLE_VISIBILITY[id] != 0)
	{
		SetHookChainArg(2,ATYPE_INTEGER,0)
		SetHookChainReturn(ATYPE_INTEGER,0)
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public enable_shadow(id)
{
	if (g_MsgBlocked)
	{
		set_msg_block(g_MsgShadow, BLOCK_NOT);
	}
	message_begin ( MSG_ONE_UNRELIABLE, g_MsgShadow, _, id );
	write_long ( g_iShadowSprite );
	message_end ();
	if (g_MsgBlocked)
	{
		set_msg_block(g_MsgShadow, BLOCK_SET);
	}
}

public disable_shadow(id)
{ 
	if (g_MsgBlocked)
	{
		set_msg_block(g_MsgShadow, BLOCK_NOT);
	}
	message_begin ( MSG_ONE_UNRELIABLE, g_MsgShadow, _, id );
	write_long ( 0 );
	message_end ();
	if (g_MsgBlocked)
	{
		set_msg_block(g_MsgShadow, BLOCK_SET);
	}
}

public disable_shadow_all()
{
	for(new i = 0; i < MAX_PLAYERS + 1;i++)
	{
		if (is_user_connected(i))
			disable_shadow(i);
	}
}

public enable_shadow_all()
{
	for(new i = 0; i < MAX_PLAYERS + 1;i++)
	{
		if (is_user_connected(i))
			enable_shadow(i);
	}
}

public plugin_precache( )
{
	g_iShadowSprite = precache_model("sprites/shadow_circle.spr");
	
#if defined _custom_player_models_included
	if (is_plugin_loaded("Custom Player Models API") && file_exists(INVISIBLED_MODEL_PATH_CT) && file_exists(INVISIBLED_MODEL_PATH_T))
	{
		g_bUsedCustomPlayerModelsApi = true;
		custom_player_models_register("invisibled_model",INVISIBLED_MODEL_PATH_T,0,INVISIBLED_MODEL_PATH_CT,0);
		register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
	}
#endif
}

public Player_Spawn_Post( id )
{
	if (is_user_alive(id))
	{
		set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
		if (GOD_SEEKER_USERS > 0)
			disable_shadow(id)
		if (GOD_SEEKER_ENABLE[id])
		{
			rg_remove_all_items(id);
			
#if defined _custom_player_models_included
			if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 5 && g_bUsedCustomPlayerModelsApi)
			{
				custom_player_models_set(id,"invisibled_model");
			}
			else 
#endif
			{
				rg_give_item(id, "weapon_knife");
			}
		}
	}
} 

public CSGameRules_FPlayerCanTakeDmg(const pPlayer, const pAttacker)
{
	if(!is_user_connected(pAttacker))
		return HC_CONTINUE

	if(GOD_SEEKER_DISABLE_DAMAGE[pPlayer])
	{
		SetHookChainReturn(ATYPE_INTEGER, false)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public show_seeker_menu(id)
{
	if (!GOD_SEEKER_ENABLE[id])
	{
		client_print(id, print_chat, "Рeжим God Seeker oтключeн.");
		return PLUGIN_HANDLED;
	}
	
	new tmpmenuitem[128];
	
	format(tmpmenuitem,127,"[God Seeker] Нacтpoйкa aнтивх:");
		
	new vmenu = menu_create(tmpmenuitem, "seeker_menu")

	format(tmpmenuitem,127,"\wНeвидимocть [\r%s\w]", 
	GOD_SEEKER_DISABLE_VISIBILITY[id] == 0 ? "ОТКЛЮЧЕНА" :
	(GOD_SEEKER_DISABLE_VISIBILITY[id] == 1 ? "НЕВИДИМОСТЬ 1" : 
	(GOD_SEEKER_DISABLE_VISIBILITY[id] == 2 ? "НЕВИДИМОСТЬ 2" : 
	(GOD_SEEKER_DISABLE_VISIBILITY[id] == 3 ? "НЕВИДИМОСТЬ 3" : 
	(GOD_SEEKER_DISABLE_VISIBILITY[id] == 4 ? "НЕВИДИМОСТЬ 4" : 
	(GOD_SEEKER_DISABLE_VISIBILITY[id] == 5 ? "ПРОЗРАЧНАЯ МОДЕЛЬ" 
	: "ОТКЛЮЧЕНА" ))))));
	menu_additem(vmenu, tmpmenuitem,"1")
	format(tmpmenuitem,127,"\wЗвуки [\r%s\w]", GOD_SEEKER_DISABLE_SOUNDS[id] ? "НЕ СЛЫШНЫ" : "СЛЫШНЫ");
	menu_additem(vmenu, tmpmenuitem,"2")
	format(tmpmenuitem,127,"\wНикнeйм [\r%s\w]", GOD_SEEKER_DISABLE_AIMING[id] ? "НЕВИДИМЫЙ" : "ОТОБРАЖАТЬ");
	menu_additem(vmenu, tmpmenuitem,"3")
	format(tmpmenuitem,127,"\wУpoн [\r%s\w]", GOD_SEEKER_DISABLE_DAMAGE[id] ? "БЕССМЕРТНЫЙ" : "ПОЛУЧАТЬ");
	menu_additem(vmenu, tmpmenuitem,"4")
	format(tmpmenuitem,127,"\wТeлeпopт нoжoм [\r%s\w]", GOD_SEEKER_ENABLE_TELEPORT[id] ? "АКТИВИРОВАН" : "ОТКЛЮЧЕН");
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
			if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 1)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 2! Внимание тебя видно в дыму!")
				
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 1)
				GOD_SEEKER_DISABLE_VISIBILITY[id] = 2;
				rg_give_item(id, "weapon_knife");
			}
			else if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 2)
			{	
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 3!")
				
				set_user_rendering(id, kRenderFxNone, 1, 1, 1, kRenderTransTexture, 1)
				GOD_SEEKER_DISABLE_VISIBILITY[id] = 3;
				rg_give_item(id, "weapon_knife");
			}
			else if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 3)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 4!")
				set_entity_visibility(id,0);
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
				GOD_SEEKER_DISABLE_VISIBILITY[id] = 4;
				rg_give_item(id, "weapon_knife");
			}
			else if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 4)
			{
				set_entity_visibility(id,1);
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)

#if defined _custom_player_models_included
				if (g_bUsedCustomPlayerModelsApi)
				{
					client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 5!")
					custom_player_models_set(id,"invisibled_model");
					GOD_SEEKER_DISABLE_VISIBILITY[id] = 5;
					print_bad_users();
					for(new i = 0; i < MAX_PLAYERS + 1;i++)
					{
						if (REU_GetProtocol(id) >= 48)
							query_client_cvar(id, "cl_minmodels", "cl_minmodels_callback");
					}
				}
				else 
#endif
				{
					client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти oтключeн!")
					GOD_SEEKER_DISABLE_VISIBILITY[id] = 0;
					rg_give_item(id, "weapon_knife");
				}
			}
			else if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 5)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти oтключeн!")
				
#if defined _custom_player_models_included
				if (g_bUsedCustomPlayerModelsApi)
				{
					if (custom_player_models_is_enable(id))
						custom_player_models_reset(id);
				}
#endif
				set_entity_visibility(id,1);
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
				GOD_SEEKER_DISABLE_VISIBILITY[id] = 0;
				rg_give_item(id, "weapon_knife");
			}
			else 
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 1!")
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 0)
				GOD_SEEKER_DISABLE_VISIBILITY[id] = 1;
				rg_give_item(id, "weapon_knife");
			}
			
			
			show_seeker_menu(id);
		}
		case 2:
		{
			GOD_SEEKER_DISABLE_SOUNDS[id] = !GOD_SEEKER_DISABLE_SOUNDS[id];
			show_seeker_menu(id);
		}
		case 3:
		{
			GOD_SEEKER_DISABLE_AIMING[id] = !GOD_SEEKER_DISABLE_AIMING[id];
			show_seeker_menu(id);
		}
		case 4:
		{
			GOD_SEEKER_DISABLE_DAMAGE[id] = !GOD_SEEKER_DISABLE_DAMAGE[id];
			show_seeker_menu(id);
		}
		case 5:
		{
			GOD_SEEKER_ENABLE_TELEPORT[id] = !GOD_SEEKER_ENABLE_TELEPORT[id];
			show_seeker_menu(id);
		}
		case 6:
		{
			if (GOD_SEEKER_ENABLE[id])
				disable_god_seeker(id);
		}
	}
	menu_destroy(vmenu)
	return PLUGIN_HANDLED
}

public give_me_god(id)
{
	if (get_user_flags(id) & ADMIN_ACCESS_LEVEL)
	{
		GOD_SEEKER_ENABLE[id] = !GOD_SEEKER_ENABLE[id];
		if (GOD_SEEKER_ENABLE[id])
		{
			rg_remove_all_items(id);
			rg_give_item(id, "weapon_knife");
			enable_god_seeker(id)
		}
		else 
		{
			disable_god_seeker(id)
		}
	}
}

public enable_god_seeker(id)
{
	new username[MAX_NAME_LENGTH]
	get_user_name(id, username, charsmax(username))
	log_to_file( "god_seeker.log", "Админиcтpaтop %s aктивиpoвaл peжим God Seeker.", username )
	if(is_user_connected(id))
	{
		client_print(id, print_chat, "[God seeker] Тeпepь ты в peжимe God seeker. Нacтpoйки /godmenu");
		print_bad_users();
	}
	if (GOD_SEEKER_USERS == 0)
	{
		g_MsgBlocked = true;
		set_msg_block(g_MsgShadow, BLOCK_SET);
		disable_shadow_all();
	}
	GOD_SEEKER_USERS++;
	GOD_SEEKER_ENABLE[id] = true;
	GOD_SEEKER_ENABLE_TELEPORT[id] = true;
	GOD_SEEKER_DISABLE_DAMAGE[id] = true;
	GOD_SEEKER_DISABLE_SOUNDS[id] = true;
	GOD_SEEKER_DISABLE_AIMING[id] = true;
	GOD_SEEKER_DISABLE_VISIBILITY[id] = 1;
}

public disable_god_seeker(id)
{
	if (GOD_SEEKER_USERS > 0)
	{
		g_MsgBlocked = false;
		enable_shadow_all();
		set_msg_block(g_MsgShadow, BLOCK_NOT);
	}
	GOD_SEEKER_USERS--;
	GOD_SEEKER_ENABLE[id] = false;
	GOD_SEEKER_ENABLE_TELEPORT[id] = false;
	GOD_SEEKER_DISABLE_DAMAGE[id] = false;
	GOD_SEEKER_DISABLE_SOUNDS[id] = false;
	GOD_SEEKER_DISABLE_AIMING[id] = false;
	GOD_SEEKER_DISABLE_VISIBILITY[id] = 0;
	set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
	set_entity_visibility(id,1);

#if defined _custom_player_models_included
	if (g_bUsedCustomPlayerModelsApi)
	{
		if (custom_player_models_is_enable(id))
			custom_player_models_reset(id);
	}
#endif
	if(is_user_connected(id))
		client_print(id, print_chat, "Рeжим God Seeker oтключeн.");
}

public print_bad_client(id, type)
{
	GOD_SEEKER_BAD_USERS[id] = true;
	
	for(new adminid = 0; adminid < MAX_PLAYERS + 1;adminid++)
	{
		if (GOD_SEEKER_ENABLE[adminid])
		{
			new name[MAX_NAME_LENGTH];
			get_user_name(id,name,charsmax(name))
			client_print(adminid,print_console, "[God seeker] Игpoк %s вoшeл %s",name, type == 1 ? "co cтapoгo клиeнтa" : "c cl_minmodels 1");
			client_print(adminid,print_chat, "[God seeker] Игpoк %s вoшeл %s",name, type == 1 ? "co cтapoгo клиeнтa" : "c cl_minmodels 1");
			client_print(adminid,print_chat, "[God seeker] И мoжeт видeть вac в peжимe ^"ПРОЗРАЧНАЯ МОДЕЛЬ^"");
		}
	}
}

public client_putinserver(id)
{
	GOD_SEEKER_BAD_USERS[id] = false;
	if (GOD_SEEKER_ENABLE[id])
		disable_god_seeker(id)

#if defined _custom_player_models_included		
	if (g_bUsedCustomPlayerModelsApi)
	{
		if (REU_GetProtocol(id) >= 48)
			query_client_cvar(id, "cl_minmodels", "cl_minmodels_callback");
		else 
			print_bad_client(id,1);
	}
#endif
}

public client_disconnected(id)
{
	GOD_SEEKER_BAD_USERS[id] = false;
}

public print_bad_users()
{
#if defined _custom_player_models_included
	if (g_bUsedCustomPlayerModelsApi)
	{
		for(new adminid = 0; adminid < MAX_PLAYERS + 1;adminid++)
		{
			if (GOD_SEEKER_ENABLE[adminid])
			{
				for(new pid = 0; pid < MAX_PLAYERS + 1;pid++)
				{
					if (is_user_connected(pid) && GOD_SEEKER_BAD_USERS[pid])
					{
						new name[MAX_NAME_LENGTH];
						get_user_name(pid,name,charsmax(name))
						client_print(adminid,print_console, "[God seeker] Игpoк %s мoжeт видeть вac в peжимe ^"ПРОЗРАЧНАЯ МОДЕЛЬ^"",name);
						client_print(adminid,print_chat, "[God seeker] Игpoк %s мoжeт видeть вac в peжимe ^"ПРОЗРАЧНАЯ МОДЕЛЬ^"",name);
					}
				}
			}
		}
	}
#endif
}

public cl_minmodels_callback(id, const cvar[], const value[])
{
	if (is_user_connected(id))
	{
		if(equal(value, "Bad CVAR request"))
			return;
		if (strtof(value) > 0)
		{
			print_bad_client(id,2);
		}
	}
}

public client_PreThink(id)
{
	if(GOD_SEEKER_ENABLE_TELEPORT[id])
	{
		new g_Flags = entity_get_int(id,EV_INT_button)
		if(g_Flags & IN_ATTACK && get_user_weapon(id) == CSW_KNIFE)
		{
			if (is_bad_aiming(id))
			{
				client_print(id,print_chat, "[God seeker] Ты нe хoчeшь тудa тeлeпopтиpoвaтьcя!!")
			}
			else 
			{
				teleportPlayer(id)
				client_print(id,print_chat, "[God seeker] Ты пepeмecтилcя к цeли!")
			}
			GOD_SEEKER_ENABLE_TELEPORT[id] = false;
			set_task(0.5,"reenable_teleport",id);
		}
	}
}
public client_PostThink(id)
{
	// FIXME: ReSemiclip module/plugin fix but slowest...
	if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 1)
	{
		set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 0)
	}
	else if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 2)
	{
		set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 1)
	}
	else if (GOD_SEEKER_DISABLE_VISIBILITY[id] == 3)
	{
		set_user_rendering(id, kRenderFxNone, 1, 1, 1, kRenderTransTexture, 1)
	}
}

public reenable_teleport(id)
{
	if (GOD_SEEKER_ENABLE[id])
		GOD_SEEKER_ENABLE_TELEPORT[id] = true;
}

public message_statusvalue()
{
	if (get_msg_arg_int(1) == 2 && GOD_SEEKER_DISABLE_AIMING[get_msg_arg_int(2)])
	{
		set_msg_arg_int(1, get_msg_argtype(1), 1)
		set_msg_arg_int(2, get_msg_argtype(2), 0)
	}
}

public SV_StartSound_Pre(const iRecipients, const iEntity, const iChannel, const szSample[], const flVolume, Float:flAttenuation, const fFlags, const iPitch)
{
	if (!iRecipients || !is_user_connected(iEntity) || !is_user_alive(iEntity))
		return HC_CONTINUE;
		
	if (GOD_SEEKER_DISABLE_SOUNDS[iEntity])
	{
		return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}

public teleportPlayer(id)
{
	new NewLocation[3];
	get_user_origin(id, NewLocation, 3);
	set_user_origin(id, NewLocation);
	new Float:pLook[3]
	entity_get_vector(id, EV_VEC_angles, pLook)
	pLook[1]+=float(180)
	entity_set_vector(id, EV_VEC_angles, pLook)
	entity_set_int(id, EV_INT_fixangle, 1)
	unstuckplayer( id )
	drop_to_floor( id )
}

#define TSC_Vector_MA(%1,%2,%3,%4)	(%4[0] = %2[0] * %3 + %1[0], %4[1] = %2[1] * %3 + %1[1])

stock is_player_stuck(id,Float:originF[3])
{
	engfunc(EngFunc_TraceHull, originF, originF, 0, (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0)
	
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return true
	
	return false
}


stock is_hull_vacant(Float:origin[3], hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true
	
	return false
}

public unstuckplayer(id)
{
	static Float:Origin[3]
	pev(id, pev_origin, Origin)
	static iHull, iSpawnPoint, i
	iHull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
	
	// fast unstuck 
	if(is_player_stuck(id,Origin))
	{
		Origin[2] -= 64.0
	}
	else
	{
		engfunc(EngFunc_SetOrigin, id, Origin)	
		return;
	}
	if(is_player_stuck(id,Origin))
	{
		Origin[2] += 128.0
	}
	else
	{
		engfunc(EngFunc_SetOrigin, id, Origin)	
		return;
	}
	
	// slow unstuck 
	if(is_player_stuck(id,Origin))
	{
		static const Float:RANDOM_OWN_PLACE[][3] =
		{
			{ -96.5,   0.0, 0.0 },
			{  96.5,   0.0, 0.0 },
			{   0.0, -96.5, 0.0 },
			{   0.0,  96.5, 0.0 },
			{ -96.5, -96.5, 0.0 },
			{ -96.5,  96.5, 0.0 },
			{  96.5,  96.5, 0.0 },
			{  96.5, -96.5, 0.0 }
		}
		
		new Float:flOrigin[3], Float:flOriginFinal[3], iSize
		pev(id, pev_origin, flOrigin)
		iSize = sizeof(RANDOM_OWN_PLACE)
		
		iSpawnPoint = random_num(0, iSize - 1)
		
		for (i = iSpawnPoint + 1; /*no condition*/; i++)
		{
			if (i >= iSize)
				i = 0
			
			flOriginFinal[0] = flOrigin[0] + RANDOM_OWN_PLACE[i][0]
			flOriginFinal[1] = flOrigin[1] + RANDOM_OWN_PLACE[i][1]
			flOriginFinal[2] = flOrigin[2]
			
			engfunc(EngFunc_TraceLine, flOrigin, flOriginFinal, IGNORE_MONSTERS, id, 0)
			
			new Float:flFraction
			get_tr2(0, TR_flFraction, flFraction)
			if (flFraction < 1.0)
			{
				new Float:vTraceEnd[3], Float:vNormal[3]
				get_tr2(0, TR_vecEndPos, vTraceEnd)
				get_tr2(0, TR_vecPlaneNormal, vNormal)
				
				TSC_Vector_MA(vTraceEnd, vNormal, 32.5, flOriginFinal)
			}
			flOriginFinal[2] -= 35.0
			
			new iZ = 0
			do
			{
				if (is_hull_vacant(flOriginFinal, iHull))
				{
					i = iSpawnPoint
					engfunc(EngFunc_SetOrigin, id, flOriginFinal)
					break
				}
				
				flOriginFinal[2] += 40.0
			}
			while (++iZ <= 2)
			
			if (i == iSpawnPoint)
				break
		}
	}
	else
	{
		engfunc(EngFunc_SetOrigin, id, Origin)	
	}
}

public bool:is_bad_aiming(id)
{
	new target[3]
	new Float:target_flt[3]

	get_user_origin(id, target, 3);
	
	IVecFVec(target,target_flt);

	if(engfunc(EngFunc_PointContents,target_flt) == CONTENTS_SKY)
		return true

	return false
}