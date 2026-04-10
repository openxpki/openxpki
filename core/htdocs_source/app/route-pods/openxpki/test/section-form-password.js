export default [
    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "Password",
            title: "Password",
            fields: [
                {
                    type: "password",
                    name: "pwd",
                    label: "Password",
                    tooltip: "Please choose wisely",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified",
                    label: "Password, verifiable",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified_preset",
                    label: "Password, verifiable, preset",
                    value: "123\n",
                    tooltip: "Rinse and repeat",
                },
            ],
        },
    },
]
