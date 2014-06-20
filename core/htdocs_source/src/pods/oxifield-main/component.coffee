`import Em from "vendor/ember"`

Component = Em.Component.extend
    isBool: Em.computed.equal "content.type", "bool"
    isCertIdentifier: Em.computed.equal "content.type", "cert_identifier"
    isCheckbox: Em.computed.equal "content.type", "checkbox"
    isDate: Em.computed.equal "content.type", "date"
    isDatetime: Em.computed.equal "content.type", "datetime"
    isHidden: Em.computed.equal "content.type", "hidden"
    isPassword: Em.computed.equal "content.type", "password"
    isSelect: Em.computed.equal "content.type", "select"
    isText: (->
        @get("content.type") not in [
            "bool", "cert_identifier", "checkbox", "date", "datetime", "hidden", "password", "select", "textarea", "uploadarea"
        ]
    ).property "content.type"
    isTextarea: Em.computed.equal "content.type", "textarea"
    isUploadarea: Em.computed.equal "content.type", "uploadarea"

    hasError: Em.computed.bool "content.error"

    resetError: Em.observer "content.value", ->
        @set "content.error"

    handleActionOnChange: Em.observer "content.value", ->
        @sendAction "valueChange", @get "content"

    actions:
        addClone: (field) -> @sendAction "addClone", @get "content"
        delClone: (field) -> @sendAction "delClone", @get "content"

`export default Component`
