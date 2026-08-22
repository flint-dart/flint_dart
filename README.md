# Flint Dart ⚡

<div align="center">

[![Pub Version](https://img.shields.io/pub/v/flint_dart.svg?style=flat-square&logo=dart)](https://pub.dev/packages/flint_dart)
[![GitHub Stars](https://img.shields.io/github/stars/flint-dart/flint_dart?style=flat-square&logo=github)](https://github.com/flint-dart/flint_dart)
[![Documentation](https://img.shields.io/badge/docs-flintdart.dev-blue.svg?style=flat-square)](https://flintdart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

**The First Official Full-Stack, Declarative, SEO-First Dart Web Framework.**

[Website](https://flintdart.dev) • [Pub.dev](https://pub.dev/packages/flint_dart) • [GitHub](https://github.com/flint-dart/flint_dart) • [Documentation](https://flintdart.dev)

</div>

---

## 🌟 What is Flint Dart?

**Flint Dart** is not just a backend server — it is the **first unified full-stack web framework for Dart**. 

Flint Dart empowers developers to build entire end-to-end web applications with **100% pure Dart**:
* 🎨 **Declarative Web UI (Flint UI natively built-in)**: Flutter-like widget syntax compiling directly to browser DOM.
* 🔍 **First-Class SEO & Server-Side Rendering (SSR)**: Instant HTML generation, meta tags, and OpenGraph crawlers with client-side hydration.
* ⚡ **High-Performance Backend**: Ultra-fast RESTful HTTP routing, RFC 10008 `QUERY` support, controllers, and middleware pipelines.
* 🗄️ **Active Record ORM & Secure DB API**: Fluent PostgreSQL & MySQL ORM, auto-migrations, and Row-Level Security (`FlintDbPolicy`).
* 🔌 **Real-Time WebSockets**: Low-latency event streaming with Socket.IO-style rooms, namespaces, and auto-serialization.
* 🤖 **AI Runtime & Agent Workflows**: Built-in multi-provider LLM engine (OpenAI, Gemini, Anthropic) with autonomous tool calling and memory.

> **💡 Zero JavaScript or CSS build tools required.** Write your backend logic, database queries, and browser UI in a single language with unified type safety!

---

## 🚀 Key Pillars

| Pillar | Description | Key Import |
| :--- | :--- | :--- |
| **Server & HTTP** | REST routing, route groups, controllers, CORS, and auth middleware. | `import 'package:flint_dart/flint_dart.dart';` |
| **Flint Web UI** | Declarative components, styles, reactive state signals, and DOM hydration. | `import 'package:flint_dart/ui.dart';` |
| **Database & ORM** | Active Record models, migrations, seeders, and secure DB API endpoints. | `import 'package:flint_dart/db.dart';` |
| **WebSockets** | Real-time channels, room broadcasting, and structured event emitters. | `import 'package:flint_dart/flint_dart.dart';` |
| **AI Runtime** | Multi-model agent orchestration, tool calling, and persistent thread memory. | `import 'package:flint_dart/flint_dart.dart';` |
| **Mailer Engine** | SMTP client with `.flint.html` email template rendering. | `import 'package:flint_dart/mail.dart';` |

---

## 📦 Installation

### 1) Global CLI Toolchain
Install the `flint` CLI globally to create and run fullstack apps:

```bash
dart pub global activate flint_dart
```

### 2) Create a New Project
```bash
flint create my_fullstack_app
cd my_fullstack_app
flint run
```

### 3) Add to an Existing Project
```bash
dart pub add flint_dart
```

---

## 💡 Quickstarts

### 1. Declarative Web UI with SSR & SEO (`package:flint_dart/ui.dart`)

Flint UI is **natively built-in**. Build Flutter-like components with reactive state, modern design tokens, and built-in SEO metadata:

```dart
import 'package:flint_dart/ui.dart';

class HomePage extends FlintComponent {
  HomePage(super.props);

  @override
  FlintNode build() {
    return AppShell(
      topbar: Topbar(title: 'Flint Fullstack App'),
      child: Container(
        padding: Spacing.all(24),
        child: Column(
          children: [
            // Built-in SEO head configuration
            Head(
              title: 'Welcome to Flint Dart',
              meta: [
                Meta(name: 'description', content: 'The first fullstack declarative Dart web framework.'),
                Meta(property: 'og:title', content: 'Flint Dart Fullstack Web'),
              ],
            ),
            Text('Build Fullstack Apps in 100% Pure Dart', style: TextStyle(size: 28, weight: '700')),
            Spacer(height: 16),
            Row(
              children: [
                Button(
                  label: 'Get Started',
                  variant: ButtonVariant.solid,
                  onClick: () => window.alert('Welcome to Flint!'),
                ),
                Spacer(width: 12),
                Button(
                  label: 'Documentation',
                  variant: ButtonVariant.outline,
                  href: 'https://flintdart.dev',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2. Fullstack Backend Server (`package:flint_dart/flint_dart.dart`)

```dart
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/db.dart';

void main() async {
  final app = Flint();

  // Middleware
  app.use(CorsMiddleware());
  app.use(LoggerMiddleware());

  // REST API Route
  app.get('/api/users', (Context ctx) async {
    final users = await User().all();
    return ctx.res?.json(users.map((u) => u.toMap()).toList());
  });

  // Server-Side Rendered (SSR) Web UI Route
  app.get('/', (Context ctx) async {
    final users = await User().limit(5).get();
    return ctx.res?.flintPage(
      'HomePage',
      title: 'Flint Dashboard',
      props: {'users': users.map((u) => u.toMap()).toList()},
    );
  });

  // Real-Time WebSocket Channel
  app.websocket('/ws/chat', (Context ctx) {
    ctx.socket?.on('message', (data) {
      ctx.socket?.broadcast('message', data);
    });
  });

  // Start Server
  await app.listen(port: 3000);
}
```

### 3. Active Record Database ORM & Migrations (`package:flint_dart/db.dart`)

```dart
import 'package:flint_dart/db.dart';

class User extends Model<User> {
  User() : super(User.new);

  String get name => getAttribute('name');
  String get email => getAttribute('email');

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(name: 'name', type: ColumnType.string, length: 255),
          Column(name: 'email', type: ColumnType.string, length: 255),
          Column(name: 'role', type: ColumnType.string, defaultValue: 'user'),
        ],
      );
}

// Fluent Database Queries:
final user = await User().find(1);
final activeUsers = await User()
    .where('role', 'admin')
    .orderBy('created_at', desc: true)
    .limit(10)
    .get();

// Safe Mutators:
await User().create({
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
  'role': 'admin',
});
```

---

## 🛠️ Complete Flint Ecosystem

The Flint ecosystem is designed as a unified suite:

* ⚡ **[`flint_dart`](https://pub.dev/packages/flint_dart)**: The flagship Fullstack Web Framework (Server, SSR, Web UI, and Database ORM).
* 📱 **[`flint_client`](https://github.com/flint-dart/flint-client)**: Standalone HTTP, WebSocket, & Database Client SDK for Flutter Mobile (iOS/Android), Desktop, and Web.
* 🤖 **[`flint_hardware`](https://github.com/flint-dart/flint-hardware)**: Embedded Systems, Robotics State Machines, and Multi-MCU code generators for ESP32, Raspberry Pi Pico, and STM32.
* 🧠 **[`flint_ai`](https://github.com/flint-dart/flint_ai)**: Multi-provider AI agents, LLM tool callers, and autonomous workflow engines.

---

## 📚 Documentation & Community

* **Official Website & Guides**: [flintdart.dev](https://flintdart.dev)
* **Pub.dev Package**: [pub.dev/packages/flint_dart](https://pub.dev/packages/flint_dart)
* **GitHub Repository**: [github.com/flint-dart/flint_dart](https://github.com/flint-dart/flint_dart)
* **Issue Tracker**: [github.com/flint-dart/flint_dart/issues](https://github.com/flint-dart/flint_dart/issues)

---

## 📄 License

Flint Dart is licensed under the [MIT License](LICENSE).
