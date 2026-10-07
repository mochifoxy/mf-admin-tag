#include <amxmodx>
#include <amxmisc>
#include <reapi>

#define PLUGIN  "MF Admin Tag System"
#define VERSION "2.2"
#define AUTHOR  "MochiFoxy"

#define MF_MAX_PLAYERS 32
#define MAX_ADMIN_TAGS 128
#define MAX_SAYTEXT_LEN 185

#define TASK_DEFERRED_FIND 1000
#define TASK_NAME_CHANGE   2000

new g_auth[MAX_ADMIN_TAGS][35];
new g_tag[MAX_ADMIN_TAGS][32];
new g_tag_color[MAX_ADMIN_TAGS];
new g_text_color[MAX_ADMIN_TAGS];
new g_name_color[MAX_ADMIN_TAGS];
new g_open_bracket[MAX_ADMIN_TAGS][16];
new g_open_color[MAX_ADMIN_TAGS];
new g_close_bracket[MAX_ADMIN_TAGS][16];
new g_close_color[MAX_ADMIN_TAGS];
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

    register_concmd("amx_reloadtags", "cmd_reload_tags", ADMIN_RCON, "- Admin taglarini admin_tags.ini dosyasindan yeniden yukler");

    g_auth_trie = TrieCreate();
    g_nick_trie = TrieCreate();

    load_tags();
}

public plugin_end() {
    if (g_auth_trie) TrieDestroy(g_auth_trie);
    if (g_nick_trie) TrieDestroy(g_nick_trie);
}

public cmd_reload_tags(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) {
        return PLUGIN_HANDLED;
    }

    load_tags();

    new maxPlayers = get_maxplayers();
    for (new i = 1; i <= maxPlayers; i++) {
        if (is_user_connected(i)) {
            find_player_tag(i);
        }
    }

    console_print(id, "[TAG] Admin taglari basariyla yenilendi! (Toplam %d tag aktif)", g_count);
    return PLUGIN_HANDLED;
}

public client_putinserver(id) {
    if (id < 1 || id > MF_MAX_PLAYERS) return;
    
    remove_task(TASK_DEFERRED_FIND + id);
    remove_task(TASK_NAME_CHANGE + id);

    g_player_tag_index[id] = -1;
    find_player_tag(id);
    
    set_task(1.5, "task_deferred_find", TASK_DEFERRED_FIND + id);
}

public client_authorized(id, const authid[]) {
    if (id < 1 || id > MF_MAX_PLAYERS) return;
    
    find_player_tag(id);
}

public task_deferred_find(taskid) {
    new id = taskid - TASK_DEFERRED_FIND;
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id)) return;
    find_player_tag(id);
}

public task_verify_name_tag(taskid) {
    new id = taskid - TASK_NAME_CHANGE;
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id)) return;
    find_player_tag(id);
}

public client_disconnected(id) {
    if (id < 1 || id > MF_MAX_PLAYERS) return;
    
    g_player_tag_index[id] = -1;
    remove_task(TASK_DEFERRED_FIND + id);
    remove_task(TASK_NAME_CHANGE + id);
}

public client_infochanged(id) {
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id)) return;

    new newname[32], oldname[32];
    get_user_info(id, "name", newname, charsmax(newname));
    get_user_name(id, oldname, charsmax(oldname));

    if (!equal(newname, oldname)) {
        find_player_tag(id, newname);
        // Harici isim filtresi/engelleyici eklentilerin mudahalesini sifir lag ile dogrulamak icin 0.1s teyit gorevi
        remove_task(TASK_NAME_CHANGE + id);
        set_task(0.1, "task_verify_name_tag", TASK_NAME_CHANGE + id);
    }
}

