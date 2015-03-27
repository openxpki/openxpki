`import Em from "vendor/ember"`

Component = Em.Component.extend
    type: Em.computed "content.type", -> "oxisection-" + @get "content.type"

    hasDescription: Em.computed "content.content.buttons.@each.description", ->
        buttons = @get "content.content.buttons"
        if buttons
            buttons.isAny "description"
        else
            false

    confirmButton: null

    actions:
        execute: (btn) ->
            if btn.confirm
                @set "confirmButton", btn
                Em.run.scheduleOnce "afterRender", =>
                    @$().find(".modal").on "hidden.bs.modal", =>
                        if not @isDestroyed
                            @set "confirmButton", null
                    @$().find(".modal").modal "show"
            else
                @send "confirm", btn

        cancel: ->
            @$().find(".btn-loading").removeClass "btn-loading"

        confirm: (btn) ->
            if btn.action
                @container.lookup("route:openxpki").sendAjax
                    data:
                        action:btn.action
            else
                console.log('Transition');
                @container.lookup("route:openxpki").transitionTo "openxpki", btn.page

`export default Component`
