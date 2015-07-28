`import Em from "vendor/ember"`

Controller = Em.Controller.extend
    queryParams: [ "count", "limit", "startat", "force" ]
    count: null
    startat: null
    limit: null

    manageActive: Em.observer "model.{navEntries,page}", ->
        page = @get "model.page"
        for entry in @get "model.navEntries"
            Em.set entry, "active", entry.key is page
            if entry.entries
                entry.entries.setEach "active", false
                subEntry = entry.entries.findBy "key", page
                if subEntry
                    Em.set subEntry, "active",true
                    Em.set entry, "active", true
        null

    statusClass: Em.computed "model.status.level", "model.status.message", ->
        level = @get "model.status.level"
        message = @get "model.status.message"
        return "hide" if not message
        return "alert-danger" if level is "error"
        return "alert-success" if level is "success"
        return "alert-warning" if level is "warn"
        return "alert-info"

    setupBootstrap: Em.on "didInsertElement", ->
        $(".modal.oxi-main-modal").on "hidden.bs.modal", =>
            @set "model.modal"

    autoshowModal: Em.observer "model.modal", ->
        $ ".modal.oxi-main-modal"
        .modal if @get "model.modal" then "show" else "hide"

    autoshowErrorModal: Em.observer "model.error", ->
        $ ".modal.oxi-error-modal"
        .modal if @get "model.error" then "show" else "hide"

    showTabs: Em.computed.gt "model.tabs.length", 1

    actions:
        activateTab: (entry) ->
            tabs = @get "model.tabs"
            tabs.setEach "active", false
            Em.set entry, "active", true
            false

        closeTab: (entry) ->
            tabs = @get "model.tabs"
            tabs.removeObject entry
            if not tabs.findBy "active", true
                tabs.set "lastObject.active", true
            false

        reload: -> window.location.reload()

`export default Controller`
