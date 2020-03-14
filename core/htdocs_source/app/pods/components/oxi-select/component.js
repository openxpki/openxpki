import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, computed } from "@ember/object";
/*
<OxiSelect
    @list={{data.keys}}
    @selected={{data.name}}
    @onChange={{mySpecialAction}}
    class="myFormat"
/>

@list is expected to be an array of hashes with these keys:

    {
        value: "..."    // option value
        label: "..."    // option label to show
    }

The @onChange function is called with two arguments: value, label

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
