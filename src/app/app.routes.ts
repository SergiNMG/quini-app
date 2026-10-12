import { Routes } from '@angular/router';
import {
  adminChildGuard,
  adminGuard,
  guestGuard,
  memberChildGuard,
  memberGuard,
} from './core/auth/auth.guards';

const sessionPage = () => import('./features/session/session-page').then((m) => m.SessionPage);

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'app' },
  {
    path: 'auth/login',
    canActivate: [guestGuard],
    loadComponent: sessionPage,
    data: {
      title: 'Acceso a Quini',
      description:
        'La sesión y los permisos están preparados. El formulario de login, registro con invitación y recuperación se implementará en F1.10.',
    },
  },
  {
    path: 'auth/callback',
    loadComponent: sessionPage,
    data: {
      title: 'Confirmación de acceso',
      description:
        'Supabase procesa la sesión del enlace. La validación de enlaces y el flujo de recuperación se completarán en F1.10.',
    },
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
