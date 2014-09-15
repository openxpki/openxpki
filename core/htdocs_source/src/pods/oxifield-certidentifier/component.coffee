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
        searchIndex = @incrementProperty "searchIndex"
        search = @get "search"
        @set "content.value", search
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
            @set "mutex", true
            @set "search", res.label
            @set "mutex", false
            @$().find(".drowdown").removeClass "open"

`export default Component`
