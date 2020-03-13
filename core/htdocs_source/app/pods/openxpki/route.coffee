import Route from '@ember/routing/route'
import EmberObject, { computed } from '@ember/object'
import { tracked } from '@glimmer/tracking'
import { A } from '@ember/array'
import { later, scheduleOnce, cancel } from '@ember/runloop'
import { inject as injectCtrl } from '@ember/controller'
import { Promise } from 'rsvp'

export default Route.extend
    queryParams:
        # refreshModel==true causes an "in-place" transition, so the model
        # hooks for this route (and any child routes) will re-fire
        startat:
            refreshModel: true
        limit:
            refreshModel: true
        force:
            refreshModel: true

    needReboot: [ "login", "logout", "login!logout", "welcome" ]

    source: tracked
        value:
            page: null
            ping: null
            refresh: null
            structure: null
            rtoken: null
            status: null
            modal: null
            tabs: []
            navEntries: []
            error: null

    beforeModel: (transition) ->
        # "force" is only evaluated above using "refreshModel: true"
        if transition.to.queryParams.force
            delete transition.to.queryParams.force

        model_id = transition.to.params.model_id

        if not @source.navEntries.length or model_id in @needReboot
            @sendAjax data:
                page: "bootstrap!structure"
                baseurl: window.location.pathname

    model: (params, transition) ->
        data = page: params.model_id
        data.limit = params.limit if params.limit
        data.startat = params.startat if params.startat

        entries = @source.navEntries.reduce (p, n) ->
            p.concat(n, n.entries||[])
        , []

        if entries.findBy "key", params.model_id
            data.target = "top"
        else if params.model_id in @needReboot
            data.target = "top"

        @source.page = params.model_id
        @sendAjax
            data: data
        .then (doc) =>
            @source

    doPing: (cfg) ->
        @source.ping = later @, =>
            $.ajax
                url: cfg.href
            @doPing cfg
        , cfg.timeout


    sendAjax: (req) ->
        req.dataType = "json"
        req.type ?= if req?.data?.action then "POST" else "GET"
        req.url ?= Ember.getOwner(this).lookup("controller:config").url
        req.data._ = new Date().getTime()
        $(".loading").addClass "in-progress"

        if req.type is "POST"
            req.data._rtoken = @source.rtoken

        target = req.data.target or "self"
        if target is "self"
            if @source.modal
                target = "modal"
            else if @source.tabs.length > 1
                target = "active"
            else
                target = "top"

        if @source.refresh
            cancel @source.refresh
            @source.refresh = null
            $(".refresh").removeClass "in-progress"

        new Promise (resolve, reject) =>
            $.ajax(req).then (doc) =>
                # work with a copy of @source
                newSource = Object.assign {
                    status: doc.status
                    modal: null
                }, @source

                if doc.ping
                    cancel @source.ping if @source.ping
                    @doPing doc.ping

                if doc.refresh
                    newSource.refresh = later(@, ->
                        @sendAjax data:
                            page: doc.refresh.href
                    , doc.refresh.timeout)
                    scheduleOnce "afterRender", ->
                        $(".refresh").addClass "in-progress"

                if doc.goto
                    if doc.target == '_blank' || /^(http|\/)/.test doc.goto
                        window.location.href = doc.goto
                    else
                        @transitionTo "openxpki", doc.goto

                else if doc.structure
                    newSource.navEntries = doc.structure
                    newSource.user =doc.user
                    newSource.rtoken = doc.rtoken

                else
                    if doc.page and doc.main
                        newSource.tabs = [ @source.tabs... ] # copy tabs to not trigger change observers for now

                        tab =
                            active: true
                            page: doc.page
                            main: doc.main
                            right: doc.right

                        if target is "modal"
                            newSource.modal = tab
                        else if target is "tab"
                            tabs = newSource.tabs
                            tabs.setEach "active", false
                            tabs.pushObject tab
                        else if target is "active"
                            tabs = newSource.tabs
                            index = tabs.indexOf tabs.findBy "active"
                            tabs.replace index, 1, [tab]
                        else # top
                            newSource.tabs
                                .clear()
                                .pushObject tab

                    scheduleOnce "afterRender", ->
                        $(".loading").removeClass "in-progress"

                @source = newSource # trigger observers

                resolve doc
            , (err) =>
                $(".loading").removeClass "in-progress"
                @source.error =
                    message: "The server did not return JSON data as
                    expected.\nMaybe your authentication session has expired."
                resolve {}
