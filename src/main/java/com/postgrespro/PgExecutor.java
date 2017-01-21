package com.postgrespro.sqlfiddle;

import java.io.*;
import java.sql.*;
import java.util.Map;
import java.security.SecureRandom;
import java.time.format.DateTimeFormatter;
import java.text.SimpleDateFormat;
import org.json.*;

public class PgExecutor {

    private String generateUsername(String userName) {
        long mstime = System.currentTimeMillis();
        if (userName == null) userName = "user";
        userName = userName.replaceAll("(?i)[^0-9^a-z]", "_");
        return String.format("%s_%05d", userName != null  ? userName : "", mstime % 10000);
    }

    private String generatePassword() {
        String chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        int len = 10;
        SecureRandom rnd = new SecureRandom();
        StringBuilder sb = new StringBuilder(len);
        for (int i = 0; i < len; i++)
            sb.append(chars.charAt(rnd.nextInt(chars.length())));
        return sb.toString();
    }

    private Boolean execQuery(Connection conn, String sql) throws SQLException {
        Statement stmt = null;
        try {
            stmt = conn.createStatement();
            stmt.execute(sql);
        } finally {
            if (stmt != null) {
                stmt.close();
            }
        }
        return true;
    }

    private JSONArray getColumnNames(ResultSetMetaData meta) throws SQLException {
        JSONArray result = new JSONArray();
        int columnCount = meta.getColumnCount();
        for (int i = 1; i <= columnCount; i++) {
            result.put(meta.getColumnName(i));
        }
        return result;
    }

    private String clobToString(Clob clob) throws SQLException, IOException {
        Reader read = new InputStreamReader(clob.getAsciiStream());
        StringWriter w = new StringWriter();
        int c = -1;
        while ((c = read.read()) != -1) w.write(c);
        w.flush();
        return w.toString();
    }

    private JSONArray getRowData(ResultSet rs, ResultSetMetaData meta) throws SQLException, IOException {
        JSONArray result = new JSONArray();
        for (int i = 1; i <= meta.getColumnCount(); i++) {
            switch (meta.getColumnType(i)) {
                case java.sql.Types.TIMESTAMP:
                    result.put(rs.getTimestamp(i) != null ? new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(rs.getTimestamp(i)) : null);
                case java.sql.Types.TIME:
                    result.put(rs.getTime(i) != null ? new SimpleDateFormat("HH:mm:ss").format(rs.getTime(i)) : null);
                case java.sql.Types.DATE:
                    result.put(rs.getDate(i) != null ? new SimpleDateFormat("yyyy-MM-dd").format(rs.getDate(i)) : null);
                    break;
                case java.sql.Types.CLOB:
                    result.put(rs.getClob(i) != null ? this.clobToString(rs.getClob(i)) : null);
                    break;
                case java.sql.Types.ARRAY:
                    result.put(rs.getArray(i) != null ? rs.getArray(i).getArray() : null);
                    break;
                case java.sql.Types.OTHER:
                    // for some reason, getObject is indexed starting at 1 instead of 0
                    Object obj = rs.getObject(i);
                    Map nullMap = null;
                    if (obj == null) {
                        result.put(nullMap);
                    } else {
                        String str = "<object>";
                        try {
                            str = obj.toString();
                        } catch (Exception e) {
                        }
                        result.put(str);
                    }
                    break;

                default:
                    result.put(rs.getString(i));
            }
        }
        return result;
    }

    private JSONObject getQueryResult(Connection conn, String sql, StringBuilder log)
      throws SQLException, JSONException, IOException {
        JSONObject result = new JSONObject();
        Boolean plan = sql.matches("(?i:\\s*EXPLAIN.*)");

        result.put("STATEMENT", sql);
        long startTime = System.nanoTime();
        Statement stmt = null;
        try {
            stmt = conn.createStatement();
            Boolean resultSetPresent = stmt.execute(sql);
            result.put("SUCCEEDED", true);
            result.put("EXECUTIONTIME", (System.nanoTime() - startTime) / 1000000);
            JSONArray resultsets = new JSONArray();
            while (resultSetPresent) {
                ResultSet rs = stmt.getResultSet();
                ResultSetMetaData rsmd = rs.getMetaData();
                JSONObject jsonrs = new JSONObject();
                jsonrs.put("COLUMNS", getColumnNames(rsmd));
                JSONArray rows = new JSONArray();
                while (rs.next()) {
                    rsmd = rs.getMetaData();
                    rows.put(getRowData(rs, rsmd));
                }
                jsonrs.put("DATA", rows);
                if (plan) {
                    result.put("EXECUTIONPLAN", jsonrs);
                    result.put("EXECUTIONPLANRAW", jsonrs);
                    break;
                } else {
                    resultsets.put(jsonrs);
                    resultSetPresent = stmt.getMoreResults();
                }
            }
            if (resultsets.length() > 0) {
                result.put("RESULTSETS", resultsets);
            }
        } catch (SQLException e) {
            result.put("SUCCEEDED", false);
            result.put("EXECUTIONTIME", (System.nanoTime() - startTime) / 1000000);
            result.put("ERRORMESSAGE", e.getMessage() + " (SQLState: " + e.getSQLState() + ")");
        } finally {
            if (stmt != null) {
                stmt.close();
            }
        }
        return result;
    }

