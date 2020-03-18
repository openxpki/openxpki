import Component from '@ember/component'
import types from "../oxivalue-format/types"

OxisectionKeyvalueComponent = Component.extend
    items: Em.computed "content.content.data", ->
        items = @get "content.content.data"
        for i in items
            i.isHead = 1 if i.format is 'head'
        items.filter (item) =>
            types[item.format||'text'](item.value) isnt ''

    actions:
        buttonClick: (button) -> @sendAction "buttonClick", button

export default OxisectionKeyvalueComponent
