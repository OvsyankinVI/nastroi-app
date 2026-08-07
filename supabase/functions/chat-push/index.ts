import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from 'npm:jose@5'

Deno.serve(async (request) => {
  try {
    const webhookSecret = Deno.env.get('CHAT_PUSH_WEBHOOK_SECRET')
    if (!webhookSecret || request.headers.get('x-chat-push-secret') !== webhookSecret) {
      return new Response('unauthorized', { status: 401 })
    }

    const { record } = await request.json()
    if (!record?.thread_id || !record?.sender_id) return new Response('ignored', { status: 202 })

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data: thread, error } = await supabase.from('chat_threads').select('user_a,user_b').eq('id', record.thread_id).single()
    if (error) throw error
    const recipient = thread.user_a === record.sender_id ? thread.user_b : thread.user_a
    const [{ data: sender }, { data: tokens }] = await Promise.all([
      supabase.from('people').select('name').eq('owner_user_id', record.sender_id).eq('relation_type', 'me').maybeSingle(),
      supabase.from('user_push_tokens').select('token').eq('user_id', recipient),
    ])
    if (!tokens?.length) return new Response('no tokens', { status: 202 })

    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!)
    const key = await importPKCS8(serviceAccount.private_key, 'RS256')
    const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
      .setProtectedHeader({ alg: 'RS256', kid: serviceAccount.private_key_id })
      .setIssuer(serviceAccount.client_email).setSubject(serviceAccount.client_email)
      .setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h').sign(key)
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }) })
    const { access_token } = await tokenResponse.json()
    const body = String(record.text ?? '').slice(0, 120)

    await Promise.all(tokens.map(({ token }) => fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
      method: 'POST', headers: { authorization: `Bearer ${access_token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ message: { token, notification: { title: sender?.name ?? 'Новое сообщение', body }, data: { type: 'chat_message', thread_id: record.thread_id, sender_user_id: record.sender_id }, apns: { payload: { aps: { sound: 'default', category: 'CHAT_MESSAGE' } } } } }),
    })))
    return new Response('ok')
  } catch (error) {
    console.error(error instanceof Error ? error.message : 'chat push failed')
    return new Response('failed', { status: 500 })
  }
})
