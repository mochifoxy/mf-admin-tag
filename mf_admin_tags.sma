#include <amxmodx>
#include <amxmisc>
#include <reapi>

#define PLUGIN  "MF Admin Tag System"
#define VERSION "1.1"
#define AUTHOR  "MochiFoxy"

#define MF_MAX_PLAYERS 64
#define MAX_ADMIN_TAGS 100

new g_auth[MAX_ADMIN_TAGS][35];
new g_tag[MAX_ADMIN_TAGS][32];
new g_tag_color[MAX_ADMIN_TAGS];
new g_text_color[MAX_ADMIN_TAGS];
new g_name_color[MAX_ADMIN_TAGS];
new g_req_flags[MAX_ADMIN_TAGS];
new g_count = 0;

new Trie:g_auth_trie;
new Trie:g_nick_trie;

new g_player_tag_index[MF_MAX_PLAYERS + 1] = { -1, ... };

new const g_TeamNames[][] = {
    "UNASSIGNED",
    "TERRORIST",
    "CT",
    "SPECTATOR"
};

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say",      "cmd_say");
    register_clcmd("say_team", "cmd_say_team");

    g_auth_trie = TrieCreate();
    g_nick_trie = TrieCreate();

    load_tags();
}

public plugin_end() {
    TrieDestroy(g_auth_trie);
    TrieDestroy(g_nick_trie);
}

public client_putinserver(id) {
    if (id < 1 || id > MF_MAX_PLAYERS) return;
    
    g_player_tag_index[id] = -1;
    find_player_tag(id);
    
    set_task(2.0, "task_deferred_find", id);
}

public client_authorized(id, const authid[]) {
    if (id < 1 || id > MF_MAX_PLAYERS) return;
    
    find_player_tag(id);
}

public task_deferred_find(id) {
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id)) return;
    find_player_tag(id);
}

public client_disconnected(id) {
    if (id < 1 || id > MF_MAX_PLAYERS) return;
    
    g_player_tag_index[id] = -1;
    remove_task(id);
}

public client_infochanged(id) {
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id)) return;

    new newname[32], oldname[32];
    get_user_info(id, "name", newname, charsmax(newname));
    get_user_name(id, oldname, charsmax(oldname));

    if (!equal(newname, oldname)) {
        find_player_tag(id, newname);
    }
}

load_tags() {
    new configsdir[64], filepath[128];
    get_configsdir(configsdir, charsmax(configsdir));
    formatex(filepath, charsmax(filepath), "%s/admin_tags.ini", configsdir);

    if (!file_exists(filepath)) {
        new file = fopen(filepath, "w");
        if (file) {
            fputs(file, "; Admin Chat Tags Ultra Yapilandirma Dosyasi^n");
            fputs(file, "; Kullanim: ^"SteamID/Nick/@Yetki^" ^"Tag Metni^" ^"Tag Rengi^" ^"Yazi Rengi^" ^"Isim Rengi^"^n");
            fputs(file, "; Renkler: 1=Yesil, 2=Kirmizi, 3=Mavi, 4=Sari/Beyaz^n");
            fputs(file, "; Not: Ayni mesajda hem Kirmizi hem Mavi kullanilamaz. Hangisi once gelirse o gecerli olur.^n");
            fputs(file, ";^n");
            fputs(file, "; ONEMLI NOT: Ustteki kurallar once gecerlidir. O yuzden ozel (nick/steamid) taglari USTE,^n");
            fputs(file, "; genel yetki (@FLAG_x veya @x) taglarini ALTA yaziniz.^n");
            fputs(file, ";^n");
            fputs(file, "; Ornekler:^n");
            fputs(file, ";^"STEAM_0:0:123456^" ^"Kurucu^" ^"2^" ^"1^" ^"2^"^n");
            fputs(file, ";^"FoxyBlinks^" ^"Support^" ^"1^" ^"4^" ^"3^"^n");
            fputs(file, ";^"@d^" ^"Admin^" ^"1^" ^"1^" ^"1^"^n");
            fclose(file);
        }
        return;
    }

    new file = fopen(filepath, "r");
    if (!file) return;

    new line[128];
    new auth[35], tag[32], tag_color_str[4], text_color_str[4], name_color_str[4];

    while (!feof(file) && g_count < MAX_ADMIN_TAGS) {
        fgets(file, line, charsmax(line));
        trim(line);

        if (line[0] == 0 || line[0] == ';') continue;

        parse(line,
            auth,          charsmax(auth),
            tag,           charsmax(tag),
            tag_color_str, charsmax(tag_color_str),
            text_color_str,charsmax(text_color_str),
            name_color_str,charsmax(name_color_str));

        if (auth[0] == 0) continue;

        // Yetki gruplari '@' karakteri ile baslar. Geriye kalanlar SteamID veya Nickname'dir.
        if (auth[0] != '@') {
            if (containi(auth, "STEAM_") == 0) {
                if (TrieKeyExists(g_auth_trie, auth)) {
                    continue;
                }
            } else {
                if (TrieKeyExists(g_nick_trie, auth)) {
                    continue;
                }
            }
        }

        copy(g_auth[g_count], charsmax(g_auth[]), auth);
        copy(g_tag[g_count],  charsmax(g_tag[]),  tag);
        g_tag_color[g_count]  = str_to_num(tag_color_str);
        g_text_color[g_count] = str_to_num(text_color_str);
        g_name_color[g_count] = str_to_num(name_color_str);

        if (g_name_color[g_count] == 0) {
            g_name_color[g_count] = g_tag_color[g_count];
        }

        g_req_flags[g_count] = 0;

        if (auth[0] == '@') {
            // @FLAG_d veya @d seklindeki yetki tanimlamalarini guvenle oku
            if (containi(auth, "@FLAG_") == 0) {
                g_req_flags[g_count] = read_flags(auth[6]);
            } else {
                g_req_flags[g_count] = read_flags(auth[1]);
            }
        } else if (containi(auth, "STEAM_") == 0) {
            TrieSetCell(g_auth_trie, auth, g_count);
        } else {
            TrieSetCell(g_nick_trie, auth, g_count);
        }

        g_count++;
    }

    fclose(file);
}

