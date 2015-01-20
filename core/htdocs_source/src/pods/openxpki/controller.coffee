`import Em from "vendor/ember"`

Controller = Em.ArrayController.extend
    structure: null

    showTabs: (->
        @get("content.length") > 1
    ).property "content.length"

    navEntries: Em.computed.alias "structure.structure"

    manageActive: Em.observer "page", ->
        return if not @get "navEntries"
        page = @get "page"
        for entry in @get "navEntries"
            Em.set entry, "active", false
            if entry.entries
                for e in entry.entries
                    if e.key is page
                        Em.set e, "active", true
                        Em.set entry, "active", true
                    else
                        Em.set e, "active", false
        null


    user: Em.computed.alias "structure.user"

    showLoader: ->  $('#ajaxLoadingModal').modal {backdrop:'static'}
    hideLoader: ->  $('#ajaxLoadingModal').modal 'hide'

    status: null
    statusClass: (->
        level = @get "status.level"
        message = @get "status.message"
        return "hide" if not message
        return "alert-danger" if level is "error"
        return "alert-success" if level is "success"
        return "alert-warning" if level is "warn"
        return "alert-info"
    ).property "status.level", "status.message"

    activeTab: null
    activateLast: Em.observer "content.length", ->
        @set "activeTab", @get("content.length")-1
    markActive: Em.observer "activeTab", ->
        activeTab = @get "activeTab"
        for entry, i in @get("content")
            Em.set entry, "active", i is activeTab

    autoshowModal: Em.observer "modalContent", ->
        if @get "modalContent"
            $(".modal")
                .modal("show")
                .on "hidden.bs.modal", =>
                    @set "modalContent"
        null

    actions:
        activate: (entry) -> @transitionToRoute "openxpki", entry
        activateTab: (entry) -> @set "activeTab", @get("content").indexOf entry
        closeTab: (entry) -> @get("content").removeObject entry

`export default Controller`
