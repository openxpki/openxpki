`import Em from "vendor/ember"`

Component = Em.Component.extend
    sanitizeValue: Em.on "init", ->
        value = @get "content.value"
        if typeof value isnt "string"
            options = @get "options"
            @set "content.value", options[0]?.value or ""

    options: Em.computed "content.{options,prompt,is_optional}", ->
        prompt = @get "content.prompt"
        prompt = "" if not prompt and @get "content.is_optional"
        options = @get "content.options"

        if typeof prompt is "string" and prompt isnt options[0]?.label
            [ label: prompt, value: "" ].concat options
        else
            options

    isStatic: Em.computed "content.{options,editable,is_optional}", ->
        options = @get "content.options"
        isEditable = @get "editable"
        isOptional = @get "is_optional"

        if options.length is 1 and not isEditable and not isOptional
            @set "content.value", options[0].value
            true
        else
            false

    isCustom: Em.computed "options", "content.value", ->
        values = (o.value for o in @get "options")
        value = @get "content.value"
        value not in values

    customize: Em.computed "isCustom", -> @get "isCustom"

    actions:
        customize: ->
            @toggleProperty "customize"
            if not @get "customize"
                if @get "isCustom"
                    @set "content.value", @get("options")[0].value
            Em.run.next => @$("input,select")[0].focus()

`export default Component`
