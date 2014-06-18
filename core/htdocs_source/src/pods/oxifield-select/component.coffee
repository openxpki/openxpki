`import Em from "vendor/ember"`

Component = Em.Component.extend
    initializeValue: Em.on "init", ->
        if prompt
            options = @get "content.options"
            options.unshift
                label: prompt
                value: ""
        else
            options = @get "content.options"
            if not @get "content.editable"
                options.unshift
                    label: ""
                    value: ""
        prompt = @get "content.prompt"

    didInsertElement: ->
        @$().find(".typeahead").typeahead
            source: @get("content.options").map (o) -> o.label

    label: ""
    updateValue: Em.observer "label", ->
        label = @get "label"
        values = (i.value for i in @get("content.options") when i.label is label)
        if values.length is 1
            @set "content.value", values[0]
        else
            @set "content.value", label

    editing: true
    actions:
        toggleEdit: ->
            @toggleProperty "editing"

`export default Component`
