define(["jquery"], function ($) {
    return {
        serviceCall : function (args) {
            if (typeof args.data !== "undefined" && typeof args.data !== "string") {
                args.data = JSON.stringify(args.data);
            }
            args.type = args.type || "GET";
            args.headers = args.headers || {
                    "X-OpenIDM-Username" : "anonymous",
                    "X-OpenIDM-Password" : "anonymous",
                    "X-OpenIDM-NoSession" : "true"
                };

            return $.ajax({
                type: args.type,
                url: '/openidm/' + args.url,
                headers: $.extend({}, args.headers, {
                    "Content-Type": "application/json"
                }),
                dataType: "json",
                data: args.data
            }).fail(function (jqXHR, textStatus, errorThrown) {
                if (jqXHR.status !== 413) {
                    alert($.i18n.t("message.xhrError"));
                }
            });
        }
    };
});