load_tags() {
    if (g_auth_trie) TrieClear(g_auth_trie);
    if (g_nick_trie) TrieClear(g_nick_trie);
    g_count = 0;

    new configsdir[64], filepath[128];
    get_configsdir(configsdir, charsmax(configsdir));
    formatex(filepath, charsmax(filepath), "%s/admin_tags.ini", configsdir);

    if (!file_exists(filepath)) {
        new file = fopen(filepath, "w");
        if (file) {
            fputs(file, "; ==========================================================^n");
            fputs(file, ";       MF Admin Chat Tags - Gelismis Tag Sistemi^n");
            fputs(file, "; ==========================================================^n");
            fputs(file, ";^n");
            fputs(file, "; Kullanim Formati:^n");
            fputs(file, "; ^"SteamID/ValveID/Nick/@Yetki^" ^"Tag Metni^" ^"Tag Rengi^" ^"Yazi Rengi^" ^"Isim Rengi^" ^"Bas Susleme^" ^"Bas Renk^" ^"Son Susleme^" ^"Son Renk^"^n");
            fputs(file, ";^n");
            fputs(file, "; Renk Kodlari:^n");
            fputs(file, "; 1 = Yesil^n");
            fputs(file, "; 2 = Kirmizi^n");
            fputs(file, "; 3 = Mavi^n");
            fputs(file, "; 4 = Sari / Normal (Varsayilan)^n");
            fputs(file, "; 5 = Gri (Spectator Grisi)^n");
            fputs(file, "; 6 = Takim Rengi (T ise Kirmizi, CT ise Mavi)^n");
            fputs(file, ";^n");
            fputs(file, "; ONEMLI BILGILER:^n");
            fputs(file, "; 1. SteamID (STEAM_...) ve ValveID (VALVE_...) tam desteklenir.^n");
            fputs(file, "; 2. Susleme istemiyorsaniz ^"^" yazip rengine 0 veya 4 verebilirsiniz.^n");
            fputs(file, "; 3. CS 1.6 motoru geregi tek bir satirda sadece BIR takim rengi (Kirmizi, Mavi veya Gri) bulunabilir.^n");
            fputs(file, "; 4. Ozel taglari (SteamID/ValveID/Nick) USTE, genel yetki (@d, @c vb.) taglarini ALTA yaziniz.^n");
            fputs(file, ";^n");
            fputs(file, "; Ornekler:^n");
            fputs(file, "; ^"STEAM_0:0:123456^"  ^"KURUCU^"   ^"2^" ^"1^" ^"2^"  ^"{^" ^"4^" ^"}^" ^"4^"^n");
            fputs(file, "; ^"VALVE_0:4:987654^"  ^"ADMIN^"    ^"5^" ^"1^" ^"4^"  ^"[^" ^"5^" ^"]^" ^"5^"^n");
            fputs(file, "; ^"MochiFoxy^"         ^"YONETICI^" ^"2^" ^"4^" ^"1^"  ^"[^" ^"2^" ^"]^" ^"2^"^n");
            fputs(file, "; ^"@d^"                ^"VIP^"      ^"3^" ^"1^" ^"4^"  ^"<^" ^"3^" ^">^" ^"3^"^n");
            fputs(file, "; ^"@c^"                ^"KOMUTAN^"  ^"1^" ^"1^" ^"4^"  ^"^"  ^"0^" ^"^"  ^"0^"^n");
            fputs(file, "; ==========================================================^n");
            fclose(file);
        }
        return;
    }

    new file = fopen(filepath, "r");
    if (!file) return;

    new line[256];
    new auth[35], tag[32], tag_color_str[4], text_color_str[4], name_color_str[4];
    new open_bracket[16], open_color_str[4], close_bracket[16], close_color_str[4];
    new auth_lower[35];

    while (!feof(file) && g_count < MAX_ADMIN_TAGS) {
        fgets(file, line, charsmax(line));
        trim(line);

        if (line[0] == 0 || line[0] == ';') continue;

        auth[0] = 0; tag[0] = 0; tag_color_str[0] = 0; text_color_str[0] = 0; name_color_str[0] = 0;
        open_bracket[0] = 0; open_color_str[0] = 0; close_bracket[0] = 0; close_color_str[0] = 0;

        parse(line,
            auth,            charsmax(auth),
            tag,             charsmax(tag),
            tag_color_str,   charsmax(tag_color_str),
            text_color_str,  charsmax(text_color_str),
            name_color_str,  charsmax(name_color_str),
            open_bracket,    charsmax(open_bracket),
            open_color_str,  charsmax(open_color_str),
            close_bracket,   charsmax(close_bracket),
            close_color_str, charsmax(close_color_str)
        );

        if (auth[0] == 0) continue;

        copy(auth_lower, charsmax(auth_lower), auth);
        strtolower(auth_lower);

        // SteamID veya ValveID veya Nick veya BOT kontrolu (Tekrar eden kayitlari engelle)
        if (auth[0] != '@') {
            if (containi(auth, "STEAM_") == 0 || containi(auth, "VALVE_") == 0 || equal(auth_lower, "bot")) {
                if (TrieKeyExists(g_auth_trie, auth_lower)) {
                    continue;
                }
            } else {
                if (TrieKeyExists(g_nick_trie, auth_lower)) {
                    continue;
                }
            }
        }

        copy(g_auth[g_count], charsmax(g_auth[]), auth);
        copy(g_tag[g_count],  charsmax(g_tag[]),  tag);
        g_tag_color[g_count]  = str_to_num(tag_color_str);
        g_text_color[g_count] = str_to_num(text_color_str);
        g_name_color[g_count] = str_to_num(name_color_str);

        if (g_tag_color[g_count] == 0)  g_tag_color[g_count] = 4;
        if (g_text_color[g_count] == 0) g_text_color[g_count] = 4;
        if (g_name_color[g_count] == 0) g_name_color[g_count] = 6; // Varsayilan: Takim Rengi

        copy(g_open_bracket[g_count], charsmax(g_open_bracket[]), open_bracket);
        copy(g_close_bracket[g_count], charsmax(g_close_bracket[]), close_bracket);

        if (open_color_str[0] != 0) {
            g_open_color[g_count] = str_to_num(open_color_str);
        } else {
            g_open_color[g_count] = (open_bracket[0] != 0) ? g_tag_color[g_count] : 0;
        }

        if (close_color_str[0] != 0) {
            g_close_color[g_count] = str_to_num(close_color_str);
        } else {
            g_close_color[g_count] = (close_bracket[0] != 0) ? g_open_color[g_count] : 0;
        }

        g_req_flags[g_count] = 0;

        if (auth[0] == '@') {
            // @FLAG_d veya @d seklindeki yetkileri cozumle
            if (containi(auth, "@FLAG_") == 0) {
                g_req_flags[g_count] = read_flags(auth[6]);
            } else {
                g_req_flags[g_count] = read_flags(auth[1]);
            }
        } else if (containi(auth, "STEAM_") == 0 || containi(auth, "VALVE_") == 0 || equal(auth_lower, "bot")) {
            TrieSetCell(g_auth_trie, auth_lower, g_count);
        } else {
            TrieSetCell(g_nick_trie, auth_lower, g_count);
        }

        g_count++;
    }

    fclose(file);
}

