// ----------------------------
// File: lib/core/helpers.dart
// ----------------------------

import 'package:flint_dart/src/template_engine/template_engine.dart';

import '../src/template_engine/template.dart';

String view(String name, [Map<String, dynamic> data = const {}]) =>
    TemplateEngine().render(name, data);

// CSRF helper stub (you must wire this to your session/auth layer)
String csrfField(String token) =>
    '<input type="hidden" name="_csrf" value="\$token">';

// Old() helper: example to preserve old input; you should integrate with your request/session storage
String old(Map<String, dynamic> oldData, String key) =>
    oldData[key]?.toString() ?? '';

// ----------------------------
// File: views/layouts/app.html (example)
// ----------------------------
// <!doctype html>
// <html>
// <head>
//   <meta charset="utf-8" />
//   <title>{@ yield('title') }}</title>
// </head>
// <body>
//   <aside>
//     {@ yield('sidebar') }}
//   </aside>
//   <main>
//     {@ yield('content') }}
//   </main>
// </body>
// </html>

// ----------------------------
// File: views/partials/sidebar.html (example)
// ----------------------------
// <nav class="sidebar">
//   <ul>
//     <li><a href="/dashboard">Dashboard</a></li>
//     <li><a href="/settings">Settings</a></li>
//   </ul>
// </nav>

// ----------------------------
// File: views/dashboard.html (example)
// ----------------------------
// {@ extends('layouts.app') }}
//
// {@ section('title', 'Dashboard') }}
//
// {@ section('sidebar') }}
//   {@ include('partials/sidebar') }}
// {@ endsection }}
//
// {@ section('content') }}
//   <h1>Hello, @{ name }</h1>
//   {@ if is_admin }}
//     <p>You are admin</p>
//   {@ else }}
//     <p>Welcome user</p>
//   {@ endif }}
// {@ endsection }}

// ----------------------------
// File: README (usage)
// ----------------------------
// 1. Copy `lib/core/flint_template.dart` and `lib/core/template_cache.dart` into your Flint project.
// 2. Set `FlintTemplate.viewsPath = 'lib/resources/views'` or wherever you keep views.
// 3. Enable/disable cache depending on environment:
//    FlintTemplate.cacheEnabled = !isDev;
//    FlintTemplate.watchFiles = isDev; // optional
//    FlintTemplate.startWatcher(); // call during app startup in dev
// 4. Use the helper: `return res.html(view('dashboard', {'name': 'Aim'}));`
// 5. Use templating syntax shown in the examples.

// ----------------------------
// Notes and next steps / improvements you can ask me to implement:
// - Add compiled templates (pre-parsing) to speed up heavy rendering.
// - Add an expression evaluator using a sandboxed mini-language (avoid eval of arbitrary Dart code).
// - Add component support like <x-button/> with parameter binding.
// - Add view caching metadata and ETag support for HTTP caching.
// - Integrate CSRF/old/errors helpers with Flint's session & validation systems.
// - Add a CLI command `flint view:cache` and `flint view:clear` for production workflows.

// ----------------------------
// End of document
