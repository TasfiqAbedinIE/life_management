# Love Pill Push Setup

This feature uses Firebase Cloud Messaging for true background and killed-app push notifications.

## 1. Firebase Android app

Create or open a Firebase project, add an Android app with package:

```text
com.example.task_management_app
```

Download `google-services.json` and place it at:

```text
android/app/google-services.json
```

## 2. Firebase service account

In Firebase Console, create a service account key and keep the JSON private.
Set it as a Supabase Edge Function secret:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='<paste-service-account-json>' --project-ref zgurszkayljitkfolysj
```

## 3. Webhook secret

Generate a long random secret and set the same value in Supabase Edge Functions and the database config table.

```bash
supabase secrets set LOVE_PILL_WEBHOOK_SECRET='<long-random-secret>' --project-ref zgurszkayljitkfolysj
```

```sql
update private.love_pill_push_config
set value = '<long-random-secret>'
where key = 'webhook_secret';
```

## 4. Deploy function

```bash
supabase functions deploy send-love-pill-push --project-ref zgurszkayljitkfolysj
```

## 5. Test

1. Install the app on two Android devices or emulators signed in as a coupled pair.
2. Open the app once on both devices so each device registers an FCM token.
3. Fully kill the recipient app.
4. Send a Love Pill from the other account.
5. Tap the notification and confirm it opens the Coupled module.
