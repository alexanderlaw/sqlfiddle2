import groovy.sql.Sql
import groovy.sql.DataSet
import org.identityconnectors.framework.common.objects.filter.Filter
import org.forgerock.openicf.misc.scriptedcommon.MapFilterVisitor


    def findDatabase = { schema_name, connection ->

        def sql = new Sql(connection)
        def result = []

        def dbTypeMatcher
        def dbTypeWhere = ""
        def dbTypeWhereParams = []

        if (schema_name) {
            // try to find the db_type_id from within the schema_name. Schema_names have the format of db_X_abcde, where X is the db_type_id
            dbTypeMatcher = schema_name =~ /^db_(\d+)_.*$/;
            if (dbTypeMatcher.size() == 1 && dbTypeMatcher[0].size() == 2) {
                dbTypeWhere = " WHERE h.db_type_id = ?"
                dbTypeWhereParams = [dbTypeMatcher[0][1].toInteger()]
            }

        }

        sql.eachRow("""\
            SELECT 
                d.id as db_type_id, 
                d.simple_name, 
                d.full_name,
                d.list_database_script, 
                d.jdbc_class_name, 
                h.id as host_id, 
                h.jdbc_url_template,
                h.default_database, 
                h.admin_username, 
                h.admin_password 
            FROM 
                db_types d 
                    INNER JOIN hosts h ON 
                        d.id = h.db_type_id
            """ + dbTypeWhere, dbTypeWhereParams) {

            def jdbc_url_template = it.jdbc_url_template
            def populatedUrl = jdbc_url_template.replace("#databaseName#", it.default_database)
            def jdbc_class_name = it.jdbc_class_name
            def simple_name = it.simple_name
            def full_name = it.full_name

            def db_type_id = it.db_type_id
            def host_id = it.host_id

            def schemaNameWhere = ""
            def schemaNameWhereParams = []

            if (schema_name) {
                if (it.simple_name == "MySQL") {
                    schemaNameWhere = " WHERE `Database` = ?"
                } else {
                    schemaNameWhere = " WHERE schema_name = ?"
                }
                schemaNameWhereParams = [schema_name]
            } else {
                if (it.simple_name == "MySQL") {
                    schemaNameWhere = " WHERE `Database` LIKE 'db_${db_type_id}_%'"
                } else {
                    schemaNameWhere = " WHERE schema_name LIKE 'db_${db_type_id}_%'"
                }

            }

            try {

                def hostConnection = Sql.newInstance(populatedUrl, it.admin_username, it.admin_password, it.jdbc_class_name)
                hostConnection.eachRow(it.list_database_script + schemaNameWhere, schemaNameWhereParams) { row ->

                    def name = row.getAt(0)
                    def short_code_matcher = name =~ /^db_\d+_(.*)$/
                    def short_code = short_code_matcher[0][1]
                    populatedUrl = jdbc_url_template.replace("#databaseName#", name)

                    handler {
                        uid name as String
                        id name
                        attribute 'db_type_id', db_type_id
                        attribute 'jdbc_class_name', jdbc_class_name
                        attribute 'simple_name', simple_name
                        attribute 'full_name', full_name
                        attribute 'jdbc_url', populatedUrl
                        attribute 'username', "user_" + db_type_id + "_" + short_code
                        attribute 'pw', db_type_id + "_" + short_code
                    }
                }
                hostConnection.close()

            } catch (e) {
                // must be unable to query the host system
                // TODO: improve this sort of failure handling
            }
        }

        sql.close()

    }

    def findAdminDatabase = { db_type_id, connection ->
        def sql = new Sql(connection)
        def result = []

        sql.eachRow("""\
            SELECT
                d.id as db_type_id,
                d.simple_name,
                d.full_name,
                d.list_database_script,
                d.jdbc_class_name,
                h.id as host_id,
                h.jdbc_url_template,
                h.default_database,
                h.admin_username,
                h.admin_password
            FROM
                db_types d
                    INNER JOIN hosts h ON
                        d.id = h.db_type_id
            WHERE h.db_type_id = ?
            """, [db_type_id.toInteger()]) {
            def name = db_type_id.toString()
            def url_template = it.jdbc_url_template
            def populatedUrl = it.jdbc_url_template.replace("#databaseName#", it.default_database)
            def jdbc_class_name = it.jdbc_class_name
            def simple_name = it.simple_name
            def full_name = it.full_name
            def admin_username = it.admin_username
            def admin_password = it.admin_password
            handler {
                uid name as String
                id name
                attribute 'db_type_id', db_type_id.toInteger()
                attribute 'jdbc_class_name', jdbc_class_name
                attribute 'simple_name', simple_name
                attribute 'full_name', full_name
                attribute 'jdbc_url', populatedUrl
                attribute 'admin_username', admin_username
                attribute 'admin_password', admin_password
                attribute 'jdbc_url_template', url_template
            }
        }
        sql.close()
    }

def schema_name = null

def filter = filter as Filter

if (filter != null) {

    def query = filter.accept(MapFilterVisitor.INSTANCE, null)

    // The only query we support is on the schema_name
    if (query != null && (query.get("left") instanceof String) && (query.get("left") == "__UID__" || query.get("left") == "__NAME__")) {
        schema_name = query.get("right")
    }
    
}
switch ( objectClass.objectClassValue ) {
    case "databases":
        findDatabase(schema_name, connection)
    break
    case "admin_databases":
        findAdminDatabase(schema_name, connection)
    break
}

return new SearchResult()