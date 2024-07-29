#include <amxmodx>
#include <engine>
#include <reapi>
#include <fakemeta>
#include <fun>
#include <hamsandwich>

#define PLUGIN "God Seeker"
#define VERSION "2.0"
#define AUTHOR "karaulov"

#define ADMIN_ACCESS_LEVEL ADMIN_ALL

#define INVISIBLED_MODEL_PATH "models/player/gsfp_vip/gsfp_vip.mdl"

new g_iModelInvis = 0;
new g_iMsgShadow;
new g_iShadowSprite;
new g_iGodSeekerUsers = 0;
new g_iGodSeekerInvisMode[MAX_PLAYERS + 1] = 0;

new bool:g_bGodSeekerActivated[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerDisableSounds[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerDisableUsername[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerDisableDamage[MAX_PLAYERS + 1] = false;
new bool:g_bGodSeekerKnifeTeleport[MAX_PLAYERS + 1] = false;
new bool:g_bBadClients[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bBlockShadowMsg = false;


public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
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
	
	g_iMsgShadow = get_user_msgid ( "ShadowIdx" );
}

public AddToFullPack_Post(es_handle, e, ent, host, hostflags, bool: player, pSet) 
{
	if(!player || host > MaxClients || ent > MaxClients || g_iGodSeekerInvisMode[ent] != 5 || !g_bBadClients[host] )
		return;
	
	set_es(es_handle, ES_RenderAmt, 1);
	set_es(es_handle, ES_RenderFx, kRenderFxNone);
	set_es(es_handle, ES_RenderMode, kRenderTransAlpha);

	set_es(es_handle, ES_ModelIndex, g_iModelInvis);
	set_es(es_handle, ES_Body, 0);
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
	if (is_user_alive(id) && g_iGodSeekerInvisMode[id] != 0)
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
	if (is_user_alive(id) && g_iGodSeekerInvisMode[id] != 0)
	{
		SetHookChainArg(2,ATYPE_INTEGER,0)
		SetHookChainReturn(ATYPE_INTEGER,0)
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public enable_shadow(id)
{
	if (g_bBlockShadowMsg)
	{
		set_msg_block(g_iMsgShadow, BLOCK_NOT);
	}
	message_begin ( MSG_ONE_UNRELIABLE, g_iMsgShadow, _, id );
	write_long ( g_iShadowSprite );
	message_end ();
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
	for(new i = 0; i <= MaxClients; i++)
	{
		if (is_user_connected(i))
			disable_shadow(i);
	}
}

public enable_shadow_all()
{
	for(new i = 0; i <= MaxClients; i++)
	{
		if (is_user_connected(i))
			enable_shadow(i);
	}
}

public plugin_precache( )
{
	g_iShadowSprite = precache_model("sprites/shadow_circle.spr");
	g_iModelInvis = precache_model(INVISIBLED_MODEL_PATH);
	register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
}

public Player_Spawn_Post( id )
{
	if (is_user_alive(id))
	{
		set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
		if (g_iGodSeekerUsers > 0)
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

public CSGameRules_FPlayerCanTakeDmg(const pPlayer, const pAttacker)
{
	if(!is_user_connected(pAttacker))
		return HC_CONTINUE

	if(g_bGodSeekerDisableDamage[pPlayer])
	{
		SetHookChainReturn(ATYPE_INTEGER, false)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public show_seeker_menu(id)
{
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
			if (g_iGodSeekerInvisMode[id] == 1)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 2! Внимание тебя видно в дыму!")
				
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 1)
				g_iGodSeekerInvisMode[id] = 2;
				rg_give_item(id, "weapon_knife");
			}
			else if (g_iGodSeekerInvisMode[id] == 2)
			{	
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 3!")
				
				set_user_rendering(id, kRenderFxNone, 1, 1, 1, kRenderTransTexture, 1)
				g_iGodSeekerInvisMode[id] = 3;
				rg_give_item(id, "weapon_knife");
			}
			else if (g_iGodSeekerInvisMode[id] == 3)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 4!")
				set_entity_visibility(id,0);
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
				g_iGodSeekerInvisMode[id] = 4;
				rg_give_item(id, "weapon_knife");
			}
			else if (g_iGodSeekerInvisMode[id] == 4)
			{
				set_entity_visibility(id,1);
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)

				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 5!")
				g_iGodSeekerInvisMode[id] = 5;
				print_bad_users();
				for(new i = 0; i <= MaxClients;i++)
				{
					if (is_user_connected(i) && REU_GetProtocol(id) >= 48)
						query_client_cvar(id, "cl_minmodels", "cl_minmodels_callback");
				}
			}
			else if (g_iGodSeekerInvisMode[id] == 5)
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти oтключeн!")
				set_entity_visibility(id,1);
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
				g_iGodSeekerInvisMode[id] = 0;
				rg_give_item(id, "weapon_knife");
			}
			else 
			{
				client_print(id,print_chat, "[God seeker] Рeжим нeвидимocти 1!")
				set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 0)
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
			if (g_bGodSeekerActivated[id])
				disable_god_seeker(id);
		}
	}
	menu_destroy(vmenu)
	return PLUGIN_HANDLED
}

public give_me_god(id)
{
	if (ADMIN_ACCESS_LEVEL == ADMIN_ALL || get_user_flags(id) & ADMIN_ACCESS_LEVEL)
	{
		g_bGodSeekerActivated[id] = !g_bGodSeekerActivated[id];
		if (g_bGodSeekerActivated[id])
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
	if (g_iGodSeekerUsers == 0)
	{
		g_bBlockShadowMsg = true;
		set_msg_block(g_iMsgShadow, BLOCK_SET);
		disable_shadow_all();
	}
	g_iGodSeekerUsers++;
	g_bGodSeekerActivated[id] = true;
	g_bGodSeekerKnifeTeleport[id] = true;
	g_bGodSeekerDisableDamage[id] = true;
	g_bGodSeekerDisableSounds[id] = true;
	g_bGodSeekerDisableUsername[id] = true;
	g_iGodSeekerInvisMode[id] = 1;
}

public disable_god_seeker(id)
{
	if (g_iGodSeekerUsers > 0)
	{
		g_bBlockShadowMsg = false;
		enable_shadow_all();
		set_msg_block(g_iMsgShadow, BLOCK_NOT);
	}

	g_iGodSeekerUsers--;
	g_bGodSeekerKnifeTeleport[id] = false;
	g_bGodSeekerDisableDamage[id] = false;
	g_bGodSeekerDisableSounds[id] = false;
	g_bGodSeekerDisableUsername[id] = false;
	g_iGodSeekerInvisMode[id] = 0;

	if(is_user_connected(id))
	{
		set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderNormal, 254)
		set_entity_visibility(id,1);
		if (g_bGodSeekerActivated[id])
		{
			client_print(id, print_chat, "Рeжим God Seeker oтключeн.");
		}
	}
	
	g_bGodSeekerActivated[id] = false;
}

public print_bad_client(id, type)
{
	g_bBadClients[id] = true;
	
	for(new iPlayer = 0; iPlayer <= MaxClients; iPlayer++)
	{
		if (g_bGodSeekerActivated[iPlayer])
		{
			new name[MAX_NAME_LENGTH];
			get_user_name(id,name,charsmax(name))
			client_print(iPlayer,print_console, "[God seeker] Игpoк %s вoшeл %s",name, type == 1 ? "co cтapoгo клиeнтa" : "c cl_minmodels 1");
			client_print(iPlayer,print_chat, "[God seeker] Игpoк %s вoшeл %s",name, type == 1 ? "co cтapoгo клиeнтa" : "c cl_minmodels 1");
			client_print(iPlayer,print_chat, "[God seeker] И мoжeт видeть вac в peжимe ^"ПРОЗРАЧНАЯ МОДЕЛЬ^"");
		}
	}
}

public client_putinserver(id)
{
	g_bBadClients[id] = false;

	if (g_bGodSeekerActivated[id])
		disable_god_seeker(id)
		
	if (!is_user_bot(id) && !is_user_hltv(id))
	{
		query_client_cvar(id, "cl_minmodels", "cl_minmodels_callback");
	}
}

public client_disconnected(id)
{
	g_bBadClients[id] = false;

	if (g_bGodSeekerActivated[id])
		disable_god_seeker(id)
}

public print_bad_users()
{
	for(new iPlayer = 0; iPlayer <= MaxClients; iPlayer++)
	{
		if (is_user_connected(iPlayer) && g_bGodSeekerActivated[iPlayer])
		{
			for(new pid = 0; pid <= MaxClients;pid++)
			{
				if (is_user_connected(pid) && g_bBadClients[pid])
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
			print_bad_client(id,1);
			return;
		}
		if (strtof(value) != 0.0)
		{
			print_bad_client(id,2);
		}
	}
}

public client_PreThink(id)
{
	if(g_bGodSeekerKnifeTeleport[id])
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
			g_bGodSeekerKnifeTeleport[id] = false;
			set_task(0.5,"reenable_teleport",id);
		}
	}
}
public client_PostThink(id)
{
	// FIXME: ReSemiclip module/plugin fix but slowest...
	if (g_iGodSeekerInvisMode[id] == 1)
	{
		set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 0)
	}
	else if (g_iGodSeekerInvisMode[id] == 2)
	{
		set_user_rendering(id, kRenderFxNone, 254, 254, 254, kRenderTransAlpha, 1)
	}
	else if (g_iGodSeekerInvisMode[id] == 3)
	{
		set_user_rendering(id, kRenderFxNone, 1, 1, 1, kRenderTransTexture, 1)
	}
}

public reenable_teleport(id)
{
	if (g_bGodSeekerActivated[id])
		g_bGodSeekerKnifeTeleport[id] = true;
}

public message_statusvalue()
{
	if (get_msg_arg_int(1) == 2 && g_bGodSeekerDisableUsername[get_msg_arg_int(2)])
	{
		set_msg_arg_int(1, get_msg_argtype(1), 1)
		set_msg_arg_int(2, get_msg_argtype(2), 0)
	}
}

public SV_StartSound_Pre(const iRecipients, const iEntity, const iChannel, const szSample[], const flVolume, Float:flAttenuation, const fFlags, const iPitch)
{
	if (iEntity > 0 && iEntity <= MaxClients && g_bGodSeekerDisableSounds[iEntity])
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
