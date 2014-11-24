`import Em from "vendor/ember"`

Component = Em.Component.extend
    classNameBindings: [
        "content.is_optional:optional:required"
        "content.class"
    ]

    isBool: Em.computed.equal "content.type", "bool"
    isCertIdentifier: Em.computed.equal "content.type", "cert_identifier"
    isCheckbox: Em.computed.equal "content.type", "checkbox"
    isDate: Em.computed.equal "content.type", "date"
    isDatetime: Em.computed.equal "content.type", "datetime"
    isHidden: Em.computed.equal "content.type", "hidden"
    isPassword: Em.computed.equal "content.type", "password"
    isPasswordVerify: Em.computed.equal "content.type", "passwordverify"
    isSelect: Em.computed.equal "content.type", "select"
    isText: (->
        @get("content.type") not in [
            "bool"
            "cert_identifier"
            "checkbox"
            "date"
            "datetime"
            "hidden"
            "password"
            "passwordverify"
            "select"
            "textarea"
            "uploadarea"
        ]
    ).property "content.type"
    isTextarea: Em.computed.equal "content.type", "textarea"
    isUploadarea: Em.computed.equal "content.type", "uploadarea"

    sFieldSize: (->
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
    ).property "content.size", "content.keysize"

    sKeyFieldSize: (->
        keysize = @get("content.keysize") || "2"
        'col-md-' + keysize
    ).property "content.keysize"

    hasError: Em.computed.bool "content.error"

    resetError: Em.observer "content.value", ->
        @set "content.error"

    handleActionOnChange: Em.observer "content.value", ->
        @sendAction "valueChange", @get "content"

    keyPress: (event) ->
        if event.which is 13
            if @get "content.clonable"
                @send "addClone"
                event.stopPropagation()
                event.preventDefault()

    actions:
        addClone: (field) -> @sendAction "addClone", @get "content"
        delClone: (field) -> @sendAction "delClone", @get "content"

`export default Component`