find_player_tag(id, const specific_name[] = "") {
    if (id < 1 || id > MF_MAX_PLAYERS || !is_user_connected(id)) return;

    new auth[35], auth_lower[35], name[32], name_lower[32];
    get_user_authid(id, auth, charsmax(auth));
    copy(auth_lower, charsmax(auth_lower), auth);
    strtolower(auth_lower);

    if (specific_name[0]) {
        copy(name, charsmax(name), specific_name);
    } else {
        get_user_name(id, name, charsmax(name));
    }
    copy(name_lower, charsmax(name_lower), name);
    strtolower(name_lower);

    new flags = get_user_flags(id);
    g_player_tag_index[id] = -1;

    // 1. SteamID / ValveID onceligi
    if (TrieGetCell(g_auth_trie, auth_lower, g_player_tag_index[id])) return;

    // 2. Nickname onceligi
    if (TrieGetCell(g_nick_trie, name_lower, g_player_tag_index[id])) return;

    // 3. Admin yetki flag onceligi (Dosyadaki sira gecerlidir)
    for (new i = 0; i < g_count; i++) {
        if (g_req_flags[i] > 0 && (flags & g_req_flags[i]) == g_req_flags[i]) {
            g_player_tag_index[id] = i;
            return;
        }
    }
}

get_color_prefix(color_id, buffer[], maxlen) {
    switch (color_id) {
        case 1: copy(buffer, maxlen, "^x04"); // Yesil
        case 2: copy(buffer, maxlen, "^x03"); // Kirmizi (Team 1)
        case 3: copy(buffer, maxlen, "^x03"); // Mavi (Team 2)
        case 4: copy(buffer, maxlen, "^x01"); // Sari / Normal
        case 5: copy(buffer, maxlen, "^x03"); // Gri (Team 3)
        case 6: copy(buffer, maxlen, "^x03"); // Takim Rengi
        default: copy(buffer, maxlen, "^x01");
    }
}

