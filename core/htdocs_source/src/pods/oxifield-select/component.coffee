`import Em from "vendor/ember"`

Component = Em.Component.extend
    initializeValue: Em.on "init", ->
        prompt = @get "content.prompt"
        if prompt
            options = @get "content.options"
            options.unshift
                label: prompt
                value: ""
        else
            options = @get "content.options"
            if @get "content.is_optional"
                if not @get "content.editable"
                    options.unshift
                        label: ""
                        value: ""


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

    sanitizeValue: Em.observer "content.options", ->
        options = (o.value for o in @get "content.options")
        value = @get "content.value"
        if value not in options
            @set "content.value", options[0]

    editing: true
    actions:
        toggleEdit: ->
            @toggleProperty "editing"

`export default Component`
