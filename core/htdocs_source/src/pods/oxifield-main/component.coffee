`import Em from "vendor/ember"`

Component = Em.Component.extend
    classNameBindings: [
        "content.is_optional:optional:required"
        "content.class"
    ]

    type: Em.computed "content.type", -> "oxifield-" + @get "content.type"
    isBool: Em.computed.equal "content.type", "bool"

    sFieldSize: Em.computed "content.size", "content.keysize", ->
        keys = @get "content.keys"
        size = @get "content.size"
        keysize = @get "content.keysize"

        if not size
            if keys
                if not keysize
                    keysize = 2
                size = 7 - keysize
            else
                size = 7

        'col-md-' + size

    sKeyFieldSize: Em.computed "content.keysize", ->
        keysize = @get("content.keysize") || "2"
        'col-md-' + keysize

    hasError: Em.computed.bool "content.error"

    resetError: Em.observer "content.value", ->
        @set "content.error"

    handleActionOnChange: Em.observer "content.value", ->
        @sendAction "valueChange", @get "content"

    keyPress: (event) ->
        if event.keyCode is 9
            if @get "content.clonable"
                if @get "content.value"
                    @send "addClone"
                    event.stopPropagation()
                    event.preventDefault()

    actions:
        addClone: (field) -> @sendAction "addClone", @get "content"
        delClone: (field) -> @sendAction "delClone", @get "content"

`export default Component`
