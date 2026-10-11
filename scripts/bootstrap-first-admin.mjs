import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const root = fileURLToPath(new URL('../', import.meta.url));
const required = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'BOOTSTRAP_ADMIN_EMAIL',
  'BOOTSTRAP_ADMIN_USERNAME',
  'BOOTSTRAP_REDIRECT_URL',
];

function readConfiguration() {
  const missing = required.filter((name) => !process.env[name]?.trim());
  if (missing.length)
    throw new Error(`Faltan variables locales en .env.bootstrap: ${missing.join(', ')}`);

  const config = JSON.parse(
    readFileSync(new URL('../supabase/development.json', import.meta.url), 'utf8'),
  );
  const url = new URL(process.env.SUPABASE_URL);
  if (config.environment !== 'development' || url.hostname !== `${config.projectRef}.supabase.co`) {
    throw new Error(
      'El bootstrap inicial solo se permite en el proyecto Supabase de desarrollo configurado.',
    );
  }
  return {
    url: url.origin,
    key: process.env.SUPABASE_SERVICE_ROLE_KEY,
    email: process.env.BOOTSTRAP_ADMIN_EMAIL.trim().toLowerCase(),
    username: process.env.BOOTSTRAP_ADMIN_USERNAME.trim(),
    redirectTo: process.env.BOOTSTRAP_REDIRECT_URL.trim(),
  };
}

async function main() {
  const config = readConfiguration();
  const supabase = createClient(config.url, config.key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { count: adminCount, error: adminCountError } = await supabase
    .from('profiles')
    .select('id', { count: 'exact', head: true })
    .eq('role', 'ADMIN');
  if (adminCountError)
    throw new Error(
      `No se pudo comprobar el estado de administradores: ${adminCountError.message}`,
    );
  if (adminCount !== 0)
    throw new Error(
      'Ya existe un perfil ADMIN. El bootstrap solo sirve para inicializar el proyecto.',
    );

  // Resume safely if an invite was sent and the process stopped before promotion.
  const { data: existingProfile, error: profileLookupError } = await supabase
    .from('profiles')
    .select('id, email, username, role, activo, invitation_code_used')
    .eq('email', config.email)
    .maybeSingle();
  if (profileLookupError)
    throw new Error(
      `No se pudo inspeccionar el perfil de bootstrap: ${profileLookupError.message}`,
    );

  let profile = existingProfile;
  if (!profile) {
    const { data: usernameOwner, error: usernameLookupError } = await supabase
      .from('profiles')
      .select('id')
      .eq('username', config.username)
      .maybeSingle();
    if (usernameLookupError)
      throw new Error(
        `No se pudo validar el username de bootstrap: ${usernameLookupError.message}`,
      );
    if (usernameOwner)
      throw new Error(
        'El username de bootstrap ya pertenece a otro perfil. No se creó ninguna invitación.',
      );
  }
  if (profile) {
    if (
      profile.role !== 'PLAYER' ||
      !profile.activo ||
      !profile.invitation_code_used ||
      profile.username !== config.username
    ) {
      throw new Error(
        'El perfil existente no cumple las condiciones de bootstrap; no se modificó. Revisar manualmente.',
      );
    }
  } else {
    // The random code is never printed, returned to the shell, or committed.
    const invitationCode = `BOOTSTRAP-${randomBytes(32).toString('base64url')}`;
    const { error: invitationError } = await supabase
      .from('invitation_codes')
      .insert({ code: invitationCode });
    if (invitationError)
      throw new Error(`No se pudo crear la invitación de bootstrap: ${invitationError.message}`);

    const { data: inviteData, error: inviteError } = await supabase.auth.admin.inviteUserByEmail(
      config.email,
      {
        redirectTo: config.redirectTo,
        data: { username: config.username, invitation_code: invitationCode },
      },
    );
    if (inviteError) {
      throw new Error(
        `Auth no pudo enviar la invitación. Quedó un código sin usar en el proyecto de desarrollo; ` +
          `inspeccionarlo/eliminarlo manualmente con un operador de base de datos antes de reintentar. (${inviteError.message})`,
      );
    }
    if (!inviteData.user?.id)
      throw new Error('Auth no devolvió el usuario invitado; revisar Auth antes de reintentar.');

    const { data: createdProfile, error: createdProfileError } = await supabase
      .from('profiles')
      .select('id, email, username, role, activo, invitation_code_used')
      .eq('id', inviteData.user.id)
      .maybeSingle();
    if (createdProfileError || !createdProfile) {
      throw new Error(
        'Auth creó la invitación pero no se encontró el perfil provisionado; no borrar la cuenta ni la invitación. ' +
          'Revisar el trigger trg_auth_user_invited_profile antes de continuar.',
      );
    }
    if (
      createdProfile.role !== 'PLAYER' ||
      !createdProfile.activo ||
      !createdProfile.invitation_code_used ||
      createdProfile.username !== config.username
    ) {
      throw new Error(
        'El trigger de invitación no creó el perfil esperado; no se promovió a ADMIN. Revisar manualmente.',
      );
    }
    profile = createdProfile;
  }

  const { data: authData, error: authError } = await supabase.auth.admin.getUserById(profile.id);
  if (authError || !authData.user)
    throw new Error('No se pudo comprobar el usuario Auth del bootstrap.');
  if (!authData.user.email_confirmed_at) {
    console.log(
      'La invitación Auth está creada, pero el correo todavía no está confirmado. Aceptar el email y ejecutar de nuevo para promover; la cuenta sigue siendo PLAYER.',
    );
    return;
  }

  const { error: promoteError } = await supabase.rpc('bootstrap_first_admin', {
    p_profile_id: profile.id,
  });
  if (promoteError) {
    throw new Error(
      `El perfil sigue sin promoción ADMIN. Corregir la causa y volver a ejecutar con esta cuenta: ${promoteError.message}`,
    );
  }

  const { data: promotedProfile, error: verifyError } = await supabase
    .from('profiles')
    .select('email, username, role, activo')
    .eq('id', profile.id)
    .single();
  if (verifyError || promotedProfile.role !== 'ADMIN' || !promotedProfile.activo) {
    throw new Error(
      'No se pudo verificar la promoción. Revisar el perfil manualmente; no crear otro bootstrap.',
    );
  }

  console.log(
    `Primer administrador inicializado: ${promotedProfile.email} (${promotedProfile.username}).`,
  );
  console.log(
    'La URL de invitación y la clave service_role no se muestran. El email de invitación debe aceptarse antes de promover.',
  );
}

main().catch((error) => {
  // Never print environment variables, invitation tokens or Auth action links.
  console.error(error.message);
  process.exitCode = 1;
});
