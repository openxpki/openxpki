`import Em from "vendor/ember"`

Component = Em.Component.extend
    submitLabel: Em.computed "content.content.submit_label", ->
        @get("content.content.submit_label") or "send"

    fields: Em.computed "content.content.fields.@each.name", ->
        fields = @get "content.content.fields"

        for f in fields
            f.placeholder = "" if typeof f.placeholder is "undefined"

        clonables = (f for f in fields when f.clonable)
        names = []
        for clonable in clonables
            if Em.isArray clonable.value
                index = fields.indexOf clonable
                fields.removeAt index
                values = if clonable.value.length then clonable.value else [""]
                clones = values.forEach (value, i) ->
                    clone = Em.copy clonable
                    clone.value = value
                    fields.insertAt index+i, clone
            if clonable.name not in names
                names.push clonable.name

        for name in names
            clones = (f for f in fields when f.name is name)
            Em.set clone, "isLast", false for clone in clones
            Em.set clone, "canDelete", true for clone in clones            
            Em.set clones[clones.length-1], "isLast", true
            if clones.length == 1
                Em.set clones[0], "canDelete", false

        for field in fields
            if field.value and typeof field.value is "object"
                field.name = field.value.key
                field.value = field.value.value

        fields

    visibleFields: Em.computed "fields", ->
        (f for f in @get("fields") when f.type isnt "hidden")

    actions:
        buttonClick: (button) -> @sendAction "buttonClick", button

        addClone: (field) ->
            fields = @get "content.content.fields"
            index = fields.indexOf field
            copy = Em.copy(field)
            copy.value = ""
            fields.insertAt index+1, copy 
        delClone: (field) ->
            fields = @get "content.content.fields"
            index = fields.indexOf field
            fields.removeAt index
        valueChange: (field) ->
            if field.actionOnChange
                fields = @get "content.content.fields"
                data =
                   action: field.actionOnChange
                   _sourceField: field.name

                names = []
                for field in fields
                    names.push field.name if field.name not in names
                for name in names
                    clones = (f for f in fields when f.name is name)
                    if clones.length > 1
                        data[name] = (c.value for c in clones)
                    else
                        data[name] = clones[0].value

                @container.lookup("route:openxpki").sendAjax
                    data: data
                .then (doc) =>
                    for newField in doc.fields
                        for oldField, i in fields
                            if oldField.name is newField.name
                                idx = fields.indexOf oldField
                                fields.replace idx, 1, [Em.copy newField]
                    null

        reset: -> @sendAction "buttonClick", page: @get "content.reset"

        submit: ->
            action = @get "content.action"
            fields = @get "content.content.fields"
            data =
                action:action

            # check validity and gather form data
            isError = false
            names = []
            for field in fields
                if not field.is_optional and not field.value
                    isError = true
                    Em.set field, "error", "Please specify a value"
                else
                    delete field.error
                names.push field.name if field.name not in names

            if isError
                @$().find(".btn-loading").removeClass "btn-loading"
                return

            for name in names
                clones = (f for f in fields when f.name is name)
                if clones[0].clonable
                    data[name] = (c.value for c in clones)
                else
                    data[name] = clones[0].value

            @set "loading", true
            @container.lookup("route:openxpki").sendAjax
                data:data
            .then (res) =>
                @set "loading", false
                errors = res.status?.field_errors
                if errors
                    fields = @get "fields"
                    for error in errors
                        clones = fields.filter (f) -> f.name is error.name
                        if typeof error.index is "undefined"
                            clones.setEach "error", error.error
                        else
                            Em.set clones[error.index], "error", error.error

`export default Component`
