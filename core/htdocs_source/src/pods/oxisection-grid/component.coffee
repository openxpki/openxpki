`import Em from "vendor/ember"`
`import BootstrapContextmenu from 'vendor/bootstrap-contextmenu'`

Component = Em.Component.extend
    visibleColumns: Em.computed "content.content.columns", ->
        @get "content.content.columns"
        .map (col, index) ->
            col.index = index
            col
        .filter (col) -> col.sTitle[0] isnt "_" and col.bVisible isnt 0

    pager: Em.computed "content.content.pager", "visibleColumns", ->
        pager = @get("content.content.pager") || {}
        columns = @get "visibleColumns"

        pager.count ?= 0
        pager.startat ?= 0
        pager.limit ?= Number.MAX_VALUE
        pager.reverse ?= 0
        pager

    pages: Em.computed "pager.{startat,limit,order,reverse}", ->
        pager = @get "pager"
        return [] if not pager
        return [] if pager.count <= pager.limit

        pages = Math.ceil pager.count/pager.limit
        current = Math.floor pager.startat/pager.limit

        o = []
        for i in [0..pages-1]
            o.push
                num: i+1
                active: i is current
                startat: i * pager.limit
                limit: pager.limit
                order: pager.order
                reverse: pager.reverse

        pagersize = pager.pagersize
        if o.length > pagersize
            ellipsis =
                num: "..."
                disabled: true
            pagersize = pagersize - 1
            l = r = pagersize >> 1
            r = r + (pagersize & 1)

            if current <= l
                o.splice pagersize-1, o.length-pagersize, ellipsis
            else if current >= o.length-1-r
                o.splice 1, o.length-pagersize, ellipsis
            else
                o.splice current+r-1, o.length-1-(current+r-1), ellipsis
                o.splice 1, current-(l-1), ellipsis
        o.prev =
            disabled: current is 0
            startat:  (current-1) * pager.limit
            limit: pager.limit
            order: pager.order
            reverse: pager.reverse
        o.next =
            disabled: current is pages-1
            startat:  (current+1) * pager.limit
            limit: pager.limit
            order: pager.order
            reverse: pager.reverse
        o

    pagesizes: Em.computed "pager.{pagesizes,limit,startat,order,reverse}", ->
        pager = @get "pager"
        greater = pager.pagesizes.filter (pagesize) -> pagesize >= pager.count
        limit = Math.min.apply null, greater
        pager.pagesizes
        .filter (pagesize) ->
            pagesize <= limit
        .map (pagesize) ->
            active: pagesize is pager.limit
            limit: pagesize
            startat: (pager.startat/pagesize>>0) * pagesize
            order: pager.order
            reverse: pager.reverse

    columns: Em.computed "visibleColumns",
    "pager.{limit,startat,order,reverse}", ->
        columns = @get "visibleColumns"
        pager = @get "pager"

        for column in columns
            order = if pager.pagerurl
                column.sortkey
            else
                column.sTitle
            reverse = if order is pager.order then not pager.reverse else false

            index: column.index
            sTitle: column.sTitle
            format: column.format
            sortable: not not column.sortkey
            isSorted: pager.order and pager.order is order
            limit: pager.limit
            order: order
            reverse: +reverse
            startat: pager.startat

    data: Em.computed "content.content.data", ->
        data = @get "content.content.data"
        columns = @get "columns"

        titles = @get("content.content.columns").getEach "sTitle"
        classIndex = titles.indexOf "_status"
        if classIndex is -1
            classIndex = titles.indexOf "_className"

        for row, y in data
            className: "gridrow-#{row[classIndex]}"
            originalData: row
            data: for column in columns
                format: column.format
                value: row[column.index]
            checked: false
            originalIndex: y

    sortedData: Em.computed "data", "columns", "pager.reverse", ->
        pager = @get "pager"
        data = @get "data"

        if pager.pagerurl
            data
        else
            data = data.toArray()
            columns = @get "columns"
            column = columns.findBy "isSorted"

            sortNum = columns.indexOf column
            if sortNum >= 0
                re = /^[0-9.]+$/
                data.sort (a,b) ->
                    a = a.data[sortNum].value
                    b = b.data[sortNum].value

                    if re.test(a) and re.test(b)
                        a = parseFloat(a, 10)
                        b = parseFloat(b, 10)

                    if a > b then 1 else -1

                data.reverseObjects() if pager.reverse

            Em.run.scheduleOnce "afterRender", => @initializeContextmenu()
            data

    allChecked: Em.computed "sortedData.@each.checked", ->
        @get("sortedData").isEvery "checked", true

    manageBulkButtons: Em.on "init", Em.observer "sortedData.@each.checked", ->
        data = @get("sortedData").filterBy "checked"
        buttons = @get "content.content.buttons"
        return if not buttons
        for button in buttons.filterBy "select"
            Em.set button, "disabled", not data.length

    isBulkable: Em.computed "content.content.buttons.@each.select", ->
        @get("content.content.buttons")?.isAny "select"

    hasAction: Em.computed.bool "content.content.actions"

    contextIndex: null

    onItem: (context, e) ->
        actions = @get "content.content.actions"
        if actions.length is 1
            action = actions[0]
        else
            action = (a for a in actions when a.label is $(e.target).text())[0]

        columns = @get "content.content.columns"
        index = @get("sortedData")[@get("contextIndex")].originalIndex
        data = @get("content.content.data")[index]
        path = action.path
        for col, i in columns
            path = path.replace "{#{col.sTitle}}", data[i]
            path = path.replace "{col#{i}}", data[i]

        if action.target == "_blank"
            window.location.href = path
        else
            @container.lookup("route:openxpki").sendAjax
                data:
                    page:path
                    target:action.target

    initializeContextmenu: Em.on "didInsertElement", ->
        @$()?.find(".context")
        .contextmenu
            target: @$().find(".dropdown")
            onItem: => @onItem.apply @, arguments
        .off "contextmenu"

    actions:
        buttonClick: (button) ->
            if button.select
                columns = @get("content.content.columns").getEach "sTitle"
                index = columns.indexOf button.select
                if index is -1
                    throw new Error "There is not column matching
                        #{button.select}"

                data = action: button.action

                data[button.selection] = @get "sortedData"
                .filterBy "checked"
                .getEach "originalData"
                .getEach ""+index

                Em.set button, "loading", true
                @container.lookup("route:openxpki").sendAjax
                    data: data
                .then ->
                    Em.set button, "loading", false
            else
                @sendAction "buttonClick", button

        select: (row) ->
            if row
                Em.set row, "checked", not row.checked
            else
                @get("sortedData").setEach "checked", not @get "allChecked"

        page: (page) ->
            return if page.disabled or page.active
            pager = @get "pager"
            @container.lookup("route:openxpki").sendAjax
                data:
                    page: pager.pagerurl
                    limit: page.limit
                    startat: page.startat
                    order: page.order
                    reverse: page.reverse
            .then (res) =>
                @set "content.content.data", res.data
                Em.setProperties pager, page

        sort: (page) ->
            pager = @get "pager"
            if pager.pagerurl
                @send "page", page if page.order
            else
                pager = @get "pager"
                Em.setProperties pager, page

        rowClick: (index) ->
            @set "contextIndex", index
            actions = @get "content.content.actions"
            return if not actions
            if actions.length is 1
                @onItem()
            else
                currentTarget = event.currentTarget
                clientX = event.clientX
                clientY = event.clientY
                Em.run.next =>
                    @$("tbody tr:nth-child(#{index+1})").contextmenu "show",
                        { currentTarget, clientX, clientY }

`export default Component`