    private Boolean validTemplateIdentifier(String template_db) {
        return (template_db != null && template_db.length() > 0 &&
                !(template_db.contains("\"") || template_db.contains("'") || template_db.contains("\\")));
    }

    private Boolean prepareDbUser(Connection adminConn, String template_db, String username, String password) throws SQLException {
        this.execQuery(adminConn, String.format("CREATE ROLE \"%s\" WITH LOGIN PASSWORD '%s'", username, password));
        this.execQuery(adminConn, String.format("CREATE DATABASE \"%s\" WITH %s OWNER \"%s\"", username,
             (this.validTemplateIdentifier(template_db) ? "TEMPLATE \"" + template_db + "\"" : ""), username));
        return true;
    }

    private Boolean reassignObjects(Connection adminConn, String username) throws SQLException {
        this.execQuery(adminConn, String.format("REASSIGN OWNED BY admin TO \"%s\"", username));
        return true;
    }

    private Boolean destroyDbUser(Connection adminConn, String username) throws SQLException {
        this.execQuery(adminConn, String.format("DROP DATABASE IF EXISTS \"%s\"", username));
        this.execQuery(adminConn, String.format("DROP ROLE IF EXISTS \"%s\"", username));
        return true;
    }

    private Boolean prepareEnvironment(Connection conn, String preparationScript) throws SQLException {
        if (preparationScript != null && preparationScript.trim().length() > 0) {
            this.execQuery(conn, preparationScript);
        }
        return true;
    }

    public JSONArray execute(String driverClass, String adminConnectionUrl,
                          String adminName, String adminPassword,
                          String connectionUrlTemplate, String userName,
                          String preparationScript, String fullQuery,
                          String template_db,
                          String querySeparator,
                          int isolationLevel,
                          StringBuilder log) throws Exception {

        JSONArray results = new JSONArray();
        String username = this.generateUsername(userName);
        Connection adminConnection = null;
        Connection adminNewDbConnection = null;
        Connection userConnection = null;
        try {
            Class.forName(driverClass);
            adminConnection = DriverManager.getConnection(adminConnectionUrl, adminName, adminPassword);
            String password = this.generatePassword();
            this.prepareDbUser(adminConnection, template_db, username, password);
            if (this.validTemplateIdentifier(template_db)) {
                adminNewDbConnection = DriverManager.getConnection(connectionUrlTemplate.replaceAll("#databaseName#", username), adminName, adminPassword);
                this.reassignObjects(adminNewDbConnection, username);
                adminNewDbConnection.close();
            }

            userConnection = DriverManager.getConnection(connectionUrlTemplate.replaceAll("#databaseName#", username), username, password);
            this.prepareEnvironment(userConnection, preparationScript);

            for (String query : fullQuery.split("[\r\n]" + (querySeparator != null ? querySeparator : "\\") + "[\r\n]")) {
                log.append("query: " + query + "\n");
                if (query.trim().length() > 0) {
                    JSONObject result = this.getQueryResult(userConnection, query, log);
                    results.put(result);
                    log.append("result: " + result.toString());
                }
            }
        } finally {
            if (userConnection != null) {
                try {
                    userConnection.close();
                } catch (Exception ex) {
                    log.append("Failed to close user connection: " + ex.getMessage() + "\n");
                }
            }
            if (adminNewDbConnection != null) {
                try {
                    adminNewDbConnection.close();
                } catch (Exception ex) {
                    log.append("Failed to close admin connection (2): " + ex.getMessage() + "\n");
                }
            }

            if (adminConnection != null) {
                try {
                    this.destroyDbUser(adminConnection, username);
                } catch (Exception ex) {
                    log.append("Failed to destroy user environment: " + ex.getMessage() + "\n");
                }

                try {
                    adminConnection.close();
                } catch (Exception ex) {
                    log.append("Failed to close admin connection: " + ex.getMessage() + "\n");
                }
            }
        }
        return results;
    }

}