find_player_tag(id, const specific_name[] = "") {
    if (id < 1 || id > MF_MAX_PLAYERS) return;

    new auth[35], name[32];
    get_user_authid(id, auth, charsmax(auth));

    if (specific_name[0]) {
        copy(name, charsmax(name), specific_name);
    } else {
        get_user_name(id, name, charsmax(name));
    }

    new flags = get_user_flags(id);
    g_player_tag_index[id] = -1;

    if (TrieGetCell(g_auth_trie, auth, g_player_tag_index[id])) return;
    if (TrieGetCell(g_nick_trie, name, g_player_tag_index[id])) return;

    for (new i = 0; i < g_count; i++) {
        if (g_req_flags[i] > 0 && (flags & g_req_flags[i]) == g_req_flags[i]) {
            g_player_tag_index[id] = i;
            return;
        }
    }
}

build_chat_prefix(index, bool:is_team_msg, id,
    alive_prefix[], ap_len,
    team_str[],     ts_len,
    tag_prefix[],   tp_len,
    text_prefix[],  txp_len,
    name_prefix[],  np_len,
    &target_team)
{
    new tag_color  = (index == -1) ? 4 : g_tag_color[index];
    new text_color = (index == -1) ? 4 : g_text_color[index];
    new name_color = (index == -1) ? 3 : g_name_color[index];

    new user_team = get_member(id, m_iTeam);
    if (user_team < 0 || user_team > 3) user_team = 0;

    new bool:need_red  = (tag_color == 2 || text_color == 2 || name_color == 2);
    new bool:need_blue = (tag_color == 3 || text_color == 3 || name_color == 3);

    target_team = need_red ? 1 : (need_blue ? 2 : user_team);

    get_color_prefix(tag_color,  tag_prefix,  tp_len);
    get_color_prefix(text_color, text_prefix, txp_len);
    get_color_prefix(name_color, name_prefix, np_len);

    new is_alive = is_user_alive(id);

    alive_prefix[0] = 0;
    if (!is_alive) {
        if (user_team == 1 || user_team == 2)
            copy(alive_prefix, ap_len, "*OLU* ");
        else
            copy(alive_prefix, ap_len, "*IZLEYICI* ");
    }

    team_str[0] = 0;
    if (is_team_msg) {
        switch (user_team) {
            case 1: copy(team_str, ts_len, "(Terrorist) ");
            case 2: copy(team_str, ts_len, "(Counter-Terrorist) ");
            case 3: copy(team_str, ts_len, "(Spectator) ");
            default: copy(team_str, ts_len, "(Team) ");
        }
    }
}

send_chat_to_players(sender_id, const formatted_message[], target_team,
    bool:is_team_msg, bool:sender_alive)
{
    new user_team = get_member(sender_id, m_iTeam);
    if (user_team < 0 || user_team > 3) user_team = 0;

    new alltalk = get_cvar_num("sv_alltalk");
    new maxPlayers = get_maxplayers();
    for (new target = 1; target <= maxPlayers; target++) {
        if (!is_user_connected(target) || is_user_bot(target) || is_user_hltv(target))
            continue;

        if (!alltalk && !sender_alive && is_user_alive(target))
            continue;

        if (is_team_msg && get_member(target, m_iTeam) != user_team)
            continue;

        send_say_text_team_color(target, sender_id, formatted_message, target_team);
    }
}

