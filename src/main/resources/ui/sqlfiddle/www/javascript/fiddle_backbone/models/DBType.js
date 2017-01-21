define(["Backbone"], function (Backbone) {
    return Backbone.Model.extend({
        defaults: {
            "sample_fragment":"",
            "notes":"",
            "simple_name": "",
            "full_name": "",
            "available_environments": null,
            "selected": false,
            "context": "host",
            "className": "",
            "num_hosts": 0
        },
        liveSchema: function () {
            return this.get("simple_name") == "PostgreSQL";
        },
        getEnvironments : function () {
            if (!this.get("available_environments")) return null;
            var environments = new Backbone.Collection();
            environments.add({id: "", title: "<Default>"});
            $.each(this.get("available_environments").split(","), function(index, env) {
                environments.add({id: env, title: env});
            });
            return environments;
        }
    });
});