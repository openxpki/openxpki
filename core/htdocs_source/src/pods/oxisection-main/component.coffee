`import Em from "vendor/ember"`

Component = Em.Component.extend
    isForm: Em.computed.equal "content.type", "form"
    isGrid: Em.computed.equal "content.type", "grid"
    isKeyValue: Em.computed.equal "content.type", "keyvalue"
    isText: Em.computed.equal "content.type", "text"

    buttonsWithDescription: (->
        buttons = @get "content.content.buttons"
        if buttons
            buttons.isAny "description"
        else
            false
    ).property "content.content.buttons.@each.description"

    click: (evt) ->
        if evt.target.tagName is "A" and evt.target.target != '_blank'
            evt.stopPropagation()
            evt.preventDefault()
            @container.lookup("route:openxpki").sendAjax
                data:
                    page:evt.target.href.split("#")[1]
                    target:evt.target.target

    confirmButton: null

    actions:
        execute: (btn) ->
            if event.target.tagName is "BUTTON"
                $(event.target).addClass "btn-loading"

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
