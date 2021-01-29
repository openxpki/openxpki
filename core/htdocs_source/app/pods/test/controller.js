import Controller from '@ember/controller';
import { action } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';

export default class TestController extends Controller {
    @service('oxi-locale') oxiLocale;

    constructor() {
        super(...arguments);
        this.oxiLocale.locale = 'de-DE';
        // add some more grid rows
        for (let i=0; i<50; i++) {
            this.gridDef.content.data.push([
                334455 + i,
                `CN=client-${i},DC=Test Deployment,DC=OpenXPKI,DC=org`,
                {
                    "value": "ISSUED",
                    "label": "Issued"
                },
                1585959633 + 60*60*24*i,
                `${1585959633 + 60*60*24*i}`,
                `ID-IS-${i}`,
                `id-${i}`,
                {
                    "label": "Issued",
                    "value": "ISSUED"
                }
            ]);
        }
    }

    @action
    setLang(lang) {
        this.oxiLocale.locale = lang;
    }

    testButton = {
        label: "Button",
        format: "primary",
        tooltip: "This should do it",
        disabled: false,
    };

    chart_line = {
        options: {
            type: 'line',
            width: 300,
            height: 150,
            title: 'Line chart',
            cssClass: 'test-chart',
            x_is_timestamp: true,
            legend_label: true,
            legend_value: false,
            y_values: [
                {
                    label: 'Amount',
                    scale: 'amount',
                    color: 'rgba(200, 200, 200, 1)',
                    line_width: 2,
                },
                {
                    label: 'ABC',
                    scale: '%',
                    color: 'rgba(0, 100, 200, 0.9)',
                },
                {
                    label: "DEF",
                    scale: [0, 100],
                    color: 'rgba(200, 30, 100, 0.9)',
                },
            ],
        },
        data: [['1609462800','29015','53.6','47.4'],['1609462860','28972','51.3','47.4'],['1609462920','28982','51.8','47.4'],['1609462980','29000.65968091','52.7','47.5'],['1609463040','29015','53.4','47.5'],['1609463100','29072.47060638','56.0','47.7'],['1609463160','29074','56.0','47.8'],['1609463220','29096','57.0','48.0'],['1609463280','29080','56.1','48.2'],['1609463340','29116','57.6','48.4'],['1609463400','29133','58.3','48.6'],['1609463460','29187','60.4','48.9'],['1609463520','29204','61.0','49.3'],['1609463580','29246.52081557','62.5','49.6'],['1609463640','29261','63.0','50.1'],['1609463700','29355','66.0','50.5'],['1609463760','29354','65.9','50.9'],['1609463820','29339','65.1','51.3'],['1609463880','29316','63.8','51.7'],['1609463940','29325.56322878','64.1','52.0'],['1609464000','29270','61.1','52.3'],['1609464060','29348.31047748','63.5','52.7'],['1609464120','29329.21462289','62.5','53.0'],['1609464180','29291.946697','60.7','53.3'],['1609464240','29310','61.3','53.6'],['1609464300','29300','60.8','53.8'],['1609464360','29311','61.1','54.1'],['1609464420','29304','60.8','54.3'],['1609464480','29304.87199549','60.8','54.6'],['1609464540','29353','62.3','54.9'],['1609464600','29399','63.7','55.2'],['1609464660','29450','65.2','55.5'],['1609464720','29373','61.4','55.7'],['1609464780','29410','62.5','56.0'],['1609464840','29363','60.3','56.2'],['1609464900','29357','60.1','56.4'],['1609464960','29388','61.0','56.6'],['1609465020','29410','61.6','56.8'],['1609465080','29441','62.5','57.0'],['1609465140','29480','63.5','57.2'],['1609465200','29416','60.7','57.4'],['1609465260','29396','59.8','57.6'],['1609465320','29392','59.7','57.7'],['1609465380','29360','58.3','57.9'],['1609465440','29381','58.9','58.0'],['1609465500','29341','57.3','58.2'],['1609465560','29344','57.4','58.3'],['1609465620','29390.69367066','58.8','58.4'],['1609465680','29385','58.5','58.5'],['1609465740','29368','57.8','58.7'],['1609465800','29386','58.4','58.8'],['1609465860','29380','58.1','58.9'],['1609465920','29360','57.3','59.0'],['1609465980','29356','57.1','59.1'],['1609466040','29378','57.8','59.2'],['1609466100','29384.20015692','58.0','59.3'],['1609466160','29382','57.9','59.4'],['1609466220','29403','58.6','59.5'],['1609466280','29440','59.7','59.6'],['1609466340','29411','58.4','59.7'],['1609466400','29432','59.1','59.8'],['1609466460','29462','60.0','59.9'],['1609466520','29466','60.1','60.0'],['1609466580','29412','57.7','60.1'],['1609466640','29397','57.1','60.2'],['1609466700','29393','56.9','60.2'],['1609466760','29390','56.8','60.2'],['1609466820','29369','55.9','60.2'],['1609466880','29382','56.3','60.2'],['1609466940','29379','56.2','60.2'],['1609467000','29392','56.6','60.2'],['1609467060','29394','56.7','60.1'],['1609467120','29370','55.6','60.0'],['1609467180','29371','55.7','59.9'],['1609467240','29303','52.7','59.7'],['1609467300','29270','51.4','59.5'],['1609467360','29295','52.3','59.2'],['1609467420','29302','52.6','59.0'],['1609467480','29308','52.8','58.9'],['1609467540','29333','53.7','58.7'],['1609467600','29326','53.4','58.6'],['1609467660','29325','53.4','58.4'],['1609467720','29332','53.6','58.2'],['1609467780','29349','54.3','58.1'],['1609467840','29361','54.7','58.0'],['1609467900','29371','55.1','57.9'],['1609467960','29328','53.2','57.8'],['1609468020','29349','54.0','57.7'],['1609468080','29325','52.9','57.6'],['1609468140','29285','51.3','57.4'],['1609468200','29296','51.7','57.2'],['1609468260','29222','48.7','56.9'],['1609468320','29245','49.6','56.7'],['1609468380','29222','48.8','56.5'],['1609468440','29233.27476468','49.2','56.3'],['1609468500','29250','49.9','56.1'],['1609468560','29220','48.7','55.9'],['1609468620','29259','50.2','55.7'],['1609468680','29260','50.3','55.5']],
    };

