import Controller from '@ember/controller'
import { computed, observer } from '@ember/object'
import { set as emSet } from '@ember/object'

export default Controller.extend
    queryParams: [ "count", "limit", "startat", "force" ]
    count: null
    startat: null
    limit: null

    manageActive: observer "model.{navEntries,page}", ->
        page = @get "model.page"
        for entry in @get "model.navEntries"
            emSet entry, "active", entry.key is page
            if entry.entries
                entry.entries.setEach "active", false
                subEntry = entry.entries.findBy "key", page
                if subEntry
                    emSet subEntry, "active",true
                    emSet entry, "active", true
        null

    statusClass: computed "model.status.level", "model.status.message", ->
        level = @get "model.status.level"
        message = @get "model.status.message"
        return "hide" if not message
        return "alert-danger" if level is "error"
        return "alert-success" if level is "success"
        return "alert-warning" if level is "warn"
        return "alert-info"

    autoshowModal: observer "model.modal", ->
        $ ".modal.oxi-main-modal"
        .modal if @get "model.modal" then "show" else "hide"
        .one "hidden.bs.modal", =>
            @set "model.modal"

    autoshowErrorModal: observer "model.error", ->
        $ ".modal.oxi-error-modal"
        .modal if @get "model.error" then "show" else "hide"

    showTabs: computed.gt "model.tabs.length", 1

    actions:
        activateTab: (entry) ->
            tabs = @get "model.tabs"
            tabs.setEach "active", false
            emSet entry, "active", true
            false

        closeTab: (entry) ->
            tabs = @get "model.tabs"
            tabs.removeObject entry
            if not tabs.findBy "active", true
                tabs.set "lastObject.active", true
            false

        reload: -> window.location.reload()
