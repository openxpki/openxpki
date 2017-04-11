`import Em from "vendor/ember"`

Route = Em.Route.extend
    queryParams:
        startat:
            refreshModel: true
        limit:
            refreshModel: true
        force:
            refreshModel: true

    setupAjax: Em.on "init", ->
        Em.$.ajaxSetup
            beforeSend: (xhr) ->
                xhr.setRequestHeader "X-OPENXPKI-Client", "1"

    needReboot: [ "login", "logout", "welcome" ]

    source: Em.computed -> Em.Object.create
        page: null
        ping: null
        refresh: null
        structure: null
        rtoken: null
        status: null
        tabs: []
        navEntries: []

    beforeModel: (req) ->
        if req.queryParams.force
            delete req.queryParams.force

        source = @get "source"
        model_id = req.params.openxpki.model_id

        if not source.get("navEntries.length") or model_id in @needReboot
            @sendAjax data:
                page: "bootstrap!structure"
                baseurl: window.location.pathname

    model: (req) ->
        navEntries = @get "source.navEntries"
        data = page: req.model_id
        data.limit = req.limit if req.limit
        data.startat = req.startat if req.startat

        entries = navEntries.reduce (p, n) ->
            p.concat(n, n.entries||[])
        , []

        if entries.findBy "key", req.model_id
            data.target = "top"
        else if req.model_id is "login"
            data.target = "top"

        source = @get "source"
        source.set "page", req.model_id
        @sendAjax
            data: data
        .then (doc) ->
            source

    doPing: (cfg) ->
        @set "source.ping", Em.run.later(@, =>
            Em.$.ajax
                url: cfg.href
            @doPing cfg
        , cfg.timeout)


    sendAjax: (req) ->
        req.dataType = "json"
        req.type ?= if req?.data?.action then "POST" else "GET"
        req.url ?= @controllerFor("config").get "url"
        req.data._ = new Date().getTime()
        $(".loading").addClass "in-progress"

        source = @get "source"
        
        if req.type is "POST" 
            req.data._rtoken = source.rtoken
        
        target = req.data.target or "self"
        if target is "self"
            if source.get "modal"
                target = "modal"
            else if source.get("tabs.length") > 1
                target = "active"
            else
                target = "top"

        if source.get "refresh"
            Em.run.cancel source.get "refresh"
            source.set "refresh", null
            $(".refresh").removeClass "in-progress"

        new Em.RSVP.Promise (resolve, reject) =>
            Em.$.ajax(req).then (doc) =>
                source.beginPropertyChanges()

                source.set "status", doc.status
                source.set "modal", null

                if doc.ping
                    if source.get "ping"
                        Em.run.cancel source.get "ping"
                    @doPing doc.ping

                if doc.refresh
                    source.set "refresh", Em.run.later(@, ->
                        @sendAjax data:
                            page: doc.refresh.href
                    , doc.refresh.timeout)
                    Em.run.scheduleOnce "afterRender", =>
                        $(".refresh").addClass "in-progress"

                if doc.goto
                    if doc.target == '_blank' || /^(http|\/)/.test doc.goto
                        window.location.href = doc.goto
                    else
                        @transitionTo "openxpki", doc.goto

                else if doc.structure
                    source.set "navEntries", doc.structure
                    source.set "user", doc.user
                    source.set "rtoken", doc.rtoken

                else
                    if doc.page and doc.main
                        tab =
                            active: true
                            page: doc.page
                            main: doc.main
                            right: doc.right

                        if target is "modal"
                            source.set "modal", tab
                        else if target is "tab"
                            tabs = source.get "tabs"
                            tabs.setEach "active", false
                            source.get("tabs").pushObject tab
                        else if target is "active"
                            tabs = source.get "tabs"
                            index = tabs.indexOf tabs.findBy "active"
                            tabs.replace index, 1, [tab]
                        else # top
                            source.get("tabs")
                                .clear()
                                .pushObject tab

                    Em.run.scheduleOnce "afterRender", ->
                        $(".loading").removeClass "in-progress"

                source.endPropertyChanges()
                resolve doc
            , (err) =>
                $(".loading").removeClass "in-progress"
                @controllerFor("openxpki").set("model", source)
                Em.run.scheduleOnce "afterRender", ->
                    $ ".modal.oxi-error-modal"
                    .modal "show"
                source.set "error",
                    message: "The server did not return JSON data as
                    expected.\nMaybe your authentication session has expired."
                    resolve {}


`export default Route`
