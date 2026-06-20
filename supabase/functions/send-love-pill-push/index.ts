import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

const corsHeaders = {
  "content-type": "application/json",
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const expectedSecret = Deno.env.get("LOVE_PILL_WEBHOOK_SECRET");
  const receivedSecret = req.headers.get("x-love-pill-webhook-secret");
  if (!expectedSecret || receivedSecret !== expectedSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  const { pill_id } = await req.json().catch(() => ({ pill_id: null }));
  if (!pill_id) {
    return json({ error: "Missing pill_id" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!supabaseUrl || !serviceRoleKey || !firebaseServiceAccountJson) {
    return json({ error: "Missing server configuration" }, 500);
  }

  const serviceAccount = JSON.parse(firebaseServiceAccountJson) as ServiceAccount;
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: pill, error: pillError } = await supabase
    .from("couple_love_pills")
    .select("id, couple_id, sender_id, message, created_at")
    .eq("id", pill_id)
    .single();

  if (pillError || !pill) {
    return json({ error: "Pill not found" }, 404);
  }

  const { data: couple, error: coupleError } = await supabase
    .from("couples")
    .select("user1_id, user2_id, status")
    .eq("id", pill.couple_id)
    .single();

  if (coupleError || !couple || couple.status !== "active") {
    return json({ error: "Couple not active" }, 409);
  }

  const recipientIds = [couple.user1_id, couple.user2_id].filter((id) =>
    id && id !== pill.sender_id
  );

  if (recipientIds.length === 0) {
    return json({ sent: 0 });
  }

  const { data: tokens, error: tokenError } = await supabase
    .from("user_push_tokens")
    .select("token, user_id")
    .in("user_id", recipientIds);

  if (tokenError) {
    return json({ error: tokenError.message }, 500);
  }

  if (!tokens || tokens.length === 0) {
    return json({ sent: 0 });
  }

  const accessToken = await getFirebaseAccessToken(serviceAccount);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  let sent = 0;
  const invalidTokens: string[] = [];
  await Promise.all(tokens.map(async ({ token }) => {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "authorization": `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: "New love pill",
            body: pill.message,
          },
          data: {
            destination: "love_pills",
            type: "love_pill",
            pill_id: pill.id,
            couple_id: pill.couple_id,
          },
          android: {
            priority: "HIGH",
            notification: {
              channel_id: "couple_love_pills",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
        },
      }),
    });

    if (response.ok) {
      sent += 1;
      return;
    }

    const errorBody = await response.text();
    if (
      errorBody.includes("UNREGISTERED") ||
      errorBody.includes("INVALID_ARGUMENT")
    ) {
      invalidTokens.push(token);
    }
  }));

  if (invalidTokens.length > 0) {
    await supabase.from("user_push_tokens").delete().in("token", invalidTokens);
  }

  return json({ sent, invalid_tokens_removed: invalidTokens.length });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

async function getFirebaseAccessToken(serviceAccount: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const unsignedJwt = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(payload))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedJwt),
  );
  const jwt = `${unsignedJwt}.${base64Url(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`Firebase OAuth failed: ${await response.text()}`);
  }

  const token = await response.json();
  return token.access_token as string;
}

function pemToArrayBuffer(pem: string) {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\\n", "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function base64Url(input: string | ArrayBuffer) {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}
