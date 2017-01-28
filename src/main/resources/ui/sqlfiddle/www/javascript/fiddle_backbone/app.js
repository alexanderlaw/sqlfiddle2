define([
    'utils/browserEngines/engines',

    './models/OpenIDConnectProviders',
    './models/UsedFiddle',
    './models/MyFiddleHistory',
    './models/DBTypesList',
    './models/SchemaDef',
    './models/Query',

    './views/DBTypesList',
    './views/QueryEnvironmentsList',
    './views/SchemaDef',
    './views/Query',
    './views/LoginDialog',
    './views/UserOptions',
    './views/MyFiddleDialog',

    './router',
    'utils/renderTerminator',
    'utils/openidconnect',
    'Backbone', 'underscore', 'jquery', 'Handlebars',
    'text!./templates/navbar.html', 'text!./templates/mainContainer.html',
    'text!./templates/textToDdlModal.html', 'text!./templates/myFiddlesModal.html'
], function (
        browserEngines,
        OpenIDConnectProviers, UsedFiddle, MyFiddleHistory, DBTypesList, SchemaDef, Query,
        DBTypesListView, QueryEnvironmentsList, SchemaDefView, QueryView, LoginDialog, UserOptions, MyFiddleDialog,
        Router, renderTerminator, openidconnect,
        Backbone, _, $, Handlebars,
        navbarTemplate, mainContainerTemplate, textToDdlTemplate, myFiddlesTemplate
    ) {

var obj = {

    initialize : function() {

        var navbarCompiledTemplate = Handlebars.compile(navbarTemplate);
        $("#navbar").html(navbarCompiledTemplate({}));

        var mainContainerCompiledTemplate = Handlebars.compile(mainContainerTemplate);
        $("#mainContainer").html(mainContainerCompiledTemplate({}));

        var textToDdlCompiledTemplate = Handlebars.compile(textToDdlTemplate);
        $("#textToDDLModal").html(textToDdlCompiledTemplate({}));

        var myFiddlesCompiledTemplate = Handlebars.compile(myFiddlesTemplate);
        $("#myFiddlesModal").html(myFiddlesCompiledTemplate({}));

        var router = {};

        var oidc = new OpenIDConnectProviers();

        var myFiddleHistory = new MyFiddleHistory();

        var dbTypes = new DBTypesList();

        var schemaDef = new SchemaDef({browserEngines: browserEngines});

        var query = new Query({
            "schemaDef": schemaDef
        });

        var dbTypesListView = new DBTypesListView({
            el: $("#db_type_id")[0],
            collection: dbTypes
        });

        var queryEnvironmentsListView = new QueryEnvironmentsList({
            el: $("#environment")[0],
            "schemaDef": schemaDef
        });

        var schemaDefView = new SchemaDefView({
            id: "schema_ddl",
            model: schemaDef,
            output_el: $("#output"),
            browser_el: $("#browser")
        });

        var queryView = new QueryView({
            id: "sql",
            model: query,
            output_el: $("#output")
        });

        var loginDialog = new LoginDialog({
            el: $("#loginModal")[0],
            collection: oidc
        });

        var myFiddleDialog = new MyFiddleDialog({
            el: $("#myFiddlesModal")[0],
            collection: myFiddleHistory
        });

        var userOptions = new UserOptions({
            el: $("#userOptions .dropdown-menu")[0],
            oidc: oidc,
            myFiddleDialog: myFiddleDialog
        });

        /* UI Changes */
        dbTypes.on("change", function () {
        // see also the router function defined below that also binds to this event
            dbTypesListView.render();
            if (schemaDef.has("dbType")) {
                if (!this.getSelectedType().liveSchema()) {
                    schemaDef.set("ready", (schemaDef.get("short_code").length && schemaDef.get("dbType").id === this.getSelectedType().id));
                }
            }
        });

        schemaDef.on("change", function () {
            if (this.hasChanged("ready")) {
                schemaDefView.updateDependents();
            }

            if (this.hasChanged("errorMessage")) {
                schemaDefView.renderOutput();
            }

            if (this.hasChanged("schema_structure")) {
                schemaDefView.renderSchemaBrowser();
            }
        });

        schemaDef.on("reloaded", function () {
            this.set("dbType", dbTypes.getSelectedType());
            schemaDefView.render();
        });

        query.on("reloaded", function () {
            this.set({"pendingChanges": false}, {silent: true});
            queryEnvironmentsListView.setSelectedEnvironment(this.get("environment"));

            queryEnvironmentsListView.render(dbTypes.getSelectedType().getEnvironments());
            queryView.render();
        });

        schemaDef.on("built failed", function () {
        // see also the router function defined below that also binds to this event
            $("#buildSchema label").prop('disabled', false);
            $("#buildSchema label").html($("#buildSchema label").data("originalValue"));
            schemaDefView.renderOutput();
            schemaDefView.renderSchemaBrowser();
        });

        query.on("change", function () {
            if ((this.hasChanged("sql") || this.hasChanged("statement_separator")) && !this.hasChanged("id") && !this.get("pendingChanges"))
            {
                this.set({"pendingChanges": true}, {silent: true});
            }
        });

        query.on("executed", function () {
        // see also the router function defined below that also binds to this event
            var $button = $(".runQuery");
            $button.prop('disabled', false);
            $button.html($button.data("originalValue"));

            this.set({"pendingChanges": false}, {silent: true});
            queryView.renderOutput();
        });

        /* Non-view object event binding */
        $("#buildSchema").click(function (e) {
            var $button = $("label", this);
            e.preventDefault();

            if ($button.prop('disabled')) {
                return false;
            }

            $button.data("originalValue", $button.html());
            $button.prop('disabled', true).text($.i18n.t("status.buildingSchema"));

            schemaDef.build();
        });

        var handleRunQuery = function (e) {
            var $button = $(".runQuery");
            e.preventDefault();

            if ($button.prop('disabled')) return false;
            $button.data("originalValue", $button.html());
            $button.prop('disabled', true).text($.i18n.t("status.executingSql"));

            queryView.checkForSelectedText();
            query.execute();
        };

        $(".runQuery").click(handleRunQuery);
        $(document).keyup(function (e) {
            if (e.keyCode == 116) // F5
            {
                e.preventDefault();
                handleRunQuery(e);
            }
        });

        $("#runQueryOptions li a").click(function (e) {
            e.preventDefault();
            queryView.setOutputType(this.id);
            queryView.renderOutput();
        });

        $("#queryPrettify").click(function (e) {
            var thisButton = $(this);
            thisButton.attr("disabled", true);
            e.preventDefault();
            $.post("https://sqlformat.org/api/v1/format", {sql: query.get("sql"), reindent: 1, keyword_case: "upper"}, function (resp) {
                query.set({"sql": resp['result']});
                query.trigger('reloaded');
                query.set({"pendingChanges": true});

                thisButton.attr("disabled", false);
            });
        });

        $(".terminator .dropdown-menu a").on('click', function (e) {
            e.preventDefault();

            renderTerminator($(this).closest(".panel"), $(this).attr('href'));

            if ($(this).closest(".panel").hasClass("schema"))
            {
                schemaDefView.handleSchemaChange();
            }
            else // must be the query panel button
            {
                query.set({
                    "pendingChanges": true,
                    "statement_separator": $(this).attr('href')
                }, {silent: true});
            }

        });

        $("#output").on("click", ".depesz", function (e) {
            var fullTextPlan = $(this).closest(".set").find(".executionPlan tr:not(:first)").text();
            $(this).closest("form").find("[name=plan]").val(fullTextPlan);
        });

        $(window).bind('beforeunload', function () {
            if (query.get("pendingChanges"))
                return $.i18n.t("message.unsavedChanges");
        });

        /* Data loading */
        dbTypes.on("reset", function () {
            // When the dbTypes are loaded, everything else is ready to go....
            router = Router.initialize(dbTypes, schemaDef, query, myFiddleHistory, dbTypesListView);

            if (this.length && !this.getSelectedType())
            {
                var visible = this.filter(function(dbtype) {return (dbtype.get('context') != 'host' || dbtype.get('num_hosts') > 0)});
                if (visible.length)
                    this.setSelectedType(visible[0].id, true);
            }

            schemaDef.set({"dbType": this.getSelectedType()}, {silent: true});

            // make sure everything is up-to-date on the page
            dbTypesListView.render();
            queryEnvironmentsListView.render(this.getSelectedType().getEnvironments());
            if (this.getSelectedType().liveSchema()) {
                $(".panel.schema .action_buttons").hide();
                $(".helpTip").css("display", "block");
                schemaDef.set("ready", true);
            } else {
                $(".panel.schema .action_buttons").show();
            }
            schemaDefView.render();
            queryView.render();
        });

        oidc.on("reset", function () {
            // note that this isn't visible until the login button is clicked
            loginDialog.render();
        });

        myFiddleHistory.on("change reset remove", myFiddleHistory.sync, myFiddleHistory);


        /* Events which will trigger new route navigation */

        $("#clear").click(function (e) {
            e.preventDefault();
            schemaDef.reset();
            query.reset();
            queryView.handleQueryChange();
            $("body").unblock();
            router.navigate("!" + dbTypes.getSelectedType().id, {trigger: true});
        });

        $("#sample").click(function (e) {
            e.preventDefault();
            router.navigate("!" + dbTypes.getSelectedType().get("sample_fragment"), {trigger: true});
        });

        dbTypes.on("change", function () {
            dbTypesListView.render();
            queryEnvironmentsListView.render(this.getSelectedType().getEnvironments());
            if (this.getSelectedType().liveSchema)
                router.navigate("!" + this.getSelectedType().id + "/" + (schemaDef.get("short_code") ? schemaDef.get("short_code") : "") +  (query.id ? ("/" + query.id) : ""));
            else if (
                    query.id &&
                    schemaDef.get("short_code").length &&
                    schemaDef.get("dbType").id === this.getSelectedType().id
                )
                router.navigate("!" + this.getSelectedType().id + "/" + schemaDef.get("short_code") + "/" + query.id);
            else if (
                    schemaDef.get("short_code").length &&
                    schemaDef.get("dbType").id == this.getSelectedType().id
                )
                router.navigate("!" + this.getSelectedType().id + "/" + schemaDef.get("short_code"));
            else
                router.navigate("!" + this.getSelectedType().id);

            schemaDef.set("dbType", this.getSelectedType());

        });

        schemaDef.on("built", function () {

            myFiddleHistory.insert(new UsedFiddle({
                "fragment": "!" + this.get("dbType").id + "/" + this.get("short_code"),
                "full_name": this.get("dbType").get("full_name"),
                "structure": this.get("schema_structure")
            }));

            router.navigate("!" + this.get("dbType").id + "/" + this.get("short_code"));
        });

        query.on("executed", function () {
            var schemaDef = this.get("schemaDef");

            if (this.id) {
                myFiddleHistory.insert(new UsedFiddle({
                    "fragment": "!" + schemaDef.get("dbType").id + "/" + schemaDef.get("short_code") + "/" + this.id,
                    "full_name": schemaDef.get("dbType").get("full_name"),
                    "structure": schemaDef.get("schema_structure"),
                    "sql": this.get("sql"),
                    "sets": _.map(this.get("sets"), function (set) {
                                return {
                                    "succeeded": set.SUCCEEDED,
                                    "statement_sql": set.STATEMENT.substring(0,4000),
                                    "row_count": set.RESULTS ? set.RESULTS.DATA.length : 0,
                                    "columns": set.RESULTS ? set.RESULTS.COLUMNS.join(", ") : null,
                                    "resultsets": set.RESULTSETS == null ? null : _.map(set.RESULTSETS, function (rset) {
                                        return {
                                        "row_count": rset.DATA.length,
                                        "columns": rset.COLUMNS.join(", ")
                                        };
                                    }),
                                    "error_message": set.ERRORMESSAGE
                                };
                            })
                }));

                router.navigate(
                    "!" + schemaDef.get("dbType").id + "/" + schemaDef.get("short_code") + "/" + this.id
                );
            }

        });

        dbTypes.fetch();

        openidconnect.getLoggedUserDetails().then(function (userInfo) {
            if (userInfo) {
                userOptions.renderAuthenticated(userInfo);
                myFiddleDialog.setAnonymous(false);
            } else {
                userOptions.renderAnonymous();
                myFiddleDialog.setAnonymous(true);
            }
        }, function () {
            userOptions.renderAnonymous();
            myFiddleDialog.setAnonymous(true);
        });

        _.extend(this, {
                dbTypes: dbTypes,
                schemaDef: schemaDef,
                schemaDefView: schemaDefView,
                queryView: queryView
            });

        return this;

        }

    };

    return obj;

});
