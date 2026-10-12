import { Component, inject } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

/** Destinos mínimos de F1.9; los formularios y pantallas funcionales vendrán después. */
@Component({
  selector: 'app-session-page',
  imports: [RouterLink],
  template: `
    <section class="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
      <h1 class="text-3xl font-bold">{{ title }}</h1>
      <p class="mt-4 leading-7 text-slate-300">{{ description }}</p>
      <a routerLink="/app" class="mt-6 inline-block text-emerald-300 underline"
        >Ir al inicio privado</a
      >
    </section>
  `,
})
export class SessionPage {
  private readonly route = inject(ActivatedRoute);
  readonly title = this.route.snapshot.data['title'] as string;
  readonly description = this.route.snapshot.data['description'] as string;
}
