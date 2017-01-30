import groovy.sql.Sql
import groovy.sql.DataSet
import org.identityconnectors.framework.common.objects.filter.Filter
import org.forgerock.openicf.misc.scriptedcommon.OperationType
import org.forgerock.openicf.misc.scriptedcommon.MapFilterVisitor
import org.identityconnectors.framework.common.exceptions.ConnectorException


def operation = operation as OperationType
def sql = new Sql(connection)
def updateAttributes = new AttributesAccessor(attributes as Set<Attribute>)

switch ( operation ) {
    case OperationType.UPDATE:
        switch ( objectClass.objectClassValue ) {
            case "admin_databases":
                sql.executeUpdate("""
                    UPDATE
                        hosts h
                    SET
                        admin_username = ?,
                        admin_password = ?
                    WHERE
                        h.db_type_id  = ?
                """,
                [
                    updateAttributes.findString("admin_username"),
                    updateAttributes.findString("admin_password"),
                    uid.uidValue.toInteger()
                ])
                sql.close()
                break;
        }
        break;

    default:
        sql.close()
        throw new ConnectorException("UpdateScript can not handle operation:" + operation.name())
}
sql.close()
return uid