resolve_target_team(id, index) {
    new user_team = get_member(id, m_iTeam);
    if (user_team < 0 || user_team > 3) user_team = 0;

    if (index == -1) {
        return user_team;
    }

    new open_col  = g_open_color[index];
    new tag_col   = g_tag_color[index];
    new close_col = g_close_color[index];
    new name_col  = g_name_color[index];
    new text_col  = g_text_color[index];

    // 1. Tag veya suslemelerdeki ozel renk onceligi (Gri, Kirmizi, Mavi)
    if (open_col == 5 || tag_col == 5 || close_col == 5) return 3; // Gri
    if (open_col == 2 || tag_col == 2 || close_col == 2) return 1; // Kirmizi
    if (open_col == 3 || tag_col == 3 || close_col == 3) return 2; // Mavi

    // 2. Isim rengindeki ozel renk onceligi
    if (name_col == 5) return 3; // Gri
    if (name_col == 2) return 1; // Kirmizi
    if (name_col == 3) return 2; // Mavi

    // 3. Yazi rengindeki ozel renk onceligi
    if (text_col == 5) return 3; // Gri
    if (text_col == 2) return 1; // Kirmizi
    if (text_col == 3) return 2; // Mavi

    // 4. Varsayilan: Oyuncunun kendi takim rengi
    return user_team;
}

build_tag_decoration(index, output[], maxlen) {
    output[0] = 0;
    if (index < 0 || index >= g_count) return;

    new open_col_prefix[8], tag_col_prefix[8], close_col_prefix[8];
    get_color_prefix(g_open_color[index], open_col_prefix, charsmax(open_col_prefix));
    get_color_prefix(g_tag_color[index], tag_col_prefix, charsmax(tag_col_prefix));
    get_color_prefix(g_close_color[index], close_col_prefix, charsmax(close_col_prefix));

    new open_str[32], tag_str[48], close_str[32];
    open_str[0] = 0;
    tag_str[0] = 0;
    close_str[0] = 0;

    if (g_open_bracket[index][0] != 0) {
        formatex(open_str, charsmax(open_str), "%s%s", open_col_prefix, g_open_bracket[index]);
    }

    if (g_tag[index][0] != 0) {
        formatex(tag_str, charsmax(tag_str), "%s%s", tag_col_prefix, g_tag[index]);
    }

    if (g_close_bracket[index][0] != 0) {
        formatex(close_str, charsmax(close_str), "%s%s", close_col_prefix, g_close_bracket[index]);
    }

    formatex(output, maxlen, "%s%s%s", open_str, tag_str, close_str);
}

