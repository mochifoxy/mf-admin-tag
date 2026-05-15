/*
* Gereksinim: AMX Mod X 1.8.3 veya üzeri
*/
#include <amxmodx>
#include <amxmisc>
#include <reapi>

#define PLUGIN "Admin Chat Tags Ultra"
#define VERSION "3.0"
#define AUTHOR "MochiFoxy"

#define MAX_ADMIN_TAGS 100

new g_auth[MAX_ADMIN_TAGS][35]; // SteamID, Nick ya da Yetki harfi
new g_tag[MAX_ADMIN_TAGS][32];
new g_tag_color[MAX_ADMIN_TAGS];
new g_text_color[MAX_ADMIN_TAGS];
new g_name_color[MAX_ADMIN_TAGS];
new g_count = 0;

new Trie:g_auth_trie;
new Trie:g_nick_trie;

new g_player_tag_index[33] = { -1, ... };

new const g_TeamNames[][] = {
    "UNASSIGNED",
    "TERRORIST",
    "CT",
    "SPECTATOR"
};

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_clcmd("say", "cmd_say")
    register_clcmd("say_team", "cmd_say_team")
    
    g_auth_trie = TrieCreate();
    g_nick_trie = TrieCreate();
    
    load_tags();
}

public plugin_end() {
    TrieDestroy(g_auth_trie);
    TrieDestroy(g_nick_trie);
}

public client_putinserver(id) {
    g_player_tag_index[id] = -1;
    find_player_tag(id);
}

public client_disconnected(id) {
    g_player_tag_index[id] = -1;
}

public client_infochanged(id) {
    if (!is_user_connected(id))
        return;
        
    new newname[32], oldname[32];
    get_user_info(id, "name", newname, charsmax(newname));
    get_user_name(id, oldname, charsmax(oldname));
    
    if (!equal(newname, oldname)) {
        // Evaluate tag with the new name since the engine hasn't applied it yet
        find_player_tag(id, newname);
    }
}

