//
//  GIStructure.m
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIStructure.h"

@implementation GIStructure

@end

/*package com.goinvest.meta;

import com.goinvest.data.Type;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/*
 * Описание брокерской площадки - совокупности рынков {@link Structure.Market} и
 * сеансов {@link Structure.Channel}, необходимых для доступа к данным этих рынков.
 * Описание формируется на основании составленного брокером файла
 * {@code http://<base.broker.path>/statics/marketplaces.json}.
 *
 * Торговая площадка {@link Structure} включает в себя один или более
 * рынков {@link Structure.Market} и описывает возможные сеансы
 * подключени {@link  Structure.Channel}.
 * Под рынком в данном случае понимается набор таблиц и транзакций.
 * Рынок может быть <b>сессионным</b>, т.е. требовать для получения данных и
 * выполнения операции процедуры установления сессии (аутентификации),
 * и <b>общедоступным</b>, данные котого доступны при любой уже имеющейся
 * сессии.
 *
public final class Structure {
    
    static class Parser implements MetaParser<Structure> {
        
        @Override
        public Structure parse(String text) throws JSONException {
            final JSONObject source = new JSONObject(text);
            return new Structure(source);
        }
        
    }
    
    private final Map<String,Channel> channels;
    private final Map<String,Market> markets;
    
    Structure(final JSONObject source) throws JSONException {
        JSONArray array = source.getJSONArray("channels");
        final Map<String,Channel> cm = new LinkedHashMap<String,Channel>();
        for (int i = 0; i < array.length(); i++) {
            final Channel channel = new Channel(array.getJSONObject(i));
            cm.put(channel.id, channel);
        }
        channels = Collections.unmodifiableMap(cm);
        
        array = source.getJSONArray("marketplaces");
        final Map<String,Market> mm = new LinkedHashMap<String,Market>();
        for (int i = 0; i < array.length(); i++) {
            final Market market = new Market(array.getJSONObject(i));
            mm.put(market.id, market);
        }
        markets = Collections.unmodifiableMap(mm);
    }
    
    /**
     * @return Список описаний сеансов.
     *
    public final Map<String,Channel> channels() {
        return channels;
    }
    
    /**
     * @return Список описаний рынков.
     *
    public final Map<String,Market> markets() {
        return markets;
    }
    
    /**
     * Описание сеанса (сессии, логического подключения), которое необходимо
     * установить(аутентифицироваться) для доступа к данным рынка(-ов).
     * В описании рынка {@link Market} указывается код описания сеанса
     * (или <b>any</b> для общедоступного рынка). Доступ к данным рынка
     * обязательно требует наличия сеанса (явно созданного для сеансовых
     * рынков или любого из уже имеющихся для общедоступных), однако
     * один сеанс может использоваться несколькими рынками.
     * Таким образом, если брокер опишет 2 рынка (например, Фондовый и
     * Вылютный), то он может задать отдельную аутентификацию для каждого
     * из них (т.е. потребовать наличия двух сеансов и, соответственно,
     * двух отдельных процедур аутентификации), либо же задать единую.
     *
    public static class Channel {
        
        final String id;
        final String usernamePrefix;
        
        Channel(final String id) {
            this.id = id;
            this.usernamePrefix = "";
        }
        
        Channel(final JSONObject source) throws JSONException {
            id = source.getString("id");
            usernamePrefix = source.optString("username_prefix", "");
        }
        
        /**
         * @return Уникальный в пределах брокера код описания сеанса.
         *
        public final String id() {
            return id;
        }
        
        /**
         * @return Префикс, который должен быть добавлен к имени пользователя при подключении.
         *
        public final String usernamePrefix() {
            return usernamePrefix;
        }
        
        /**
         * @return Имя пользователя, дополненное префиксом в случае, если таковой задан.
         *
        public final String formatUsername(final String username) {
            return (usernamePrefix == null || usernamePrefix.isEmpty()) ? username : usernamePrefix + username;
        }
    }
    
    /**
     * Рынок (рыночная площадка) - набор доступных таблиц.
     *
     *
    public static class Market {
        
        final String id;
        final String channel;
        final String caption;
        final int system;
        final String panel;
        final String panelTitle;
        final Map<String,Table> tables;
        
        Market(final JSONObject source) throws JSONException {
            id = source.getString("id");
            channel = source.getString("channel");
            caption = source.getString("caption");
            panel = source.optString("panel", id);
            panelTitle = source.optString("panelTitle", caption);
            system = source.optInt("system", 0);
            final Map<String,Table> temp = new LinkedHashMap<String,Table>();
            final JSONArray array = source.getJSONArray("tables");
            for (int i = 0; i < array.length(); i++) {
                final Table table = new Table(array.getJSONObject(i));
                temp.put(table.id, table);
            }
            tables = Collections.unmodifiableMap(temp);
        }
        
        /**
         * @return Уникальный в пределах брокерской площадки идентификатор рынка.
         *
        public final String id() {
            return id;
        }
        /**
         * @return Наименование рынка
         *
        public final String caption() {
            return caption;
        }
        /**
         * @return Код описания сеанса, требуемого для доступа к рынку.
         *
        public final String channel() {
            return channel;
        }
        /**
         * @return Набор описаний таблиц, доступных на ранке.
         *
        public final Map<String,Table> tables() {
            return tables;
        }
    }
    
    public static class Table {
        
        final String id;
        final String caption;
        final String panel;
        final String panelTitle;
        final Map<String,Field> fields = new LinkedHashMap<String,Field>();;
        
        Table(final JSONObject source) throws JSONException {
            id = source.getString("id");
            caption = source.optString("caption", id);
            panel = source.optString("panel", id);
            panelTitle = source.optString("panelTitle", caption);
            final JSONArray array = source.getJSONArray("fields");
            for (int i = 0; i < array.length(); i++) {
                final Field field = new Field(array.getJSONObject(i));
                fields.put(field.name, field);
            }
        }
        
        public final String id() {
            return id;
        }
        public final String caption() {
            return caption;
        }
        public final Map<String,Field> fields() {
            return fields;
        }
    }
    
    public static class Field {
        
        final String name;
        final String caption;
        final Type type;
        final int size;
        final boolean key;
        final boolean hidden;
        
        Field(final JSONObject source) throws JSONException {
            name = source.getString("name");
            caption = source.optString("caption", name);
            key = source.optBoolean("key", false);
            hidden = source.optBoolean("hidden", false);
            size = source.optInt("size", 0);
            final Type temp = Enum.valueOf(Type.class, source.getString("type").toUpperCase());
            type = (temp == Type.STRING && size == 1) ? Type.CHAR : temp;
        }
        
        public final String name() {
            return name;
        }
        public final String caption() {
            return caption;
        }
        public final int size() {
            return size;
        }
        public final Type type() {
            return type;
        }
        public final boolean key() {
            return key;
        }
        public final boolean hidden() {
            return hidden;
        }
    }
    
}*/
