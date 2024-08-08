#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <xs>

#define _easy_cfg_internal
#include <easy_cfg>

#define PLUGIN "God Seeker"
#define VERSION "3.3"
#define AUTHOR "karaulov"


#define BAD_STATE_PENDING 3
#define BAD_STATE_SOFWARE 2
#define BAD_STATE_MINMODELS 1
#define BAD_STATE_NONE 0

new bool:g_bGodSeekerActivated[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerDisableSounds[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerDisableUsername[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerDisableDamage[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerTeleport[MAX_PLAYERS + 1] = {false,...};
new bool:g_bGodSeekerHideFromBots[MAX_PLAYERS + 1] = {false,...};
new bool:g_bIsUserBot[MAX_PLAYERS + 1] = {false,...};
new bool:g_bAllowSoftwareMode = false;
new bool:g_bTurnTeleportAround = false;

new g_pCommonTr;
new g_pMenuHandle[MAX_PLAYERS + 1] = {-1, ...};

new g_iMsgShadow;
new g_iShadowSprite;
new g_iBadClients[MAX_PLAYERS + 1] = {0, ...};
new g_iGodSeekerInvisMode[MAX_PLAYERS + 1] = 0;
new g_iPlayerAim[MAX_PLAYERS + 1] = {0, ...};
new g_iPlayerAttack[MAX_PLAYERS + 1] = {0, ...};
new g_iAccessFlags = ADMIN_BAN;

new Float:g_fLastUpdateMinModels[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_fRefreshMinModels = 1.0;

new g_sPlayerUsernames[MAX_PLAYERS + 1][64];
new g_sPlayerSteamIDs[MAX_PLAYERS + 1][64];
new g_sInvisModelPlayer[64] = "gsfp_vip";
new g_sGodSeekerMenu[64] = "say /godmenu";

enum _:LANG_ID
{
	PLUGIN_PREFIX,
	MENU_HEADER,
	GOD_DISABLED,
	INVIS_MODE1,
	INVIS_MODE2,
	INVIS_MODE3,
	INVIS_MODE4,
	INVIS_MODE5,
	AIMING,
	NO_BLIND,
	ATTACKED,
	NO_PLAYERS,
	BAD_TARGET,
	DO_TARGET,
	SEE_MODEL,
	SEE_SOFTWARE,
	ACTIVATE_GOD,
	DEACTIVATE_GOD,
	SELECT_TEAM,
	GOD_MODE_ACTIVATED,
	INVIS_MODE_PRINT,
	INVIS_MODE_MENU,
	INVIS_MODEL,
	WEAK_INVIS,
	SEE_SMOKE,
	EXIT_MENU,
	DISABLE_MENU,
	BOTS_MENU,
	SOUNDS_MENU,
	USERNAME_MENU,
	DAMAGE_MENU,
	TELEPORT_MENU,
	CAN_HEAR_MENU,
	CANT_HEAR_MENU,
	ON_MENU,
	OFF_MENU,
	VISIBLE_MENU,
	INVISIBLE_MENU,
	BOT_TRIGGERED,
	BOT_IGNORES,
	INVULNERABLE,
	VULNERABLE
};

new g_sLANG[LANG_ID][128];

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	create_cvar("god_seeker", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	RegisterHookChain(RG_CSGameRules_FPlayerCanTakeDamage, "CSGameRules_FPlayerCanTakeDmg", .post = false);
	RegisterHookChain(RH_SV_StartSound, "SV_StartSound_Pre", .post = false);
	RegisterHookChain(RG_PlayerBlind, "PlayerBlind", .post = false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "Player_Spawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Killed, "Player_Killed_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", .post = false);
	RegisterHookChain(RG_CBasePlayer_Observer_IsValidTarget, "CBasePlayer_Observer_IsValidTarget", .post = false);
	RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CSGameRules_CanPlayerHearPlayer", .post = false);
	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoModel, "CBasePlayer_SetClientUserInfoModel", .post = false);
	register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
	register_message(get_user_msgid("StatusValue"), "message_statusvalue");

	g_iMsgShadow = get_user_msgid("ShadowIdx");
	g_pCommonTr = create_tr2();

	set_task(5.0, "update_min_models", 2);
}

public plugin_end()
{
	free_tr2(g_pCommonTr);
}

public plugin_precache()
{
	initialize_god_cfg();
	
	g_iShadowSprite = precache_model("sprites/shadow_circle.spr");
	/*g_iModelInvis = */
	new modelName[64];
	formatex(modelName, charsmax(modelName), "models/player/%s/%s.mdl", g_sInvisModelPlayer, g_sInvisModelPlayer);
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

public initialize_god_cfg()
{
	cfg_set_path("plugins/god_seeker.cfg");

	new tmp_cfgdir[512];
	cfg_get_path(tmp_cfgdir,charsmax(tmp_cfgdir));
	trim_to_dir(tmp_cfgdir);

	if (!dir_exists(tmp_cfgdir))
	{
		log_amx("Warning config dir not found: %s",tmp_cfgdir);
		if (mkdir(tmp_cfgdir) < 0)
		{
			log_error(AMX_ERR_NOTFOUND, "Can't create %s dir",tmp_cfgdir);
			set_fail_state("Fail while create %s dir",tmp_cfgdir);
			return;
		}
		else 
		{
			log_amx("Config dir %s created!",tmp_cfgdir);
		}
	}

	cfg_read_str("GENERAL", "invisibled_player_model", g_sInvisModelPlayer, g_sInvisModelPlayer, charsmax(g_sInvisModelPlayer));
	cfg_read_bool("GENERAL", "allow_software_mode", g_bAllowSoftwareMode, g_bAllowSoftwareMode);
	cfg_read_bool("GENERAL", "turn_teleport_around", g_bTurnTeleportAround, g_bTurnTeleportAround);

	new cmds_toggle = 0;
	new cmds_menu = 0;

	cfg_read_int("GENERAL", "num_toggle_cmds", cmds_toggle, cmds_toggle);
	cfg_read_int("GENERAL", "num_menu_cmds", cmds_menu, cmds_menu);

	if (cmds_toggle == 0)
	{
		cmds_toggle = 3;
		cfg_write_int("GENERAL", "num_toggle_cmds", cmds_toggle);
		cfg_write_str("TOGGLE_CMDS", "CMD_1", "say /wh");
		cfg_write_str("TOGGLE_CMDS", "CMD_2", "say /god");
		cfg_write_str("TOGGLE_CMDS", "CMD_3", "say /antiwh");
	}

	if (cmds_menu == 0)
	{
		cmds_menu = 2;
		cfg_write_int("GENERAL", "num_menu_cmds", cmds_menu);
		cfg_write_str("MENU_CMDS", "CMD_1", "say /whmenu");
		cfg_write_str("MENU_CMDS", "CMD_2", "say /godmenu");
	}

	new language[64] = {EOS};
	cfg_read_str("GENERAL", "language", language, language, charsmax(language));

	if (language[0] == EOS)
	{
		copy(language, charsmax(language), "English");
		cfg_write_str("GENERAL", "language", language);

		cfg_write_str("English", "plugin_prefix", "GOD SEEKER");
		cfg_write_str("Russian", "plugin_prefix", "АНТИ ВХ");

		cfg_write_str("English", "menu_header", "[God Seeker] Configuration:");
		cfg_write_str("Russian", "menu_header", "[God Seeker] Настройки:");

		cfg_write_str("English", "god_disabled", "^^4God Seeker^^3 mode is disabled!");
		cfg_write_str("Russian", "god_disabled", "Режим ^^4God Seeker^^3 отключен!");

		cfg_write_str("English", "invis_model", "INVISIBLE MODEL");
		cfg_write_str("Russian", "invis_model", "НЕВИДИМАЯ МОДЕЛЬ");

		cfg_write_str("English", "invis_mode1", "INVISIBLE MODEL");
		cfg_write_str("Russian", "invis_mode1", "МОДЕЛЬ");

		cfg_write_str("English", "invis_mode2", "TRANSPARENT 1");
		cfg_write_str("Russian", "invis_mode2", "ПРОЗРАЧНОСТЬ 1");

		cfg_write_str("English", "invis_mode3", "TRANSPARENT 2");
		cfg_write_str("Russian", "invis_mode3", "ПРОЗРАЧНОСТЬ 2");

		cfg_write_str("English", "invis_mode4", "HIDDEN 1");
		cfg_write_str("Russian", "invis_mode4", "СКРЫТЫЙ 1");

		cfg_write_str("English", "invis_mode5", "HIDDEN 2");
		cfg_write_str("Russian", "invis_mode5", "СКРЫТЫЙ 2");

		cfg_write_str("English", "aiming", "Player ^^4%s^^3 [SteamID: ^^1%s^^3] aimed at you!");
		cfg_write_str("Russian", "aiming", "Игрок ^^4%s^^3 [^^1%s^^3] прицелился в тебя!");

		cfg_write_str("English", "no_blind", "You not blinded because ^^4God Seeker^^3 was activated!");
		cfg_write_str("Russian", "no_blind", "Не ослеплен! Ты в ^^4God Seeker^^3 режиме.");

		cfg_write_str("English", "attacked", "Player ^^4%s^^3 [SteamID: ^^1%s^^3] attacked you!");
		cfg_write_str("Russian", "attacked", "Игрок ^^4%s^^3 [^^1%s^^3] атакует тебя!");

		cfg_write_str("English", "no_players", "No players!");
		cfg_write_str("Russian", "no_players", "Недостаточно игроков!");

		cfg_write_str("English", "bad_target", "Bad target!");
		cfg_write_str("Russian", "bad_target", "Туда нельзя!");

		cfg_write_str("English", "do_target", "Successful teleport to target!");
		cfg_write_str("Russian", "do_target", "Успешное перемещение к цели!");

		cfg_write_str("English", "see_model", "Player ^^4%s^^3 can see you in invisible mode ^"%s^"!");
		cfg_write_str("Russian", "see_model", "Игрок ^^4%s^^3 мoжeт видeть вac в peжимe ^"%s^"");

		cfg_write_str("English", "see_software", "Player ^^4%s^^3 can see you in invisible mode ^"%s^" and ^"%s^"");
		cfg_write_str("Russian", "see_software", "Игрок ^^4%s^^3 видит вac в peжимах ^"%s^" и ^"%s^"");

		cfg_write_str("English", "activate_god", "Administrator %s [%s] activated God Seeker mode.");
		cfg_write_str("Russian", "activate_god", "Админиcтpaтop %s [%s] aктивиpoвaл peжим God Seeker.");

		cfg_write_str("English", "deactivate_god", "Administrator %s [%s] deactivated God Seeker mode.");
		cfg_write_str("Russian", "deactivate_god", "Админиcтpaтop %s [%s] дeактивиpoвaл peжим God Seeker.");

		cfg_write_str("English", "select_team", "Join team to activate ^^4God seeker^^3.");
		cfg_write_str("Russian", "select_team", "Войдите в игру для активации ^^4God seeker^^3.");

		cfg_write_str("English", "god_mode_activated", "Now you in ^^4God seeker^^3 mode. Settings %s");
		cfg_write_str("Russian", "god_mode_activated", "Теперь ты в ^^4God seeker^^3. Настройки %s");

		cfg_write_str("English", "invis_mode_print", "Invisible mode");
		cfg_write_str("Russian", "invis_mode_print", "Рeжим нeвидимocти");

		cfg_write_str("English", "invis_mode_menu", "Invis mode");
		cfg_write_str("Russian", "invis_mode_menu", "Невидимость");

		cfg_write_str("English", "weak_invis", "Weak check");
		cfg_write_str("Russian", "weak_invis", "Слабая проверка");

		cfg_write_str("English", "see_smoke", "Visible through smoke/sprites");
		cfg_write_str("Russian", "see_smoke", "Видно сквозь дым!");

		cfg_write_str("English", "exit_menu", "Hide menu");
		cfg_write_str("Russian", "exit_menu", "Скрыть меню");

		cfg_write_str("English", "disable_menu", "Exit God Seeker");
		cfg_write_str("Russian", "disable_menu", "Отключить");

		cfg_write_str("English", "bot_menu", "Bots");
		cfg_write_str("Russian", "bot_menu", "Боты");

		cfg_write_str("English", "sounds_menu", "Sounds");
		cfg_write_str("Russian", "sounds_menu", "Звуки");

		cfg_write_str("English", "username_menu", "Nickname");
		cfg_write_str("Russian", "username_menu", "Никнейм");

		cfg_write_str("English", "damage_menu", "Damage");
		cfg_write_str("Russian", "damage_menu", "Урон");

		cfg_write_str("English", "teleport_menu", "Teleport");
		cfg_write_str("Russian", "teleport_menu", "Телепорт");

		cfg_write_str("English", "can_hear_menu", "CAN HEAR");
		cfg_write_str("Russian", "can_hear_menu", "СЛЫШНЫ");

		cfg_write_str("English", "cant_hear_menu", "NO HEAR");
		cfg_write_str("Russian", "cant_hear_menu", "НЕ СЛЫШНЫ");

		cfg_write_str("English", "on_menu", "ON");
		cfg_write_str("Russian", "on_menu", "ВКЛ");
		
		cfg_write_str("English", "off_menu", "OFF");
		cfg_write_str("Russian", "off_menu", "ВЫКЛ");

		cfg_write_str("English", "visible_menu", "VISIBLE");
		cfg_write_str("Russian", "visible_menu", "ПОКАЗАТЬ");

		cfg_write_str("English", "invisible_menu", "INVISIBLE");
		cfg_write_str("Russian", "invisible_menu", "СКРЫТЬ");

		cfg_write_str("English", "bot_triggered", "ATTACK");
		cfg_write_str("Russian", "bot_triggered", "АТАКУЮТ");

		cfg_write_str("English", "bot_ignores", "IGNORE");
		cfg_write_str("Russian", "bot_ignores", "ИГНОРЯТ");

		cfg_write_str("English", "invulnerable", "INVULNERABLE");
		cfg_write_str("Russian", "invulnerable", "БЕССМЕРТНЫЙ");

		cfg_write_str("English", "vulnerable", "GET");
		cfg_write_str("Russian", "vulnerable", "ПОЛУЧАТЬ");
	}

	cfg_read_str(language, "plugin_prefix", g_sLANG[PLUGIN_PREFIX], g_sLANG[PLUGIN_PREFIX], charsmax(g_sLANG[]));
	cfg_read_str(language, "menu_header", g_sLANG[MENU_HEADER], g_sLANG[MENU_HEADER], charsmax(g_sLANG[]));
	cfg_read_str(language, "god_disabled", g_sLANG[GOD_DISABLED], g_sLANG[GOD_DISABLED], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_model", g_sLANG[INVIS_MODEL], g_sLANG[INVIS_MODEL], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_mode1", g_sLANG[INVIS_MODE1], g_sLANG[INVIS_MODE1], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_mode2", g_sLANG[INVIS_MODE2], g_sLANG[INVIS_MODE2], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_mode3", g_sLANG[INVIS_MODE3], g_sLANG[INVIS_MODE3], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_mode4", g_sLANG[INVIS_MODE4], g_sLANG[INVIS_MODE4], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_mode5", g_sLANG[INVIS_MODE5], g_sLANG[INVIS_MODE5], charsmax(g_sLANG[]));
	cfg_read_str(language, "aiming", g_sLANG[AIMING], g_sLANG[AIMING], charsmax(g_sLANG[]));
	cfg_read_str(language, "no_blind", g_sLANG[NO_BLIND], g_sLANG[NO_BLIND], charsmax(g_sLANG[]));
	cfg_read_str(language, "attacked", g_sLANG[ATTACKED], g_sLANG[ATTACKED], charsmax(g_sLANG[]));
	cfg_read_str(language, "no_players", g_sLANG[NO_PLAYERS], g_sLANG[NO_PLAYERS], charsmax(g_sLANG[]));
	cfg_read_str(language, "bad_target", g_sLANG[BAD_TARGET], g_sLANG[BAD_TARGET], charsmax(g_sLANG[]));
	cfg_read_str(language, "do_target", g_sLANG[DO_TARGET], g_sLANG[DO_TARGET], charsmax(g_sLANG[]));
	cfg_read_str(language, "see_model", g_sLANG[SEE_MODEL], g_sLANG[SEE_MODEL], charsmax(g_sLANG[]));
	cfg_read_str(language, "see_software", g_sLANG[SEE_SOFTWARE], g_sLANG[SEE_SOFTWARE], charsmax(g_sLANG[]));
	cfg_read_str(language, "activate_god", g_sLANG[ACTIVATE_GOD], g_sLANG[ACTIVATE_GOD], charsmax(g_sLANG[]));
	cfg_read_str(language, "deactivate_god", g_sLANG[DEACTIVATE_GOD], g_sLANG[DEACTIVATE_GOD], charsmax(g_sLANG[]));
	cfg_read_str(language, "select_team", g_sLANG[SELECT_TEAM], g_sLANG[SELECT_TEAM], charsmax(g_sLANG[]));
	cfg_read_str(language, "god_mode_activated", g_sLANG[GOD_MODE_ACTIVATED], g_sLANG[GOD_MODE_ACTIVATED], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_mode_print", g_sLANG[INVIS_MODE_PRINT], g_sLANG[INVIS_MODE_PRINT], charsmax(g_sLANG[]));
	cfg_read_str(language, "invis_mode_menu", g_sLANG[INVIS_MODE_MENU], g_sLANG[INVIS_MODE_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "weak_invis", g_sLANG[WEAK_INVIS], g_sLANG[WEAK_INVIS], charsmax(g_sLANG[]));
	cfg_read_str(language, "see_smoke", g_sLANG[SEE_SMOKE], g_sLANG[SEE_SMOKE], charsmax(g_sLANG[]));
	cfg_read_str(language, "exit_menu", g_sLANG[EXIT_MENU], g_sLANG[EXIT_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "disable_menu", g_sLANG[DISABLE_MENU], g_sLANG[DISABLE_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "bot_menu", g_sLANG[BOTS_MENU], g_sLANG[BOTS_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "sounds_menu", g_sLANG[SOUNDS_MENU], g_sLANG[SOUNDS_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "username_menu", g_sLANG[USERNAME_MENU], g_sLANG[USERNAME_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "damage_menu", g_sLANG[DAMAGE_MENU], g_sLANG[DAMAGE_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "teleport_menu", g_sLANG[TELEPORT_MENU], g_sLANG[TELEPORT_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "can_hear_menu", g_sLANG[CAN_HEAR_MENU], g_sLANG[CAN_HEAR_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "cant_hear_menu", g_sLANG[CANT_HEAR_MENU], g_sLANG[CANT_HEAR_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "on_menu", g_sLANG[ON_MENU], g_sLANG[ON_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "off_menu", g_sLANG[OFF_MENU], g_sLANG[OFF_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "visible_menu", g_sLANG[VISIBLE_MENU], g_sLANG[VISIBLE_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "invisible_menu", g_sLANG[INVISIBLE_MENU], g_sLANG[INVISIBLE_MENU], charsmax(g_sLANG[]));
	cfg_read_str(language, "bot_triggered", g_sLANG[BOT_TRIGGERED], g_sLANG[BOT_TRIGGERED], charsmax(g_sLANG[]));
	cfg_read_str(language, "bot_ignores", g_sLANG[BOT_IGNORES], g_sLANG[BOT_IGNORES], charsmax(g_sLANG[]));
	cfg_read_str(language, "invulnerable", g_sLANG[INVULNERABLE], g_sLANG[INVULNERABLE], charsmax(g_sLANG[]));
	cfg_read_str(language, "vulnerable", g_sLANG[VULNERABLE], g_sLANG[VULNERABLE], charsmax(g_sLANG[]));



	for(new i = 0; i < sizeof(g_sLANG); i++)
	{
		fix_colors(g_sLANG[i], charsmax(g_sLANG[]));
	}

	log_amx("Plugin [%s] loaded!",g_sLANG[PLUGIN_PREFIX]);
	log_amx("Settings:");
	log_amx("  - Invisibled player model: models/player/%s/%s.mdl", g_sInvisModelPlayer,g_sInvisModelPlayer);
	log_amx("  - Allow players in 'software' mode: %s", g_bAllowSoftwareMode ? "true" : "false");
	log_amx("  - Turn teleport around: %s", g_bTurnTeleportAround ? "true" : "false");
	log_amx("  - Num toggle cmds: %d", cmds_toggle);

	for(new i = 1; i <= cmds_toggle; i++)
	{
		new cmd[64];
		new cmd_var[64];
		formatex(cmd_var,charsmax(cmd_var),"CMD_%d",i);
		cfg_read_str("TOGGLE_CMDS", cmd_var, cmd, cmd, charsmax(cmd));
		register_clcmd(cmd, "give_me_god");
		log_amx("  - %d: %s",i,cmd);
	}

	log_amx("  - Num menu cmds: %d",cmds_menu);
	for(new i = 1; i <= cmds_menu; i++)
	{
		new cmd[64];
		new cmd_var[64];
		formatex(cmd_var,charsmax(cmd_var),"CMD_%d",i);
		cfg_read_str("MENU_CMDS", cmd_var, cmd, cmd, charsmax(cmd));
		register_clcmd(cmd, "show_seeker_menu");

		if (i == 1)
			log_amx("  - %d: %s [set as default]",i,cmd);
		else 
			log_amx("    %d: %s",i,cmd);

		copy(g_sGodSeekerMenu, charsmax(g_sGodSeekerMenu), cmd);
	}

	new flags[64] = "d";
	cfg_read_str("GENERAL", "access_flags", flags, flags, charsmax(flags));
	g_iAccessFlags = read_flags(flags);

	log_amx("  - Access flags: %s [bin %X]",flags, g_iAccessFlags);
	
	log_amx("Language set to: %s", language);
}

public show_seeker_menu(id)
{
	if (get_user_flags(id) & g_iAccessFlags == 0)
	{
		return PLUGIN_CONTINUE;
	}

	if (!g_bGodSeekerActivated[id])
	{
		client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX],g_sLANG[GOD_DISABLED]);
		return PLUGIN_HANDLED;
	}
	
	if (g_pMenuHandle[id] != -1)
	{
		menu_destroy(g_pMenuHandle[id]);
		g_pMenuHandle[id] = -1;
		show_menu(id, 0, "^n", 0);
		return PLUGIN_HANDLED;
	}

	new vmenu = menu_create(g_sLANG[MENU_HEADER], "seeker_menu");

	g_pMenuHandle[id] = vmenu;

	new tmpmenuitem[128];
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\w%s [\r%s\w]", g_sLANG[INVIS_MODE_MENU],
	g_iGodSeekerInvisMode[id] == 1 ? g_sLANG[INVIS_MODE1] : 
	(g_iGodSeekerInvisMode[id] == 2 ? g_sLANG[INVIS_MODE2] : 
	(g_iGodSeekerInvisMode[id] == 3 ? g_sLANG[INVIS_MODE3] : 
	(g_iGodSeekerInvisMode[id] == 4 ? g_sLANG[INVIS_MODE4] : 
	(g_iGodSeekerInvisMode[id] == 5 ? g_sLANG[INVIS_MODE5]
	: "" )))));
	menu_additem(vmenu, tmpmenuitem,"1");
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\w%s [\r%s\w]", g_sLANG[SOUNDS_MENU], g_bGodSeekerDisableSounds[id] ? g_sLANG[CANT_HEAR_MENU] : g_sLANG[CAN_HEAR_MENU]);
	menu_additem(vmenu, tmpmenuitem,"2");
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\w%s [\r%s\w]", g_sLANG[USERNAME_MENU], g_bGodSeekerDisableUsername[id] ? g_sLANG[INVISIBLE_MENU] : g_sLANG[VISIBLE_MENU]);
	menu_additem(vmenu, tmpmenuitem,"3");
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\w%s [\r%s\w]", g_sLANG[DAMAGE_MENU], g_bGodSeekerDisableDamage[id] ?  g_sLANG[INVULNERABLE] : g_sLANG[VULNERABLE]);
	menu_additem(vmenu, tmpmenuitem,"4");
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\w%s [\r%s\w]", g_sLANG[TELEPORT_MENU], g_bGodSeekerTeleport[id] ? g_sLANG[ON_MENU] : g_sLANG[OFF_MENU]);
	menu_additem(vmenu, tmpmenuitem,"5");
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\w%s [\r%s\w]", g_sLANG[BOTS_MENU], g_bGodSeekerHideFromBots[id] ? g_sLANG[BOT_IGNORES] : g_sLANG[BOT_TRIGGERED]);
	menu_additem(vmenu, tmpmenuitem,"6");
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\w%s", g_sLANG[DISABLE_MENU]);
	menu_additem(vmenu, tmpmenuitem,"7");
	
	formatex(tmpmenuitem,charsmax(tmpmenuitem),"\r%s", g_sLANG[EXIT_MENU]);
	menu_setprop(vmenu, MPROP_EXITNAME, tmpmenuitem);
	menu_setprop(vmenu, MPROP_EXIT,MEXIT_ALL);
	
	menu_display(id,vmenu,0);
	return PLUGIN_HANDLED;
}

public print_invis_mode(id)
{
	if (g_iGodSeekerInvisMode[id] == 2)
	{
		client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s %d! ^1%s!",g_sLANG[PLUGIN_PREFIX], g_sLANG[INVIS_MODE_PRINT], g_iGodSeekerInvisMode[id], g_sLANG[SEE_SMOKE]);
	}
	else if (g_iGodSeekerInvisMode[id] == 3)
	{	
		client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s %d! ^1%s!",g_sLANG[PLUGIN_PREFIX], g_sLANG[INVIS_MODE_PRINT], g_iGodSeekerInvisMode[id], g_sLANG[SEE_SMOKE]);
	}
	else if (g_iGodSeekerInvisMode[id] == 4)
	{
		client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s %d! ^1[%s]",g_sLANG[PLUGIN_PREFIX], g_sLANG[INVIS_MODE_PRINT], g_iGodSeekerInvisMode[id], g_sLANG[WEAK_INVIS]);
	}
	else if (g_iGodSeekerInvisMode[id] == 5)
	{
		client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s %d! ^1[%s]",g_sLANG[PLUGIN_PREFIX], g_sLANG[INVIS_MODE_PRINT], g_iGodSeekerInvisMode[id], g_sLANG[WEAK_INVIS]);
	}
	else 
	{
		client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s %d! [%s]",g_sLANG[PLUGIN_PREFIX], g_sLANG[INVIS_MODE_PRINT], g_iGodSeekerInvisMode[id], g_sLANG[INVIS_MODEL]);
	}
}

public seeker_menu(id, vmenu, item) 
{
	if(item == MENU_EXIT || !is_user_connected(id) || !is_user_alive(id)) 
	{
		menu_destroy(vmenu);
		g_pMenuHandle[id] = -1;
		return PLUGIN_HANDLED;
	}
	
	new data[6], iName[64], access, callback;
	menu_item_getinfo(vmenu, item, access, data, charsmax(data), iName, charsmax(iName), callback);
	     
	new key = str_to_num(data);
	switch(key) 
	{	
		case 1:
		{
			if (g_iGodSeekerInvisMode[id] == 1)
			{
				rg_reset_user_model(id, true);
				g_iGodSeekerInvisMode[id] = 2;
			}
			else if (g_iGodSeekerInvisMode[id] == 2)
			{	
				g_iGodSeekerInvisMode[id] = 3;
			}
			else if (g_iGodSeekerInvisMode[id] == 3)
			{
				g_iGodSeekerInvisMode[id] = 4;
			}
			else if (g_iGodSeekerInvisMode[id] == 4)
			{
				g_iGodSeekerInvisMode[id] = 5;
			}
			else 
			{
				g_iGodSeekerInvisMode[id] = 1;
				rg_set_user_model(id, g_sInvisModelPlayer, true);
			}

			print_invis_mode(id);

			remove_task(1);
			set_task(2.0, "print_bad_users", 1);
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
	if (get_user_flags(id) & g_iAccessFlags == 0)
		return PLUGIN_CONTINUE;

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
				client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s", g_sLANG[PLUGIN_PREFIX], g_sLANG[SELECT_TEAM]);
				return PLUGIN_HANDLED;
			}
		}
		enable_god_seeker(id);
		show_seeker_menu(id);
	}
	else 
	{
		disable_god_seeker(id);
	}
	return PLUGIN_HANDLED;
}

public enable_god_seeker(id)
{
	if (g_bGodSeekerActivated[id])
		return;

	log_to_file("god_seeker.log", g_sLANG[ACTIVATE_GOD], g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);
	server_print(g_sLANG[ACTIVATE_GOD], g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);

	static sGodSeekerActivate[128];
	format(sGodSeekerActivate, charsmax(sGodSeekerActivate), "^1[^4%s^1]^3 %s", g_sLANG[PLUGIN_PREFIX], g_sLANG[GOD_MODE_ACTIVATED]);

	client_print_color(id, print_team_blue, sGodSeekerActivate, g_sGodSeekerMenu);
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
		rg_set_user_model(id, g_sInvisModelPlayer, true);

	print_invis_mode(id);
}

public disable_god_seeker(id)
{
	if(is_user_connected(id))
	{
		if (g_bGodSeekerActivated[id])
		{
			client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX], g_sLANG[GOD_DISABLED]);
		}
	}

	if (g_bGodSeekerActivated[id])
	{
		log_to_file("god_seeker.log", g_sLANG[DEACTIVATE_GOD], g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);
		server_print(g_sLANG[DEACTIVATE_GOD], g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);
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

	new flags = get_entvar(id, var_flags);
			
	if (flags & FL_NOTARGET)
	{
		flags -= FL_NOTARGET;
		set_entvar(id, var_flags, flags);
	}
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
					static sSeePlayer[128];
					if (g_iBadClients[pid] == BAD_STATE_PENDING)
					{
						format(sSeePlayer, sizeof(sSeePlayer), "^1[^4%s^1]^3 %s", g_sLANG[PLUGIN_PREFIX], g_sLANG[SEE_MODEL]);
						client_print_color(iPlayer, print_team_blue, sSeePlayer, g_sPlayerUsernames[pid], g_sLANG[INVIS_MODE1]);
					}
					else if (g_iBadClients[pid] == BAD_STATE_SOFWARE)
					{
						format(sSeePlayer, sizeof(sSeePlayer), "^1[^4%s^1]^3 %s", g_sLANG[PLUGIN_PREFIX], g_sLANG[SEE_SOFTWARE]);
						client_print_color(iPlayer, print_team_blue, sSeePlayer, g_sPlayerUsernames[pid], g_sLANG[INVIS_MODE2], g_sLANG[INVIS_MODE3]);
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

		if (!g_bAllowSoftwareMode)
		{
			set_task(0.1, "drop_client_delayed", id);
		}
	
		g_iBadClients[id] = BAD_STATE_SOFWARE;
	}
}

public drop_client_delayed(id)
{
	if (is_user_connected(id))
		rh_drop_client(id, "Software mode");
}

public cl_minmodels_callback(id, const cvar[], const value[])
{
	if (is_user_connected(id))
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

public update_min_models(id)
{
	new bool:need_update = false;

	for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (g_bGodSeekerActivated[iPlayer] && g_iGodSeekerInvisMode[iPlayer] == 1)
		{
			need_update = true;
			break;
		}
	}

	if (need_update)
	{
		for(new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (!g_bIsUserBot[iPlayer] && is_user_connected(iPlayer) && floatabs(get_gametime() - g_fLastUpdateMinModels[iPlayer]) > 2.0)
			{
				if (g_iBadClients[iPlayer] != BAD_STATE_PENDING && g_iBadClients[iPlayer] != BAD_STATE_SOFWARE)
				{
					query_client_cvar(iPlayer, "cl_minmodels", "cl_minmodels_callback");
				}
				g_fLastUpdateMinModels[iPlayer] = get_gametime();
			}
		}
	}

	set_task(g_fRefreshMinModels, "update_min_models", 2);
}

public CBasePlayer_PreThink(id)
{
	if (id > MaxClients || g_bIsUserBot[id])
		return HC_CONTINUE;
	
	new btn = get_entvar(id,var_button);
	if(g_bGodSeekerActivated[id])
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
				if (g_bGodSeekerTeleport[id])
				{
					if (is_bad_aiming(id))
					{
						client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX], g_sLANG[BAD_TARGET]);
					}
					else 
					{
						static Float:TeleportPoint[3];
						if (get_teleport_point(id,TeleportPoint))
						{
							teleportPlayer(id,TeleportPoint);
							client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s", g_sLANG[PLUGIN_PREFIX], g_sLANG[DO_TARGET]);
						}
						else 
						{
							client_print_color(id, print_team_blue, "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX], g_sLANG[BAD_TARGET]);
						}
					}
				}
			}
			set_member(id, m_flNextAttack, 0.35);
			set_member(iActiveItem, m_Weapon_flNextSecondaryAttack, 0.35);
			set_member(iActiveItem, m_Weapon_flNextPrimaryAttack, 0.35);
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
				client_print_color(iPlayer, print_team_blue, "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX], g_sLANG[NO_PLAYERS]);
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

public CBasePlayer_SetClientUserInfoModel(const id, infobuffer[], szNewModel[])
{
	if(g_bGodSeekerActivated[id] && g_iGodSeekerInvisMode[id] == 1)
	{
		engfunc(EngFunc_SetClientKeyValue, id, engfunc(EngFunc_GetInfoKeyBuffer, id), "model", g_sInvisModelPlayer);
		return HC_BREAK;
	}		
	return HC_CONTINUE;
}

public AddToFullPack_Post(es_handle, e, ent, host, hostflags, bool:player, pSet) 
{
	if(!player || host > MaxClients || ent > MaxClients || !g_bGodSeekerActivated[ent])
		return FMRES_IGNORED;

	if (g_iGodSeekerInvisMode[ent] == 5)
	{
		new effects = get_es(es_handle, ES_Effects);
		if (effects & EF_NODRAW == 0)
			set_es(es_handle, ES_Effects, effects | EF_NODRAW);
		return FMRES_HANDLED;
	}
	else if (g_iGodSeekerInvisMode[ent] == 4)
	{
		set_es(es_handle, ES_RenderMode, kRenderTransTexture);
		set_es(es_handle, ES_RenderAmt, 0);
		set_es(es_handle, ES_RenderColor, {1,1,1});
		return FMRES_HANDLED;
	}
	else if (g_iGodSeekerInvisMode[ent] == 3)
	{
		set_es(es_handle, ES_RenderMode, kRenderTransColor);
		set_es(es_handle, ES_RenderAmt, 1);
		set_es(es_handle, ES_RenderColor, {1,1,1});
		return FMRES_HANDLED;
	}
	else if (g_iGodSeekerInvisMode[ent] == 2)
	{
		set_es(es_handle, ES_RenderMode, kRenderTransTexture);
		set_es(es_handle, ES_RenderAmt, 1);
		set_es(es_handle, ES_RenderColor, {255,255,255});
		return FMRES_HANDLED;
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
		return FMRES_HANDLED;
	}
	return FMRES_IGNORED;
}

public CSGameRules_CanPlayerHearPlayer(const listener, const sender)
{
	if(sender <= MaxClients && g_bGodSeekerActivated[sender])
	{
		SetHookChainReturn(ATYPE_BOOL, false);
		return HC_SUPERCEDE;
	}
	else
	{
		return HC_CONTINUE;
	}
}

public CSGameRules_FPlayerCanTakeDmg(const pPlayer, const pAttacker)
{
	if(pAttacker > MaxClients || pAttacker == 0)
	{
		return HC_CONTINUE;
	}

	if(g_bGodSeekerActivated[pPlayer] && g_bGodSeekerDisableDamage[pPlayer])
	{
		if (pPlayer != pAttacker && g_iPlayerAttack[pAttacker] != pPlayer && !g_bIsUserBot[pAttacker])
		{
			static sAttackedText[128];
			format(sAttackedText, sizeof(sAttackedText), "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX], g_sLANG[ATTACKED]);
			client_print_color(pPlayer, print_team_blue, sAttackedText, g_sPlayerUsernames[pAttacker], g_sPlayerSteamIDs[pAttacker]);
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
	if (g_bGodSeekerActivated[index])
	{	
		client_print_color(index, print_team_blue, "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX], g_sLANG[NO_BLIND]);
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
			static sAimingText[128];
			formatex(sAimingText, charsmax(sAimingText), "^1[^4%s^1]^3 %s",g_sLANG[PLUGIN_PREFIX],  g_sLANG[AIMING]);
			client_print_color(targetid, print_team_blue, sAimingText, g_sPlayerUsernames[id], g_sPlayerSteamIDs[id]);
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
	if (g_bTurnTeleportAround)
	{
		pLook[1]+=180.0;
	}
	set_entvar(id, var_angles, pLook);
	set_entvar(id, var_fixangle, 1);
	set_entvar(id, var_velocity,Float:{0.0,0.0,0.0});
	unstuck_player(id);
}

stock bool:get_teleport_point(iPlayer, Float:newTeleportPoint[3])
{
	static iEyesOrigin[ 3 ];
	static iEyesEndOrigin[ 3 ];
	static Float:vecEyesOrigin[ 3 ];
	static Float:vecEyesEndOrigin[ 3 ];
	static Float:vecDirection[ 3 ];
	static Float:vecAimOrigin[ 3 ];

	get_user_origin(iPlayer, iEyesOrigin, Origin_Eyes);
	get_user_origin(iPlayer, iEyesEndOrigin, Origin_AimEndEyes);
	IVecFVec(iEyesOrigin, vecEyesOrigin);
	IVecFVec(iEyesEndOrigin, vecEyesEndOrigin);
	
	new maxDistance = get_distance(iEyesOrigin,iEyesEndOrigin);
	if (maxDistance < 24)
	{
		return false;
	}
	
	velocity_by_aim(iPlayer, 24, vecDirection);
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
		i+=24;
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
	new target[3];
	new Float:target_flt[3];

	get_user_origin(id, target, 3);
	
	IVecFVec(target,target_flt);

	if(engfunc(EngFunc_PointContents,target_flt) == CONTENTS_SKY)
		return true;

	return false;
}

#pragma ctrlchar '\'
stock trim_to_dir(path[])
{
	new len = strlen(path);
	len--;
	for(; len >= 0; len--)
	{
		if(path[len] == '/' || path[len] == '\\')
		{
			path[len] = EOS;
			break;
		}
	}
}

stock fix_colors(str[], len)
{
	replace_all(str, len, "^1", "\x01");
	replace_all(str, len, "^2", "\x02");
	replace_all(str, len, "^3", "\x03");
	replace_all(str, len, "^4", "\x04");
}