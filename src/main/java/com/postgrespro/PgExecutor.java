package com.postgrespro.sqlfiddle;

import java.io.*;
import java.sql.*;
import java.util.Locale;
import java.util.Map;
import java.util.regex.*;
import java.util.ResourceBundle;
import java.security.SecureRandom;
import java.time.format.DateTimeFormatter;
import java.text.SimpleDateFormat;
import org.json.*;

enum EnvironmentType { SeparateDb, DedicatedCluster };

public class PgExecutor implements AutoCloseable {

    public int MaxColumnSize = 1000;
    public int MaxRowCount = 1000;
    public int MaxWarningsSize = 10000;
    public int MaxResultSetCount = 10;
    public int MaxQueryDuration = 60; // seconds

    private StringBuilder log;
    private Connection adminConnection = null;
    private Connection adminNewDbConnection = null;
    private Connection userConnection = null;
    private String adminName;
    private String adminPassword;
    private String username;
    private String userPassword;
    private String connectionStringTemplate = null;
    private EnvironmentType envType;
    private String dedicatedDbUser = "postgres";
    private JSONObject dedicatedClusterProperties = null;
    private Pattern connectPattern = Pattern.compile("(?mi)\\A\\s*\\\\connect\\s+(.*)$");
    ResourceBundle i18nbundle = null;

    public PgExecutor(StringBuilder log) {
        this.log = log;
        this.i18nbundle = ResourceBundle.getBundle("i18n", Locale.getDefault());
    }

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

    private String validateString(String arg) {
        if (arg == null)
            return arg;
        if (arg.length() > MaxColumnSize) return arg.substring(0, MaxColumnSize) + " ... " + "(truncated)";
        return arg;
    }

    private Object validateArray(Object arg) {
        return arg;
    }

    private JSONArray getRowData(ResultSet rs, ResultSetMetaData meta) throws SQLException, IOException {
        JSONArray result = new JSONArray();
        for (int i = 1; i <= meta.getColumnCount(); i++) {
            switch (meta.getColumnType(i)) {
                case java.sql.Types.TIMESTAMP:
                    result.put(rs.getTimestamp(i) != null ? new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(rs.getTimestamp(i)) : null);
                    break;
                case java.sql.Types.TIME:
                    result.put(rs.getTime(i) != null ? new SimpleDateFormat("HH:mm:ss").format(rs.getTime(i)) : null);
                    break;
                case java.sql.Types.DATE:
                    result.put(rs.getDate(i) != null ? new SimpleDateFormat("yyyy-MM-dd").format(rs.getDate(i)) : null);
                    break;
                case java.sql.Types.CLOB:
                    result.put(validateString(rs.getClob(i) != null ? clobToString(rs.getClob(i)) : null));
                    break;
                case java.sql.Types.ARRAY:
                    result.put(validateArray(rs.getArray(i) != null ? rs.getArray(i).getArray() : null));
                    break;
                case java.sql.Types.OTHER:
                    // for some reason, getObject is indexed starting at 1 instead of 0
                    Object obj = rs.getObject(i);
                    if (obj == null) {
                        result.put(JSONObject.NULL);
                    } else {
                        String str = "<object>";
                        try {
                            str = obj.toString();
                        } catch (Exception e) {
                        }
                        result.put(validateString(str));
                    }
                    break;

                default:
                    result.put(validateString(rs.getString(i)));
            }
        }
        return result;
    }

