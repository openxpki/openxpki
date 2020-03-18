import Component from '@ember/component';
import moment from "moment";

const OxifieldDatetimeComponent = Component.extend({
    format: "DD.MM.YYYY HH:mm",
    options: {},
    setup: Em.on("didInsertElement", function() {
        let value = this.get("content.value");
        if (value === "now") {
            this.set("content.pickvalue", moment().utc().format(this.get("format")));
        } else if (value) {
            this.set("content.pickvalue", moment.unix(value).utc().format(this.get("format")));
        }
        return Em.run.next(() => {
            return this.$().find(".date").datetimepicker({
                format: this.get("format")
            });
        });
    }),
    propagate: Em.observer("content.pickvalue", function() {
        if (this.get("content.pickvalue") && !this.get("content.value")) {
            this.set("content.pickvalue", moment().utc().format(this.get("format")));
            this.$().find(".date").data("DateTimePicker").setDate(this.get("content.pickvalue"));
        }
        let datetime;
        if (this.get("content.pickvalue") && this.get("content.pickvalue") !== "0") {
            datetime = moment.utc(this.get("content.pickvalue"), this.get("format")).unix();
        } else {
            datetime = "";
        }
        return this.set("content.value", datetime);
    })
});

export default OxifieldDatetimeComponent;