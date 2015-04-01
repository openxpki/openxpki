`import Em from "vendor/ember"`

Component = Em.Component.extend
    tagName: "span"

    actions:
        click: ->
            button = @get "button"
            if button.confirm
                Em.set @get("button"), "loading", true
                @$().find(".modal").modal "show"
            else
                @sendAction "click", button

        confirm: ->
            Em.set @get("button"), "loading", false
            @$().find(".modal").modal "hide"
            @sendAction "click", @get "button"

        cancel: ->
            Em.set @get("button"), "loading", false

`export default Component`