    private JSONObject getQueryResult(Connection conn, String sql)
      throws Exception {
        JSONObject result = new JSONObject();
        Boolean plan = sql.matches("(?i:\\s*EXPLAIN.*)");

        result.put("STATEMENT", sql);
        long startTime = System.nanoTime();
        Statement stmt = null;
        try {
            stmt = conn.createStatement();
            stmt.setQueryTimeout(MaxQueryDuration);
            Boolean resultSetPresent = stmt.execute(sql);
            result.put("SUCCEEDED", true);
            result.put("EXECUTIONTIME", (System.nanoTime() - startTime) / 1000000);
            JSONArray resultsets = new JSONArray();
            int rsCount = 0;
            while (resultSetPresent) {
                rsCount++;
                if (rsCount > MaxResultSetCount) {
                    throw new Exception(
                        String.format(i18nbundle.getString("error.tooManyResultsets"), MaxResultSetCount));
                }
                ResultSet rs = stmt.getResultSet();
                ResultSetMetaData rsmd = rs.getMetaData();
                JSONObject jsonrs = new JSONObject();
                jsonrs.put("COLUMNS", getColumnNames(rsmd));
                JSONArray rows = new JSONArray();
                int rowCount = 0;
                while (rs.next()) {
                    rsmd = rs.getMetaData();
                    rows.put(getRowData(rs, rsmd));
                    rowCount++;
                    if (rowCount > MaxRowCount) {
                        throw new Exception(
                          String.format(i18nbundle.getString("error.tooManyRows"), MaxRowCount));
                    }
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
            SQLWarning sw = stmt.getWarnings();
            if (sw != null) {
                JSONArray warnings = new JSONArray();
                do {
                    warnings.put(sw.getMessage());
                    if (warnings.toString().length() > MaxWarningsSize) {
                        throw new Exception(
                            String.format(i18nbundle.getString("error.tooLargeWarnings"), MaxWarningsSize));
                    }
                    sw = sw.getNextWarning();
                } while (sw != null);
                result.put("WARNINGS", warnings);
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
        execQuery(adminConn, String.format("CREATE ROLE \"%s\" WITH LOGIN PASSWORD '%s'", username, password));
        execQuery(adminConn, String.format("CREATE DATABASE \"%s\" WITH %s OWNER \"%s\"", username,
             (validTemplateIdentifier(template_db) ? "TEMPLATE \"" + template_db + "\"" : ""), username));
        return true;
    }

    private Boolean reassignObjects(Connection adminConn, String username) throws SQLException {
        execQuery(adminConn, String.format("REASSIGN OWNED BY admin TO \"%s\"", username));
        return true;
    }

    private Boolean destroyDbUser(Connection adminConn, String username) throws SQLException {
        execQuery(adminConn, String.format("DROP DATABASE IF EXISTS \"%s\"", username));
        execQuery(adminConn, String.format("DROP ROLE IF EXISTS \"%s\"", username));
        return true;
    }

    private Boolean prepareEnvironment(Connection conn, String preparationScript) throws SQLException {
        if (preparationScript != null && preparationScript.trim().length() > 0) {
            execQuery(conn, preparationScript);
        }
        return true;
    }

    private StringBuilder executeOSCommandRaw(Connection conn, String command) throws Exception {
        execQuery(conn, "CREATE TEMPORARY TABLE IF NOT EXISTS command_output(output TEXT); TRUNCATE command_output;");
        execQuery(conn,
         String.format("COPY command_output FROM PROGRAM 'sh -c \"%s 2>&1 | sed ''s/\\\\\\\\/\\\\\\\\\\\\\\\\/g'' 2>&1; true\"' (DELIMITER E'\01')",
         command));
        Statement stmt = conn.createStatement();
        StringBuilder sb = new StringBuilder();
        try {
            Boolean resultSetPresent = stmt.execute("SELECT * FROM command_output");
            if (!resultSetPresent) throw new Exception(i18nbundle.getString("error.couldntGetCommandOutput"));
            ResultSet rs = stmt.getResultSet();
            while (rs.next()) {
                sb.append(rs.getString(1));
            }
        } finally {
            stmt.close();
        }
        return sb;
    }

    private JSONObject executeOSCommand(Connection conn, String command) throws Exception {
        StringBuilder sb = executeOSCommandRaw(conn, command);
        try {
            return new JSONObject(sb.toString());
        } catch (Exception ex) {
            log.append("Invalid output: " + sb.toString() + "\n");
            throw ex;
        }
    }

    private JSONObject prepareDedicatedCluster(Connection adminConn, String username) throws Exception {
        String postgres_path = executeOSCommandRaw(adminConn, "readlink -f /proc/`ps -p $$ -o ppid:1=`/exe").toString();
        File postgres_program = new File(postgres_path);
        String program_path = postgres_program.getAbsoluteFile().getParent() + File.separator;
        return executeOSCommand(adminConn, String.format(
         "dbus-send --system --type=method_call --reply-timeout=60000 --print-reply=literal " +
          "--dest=com.postgrespro.PGManager /com/postgrespro/PGManager " +
          "com.postgrespro.PGManager.CreateCluster string:%s string:%s",
         username, program_path
        ));
    }

    private Boolean dropDedicatedCluster(Connection adminConn, JSONObject clusterProperties) throws Exception {
        JSONObject dropResult  = executeOSCommand(adminConn, String.format(
         "dbus-send --system --type=method_call --reply-timeout=60000 --print-reply=literal " +
          "--dest=com.postgrespro.PGManager /com/postgrespro/PGManager " +
          "com.postgrespro.PGManager.DropCluster string:%s string:%s",
         clusterProperties.get("user_name"), clusterProperties.get("program_path")
        ));
        return true;
    }

    public Boolean setAdminConnection(String driverClass, String adminConnectionUrl,
                                      String adminName, String adminPassword) throws ClassNotFoundException, SQLException {
        Class.forName(driverClass);
        adminConnection = DriverManager.getConnection(adminConnectionUrl, adminName, adminPassword);
        this.adminName = adminName;
        this.adminPassword = adminPassword;
        return true;
    }

    public Boolean prepare(String connectionUrlTemplate, String userName,
                           String preparationScript,
                           String environment) throws Exception {

        this.username = generateUsername(userName);
        String dbusername = null;

        if (environment.equals("*")) {
            envType = EnvironmentType.DedicatedCluster;
            JSONObject preparationResult = prepareDedicatedCluster(adminConnection, this.username);
            if (preparationResult.has("result")) {
                dedicatedClusterProperties = (JSONObject)preparationResult.get("result");

                int port = dedicatedClusterProperties.getInt("port_number");
                dbusername = dedicatedDbUser;
                userPassword = dedicatedClusterProperties.getString("postgres_password");
                connectionStringTemplate = connectionUrlTemplate.replaceFirst("(?i)(//[\\w\\d_-]+)(:\\d+)?(/)", "$1:" + port + "$3");
            } else {
                String messages = preparationResult.getString("error");
                dedicatedClusterProperties = null;
                throw new Exception(String.format(i18nbundle.getString("error.failedToCreateCluster"), messages));
            }
        } else {
            envType = EnvironmentType.SeparateDb;
            userPassword = generatePassword();
            prepareDbUser(adminConnection, environment, this.username, userPassword);
            dbusername = this.username;
            if (validTemplateIdentifier(environment)) {
                adminNewDbConnection = DriverManager.getConnection(connectionUrlTemplate.replaceAll("#databaseName#", dbusername), adminName, adminPassword);
                reassignObjects(adminNewDbConnection, dbusername);
                adminNewDbConnection.close();
            }
            connectionStringTemplate = connectionUrlTemplate;
        }
        userConnection = DriverManager.getConnection(connectionStringTemplate.replaceAll("#databaseName#", dbusername), dbusername, userPassword);
        prepareEnvironment(userConnection, preparationScript);

        return true;
    }

    public JSONArray execute(String fullQuery, String querySeparator) throws Exception {

        JSONArray results = new JSONArray();

        for (String query : fullQuery.split("[\r\n]" + (querySeparator != null ? querySeparator : "\\") + "[\r\n]")) {
            log.append("query: " + query + "\n");
            if (query.trim().length() > 0) {
                if (envType == EnvironmentType.DedicatedCluster) {
                    Matcher matcher = connectPattern.matcher(query);
                    if (matcher.find()) {
                        userConnection.close();
                        userConnection = null;
                        userConnection = DriverManager.getConnection(connectionStringTemplate.replaceAll("#databaseName#", matcher.group(1)), dedicatedDbUser, userPassword);
                        query = query.substring(matcher.end());
                        if (query.trim().length() == 0)
                            continue;
                    }
                }
                JSONObject result = getQueryResult(userConnection, query);
                results.put(result);
                log.append("result: " + result.toString() + "\n");
            }
        }
        return results;
    }


    public void close() {
        if (userConnection != null) {
            try {
                userConnection.close();
            } catch (Exception ex) {
                log.append("Failed to close user connection: " + ex.getMessage() + "\n");
            }
            userConnection = null;
        }
        if (adminNewDbConnection != null) {
            try {
                adminNewDbConnection.close();
            } catch (Exception ex) {
                log.append("Failed to close admin connection (2): " + ex.getMessage() + "\n");
            }
            adminNewDbConnection = null;
        }

        if (adminConnection != null) {
            if (envType == EnvironmentType.DedicatedCluster) {
                try {
                    if (dedicatedClusterProperties != null)
                        dropDedicatedCluster(adminConnection, dedicatedClusterProperties);
                } catch (Exception ex) {
                    log.append("Failed to drop dedicated cluster: " + ex.getMessage() + "\n");
                }
            } else {
                try {
                    destroyDbUser(adminConnection, username);
                } catch (Exception ex) {
                    log.append("Failed to destroy user environment: " + ex.getMessage() + "\n");
                }
            }

            try {
                adminConnection.close();
            } catch (Exception ex) {
                log.append("Failed to close admin connection: " + ex.getMessage() + "\n");
            }
            adminConnection = null;
        }
    }
}
