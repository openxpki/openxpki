export default [
    {
        type: "form",
        label: "Datetime",
        content: {
            action: "login!password",
            reset: "login!password",
            fields: [
                {
                    type: "datetime",
                    name: "dt_now",
                    label: "Date, now",
                    placeholder: "Please select a date...",
                    tooltip: "It's now or never!",
                },
                {
                    type: "datetime",
                    name: "dt_now_preset",
                    label: "Date, now (preset)",
                    timezone: "local",
                    value: "now",
                },
                {
                    type: "datetime",
                    name: "dt_some_local",
                    label: "Date, 2020-03-03 03:33 UTC\nepoch = 1583206380",
                    timezone: "local",
                    value: "1583206380",
                },
                {
                    type: "datetime",
                    name: "dt_some",
                    label: "Date, 2020-03-03 03:33 UTC",
                    value: "1583206380",
                    is_optional: 1,
                },
                {
                    type: "datetime",
                    name: "dt_some_pitcairn",
                    label: "Date, 2020-03-03 03:33 UTC",
                    value: "1583206380",
                    timezone: "Pacific/Pitcairn",
                    is_optional: 1,
                },
            ],
        },
    },
]
