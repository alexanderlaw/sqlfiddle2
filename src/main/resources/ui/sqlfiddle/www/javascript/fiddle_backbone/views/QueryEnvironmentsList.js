define (["jquery", "Backbone", "Handlebars", "text!fiddle_backbone/templates/queryEnvironments.html"],
        function ($,Backbone,Handlebars,queryEnvironments) {

    var QueryEnvironmentsListView = Backbone.View.extend({
        initialize: function (options) {
            this.options = options;
            this.compiledTemplate = Handlebars.compile(queryEnvironments);
            this.collection = null;
            this.setSelectedEnvironment("");
        },
        events: {
            "click ul.dropdown-menu a": "clickEnvironment"
        },
        setSelectedEnvironment: function(env) {
            this.selectedEnvironment = env;
            this.options["schemaDef"].set("environment", env);
        },
        clickEnvironment: function (e) {
            e.preventDefault();
            this.setSelectedEnvironment($(e.currentTarget).parent('li').attr("data-environment-id"));
            this.render(this.collection);
        },
        render: function (collection) {
            this.collection = collection;
            if (!this.collection) {
                $(this.el).html("");
                this.setSelectedEnvironment("");
            } else {
                if (!this.collection.get(this.selectedEnvironment)) {
                    this.setSelectedEnvironment("");
                }
                $(this.el).html(
                    this.compiledTemplate({
                        selectedEnvironmentTitle: this.collection.get(this.selectedEnvironment).get("title"),
                        environments: this.collection.map(function (environment) {
                            var json = environment.toJSON();
                            json.selected = (this.selectedEnvironment === environment.id);
                            json.className = (json.selected ? "active" : "");
                            return json;
                        }),
                    })
                );
            }

            return this;
        }
    });

    return QueryEnvironmentsListView;

});
