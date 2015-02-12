`import Em from "vendor/ember"`

Component = Em.Component.extend
    search: ""

    focusOut: (evt) ->
        @$().find(".drowdown").removeClass "open"

    focusIn: (evt) ->
        if @get "searchResults.length"
            @$().find(".drowdown").addClass "open"

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
            @set "searchResults", doc
            @$().find(".drowdown").addClass "open"

    actions:
        selectResult: (res) ->
            @set "content.value", res.value
            @set "searchPrevious", res.label
            @set "search", res.label
            @$().find(".drowdown").removeClass "open"

`export default Component`
