`import Em from "vendor/ember"`

Route = Em.Route.extend
    beforeModel: (req) ->
        if not @controllerFor("openxpki").get("structure") or req.params.openxpki.model_id in ["login","logout","welcome"]
            @sendAjax
                data:
                    page: "bootstrap!structure"
    model: (req) ->
        @controllerFor("openxpki").set "page", req.model_id
        @sendAjax
            data:
                page: req.model_id
        .then (doc) ->
            [doc]

    setupController: ->

    sendAjax: (data) ->
        data.type = if data?.data?.action then "POST" else "GET"
        data.url ?= @controllerFor("config").get "url"
        data.data._ = (new Date()).getTime()
        $(".loading").show()
        $.ajax(data).then (doc) =>
            @controllerFor("openxpki").set "status", doc.status
            if doc.structure
                @controllerFor("openxpki").set "structure", doc
            if data.data.target is "modal"
                @controllerFor("openxpki").set "modalContent", doc
            else if doc.page and doc.main
                $(".modal.in").modal "hide"
                if data.data.target is "tab"
                    @controllerFor("openxpki").get("content").pushObject doc
                else
                    @controllerFor("openxpki").set "content", [doc]
            if doc.goto
                @transitionTo "openxpki", doc.goto
            Em.run.scheduleOnce "afterRender", ->
                $(".loading").hide()
                $(".btn-loading").removeClass("btn-loading")
            doc
        , (err) ->
            $(".loading").hide()
            $(".btn-loading").removeClass("btn-loading")
            console.log "Ajax error", err

`export default Route`
