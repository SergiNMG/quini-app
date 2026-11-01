import { Routes } from '@angular/router';
import {
  adminChildGuard,
  adminGuard,
  guestGuard,
  memberChildGuard,
  memberGuard,
} from './core/auth/auth.guards';

const sessionPage = () => import('./features/session/session-page').then((m) => m.SessionPage);
const authFormPage = () => import('./features/session/auth-form-page').then((m) => m.AuthFormPage);

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'app' },
  {
    path: 'auth/login',
    canActivate: [guestGuard],
    loadComponent: authFormPage,
    data: { mode: 'login' },
  },
  {
    path: 'auth/register',
    canActivate: [guestGuard],
    loadComponent: authFormPage,
    data: { mode: 'signup' },
  },
  {
    path: 'auth/forgot-password',
    loadComponent: authFormPage,
    data: { mode: 'reset' },
  },
  {
    path: 'auth/callback',
    loadComponent: () =>
      import('./features/session/auth-callback-page').then((m) => m.AuthCallbackPage),
  },
  {
    path: 'auth/access',
    loadComponent: () => import('./features/session/access-page').then((m) => m.AccessPage),
  },
  {
    path: 'app',
    canActivate: [memberGuard],
    canActivateChild: [memberChildGuard],
    children: [
      {
        path: '',
        pathMatch: 'full',
        loadComponent: sessionPage,
        data: {
          title: 'Quini',
          description:
            'Inicio privado para miembros activos. Jornadas, pronósticos e histórico se añadirán en sus fases.',
        },
      },
      { path: '**', redirectTo: '' },
    ],
  },
  {
    path: 'admin',
    canActivate: [adminGuard],
    canActivateChild: [adminChildGuard],
    children: [
      {
        path: '',
        pathMatch: 'full',
        loadComponent: sessionPage,
        data: {
          title: 'Administración',
          description:
            'Acceso reservado a admins activos. La gestión de catálogos y usuarios se implementará en F2.',
        },
      },
      { path: '**', redirectTo: '' },
    ],
  },
  { path: '**', redirectTo: 'app' },
];
