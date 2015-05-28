`import Em from "vendor/ember"`

Route = Em.Route.extend
    queryParams:
        startat:
            refreshModel: true
        limit:
            refreshModel: true


    needReboot: [ "login", "logout", "welcome" ]

    source: Em.computed -> Em.Object.create
        page: null
        structure: null
        status: null
        tabs: []
        navEntries: []

    beforeModel: (req) ->
        source = @get "source"
        model_id = req.params.openxpki.model_id

        if not source.get("structure") or model_id in @needReboot
            @sendAjax data: page: "bootstrap!structure"

    model: (req) ->
        navEntries = @get "source.navEntries"
        data = page: req.model_id
        data.limit = req.limit if req.limit
        data.startat = req.startat if req.startat

        entries = navEntries.reduce (p, n) ->
            p.concat(n, n.entries||[])
        , []
        data.target = "top" if entries.findBy "key", req.model_id

        source = @get "source"
        source.set "page", req.model_id
        @sendAjax
            data: data
        .then (doc) ->
            source

    sendAjax: (req) ->
        req.type ?= if req?.data?.action then "POST" else "GET"
        req.url ?= @controllerFor("config").get "url"
        req.data._ = new Date().getTime()
        $(".loading").addClass "in-progress"

        source = @get "source"
        target = req.data.target or "self"
        if target is "self"
            if source.get "modal"
                target = "modal"
            else if source.get("tabs.length") > 1
                target = "active"
            else
                target = "top"

        $.ajax(req).then (doc) =>
            source.beginPropertyChanges()

            source.set "status", doc.status
            source.set "modal", null

            if doc.goto
                if doc.target == '_blank' || /^(http|\/)/.test doc.goto
                    window.location.href = doc.goto
                else
                    @transitionTo "openxpki", doc.goto

            else if doc.structure
                source.set "navEntries", doc.structure
                source.set "user", doc.user

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
            doc
        , (err) ->
            $(".loading").removeClass "in-progress"
            console.log "Ajax error", err

`export default Route`
