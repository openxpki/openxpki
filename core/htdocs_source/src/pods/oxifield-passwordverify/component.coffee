`import Em from "vendor/ember"`

Component = Em.Component.extend
    password: ""
    confirm: ""

    confirmFocus: false

    showConfirm: (->
        @get("password") isnt @get("confirm") or @get "confirmFocus"
    ).property "password", "confirm", "confirmFocus"

    valueSetter: Em.observer "password", "confirm", ->
        password = @get "password"
        confirm = @get "confirm"
        if password is confirm
            @set "content.value", password
        else
            @set "content.value", null

    placeholder: (->
        @get("content.placeholder") or "Retype password"
    ).property "content.placeholder"

    label: ""
    updateValue: Em.observer "label", ->
        label = @get "label"
        values = (i.value for i in @get("content.options") when i.label is label)
        if values.length is 1
            @set "content.value", values[0]
        else
            @set "content.value", label

    passwordChange: Em.observer "password", ->
        @set "confirm", ""
        @set "content.error", null

    actions:
        confirmFocusIn: ->
            @set "confirmFocus", true
        confirmFocusOut: ->
            @set "confirmFocus", false
            if @get("password") isnt @get("confirm")
                @set "content.error", "Passwords do not match"

`export default Component`
