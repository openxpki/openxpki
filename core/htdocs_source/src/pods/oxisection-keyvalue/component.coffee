`import Em from "vendor/ember"`
`import types from "../oxivalue-format/types"`

Component = Em.Component.extend
    items: Em.computed "content.content.data", ->
        items = @get "content.content.data"
        items.filter (item) =>
            types[item.format||'text'](item.value) isnt ''

    actions:
        buttonClick: (button) -> @sendAction "buttonClick", button

`export default Component`
