import Component from "@glimmer/component"

export default Component.extend
    removeLoader: ->
        $(".waiting-for-ember").remove()
