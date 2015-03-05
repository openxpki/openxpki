`import Em from "vendor/ember"`

Component = Em.Component.extend
    search: Em.computed -> @get "content.value"

    focusOut: (evt) ->
        @$().find(".drowdown").removeClass "open"

    focusIn: (evt) ->
        if @get "searchResults.length"
            @$().find(".drowdown").addClass "open"

    searchResults: Em.computed -> []

    selectNeighbor: (diff) ->
        results = @get "searchResults"
        return if not results.length
        a = results.findBy "active", true
        Em.set a, "active", false
        index = (results.indexOf(a) + diff + results.length) % results.length
        a = results[index]
        Em.set a, "active", true

    keyboardNavigation: Em.on "keyDown", (e) ->
        if e.keyCode is 13
            results = @get "searchResults"
            a = results.findBy "active", true
            if a
                @send "selectResult", a
            e.stopPropagation()
            e.preventDefault()
        else if e.keyCode is 9
            @set "seatchResults", []
        else if e.keyCode is 38
            @selectNeighbor -1
            e.stopPropagation()
            e.preventDefault()
        else if e.keyCode is 40
            @selectNeighbor 1
            e.stopPropagation()
            e.preventDefault()

    mouseDown: (evt) ->
        return if evt.target.tagName is "INPUT"
        evt.stopPropagation()
        evt.preventDefault()

    searchIndex: 0
    searchChanged: Em.observer "search", ->
        search = @get "search"
        return if search is @get "searchPrevious"
        @set "searchPrevious", search
        @set "content.value", search
        searchIndex = @incrementProperty "searchIndex"
        @container.lookup("route:openxpki").sendAjax
            data:
                action: "certificate!autocomplete"
                query: search
        .then (doc) =>
            return if searchIndex isnt @get "searchIndex"
            doc = [] if doc.error
            @set "searchResults", doc
            doc[0]?.active = true
            @$().find(".drowdown").addClass "open"

    actions:
        selectResult: (res) ->
            @set "content.value", res.value
            @set "searchPrevious", res.label
            @set "search", res.label
            @$().find(".drowdown").removeClass "open"
            @set "searchResults", []

`export default Component`
