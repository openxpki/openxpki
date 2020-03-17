import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, computed } from "@ember/object";
/**
Shows a drop-down list of options.

```html
<OxiSelect @list={{data.keys}} @selected={{data.name}} @onChange={{myFunc}}/>
```

@module oxi-select
@param list { array } - List of hashes defining the options.
Each hash is expected to have these keys:
```javascript
[
    { value: 1, label: "Major" },
    { value: 2, label: "Tom" },
]
```
@param onChange { callback} - called if a selection was made.
It gets passed two arguments: *value* and *label* of the selected item.
The callback is also called initially to set the value of the first list item.
*/
export default class OxiSelectComponent extends Component {
    @action
    listChanged(event) {
        if (typeof this.args.onChange !== "function") {
            console.error("<OxiSelect>: Wrong type parameter type for @onChange. Expected: function, given: " + (typeof this.args.onChange));
            return;
        }
        const index = event.target.selectedIndex;
        const item = this.args.list[index];
        this.args.onChange(item.value, item.label);
    }
}
