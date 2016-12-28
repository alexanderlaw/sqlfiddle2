vcl 4.0;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

sub vcl_recv {

    if (req.method == "POST" && !req.http.Content-Length) {
        return (synth(411, "Content-Length required"));
    }

    # Require that the content be less than 8000 characters
    if (req.method == "POST" && !req.http.Content-Length ~ "^[1-7]?[0-9]{1,3}$") {
        return (synth(413, "Request content too large (>8000)"));
    }

    if (! (req.url ~ "^/openidm/") ) {
      set req.url = regsub(req.url, "^/", "/sqlfiddle/");
    }

    if ( req.url == "/sqlfiddle/") {
      set req.url = "/sqlfiddle/index.html";
    }

    if (req.method == "GET" && req.url != "/openidm/info/login" && req.url != "/openidm/endpoint/favorites?_queryId=myFavorites") {
        unset req.http.cookie;
    }

    if (req.method == "GET" && req.url == "/openidm/info/ping") {
        set req.http.X-OpenIDM-Username = "anonymous";
        set req.http.X-OpenIDM-Password = "anonymous";
        set req.http.X-OpenIDM-NoSession = "true";
    }

}

sub vcl_backend_response {
    if (bereq.method == "GET") {
        if (bereq.url ~ "/openidm/info/.*" || bereq.url == "/openidm/endpoint/favorites?_queryId=myFavorites") {
            set beresp.ttl = 0s;
        } else {
            set beresp.ttl = 60m;
        }
    }

    if (beresp.status != 200) {
        set beresp.ttl = 0s;
    }
}
