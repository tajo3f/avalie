import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const authHeader = req.headers.get('Authorization') || ''
    if (!authHeader) throw new Error('UNAUTHENTICATED')

    const callerClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } })
    const adminClient = createClient(url, service)
    const { data: { user }, error: userError } = await callerClient.auth.getUser()
    if (userError || !user) throw new Error('UNAUTHENTICATED')

    const body = await req.json()
    const { company_id, email, full_name, role = 'manager' } = body
    if (!company_id || !email || !['owner','manager'].includes(role)) throw new Error('INVALID_PAYLOAD')

    const { data: platformAdmin } = await adminClient.from('platform_admins').select('user_id').eq('user_id', user.id).maybeSingle()
    const { data: membership } = await adminClient.from('company_users').select('role,active').eq('company_id', company_id).eq('user_id', user.id).maybeSingle()
    const allowed = !!platformAdmin || (!!membership?.active && membership.role === 'owner')
    if (!allowed) throw new Error('FORBIDDEN')

    const { data: company, error: companyError } = await adminClient.from('companies').select('slug').eq('id', company_id).single()
    if (companyError) throw companyError

    let targetUserId: string | null = null
    const { data: usersPage } = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 })
    const existing = usersPage?.users?.find(u => u.email?.toLowerCase() === String(email).toLowerCase())

    if (existing) {
      targetUserId = existing.id
    } else {
      const redirectTo = `https://avalie.tajodigital.com.br/${company.slug}/painel/login`
      const { data: invited, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
        redirectTo,
        data: { full_name: full_name || '' }
      })
      if (inviteError) throw inviteError
      targetUserId = invited.user?.id || null
    }

    if (!targetUserId) throw new Error('USER_CREATE_FAILED')

    await adminClient.from('profiles').upsert({ user_id: targetUserId, full_name: full_name || '', email: String(email).toLowerCase() })
    const { error: memberError } = await adminClient.from('company_users').upsert({ company_id, user_id: targetUserId, role, active: true }, { onConflict: 'company_id,user_id' })
    if (memberError) throw memberError

    return new Response(JSON.stringify({ ok: true, user_id: targetUserId, invited: !existing }), { headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (error) {
    return new Response(JSON.stringify({ ok: false, error: String(error?.message || error) }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } })
  }
})