// Dosyadan taglari cekelim
load_tags() {
    new configsdir[64], filepath[128];
    get_configsdir(configsdir, charsmax(configsdir));
    formatex(filepath, charsmax(filepath), "%s/admin_tags.ini", configsdir);
    
    // Dosya yoksa ayip olmasin diye ornek olustur
    if (!file_exists(filepath)) {
        new file = fopen(filepath, "w");
        if (file) {
            fputs(file, "; Admin Chat Tags Ultra Yapilandirma Dosyasi^n");
            fputs(file, "; Kullanim: ^"SteamID/Nick/FLAG_x^" ^"Tag Metni^" ^"Tag Rengi^" ^"Yazi Rengi^" ^"Isim Rengi^^n");
            fputs(file, "; Renkler: 1=Yesil, 2=Kirmizi, 3=Mavi, 4=Sari/Beyaz^n");
            fputs(file, "; Not: Ayni mesajda hem Kirmizi hem Mavi kullanilamaz. Hangisi once gelirse o gecerli olur.^n");
            fputs(file, ";^n");
            fputs(file, "; ONEMLI NOT: Ustteki kurallar once gecerlidir. O yuzden ozel (nick/steamid) taglari USTE,^n");
            fputs(file, "; genel yetki (FLAG_x) taglarini ALTA yaziniz.^n");
            fputs(file, ";^n");
            fputs(file, "; Ornekler:^n");
            fputs(file, ";^"STEAM_0:0:123456^" ^"Kurucu^" ^"2^" ^"1^" ^"2^"^n");
            fputs(file, ";^"FoxyBlinks^" ^"Support^" ^"1^" ^"4^" ^"3^"^n");
            fputs(file, ";^"FLAG_d^" ^"Admin^" ^"1^" ^"1^" ^"1^"^n");
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
        
        // Bos satirlari ve yorumlari es gec
        if (line[0] == 0 || line[0] == ';') continue;
        
        // Satiri parcalayip verileri alalim
        parse(line, auth, charsmax(auth), tag, charsmax(tag), tag_color_str, charsmax(tag_color_str), text_color_str, charsmax(text_color_str), name_color_str, charsmax(name_color_str));
        
        if (auth[0] == 0) continue;
        
        copy(g_auth[g_count], charsmax(g_auth[]), auth);
        copy(g_tag[g_count], charsmax(g_tag[]), tag);
        g_tag_color[g_count] = str_to_num(tag_color_str);
        g_text_color[g_count] = str_to_num(text_color_str);
        
        g_name_color[g_count] = str_to_num(name_color_str);
        if (g_name_color[g_count] == 0) {
            g_name_color[g_count] = g_tag_color[g_count];
        }
        
        if (containi(auth, "FLAG_") == 0) {
            // Bayrakları Trie'ye eklemiyoruz, dizi üzerinden aranacak.
        } else if (containi(auth, "STEAM_") == 0) {
            TrieSetCell(g_auth_trie, auth, g_count);
        } else {
            TrieSetCell(g_nick_trie, auth, g_count);
        }
        
        g_count++;
    }
    
    fclose(file);
}

// Oyuncunun tagini bulup hafizaya aliyoruz
find_player_tag(id, const specific_name[] = "") {
    new auth[35], name[32];
    get_user_authid(id, auth, charsmax(auth));
    
    if (specific_name[0]) {
        copy(name, charsmax(name), specific_name);
    } else {
        get_user_name(id, name, charsmax(name));
    }
    
    new flags = get_user_flags(id);
    g_player_tag_index[id] = -1;
    
    // 1. SteamID ile ara
    if (TrieGetCell(g_auth_trie, auth, g_player_tag_index[id])) {
        return;
    }
    
    // 2. Nick ile ara
    if (TrieGetCell(g_nick_trie, name, g_player_tag_index[id])) {
        return;
    }
    
    // 3. Yetki (Flag) kontrolü (Dizi üzerinden)
    for (new i = 0; i < g_count; i++) {
        if (containi(g_auth[i], "FLAG_") == 0) {
            new flag_str[10];
            copy(flag_str, charsmax(flag_str), g_auth[i][5]);
            new req_flags = read_flags(flag_str);
            if (req_flags > 0 && (flags & req_flags) == req_flags) {
                g_player_tag_index[id] = i;
                return;
            }
        }
    }
}

public cmd_say(id) {
    if (!is_user_connected(id))
        return PLUGIN_CONTINUE;
        
    new message[192];
    read_args(message, charsmax(message));
    remove_quotes(message);
    trim(message);
    
    if (message[0] == 0 || message[0] == '@')
        return PLUGIN_CONTINUE;
        
    if (message[0] == '/' || message[0] == '.')
        return PLUGIN_HANDLED_MAIN;
        
    new index = g_player_tag_index[id];
    if (index == -1)
        return PLUGIN_CONTINUE;
        
    new name[32];
    get_user_name(id, name, charsmax(name));
        
    new tag[32];
    copy(tag, charsmax(tag), g_tag[index]);
    
    new tag_color = g_tag_color[index];
    new text_color = g_text_color[index];
    new name_color = g_name_color[index];
    
    new formatted_message[192];
    new target_team = 2;
    
    new bool:need_red = (tag_color == 2 || text_color == 2 || name_color == 2);
    new bool:need_blue = (tag_color == 3 || text_color == 3 || name_color == 3);
    
    if (need_red) {
        target_team = 1;
    } else if (need_blue) {
        target_team = 2;
    }
    
    new tag_prefix[10], text_prefix[10], name_prefix[10];
    get_color_prefix(tag_color, tag_prefix, charsmax(tag_prefix));
    get_color_prefix(text_color, text_prefix, charsmax(text_prefix));
    get_color_prefix(name_color, name_prefix, charsmax(name_prefix));
    
    // Olu mu izleyici mi ona bakiyoruz
    new is_alive = is_user_alive(id);
    new alive_prefix[16] = "";
    if (!is_alive) {
        new team = get_member(id, m_iTeam);
        if (team == 1 || team == 2) copy(alive_prefix, charsmax(alive_prefix), "*OLU* ");
        else copy(alive_prefix, charsmax(alive_prefix), "*IZLEYICI* ");
    }
    
    if (tag[0] == 0) {
        formatex(formatted_message, charsmax(formatted_message), "^x01%s%s%s ^x01: %s%s", alive_prefix, name_prefix, name, text_prefix, message);
    } else {
        formatex(formatted_message, charsmax(formatted_message), "^x01%s%s%s %s%s ^x01: %s%s", alive_prefix, tag_prefix, tag, name_prefix, name, text_prefix, message);
    }
    
    new players[32], num;
    get_players(players, num, "ch");
    for (new i = 0; i < num; i++) {
        new target = players[i];
        
        // Olulerin yazdigini diriler gormesin
        if (!is_alive && is_user_alive(target))
            continue;
            
        send_say_text_team_color(target, id, formatted_message, target_team);
    }
    
    new auth[35], user_team = get_member(id, m_iTeam);
    get_user_authid(id, auth, charsmax(auth));
    log_message("^"%s<%d><%s><%s>^" say ^"%s^"", name, get_user_userid(id), auth, g_TeamNames[user_team], message);
    
    return PLUGIN_HANDLED;
}

public cmd_say_team(id) {
    if (!is_user_connected(id))
        return PLUGIN_CONTINUE;
        
    new message[192];
    read_args(message, charsmax(message));
    remove_quotes(message);
    trim(message);
    
    if (message[0] == 0 || message[0] == '@')
        return PLUGIN_CONTINUE;
        
    if (message[0] == '/' || message[0] == '.')
        return PLUGIN_HANDLED_MAIN;
        
    new index = g_player_tag_index[id];
    if (index == -1)
        return PLUGIN_CONTINUE;
        
    new name[32];
    get_user_name(id, name, charsmax(name));
        
    new tag[32];
    copy(tag, charsmax(tag), g_tag[index]);
    
    new tag_color = g_tag_color[index];
    new text_color = g_text_color[index];
    new name_color = g_name_color[index];
    
    new formatted_message[192];
    new target_team = 2;
    
    new bool:need_red = (tag_color == 2 || text_color == 2 || name_color == 2);
    new bool:need_blue = (tag_color == 3 || text_color == 3 || name_color == 3);
    
    if (need_red) {
        target_team = 1;
    } else if (need_blue) {
        target_team = 2;
    }
    
    new tag_prefix[10], text_prefix[10], name_prefix[10];
    get_color_prefix(tag_color, tag_prefix, charsmax(tag_prefix));
    get_color_prefix(text_color, text_prefix, charsmax(text_prefix));
    get_color_prefix(name_color, name_prefix, charsmax(name_prefix));
    
    new user_team = get_member(id, m_iTeam);
    
    // Olu mu izleyici mi ona bakiyoruz
    new is_alive = is_user_alive(id);
    new alive_prefix[16] = "";
    if (!is_alive) {
        if (user_team == 1 || user_team == 2) copy(alive_prefix, charsmax(alive_prefix), "*OLU* ");
        else copy(alive_prefix, charsmax(alive_prefix), "*IZLEYICI* ");
    }
    
    new team_str[32] = "";
    if (user_team == 1) copy(team_str, charsmax(team_str), "(Terrorist) ");
    else if (user_team == 2) copy(team_str, charsmax(team_str), "(Counter-Terrorist) ");
    else if (user_team == 3) copy(team_str, charsmax(team_str), "(Spectator) ");
    else copy(team_str, charsmax(team_str), "(Team) ");
    
    if (tag[0] == 0) {
        formatex(formatted_message, charsmax(formatted_message), "^x01%s%s%s%s ^x01: %s%s", alive_prefix, team_str, name_prefix, name, text_prefix, message);
    } else {
        formatex(formatted_message, charsmax(formatted_message), "^x01%s%s%s%s %s%s ^x01: %s%s", alive_prefix, team_str, tag_prefix, tag, name_prefix, name, text_prefix, message);
    }
    
    new players[32], num;
    get_players(players, num, "ch");
    for (new i = 0; i < num; i++) {
        new target = players[i];
        
        if (get_member(target, m_iTeam) == user_team) {
            // Olulerin yazdigini diriler gormesin
            if (!is_alive && is_user_alive(target))
                continue;
                
            send_say_text_team_color(target, id, formatted_message, target_team);
        }
    }
    
    new auth[35];
    get_user_authid(id, auth, charsmax(auth));
    log_message("^"%s<%d><%s><%s>^" say_team ^"%s^"", name, get_user_userid(id), auth, g_TeamNames[user_team], message);
    
    return PLUGIN_HANDLED;
}

// Renk kodlarini ceviren fonksiyon
get_color_prefix(color_id, buffer[], maxlen) {
    switch (color_id) {
        case 1: copy(buffer, maxlen, "^x04"); // Yesil
        case 2: copy(buffer, maxlen, "^x03"); // Kirmizi (T)
        case 3: copy(buffer, maxlen, "^x03"); // Mavi (CT)
        case 4: copy(buffer, maxlen, "^x01"); // Sari/Beyaz
        default: copy(buffer, maxlen, "^x01");
    }
}

// Renkli mesaj gonderme isi burada
send_say_text_team_color(receiver, sender, const message[], team_id) {
    new bool:changed = false;
    new actual_team = get_member(sender, m_iTeam);
    
    if (actual_team != team_id) {
        message_begin(MSG_ONE, get_user_msgid("TeamInfo"), _, receiver);
        write_byte(sender);
        write_string(g_TeamNames[team_id]);
        message_end();
        changed = true;
    }
    
    message_begin(MSG_ONE, get_user_msgid("SayText"), _, receiver);
    write_byte(sender);
    write_string(message);
    message_end();
    
    if (changed) {
        message_begin(MSG_ONE, get_user_msgid("TeamInfo"), _, receiver);
        write_byte(sender);
        write_string(g_TeamNames[actual_team]);
        message_end();
    }
}