build_chat_context(index, bool:is_team_msg, id,
    alive_prefix[], ap_len,
    team_str[],     ts_len,
    tag_full[],     tf_len,
    text_prefix[],  txp_len,
    name_prefix[],  np_len,
    &target_team)
{
    target_team = resolve_target_team(id, index);

    new text_color = (index == -1) ? 4 : g_text_color[index];
    new name_color = (index == -1) ? 6 : g_name_color[index];

    build_tag_decoration(index, tag_full, tf_len);
    get_color_prefix(text_color, text_prefix, txp_len);
    get_color_prefix(name_color, name_prefix, np_len);

    new user_team = get_member(id, m_iTeam);
    if (user_team < 0 || user_team > 3) user_team = 0;

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
        if (!is_user_connected(target) || is_user_hltv(target))
            continue;

        if (!alltalk && !sender_alive && is_user_alive(target))
            continue;

        if (is_team_msg) {
            new target_team_member = get_member(target, m_iTeam);
            if (target_team_member < 0 || target_team_member > 3) target_team_member = 0;
            if (target_team_member != user_team)
                continue;
        }

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

    // Bos mesajlari, admin say komutlarini ve chat eklenti komutlarini (/rs, !rank, .status vb.) es gec
    if (message[0] == 0 || message[0] == '@' || message[0] == '/' || message[0] == '!' || message[0] == '.')
        return PLUGIN_CONTINUE;

    new index = g_player_tag_index[id];

    new name[32];
    get_user_name(id, name, charsmax(name));

    new alive_prefix[16], team_str[32], tag_full[96], text_prefix[8], name_prefix[8];
    new target_team;

    build_chat_context(index, false, id,
        alive_prefix, charsmax(alive_prefix),
        team_str,     charsmax(team_str),
        tag_full,     charsmax(tag_full),
        text_prefix,  charsmax(text_prefix),
        name_prefix,  charsmax(name_prefix),
        target_team);


    new header[160];
    if (tag_full[0] != 0) {
        formatex(header, charsmax(header), "^x01%s%s%s %s%s ^x01> %s",
            alive_prefix, team_str, tag_full, name_prefix, name, text_prefix);
    } 
    else {
        formatex(header, charsmax(header), "^x01%s%s%s%s ^x01> %s",
            alive_prefix, team_str, name_prefix, name, text_prefix);
    }


    // CS 1.6 SayText buffer tasmasini ve istemci cokmesini (crash) %100 engelleyen dinamik kirpma
    new header_len = strlen(header);
    new max_allowed = MAX_SAYTEXT_LEN - header_len;
    if (max_allowed < 10) max_allowed = 10;
    if (strlen(message) > max_allowed) {
        message[max_allowed] = 0;
    }

    new formatted_message[192];
    formatex(formatted_message, charsmax(formatted_message), "%s%s", header, message);

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

    if (message[0] == 0 || message[0] == '@' || message[0] == '/' || message[0] == '!' || message[0] == '.')
        return PLUGIN_CONTINUE;

    new index = g_player_tag_index[id];

    new name[32];
    get_user_name(id, name, charsmax(name));

    new alive_prefix[16], team_str[32], tag_full[96], text_prefix[8], name_prefix[8];
    new target_team;

    build_chat_context(index, true, id,
        alive_prefix, charsmax(alive_prefix),
        team_str,     charsmax(team_str),
        tag_full,     charsmax(tag_full),
        text_prefix,  charsmax(text_prefix),
        name_prefix,  charsmax(name_prefix),
        target_team);

    new header[160];
    if (tag_full[0] != 0) {
        formatex(header, charsmax(header), "^x01%s%s%s %s%s ^x01> %s",
            alive_prefix, team_str, tag_full, name_prefix, name, text_prefix);
    } else {
        formatex(header, charsmax(header), "^x01%s%s%s%s ^x01> %s",
            alive_prefix, team_str, name_prefix, name, text_prefix);
    }

    new header_len = strlen(header);
    new max_allowed = MAX_SAYTEXT_LEN - header_len;
    if (max_allowed < 10) max_allowed = 10;
    if (strlen(message) > max_allowed) {
        message[max_allowed] = 0;
    }

    new formatted_message[192];
    formatex(formatted_message, charsmax(formatted_message), "%s%s", header, message);

    send_chat_to_players(id, formatted_message, target_team, true, bool:is_user_alive(id));

    new auth[35], user_team = get_member(id, m_iTeam);
    if (user_team < 0 || user_team > 3) user_team = 0;
    
    get_user_authid(id, auth, charsmax(auth));
    log_message("^"%s<%d><%s><%s>^" say_team ^"%s^"",
        name, get_user_userid(id), auth, g_TeamNames[user_team], message);

    return PLUGIN_HANDLED;
}

send_say_text_team_color(receiver, sender, const message[], team_id) {
    if (receiver < 1 || receiver > MF_MAX_PLAYERS || sender < 1 || sender > MF_MAX_PLAYERS) return;

    new color_sender;
    switch (team_id) {
        case 1: color_sender = print_team_red;
        case 2: color_sender = print_team_blue;
        case 3: color_sender = print_team_grey;
        default: color_sender = print_team_default;
    }
    client_print_color(receiver, color_sender, "%s", message);
}
