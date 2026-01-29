# SQS Message (message router)

## 1. Message

Given SQS records, `$message = json_decode(Records.*.body)['Message']` =

```json
{
    "context": {
        "MetaWabaIds": [
            {
                "wabaId": "1393727385109399",
                "arn": "arn:aws:social-messaging:eu-west-1:533267110337:waba/a9a6973db0a54c8285f8d4e76df62869"
            }
        ],
        "MetaPhoneNumberIds": [
            {
                "metaPhoneNumberId": "729155140271006",
                "arn": "arn:aws:social-messaging:eu-west-1:533267110337:phone-number-id/5f811eaa4c81499384c496b909afbb1a"
            }
        ]
    },
    "whatsAppWebhookEntry": "{\"id\":\"1393727385109399\",\"changes\":[{\"value\":{\"messaging_product\":\"whatsapp\",\"metadata\":{\"display_phone_number\":\"393404534569\",\"phone_number_id\":\"729155140271006\"},\"contacts\":[{\"profile\":{\"name\":\"Francesco\ud83d\udcbb\"},\"wa_id\":\"393462454282\"}],\"messages\":[{\"from\":\"393462454282\",\"id\":\"wamid.HBgMMzkzNDYyNDU0MjgyFQIAEhgUM0E2RDRCN0Y5NURBRTM3OEJBN0IA\",\"timestamp\":\"1758171394\",\"text\":{\"body\":\"Prva\"},\"type\":\"text\"}]},\"field\":\"messages\"}]}",
    "aws_account_id": "533267110337",
    "message_timestamp": "2025-09-18T04:56:36.684321927Z"
}
```

## whatsAppWebhookEntry

`$whatsAppWebhookEntry = json_decode($message['whatsAppWebhookEntry'])` =

```json
{
    "id": "1393727385109399",
    "changes": [
        {
            "value": {
                "messaging_product": "whatsapp",
                "metadata": {
                    "display_phone_number": "393404534569",
                    "phone_number_id": "729155140271006"
                },
                "contacts": [
                    {
                        "profile": { "name": "Francesco💻" },
                        "wa_id": "393462454282"
                    }
                ],
                "messages": [
                    {
                        "from": "393462454282",
                        "id": "wamid.HBgMMzkzNDYyNDU0MjgyFQIAEhgUM0E2RDRCN0Y5NURBRTM3OEJBN0IA",
                        "timestamp": "1758171394",
                        "text": { "body": "Prva" },
                        "type": "text"
                    }
                ]
            },
            "field": "messages"
        }
    ]
}
```
