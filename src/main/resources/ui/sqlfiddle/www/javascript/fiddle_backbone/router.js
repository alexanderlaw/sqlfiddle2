define([
    './models/OpenIDMResource',
    'jquery',
    'underscore',
    'Backbone',
    "utils/renderTerminator",
    "./models/UsedFiddle"
], function(idm, $, _, Backbone, renderTerminator, UsedFiddle){

    var initialize = function(dbTypes, schemaDef, query, myFiddleHistory, dbTypesListView) {

        var Router = Backbone.Router.extend({

            routes: {
                "!:db_type_id": "DBType", // #!1
                "!:db_type_id/:short_code":"SchemaDef", // #!1/abc12
                "!:db_type_id/:short_code/:query_id":"QueryWithSchema", // #!1/abc12/1
                "!:db_type_id//:query_id":"Query", // #!1//1
                "!:db_type_id/:short_code/:query_id/:set_id":"SetAnchorWithSchema", // #!1/abc12/1/1
                "!:db_type_id//:query_id/:set_id":"SetAnchor" // #!1//1/1
            },

            DBType: function (db_type_id) {
                // update currently-selected dbtype
                dbTypes.setSelectedType(parseInt(db_type_id), true);
                schemaDef.set({"dbType": dbTypes.getSelectedType()});
                dbTypesListView.render();
            },

            SchemaDef: function (db_type_id, short_code) {
                this.loadContent(db_type_id, "!" + db_type_id + "/" + short_code);
            },

            Query: function (db_type_id, query_id) {
                this.QueryWithSchema(db_type_id, "", query_id);
            },

            QueryWithSchema: function (db_type_id, short_code, query_id) {
                this.loadContent(db_type_id, "!" + db_type_id + "/" + short_code + "/" + query_id);
            },

            SetAnchor: function (db_type_id, query_id, set_id) {
                this.SetAnchorWithSchema(db_type_id, "", query_id, set_id);
            },

            SetAnchorWithSchema: function (db_type_id, short_code, query_id, set_id) {

                var selectSet = function () {
                    if ($("#set_" + set_id).length) {
                        window.scrollTo(0,$("#set_" + set_id).offset()["top"]-50);
                        $("#set_" + set_id).addClass("highlight");
                    }
                };

                if (!dbTypes.getSelectedType() || dbTypes.getSelectedType().get("id") !== db_type_id ||
                    schemaDef.get("short_code") !== short_code || query.get("id") !== query_id) {

                    query.bind("reloaded", _.once(selectSet));
                    this.loadContent(db_type_id, "!" + db_type_id + "/" + short_code + "/" + query_id);

                } else {
                    $(".set").removeClass("highlight");
                    selectSet();
                }
            },

            loadContent: function (db_type_id,frag) {

                this.DBType(db_type_id);

                if (query.get("pendingChanges") && !confirm($.i18n.t("message.unsavedChanges"))) {
                    return false;
                }

                schemaDef.set("loading", true);

                $(".helpTip").css("display", "none");
                $("body").block({ message: $.i18n.t("status.loading")});

                return idm.serviceCall({
                    url: "endpoint/loadContent/" + frag.replace(/\//g, '_').replace(/^!/, '')
                })
                .then(function (resp) {
                    schemaDef.set("loading", false);

                    if (resp["short_code"] || resp["id"]) {

                        var selectedDBType = dbTypes.getSelectedType();

                        if (selectedDBType.get("context") === "browser") {
                            schemaDef.get("browserEngines")[selectedDBType.get("className")].buildSchema({

                                short_code: $.trim(resp["short_code"]),
                                statement_separator: resp["schema_statement_separator"],
                                ddl: resp["ddl"],
                                success: function () {

                                    schemaDef.set({
                                        "short_code": resp["short_code"],
                                        "ddl": resp["ddl"],
                                        "ready": true,
                                        "valid": true,
                                        "errorMessage": "",
                                        "statement_separator": resp["schema_statement_separator"],
                                        "dbType": dbTypes.getSelectedType()
                                    });
                                    renderTerminator($(".panel.schema"), resp["schema_statement_separator"]);

                                    if (resp["sql"]) {
                                        myFiddleHistory.insert(new UsedFiddle({
                                            "fragment": "!" + db_type_id + "/" + resp["short_code"] + "/" + resp["id"]
                                        }));

                                        query.set({
                                            "id": resp["id"],
                                            "sql":  resp["sql"],
                                            "statement_separator": resp["query_statement_separator"]
                                        });
                                    } else {
                                        myFiddleHistory.insert(new UsedFiddle({
                                            "fragment": "!" + db_type_id + "/" + resp["short_code"]
                                        }));
                                    }

                                    schemaDef.get("browserEngines")[selectedDBType.get("className")].getSchemaStructure({
                                        callback: function (schemaStruct) {
                                            schemaDef.set({
                                                "schema_structure": schemaStruct
                                            });

                                            schemaDef.trigger("reloaded");

                                            if (resp["sql"]) {
                                                schemaDef.get("browserEngines")[selectedDBType.get("className")].executeQuery({
                                                    sql: resp["sql"],
                                                    statement_separator: resp["query_statement_separator"],
                                                    success: function (sets) {

                                                        query.set({
                                                            "sets": sets
                                                        });

                                                        query.trigger("reloaded");

                                                        $("body").unblock();
                                                    },
                                                    error: function (e) {

                                                        query.set({
                                                            "sets": []
                                                        });

                                                        query.trigger("reloaded");

                                                        $("body").unblock();
                                                    }
                                                });
                                            }
                                            else
                                            {
                                                $("body").unblock();
                                            } // end if resp["sql"]

                                        }
                                    });


                                },
                                error: function (message) {

                                    schemaDef.set({
                                        "short_code": resp["short_code"],
                                        "ddl": resp["ddl"],
                                        "ready": true,
                                        "valid": false,
                                        "errorMessage": message,
                                        "dbType": dbTypes.getSelectedType(),
                                        "statement_separator": resp["schema_statement_separator"],
                                        "schema_structure": []
                                    });

                                    renderTerminator($(".panel.schema"), resp["schema_statement_separator"]);

                                    if (resp["sql"]) {
                                        query.set({
                                            "id": resp["id"],
                                            "sql":  resp["sql"],
                                            "statement_separator": resp["query_statement_separator"],
                                            "schemaDef": schemaDef
                                        });
                                        query.trigger("reloaded");
                                    }

                                    schemaDef.trigger("failed");
                                    schemaDef.trigger("reloaded");

                                    $("body").unblock();

                                }

                            });

                        } else { // context not "browser"

                            schemaDef.set({
                                "short_code": resp["short_code"],
                                "ddl": resp["ddl"] ? resp["ddl"] : resp["preparation"],
                                "ready": true,
                                "valid": true,
                                "errorMessage": "",
                                "statement_separator": resp["schema_statement_separator"],
                                "schema_structure": resp["schema_structure"]
                            });
                            renderTerminator($(".panel.schema"), resp["schema_statement_separator"]);
                            schemaDef.trigger("reloaded");

                            if (resp["sql"]) {
                                myFiddleHistory.insert(new UsedFiddle({
                                    "fragment": "!" + db_type_id + "/" + resp["short_code"] + "/" + resp["id"],
                                    "full_name": resp["full_name"],
                                    "structure": resp["schema_structure"],
                                    "environment": resp["environment"],
                                    "preparation": resp["preparation"],
                                    "sql": resp["sql"],
                                    "sets": _.map(resp["sets"], function (set) {
                                        return {
                                            "succeeded": set.SUCCEEDED,
                                            "statement_sql": set.STATEMENT ? set.STATEMENT.substring(0,4000) : "",
                                            "row_count": set.RESULTS ? set.RESULTS.DATA.length : null,
                                            "columns": set.RESULTS ? set.RESULTS.COLUMNS.join(", ") : null,
                                            "resultsets": set.RESULTSETS == null ? null : _.map(set.RESULTSETS, function (rset) {
                                                return {
                                                "row_count": rset.DATA.length,
                                                "columns": rset.COLUMNS.join(", ")
                                                };
                                            }),
                                            "error_message": set.ERRORMESSAGE,
                                            "warnings": set.WARNINGS ? set.WARNINGS.join("\n") : null
                                        };
                                    })
                                }));

                                query.set({
                                    "id": resp["id"],
                                    "environment": resp["environment"],
                                    "preparation": resp["preparation"],
                                    "sql": resp["sql"],
                                    "sets": resp["sets"],
                                    "statement_separator": resp["query_statement_separator"]
                                });
                                query.trigger("reloaded");
                            } else {
                                myFiddleHistory.insert(new UsedFiddle({
                                    "fragment": "!" + db_type_id + "/" + resp["short_code"],
                                    "full_name": resp["full_name"],
                                    "structure": resp["schema_structure"]
                                }));
                            }

                            $("body").unblock();

                        }

                    } else {
                        $("body").unblock();
                    }
                });
            }

        });

        var router = new Router;
        Backbone.history.start({pushState: false});

        return router;
    };

    return {
        initialize: initialize
    };

});