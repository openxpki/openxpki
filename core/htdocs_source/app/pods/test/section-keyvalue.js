export default {
    type: "keyvalue",
    content: {
        label: "oxi-section/keyvalue",
        description: "",
        data: [
            {
                format: "head",
                value: "Scalar types:",
            },
            {
                format: "raw",
                label: "raw",
                value: "Link to <a href=\"https://www.openxpki.org\">OpenXPKI</a>",
            },
            {
                format: "text",
                label: "text",
                value: "Link to <a href=\"should be escaped\">OpenXPKI</a>",
            },
            {
                format: "subject",
                label: "subject",
                value: "CN=sista.example.org:pkiclient,DC=Test Deployment,DC=PKI Examples,DC=OpenXPKI,DC=org",
            },
            {
                format: "text",
                label: "text (as list)",
                value: [ "CN=sista.example.org:pkiclient,", "DC=Test Deployment,", "DC=PKI Examples,", "DC=OpenXPKI,", "DC=org" ],
            },
            {
                format: "nl2br",
                label: "nl2br",
                value: "Link to <a href=\"should be escaped\">OpenXPKI</a>\nand a comment",
            },
            {
                format: "timestamp",
                label: "timestamp",
                value: 1617495633,
            },
            {
                format: "styled",
                label: "styled",
                value: "attention:hear my words",
            },
            {
                format: "certstatus",
                label: "certstatus",
                value: {
                    value: "issued",
                    label: "<i>Issued</i>",
                    tooltip: "It's issued",
                },
            },
            {
                format: "link",
                label: "link",
                value: {
                    page: "workflow!load!wf_id!13567",
                    label: 13567,
                    target: "_blank",
                },
            },
            {
                format: "extlink",
                label: "extlink",
                value: {
                    page: "https://www.openxpki.org",
                    label: "OpenXPKI",
                    target: "_blank",
                },
            },
            {
                format: "email",
                label: "email",
                value: {
                    address: "office@whiterabbitsecurity.com",
                    tooltip: "WRS",
                },
            },
            {
                format: "email",
                label: "email (labeled)",
                value: {
                    address: "office@whiterabbitsecurity.com",
                    label: "WRS",
                    tooltip: "WRS",
                },
            },
            {
                format: "tooltip",
                label: "tooltip (short)",
                value: {
                    value: "Hover me",
                    tooltip: "This is a short tooltip.",
                },
            },
            {
                format: "tooltip",
                label: "tooltip (long)",
                value: {
                    value: "Hover me",
                    tooltip: "This_is_intentionally_a_very_long_tooltip_text that came out of the blue. While it sprung into existence strange waves of gravity formed in a distant galaxy.",
                },
            },
            {
                format: "tooltip",
                label: "tooltip (url - keyvalue)",
                value: {
                    value: "Hover me for username",
                    tooltip_page: "tooltip!user!123",
                    tooltip_page_args: { test: 1 },
                }
            },
            {
                format: "tooltip",
                label: "tooltip (url - chart)",
                value: {
                    value: "Hover me for chart",
                    tooltip_page: "tooltip!chart",
                }
            },
            {
                format: "code",
                label: "code",
                value: "console.log('Hello world');\nArray.isArray([yep:'I_am'])",
            },
            {
                format: "asciidata",
                label: "asciidata",
                value: "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
            },
            {
                format: "download",
                label: "download",
                value: {
                    data: "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
                },
            },
            {
                format: "download",
                label: "download link",
                value: {
                    type: "link",
                    data: "img/logo.png",
                    filename: "openxpki.png",
                },
            },
            {
                format: "arbitrary",
                label: "arbitrary",
                value: {
                    'one-two-three': [
                        "first.loooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-example.org",
                        "second.example.org"
                    ],
                },
            },
            {
                format: "head",
                value: "List types...",
                className: "spacer",
            },
            {
                format: "unilist",
                label: "unilist",
                value: [
                    {
                        value: "text without label",
                    },
                    {
                        format: "tooltip",
                        label: "tooltip (short)",
                        value: {
                            value: "Hover me",
                            tooltip: "This is a short tooltip.",
                        },
                    },
                    {
                        format: "link",
                        value: {
                            label: "Technical Log",
                            page: "workflow!log!wf_id!13567",
                            tooltip: "I feel like hovering",
                        },
                    },
                    {
                        format: "link",
                        value: {
                            label: "Workflow History",
                            page: "workflow!history!wf_id!13567",
                            tooltip: "I feel like hovering",
                        },
                    },
                    {
                        format: "code",
                        label: "code",
                        value: "console.log('Hello world');\nArray.isArray([yep:'I_am'])",
                    },
                    {
                        format: "timestamp",
                        label: "timestamp",
                        value: 1617495633,
                    },
                    {
                        format: "styled",
                        label: "styled",
                        value: "attention:hear my words",
                    },
                    {
                        format: "certstatus",
                        label: "certstatus",
                        value: {
                            value: "issued",
                            label: "<i>Issued</i>",
                            tooltip: "It's issued",
                        },
                    },
                    {
                        format: "unilist",
                        label: "list-level-2",
                        value: [
                            {
                                value: "text without label",
                            },
                            {
                                format: "arbitrary",
                                value: {
                                    'one-two-three': [
                                        "first.loooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-example.org",
                                        "second.example.org"
                                    ],
                                },
                            },
                            {
                                format: "unilist",
                                label: "list-level-3",
                                value: [
                                    {
                                        format: "timestamp",
                                        value: 1617495633,
                                    },
                                    {
                                        format: "styled",
                                        value: "attention:hear my words",
                                    },
                                ],
                            },
                            {
                                format: "tooltip",
                                label: "tooltip (short)",
                                value: {
                                    value: "Hover me",
                                    tooltip: "This is a short tooltip.",
                                },
                            },
                        ],
                    },
                ],
            },
            {
                format: "deflist",
                label: "deflist",
                value: [
                    { label: "first", value: "PKI <a href=\"should be escaped\">" },
                    { label: "second", value: "<a href=\"https://www.openxpki.org\">OpenXPKI</a>", format: "raw" },
                    { label: "subject", value: [ "CN=sista.example.org", "DC=Test Deployment", "DC=PKI Examples", "DC=OpenXPKI", "DC=org" ] },
                    {
                        label: "hosts-by-group",
                        value: {
                            'one-two-three': [
                                "first.loooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-example.org",
                                "second.example.org"
                            ],
                        },
                    },
                    {
                        label: "size",
                        value: "1234"
                    },
                ],
                className: "crosses",
            },
            {
                format: "ullist",
                label: "ullist",
                value: [ "PKI", "OpenXPKI" ],
            },
            {
                format: "rawlist",
                label: "rawlist",
                value: [ "PKI", "<a href=\"https://www.openxpki.org\">OpenXPKI</a>" ],
            },
            {
                format: "linklist",
                label: "linklist",
                value: [
                    {
                        label: "Workflow History",
                        page: "workflow!history!wf_id!13567",
                        tooltip: "I feel like hovering",
                    },
                    {
                        label: "Technical Log",
                        page: "workflow!log!wf_id!13567",
                        tooltip: "I feel like hovering",
                    },
                    {
                        label: "Just a label (tooltip!)",
                        tooltip: "I feel like hovering",
                    }
                ],
            },
            {
                format: "head",
                label: "head",
            },
        ],
        buttons: [
            {
                format: "expected",
                page: "certificate!search!query!rJdrIbg1P6xsE6b9RtQCXp291SE",
                label: "Reload Search Form",
            },
            {
                format: "alternative",
                page: "redirect!certificate!result!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                label: "Refresh Result",
                break_after: 1,
            },
            {
                label: "New Search",
                format: "failure",
                page: "certificate!search"
            },
            {
                label: "Export Result",
                format: "optional",
                target: "_blank",
                href: "/cgi-bin/webui.fcgi?page=certificate!export!id!rJdrIbg1P6xsE6b9RtQCXp291SE"
            }
        ],
    }
}