    chart_bar = {
        options: {
            type: 'bar',
            width: 300,
            height: 150,
            title: 'Bar chart',
            cssClass: 'test-chart',
            y_values: [
                {
                    label: 'Amount',
                    color: 'rgba(200, 200, 200, 1)',
                    scale: '%',
                },
                {
                    label: 'ABC',
                    color: 'rgba(0, 100, 200, 0.9)',
                    scale: '%',
                },
                {
                    label: "DEF",
                    color: 'rgba(200, 30, 100, 0.9)',
                    scale: '%',
                },
            ],
            bar_group_labels: {
                a: "2019",
                b: "2020",
                c: "2021",
            },
        },
        data: [['a','23.8','53.6','37.4'],['b','19.6','43.3','63.4'],['c','4.2','51.8','47.4']],
    };

    @tracked formDef = {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            title: "Test input",
            fields: [
                {
                    type: "bool",
                    name: "ready_or_not",
                    label: "Bool, selected",
                    value: 1,
                },
                {
                    type: "select",
                    name: "select_it",
                    label: "Select, no preset",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                },
                {
                    type: "select",
                    name: "select_editable",
                    label: "Select, editable",
                    editable: 1,
                    value: 2,
                    options: [
                        { value: 1, label: "Tusen" },
                        { value: 2, label: "Takk" },
                    ],
                },
                {
                    type: "select",
                    name: "select_2",
                    label: "Select, one choice",
                    options: [
                        { value: "11", label: "Ocean" },
                    ],
                    value: "",
                },
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
                },
                {
                    type: "datetime",
                    name: "dt_now",
                    label: "Date, now",
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
                },
                {
                    type: "datetime",
                    name: "dt_some_pitcairn",
                    label: "Date, 2020-03-03 03:33 UTC",
                    value: "1583206380",
                    timezone: "Pacific/Pitcairn",
                },
                {
                    type: "text",
                    name: "plaintext",
                    label: "Text, , clone field with 2 presets",
                    value: ["sheep #1", "sheep #2"],
                    clonable: 1,
                },
                {
                    type: "text",
                    name: "attributes",
                    label: "Text, dynamic, clonable, 2 presets",
                    clonable: 1,
                    is_optional: 1,
                    keys: [
                        {
                            value: "cert_subject",
                            label: "Certificate Subject",
                        },
                        {
                            value: "requestor",
                            label: "Requestor",
                        },
                        {
                            value: "transaction_id",
                            label: "Transaction Id",
                        },
                    ],
                    value: [
                        { key: "cert_subject", value: "Subject" },
                        { key: "transaction_id", value: "TransId" },
                    ],
                },
                {
                    type: "rawtext",
                    name: "rawtext",
                    label: "Raw text",
                    value: "",
                },
                {
                    type: "static",
                    name: "label1",
                    label: "Label",
                    value: "on my shirt",
                },
                {
                    type: "static",
                    name: "label2",
                    label: "Label",
                    value: "on my shirt",
                    verbose: "is sewed onto my shirt"
                },
                {
                    type: "textarea",
                    name: "prosa",
                    label: "Textarea",
                    value: "Hi there!\nHow are you?\n",
                },
                {
                    type: "uploadarea",
                    name: "uploadarea",
                    value: "...data...",
                    label: "Uploadarea",
                },
            ],
            buttons: [
                {
                    label: "Link to external",
                    format: "failure",
                    tooltip: "Just fyi",
                    href: "https://www.openxpki.org",
                    target: "_blank",
                },
                this.testButton,
                {
                    ...this.testButton,
                    label: "With confirmation",
                    confirm: {
                        label: "Really sure?",
                        description: "Think about it one more time.",
                    },
                },
                {
                    ...this.testButton,
                    label: "Disabled",
                    disabled: true,
                },
            ],
        }
    };

    @tracked gridDef = {
        "content": {
            "empty": "No data available",
            "buttons": [
                {
                    "section": "Some",
                },
                {
                    "format": "expected",
                    "page": "certificate!search!query!rJdrIbg1P6xsE6b9RtQCXp291SE",
                    "label": "Reload Search Form",
                    "description": "Button 1",
                },
                {
                    "format": "alternative",
                    "page": "redirect!certificate!result!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                    "label": "Refresh Result",
                    "description": "Button 2",
                },
                {
                    "section": "Others",
                },
                {
                    "label": "New Search",
                    "format": "failure",
                    "page": "certificate!search"
                },
                {
                    "label": "Export Result",
                    "format": "optional",
                    "target": "_blank",
                    "href": "/cgi-bin/webui.fcgi?page=certificate!export!id!rJdrIbg1P6xsE6b9RtQCXp291SE"
                }
            ],
            "actions": [
                {
                    "label": "Download",
                    "icon": "download",
                    "path": "certificate!detail!identifier!{identifier}",
                    "target": "popup"
                },
                {
                    "label": "Check",
                    "icon": "download",
                    "path": "certificate!detail!identifier!{identifier}",
                    "target": "popup"
                }
            ],
            "columns": [
                {
                    "sTitle": "Certificate Serial",
                    "sortkey": "cert_key"
                },
                {
                    "sTitle": "Subject",
                    "sortkey": "subject"
                },
                {
                    "format": "certstatus",
                    "sortkey": "status",
                    "sTitle": "Status"
                },
                {
                    "sTitle": "not before",
                    "sortkey": "notbefore",
                    "format": "timestamp"
                },
                {
                    "format": "raw",
                    "sortkey": "notafter",
                    "sTitle": "raw"
                },
                {
                    "sortkey": "identifier",
                    "sTitle": "Certificate Identifier"
                },
                {
                    "sTitle": "identifier",
                    "bVisible": 0
                },
                {
                    "sTitle": "_className"
                },
            ],
            "data": [
                [
                    "0x3ff536fff8da93943aa",
                    "CN=e.d.c:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                    {
                        "value": "ISSUED",
                        "label": "Issued"
                    },
                    "1585959633",
                    "1617495633",
                    "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                    "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    }
                ],
                [
                    "0x2ff8fa8ee5590e2553a",
                    "CN=sista.example.org:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    },
                    "1585434533",
                    "<a href=\"test\" onclick=\"alert('huh')\">test</a>",
                    "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                    "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    }
                ],
                // ... more rows are added in constructor above
            ]
        },
        "type": "grid",
        "className": "certificate"
    };


    @tracked keyvalueDef = {
        "type": "keyvalue",
        "content": {
            "label": "oxisection/keyvalue",
            "description": "",
            "data": [
                {
                    "format": "certstatus",
                    "label": "certstatus",
                    "value": {
                        "value": "issued",
                        "label": "<i>Issued</i>",
                        "tooltip": "It's issued",
                    },
                },
                {
                    "format": "link",
                    "label": "link",
                    "value": {
                        "page": "workflow!load!wf_id!13567",
                        "label": 13567,
                        "target": "_blank",
                    },
                },
                {
                    "format": "extlink",
                    "label": "extlink",
                    "value": {
                        "page": "https://www.openxpki.org",
                        "label": "OpenXPKI",
                        "target": "_blank",
                    },
                },
                {
                    "format": "timestamp",
                    "label": "timestamp",
                    "value": 1617495633,
                },
                {
                    "format": "text",
                    "label": "text",
                    "value": "Link to <a href=\"should be escaped\">OpenXPKI</a>",
                },
                {
                    "format": "text",
                    "label": "text_as_list",
                    "value": [ "CN=sista.example.org:pkiclient,", "DC=Test Deployment,", "DC=PKI Examples,", "DC=OpenXPKI,", "DC=org" ],
                },
                {
                    "format": "nl2br",
                    "label": "nl2br",
                    "value": "Link to <a href=\"should be escaped\">OpenXPKI</a>\nand a comment",
                },
                {
                    "format": "code",
                    "label": "code",
                    "value": "console.log('Hello world');\nArray.isArray([yep:'I_am'])",
                },
                {
                    "format": "asciidata",
                    "label": "asciidata",
                    "value": "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
                },
                {
                    "format": "download",
                    "label": "download",
                    "value": {
                        data: "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
                    },
                },
                {
                    "format": "download",
                    "label": "download link",
                    "value": {
                        type: "link",
                        data: "img/logo.png",
                        filename: "openxpki.png",
                    },
                },
                {
                    "format": "raw",
                    "label": "raw",
                    "value": "Link to <a href=\"https://www.openxpki.org\">OpenXPKI</a>",
                },
                {
                    "format": "deflist",
                    "label": "deflist",
                    "value": [
                        { "label": "first", "value": "PKI <a href=\"should be escaped\">" },
                        { "label": "second", "value": "<a href=\"https://www.openxpki.org\">OpenXPKI</a>", "format": "raw" },
                        { "label": "subject", "value": [ "CN=sista.example.org", "DC=Test Deployment", "DC=PKI Examples", "DC=OpenXPKI", "DC=org" ] },
                    ],
                },
                {
                    "format": "deflist",
                    "label": "deflist-arbitrary",
                    "value": [
                        {
                            "label": "hosts-by-group",
                            "value": {
                                "one-two-three": [
                                    "first.example.org",
                                    "second.example.org"
                                ],
                            },
                        },
                        {
                            "label": "size",
                            "value": "1234"
                        },
                    ],
                },
                {
                    "format": "ullist",
                    "label": "ullist",
                    "value": [ "PKI", "OpenXPKI" ],
                },
                {
                    "format": "rawlist",
                    "label": "rawlist",
                    "value": [ "PKI", "<a href=\"https://www.openxpki.org\">OpenXPKI</a>" ],
                },
                {
                    "format": "linklist",
                    "label": "linklist",
                    "value": [
                        {
                            "label": "Workflow History",
                            "page": "workflow!history!wf_id!13567",
                            "tooltip": "I feel like hovering",
                        },
                        {
                            "label": "Technical Log",
                            "page": "workflow!log!wf_id!13567",
                            "tooltip": "I feel like hovering",
                        },
                        {
                            "label": "Just a label (tooltip!)",
                            "tooltip": "I feel like hovering",
                        }
                    ],
                },
                {
                    "format": "styled",
                    "label": "styled",
                    "value": "attention:hear my words",
                },
                {
                    "format": "tooltip",
                    "label": "tooltip",
                    "value": {
                        "value": "Hover me",
                        "tooltip": "...to see more",
                    },
                },
                {
                    "format": "head",
                    "label": "head",
                },
            ],
        }
    };
}