public cmd_say(id) {
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id))
        return PLUGIN_CONTINUE;

    new message[192];
    read_args(message, charsmax(message));
    remove_quotes(message);
    trim(message);

    // Ignore empty messages, admin messages, and command characters (say /rs, !help, .status)
    if (message[0] == 0 || message[0] == '@' || message[0] == '/' || message[0] == '!' || message[0] == '.')
        return PLUGIN_CONTINUE;

    new index = g_player_tag_index[id];

    new name[32];
    get_user_name(id, name, charsmax(name));

    new alive_prefix[16], team_str[32], tag_prefix[10], text_prefix[10], name_prefix[10];
    new target_team;

    build_chat_prefix(index, false, id,
        alive_prefix, charsmax(alive_prefix),
        team_str,     charsmax(team_str),
        tag_prefix,   charsmax(tag_prefix),
        text_prefix,  charsmax(text_prefix),
        name_prefix,  charsmax(name_prefix),
        target_team);

    new formatted_message[256];

    if (index == -1 || g_tag[index][0] == 0) {
        formatex(formatted_message, charsmax(formatted_message),
            "^x01%s%s%s ^x01: %s%s",
            alive_prefix, name_prefix, name, text_prefix, message);
    } else {
        formatex(formatted_message, charsmax(formatted_message),
            "^x01%s%s%s %s%s ^x01: %s%s",
            alive_prefix, tag_prefix, g_tag[index], name_prefix, name,
            text_prefix, message);
    }

    send_chat_to_players(id, formatted_message, target_team, false, bool:is_user_alive(id));

    new auth[35], user_team = get_member(id, m_iTeam);
    if (user_team < 0 || user_team > 3) user_team = 0;
    
    get_user_authid(id, auth, charsmax(auth));
    log_message("^"%s<%d><%s><%s>^" say ^"%s^"",
        name, get_user_userid(id), auth, g_TeamNames[user_team], message);

    return PLUGIN_HANDLED;
}

public cmd_say_team(id) {
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id))
        return PLUGIN_CONTINUE;

    new message[192];
    read_args(message, charsmax(message));
    remove_quotes(message);
    trim(message);

    // Ignore empty messages, admin messages, and command characters (say /rs, !help, .status)
    if (message[0] == 0 || message[0] == '@' || message[0] == '/' || message[0] == '!' || message[0] == '.')
        return PLUGIN_CONTINUE;

    new index = g_player_tag_index[id];

    new name[32];
    get_user_name(id, name, charsmax(name));

    new alive_prefix[16], team_str[32], tag_prefix[10], text_prefix[10], name_prefix[10];
    new target_team;

    build_chat_prefix(index, true, id,
        alive_prefix, charsmax(alive_prefix),
        team_str,     charsmax(team_str),
        tag_prefix,   charsmax(tag_prefix),
        text_prefix,  charsmax(text_prefix),
        name_prefix,  charsmax(name_prefix),
        target_team);

    new formatted_message[256];

    if (index == -1 || g_tag[index][0] == 0) {
        formatex(formatted_message, charsmax(formatted_message),
            "^x01%s%s%s%s ^x01: %s%s",
            alive_prefix, team_str, name_prefix, name, text_prefix, message);
    } else {
        formatex(formatted_message, charsmax(formatted_message),
            "^x01%s%s%s%s %s%s ^x01: %s%s",
            alive_prefix, team_str, tag_prefix, g_tag[index], name_prefix, name,
            text_prefix, message);
    }

    send_chat_to_players(id, formatted_message, target_team, true, bool:is_user_alive(id));

    new auth[35], user_team = get_member(id, m_iTeam);
    if (user_team < 0 || user_team > 3) user_team = 0;
    
    get_user_authid(id, auth, charsmax(auth));
    log_message("^"%s<%d><%s><%s>^" say_team ^"%s^"",
        name, get_user_userid(id), auth, g_TeamNames[user_team], message);

    return PLUGIN_HANDLED;
}

get_color_prefix(color_id, buffer[], maxlen) {
    switch (color_id) {
        case 1: copy(buffer, maxlen, "^x04");
        case 2: copy(buffer, maxlen, "^x03");
        case 3: copy(buffer, maxlen, "^x03");
        case 4: copy(buffer, maxlen, "^x01");
        default: copy(buffer, maxlen, "^x01");
    }
}

send_say_text_team_color(receiver, sender, const message[], team_id) {
    if (receiver < 1 || receiver > MF_MAX_PLAYERS || sender < 1 || sender > MF_MAX_PLAYERS) return;

    new color_sender;
    switch (team_id) {
        case 1: color_sender = print_team_red;
        case 2: color_sender = print_team_blue;
        case 3: color_sender = print_team_grey;
        default: color_sender = sender;
    }
    client_print_color(receiver, color_sender, "%s", message);
}
