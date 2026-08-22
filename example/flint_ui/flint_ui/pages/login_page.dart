import 'package:flint_dart/ui.dart';

class LoginPage extends FlintComponent {
  final Map<String, dynamic> props;

  LoginPage(this.props);

  @override
  FlintNode build() {
    final title = props['title']?.toString() ?? 'Welcome back';
    final subtitle = props['subtitle']?.toString() ??
        'Sign in to continue building with Flint.';

    return Container(
      props: {
        'className':
            'min-h-screen bg-[radial-gradient(circle_at_top_left,_rgba(15,118,110,0.18),_transparent_32%),linear-gradient(180deg,_#fffef6,_#eef6f6)] px-4 py-8 text-slate-900'
      },
      children: [
        h(
          'div',
          props: {'className': 'mx-auto flex max-w-6xl justify-between gap-4'},
          children: [
            h(
              'a',
              props: {
                'href': '/',
                'className':
                    'inline-flex items-center gap-3 text-sm font-semibold tracking-wide text-slate-700'
              },
              children: [
                h(
                  'span',
                  props: {
                    'className':
                        'grid h-9 w-9 place-items-center rounded-xl bg-teal-700 text-white shadow-lg shadow-teal-900/20'
                  },
                  children: ['F'],
                ),
                'Flint Dart',
              ],
            ),
            h(
              'div',
              props: {
                'className':
                    'hidden items-center gap-3 text-sm font-medium text-slate-600 md:flex'
              },
              children: [
                h('a', props: {
                  'href': '/guide',
                  'className': 'hover:text-slate-900'
                }, children: [
                  'Guide'
                ]),
                h('a', props: {
                  'href': '/docs',
                  'className': 'hover:text-slate-900'
                }, children: [
                  'Docs'
                ]),
              ],
            ),
          ],
        ),
        h(
          'div',
          props: {
            'className':
                'mx-auto grid min-h-[calc(100vh-5rem)] max-w-6xl items-center gap-8 py-10 lg:grid-cols-[1.1fr_0.9fr]'
          },
          children: [
            h(
              'section',
              props: {'className': 'space-y-6'},
              children: [
                h(
                  'span',
                  props: {
                    'className':
                        'inline-flex rounded-full border border-teal-700/20 bg-teal-700/10 px-3 py-1 text-xs font-bold uppercase tracking-[0.18em] text-teal-800'
                  },
                  children: ['Tailwind test page'],
                ),
                h(
                  'h1',
                  props: {
                    'className':
                        'max-w-xl font-["Sora","Segoe_UI",sans-serif] text-5xl font-semibold leading-[0.95] text-slate-950 md:text-7xl'
                  },
                  children: [title],
                ),
                h(
                  'p',
                  props: {
                    'className':
                        'max-w-xl text-base leading-8 text-slate-600 md:text-lg'
                  },
                  children: [subtitle],
                ),
                h(
                  'div',
                  props: {'className': 'flex flex-wrap gap-3'},
                  children: [
                    h(
                      'a',
                      props: {
                        'href': '/guide',
                        'className':
                            'inline-flex min-h-11 items-center justify-center rounded-xl bg-teal-700 px-5 text-sm font-semibold text-white shadow-lg shadow-teal-900/20 transition hover:bg-teal-800'
                      },
                      children: ['Read the guide'],
                    ),
                    h(
                      'a',
                      props: {
                        'href': '/',
                        'className':
                            'inline-flex min-h-11 items-center justify-center rounded-xl border border-slate-300 bg-white px-5 text-sm font-semibold text-slate-800 transition hover:border-slate-400'
                      },
                      children: ['Back home'],
                    ),
                  ],
                ),
              ],
            ),
            h(
              'section',
              props: {
                'className':
                    'rounded-[28px] border border-white/70 bg-white/85 p-6 shadow-2xl shadow-slate-900/10 backdrop-blur md:p-8'
              },
              children: [
                h(
                  'div',
                  props: {'className': 'mb-6 space-y-2'},
                  children: [
                    h(
                      'h2',
                      props: {
                        'className':
                            'font-["Sora","Segoe_UI",sans-serif] text-2xl font-semibold text-slate-950'
                      },
                      children: ['Sign in'],
                    ),
                    h(
                      'p',
                      props: {'className': 'text-sm leading-6 text-slate-500'},
                      children: [
                        'This page uses Tailwind utility classes generated from a standalone binary.'
                      ],
                    ),
                  ],
                ),
                h(
                  'form',
                  props: {'className': 'space-y-4'},
                  children: [
                    _field(
                      label: 'Email address',
                      name: 'email',
                      type: 'email',
                      placeholder: 'you@example.com',
                    ),
                    _field(
                      label: 'Password',
                      name: 'password',
                      type: 'password',
                      placeholder: 'Enter your password',
                    ),
                    h(
                      'div',
                      props: {
                        'className':
                            'flex items-center justify-between gap-3 pt-1 text-sm'
                      },
                      children: [
                        h(
                          'label',
                          props: {
                            'className':
                                'inline-flex items-center gap-2 text-slate-600'
                          },
                          children: [
                            h('input', props: {
                              'type': 'checkbox',
                              'className':
                                  'h-4 w-4 rounded border-slate-300 text-teal-700 focus:ring-teal-700'
                            }),
                            'Remember me',
                          ],
                        ),
                        h(
                          'a',
                          props: {
                            'href': '#',
                            'className':
                                'font-semibold text-teal-800 hover:text-teal-900'
                          },
                          children: ['Forgot password?'],
                        ),
                      ],
                    ),
                    h(
                      'button',
                      props: {
                        'type': 'submit',
                        'className':
                            'inline-flex w-full min-h-12 items-center justify-center rounded-xl bg-slate-950 px-5 text-sm font-semibold text-white transition hover:bg-slate-800'
                      },
                      children: ['Sign in'],
                    ),
                  ],
                ),
                h(
                  'div',
                  props: {
                    'className':
                        'mt-6 rounded-2xl bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-900'
                  },
                  children: [
                    'Test note: if this page looks unstyled, the Tailwind standalone build is not being picked up yet.'
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintNode _field({
    required String label,
    required String name,
    required String type,
    required String placeholder,
  }) {
    return h(
      'label',
      props: {'className': 'block space-y-2'},
      children: [
        h(
          'span',
          props: {'className': 'text-sm font-medium text-slate-700'},
          children: [label],
        ),
        h(
          'input',
          props: {
            'name': name,
            'type': type,
            'placeholder': placeholder,
            'className':
                'h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-teal-700 focus:ring-4 focus:ring-teal-700/10'
          },
        ),
      ],
    );
  }
}
