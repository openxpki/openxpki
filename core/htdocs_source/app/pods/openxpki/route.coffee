import Route from '@ember/routing/route'
import EmberObject, { computed } from '@ember/object'
import { tracked } from '@glimmer/tracking'
import { A } from '@ember/array'
import { later, scheduleOnce, cancel } from '@ember/runloop'
import { inject as injectCtrl } from '@ember/controller'
import Promise from 'rsvp'

export default Route.extend
    config: injectCtrl()        # injects ConfigController

    queryParams:
        startat:
            refreshModel: true
        limit:
            refreshModel: true
        force:
            refreshModel: true

    setupAjax: @on "init", ->
        $.ajaxSetup
            beforeSend: (xhr) ->
                xhr.setRequestHeader "X-OPENXPKI-Client", "1"

    needReboot: [ "login", "logout", "login!logout", "welcome" ]

    source: EmberObject.extend
        page: tracked()
        ping: tracked()
        refresh: tracked()
        structure: tracked()
        rtoken: tracked()
        status: tracked()
        modal: tracked()
        tabs: A []          # Ember Arrays are automatically tracked
        navEntries: A []    # Ember Arrays are automatically tracked

    beforeModel: (req) ->
        if req.queryParams.force
            delete req.queryParams.force

        model_id = req.params.openxpki.model_id

        if not this.source.navEntries.length or model_id in @needReboot
            @sendAjax data:
                page: "bootstrap!structure"
                baseurl: window.location.pathname

    model: (req) ->
        data = page: req.model_id
        data.limit = req.limit if req.limit
        data.startat = req.startat if req.startat

        entries = this.source.navEntries.reduce (p, n) ->
            p.concat(n, n.entries||[])
        , []

        if entries.findBy "key", req.model_id
            data.target = "top"
        else if req.model_id in @needReboot
            data.target = "top"

        this.source.page = req.model_id
        @sendAjax
            data: data
        .then (doc) ->
            this.source

    doPing: (cfg) ->
        this.source.ping = later @, =>
            $.ajax
                url: cfg.href
            @doPing cfg
        , cfg.timeout


    sendAjax: (req) ->
        req.dataType = "json"
        req.type ?= if req?.data?.action then "POST" else "GET"
        req.url ?= @config.url
        req.data._ = new Date().getTime()
        $(".loading").addClass "in-progress"

        if req.type is "POST"
            req.data._rtoken = this.source.rtoken

        target = req.data.target or "self"
        if target is "self"
            if this.source.modal
                target = "modal"
            else if this.source.tabs.length > 1
                target = "active"
            else
                target = "top"

        if this.source.refresh
            cancel this.source.refresh
            this.source.refresh = null
            $(".refresh").removeClass "in-progress"

        new Promise (resolve, reject) =>
            $.ajax(req).then (doc) =>
                this.source.beginPropertyChanges()

                this.source.status = doc.status
                this.source.modal = null

                if doc.ping
                    cancel this.source.ping if this.source.ping
                    @doPing doc.ping

                if doc.refresh
                    this.source.refresh = later(@, ->
                        @sendAjax data:
                            page: doc.refresh.href
                    , doc.refresh.timeout)
                    scheduleOnce "afterRender", =>
                        $(".refresh").addClass "in-progress"

                if doc.goto
                    if doc.target == '_blank' || /^(http|\/)/.test doc.goto
                        window.location.href = doc.goto
                    else
                        @transitionTo "openxpki", doc.goto

                else if doc.structure
                    this.source.navEntries = doc.structure
                    this.source.user =doc.user
                    this.source.rtoken = doc.rtoken

                else
                    if doc.page and doc.main
                        tab =
                            active: true
                            page: doc.page
                            main: doc.main
                            right: doc.right

                        if target is "modal"
                            this.source.modal = tab
                        else if target is "tab"
                            tabs = this.source.tabs
                            tabs.setEach "active", false
                            this.source.tabs.pushObject tab
                        else if target is "active"
                            tabs = this.source.tabs
                            index = tabs.indexOf tabs.findBy "active"
                            tabs.replace index, 1, [tab]
                        else # top
                            this.source.tabs
                                .clear()
                                .pushObject tab

                    scheduleOnce "afterRender", ->
                        $(".loading").removeClass "in-progress"

                this.source.endPropertyChanges()
                resolve doc
            , (err) =>
                $(".loading").removeClass "in-progress"
                scheduleOnce "afterRender", ->
                    $ ".modal.oxi-error-modal"
                    .modal "show"
                this.source.error =
                    message: "The server did not return JSON data as
                    expected.\nMaybe your authentication session has expired."
                resolve {}
