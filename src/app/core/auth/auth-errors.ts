import type { AuthError } from '@supabase/supabase-js';

export function authErrorMessage(
  error: AuthError,
  context: 'login' | 'signup' | 'reset' | 'password',
): string {
  switch (error.code) {
    case 'invalid_credentials':
      return 'El correo o la contraseña no son correctos.';
    case 'email_not_confirmed':
      return 'Confirma tu correo antes de iniciar sesión. Revisa también la carpeta de spam.';
    case 'weak_password':
      return 'La contraseña no cumple los requisitos de seguridad del servidor.';
    case 'same_password':
      return 'Elige una contraseña diferente a la anterior.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Demasiados intentos. Espera unos minutos antes de volver a intentarlo.';
    case 'email_address_invalid':
      return 'Introduce una dirección de correo válida.';
    case 'signup_disabled':
      return 'El registro no está disponible en este momento. Contacta con el administrador.';
    case 'reauthentication_needed':
      return 'Solicita un nuevo enlace de recuperación y vuelve a intentarlo.';
  }
  // GoTrue oculta detalles de triggers bajo unexpected_failure. No inventar
  // cuál de invitación/username falló ni exponer SQL, emails o mensajes internos.
  if (context === 'signup')
    return 'No se ha podido completar el registro. Comprueba que la invitación siga disponible y el nombre de usuario no esté ocupado. Si el problema continúa, contacta con el administrador.';
  if (context === 'login')
    return 'No se ha podido iniciar sesión. Revisa tus credenciales y la conexión.';
  if (context === 'password')
    return 'No se ha podido cambiar la contraseña. Inténtalo de nuevo o solicita otro enlace.';
  return 'No se ha podido solicitar el correo. Comprueba la conexión e inténtalo más tarde.';
}
