Perfect! Here’s a **fully updated README.md** for Flint Dart with a polished **contributors section** added at the end. I’ve also cleaned up minor formatting issues so it’s consistent and professional.
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-0-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

---

# Flint Dart 🔥

### 🚀 **Flint Dart**

**Flint Dart** is a high-performance, expressive, and extensible server-side framework built entirely with Dart.
Designed for developers who demand speed and simplicity, it delivers everything you need to build RESTful APIs, authentication systems, and scalable backend services — all with clean, modern syntax and hot-reload precision.

> ⚡ **Build fast. Scale effortlessly.**
> Flint Dart gives you the freedom to create powerful applications without the limits of rigid frameworks.

Developed and maintained by **[Eulogia Technologies](https://flintdart.eulogia.net)**.

---

## 📚 Table of Contents

| Topic                                                                        | Description                                     |
| ---------------------------------------------------------------------------- | ----------------------------------------------- |
| [🚀 Getting Started](https://www.flintdart.eulogia.net/docs/getting-started) | Set up Flint in your project                    |
| [🛣️ Routing](https://www.flintdart.eulogia.net/docs/routing)                | Define routes for your Flint Dart app           |
| [🛡 Middleware](https://www.flintdart.eulogia.net/docs/middleware)           | Protect and modify requests with middleware     |
| [🗄 ORM & Models](https://www.flintdart.eulogia.net/docs/orm)                | Work with databases using Flint Dart ORM        |
| [💾 Database & Migrations](https://www.flintdart.eulogia.net/docs/database)  | Manage your database schema and migrations      |
| [🔑 Authentication](https://www.flintdart.eulogia.net/docs/auth)             | Built-in authentication and Google Auth support |
| [✅ Validation](https://www.flintdart.eulogia.net/docs/validation)            | Validate input like Laravel                     |
| [♻️ Hot Reload](https://www.flintdart.eulogia.net/docs/hot-reload)           | Instant feedback while developing               |
| [💾 Storage](https://www.flintdart.eulogia.net/docs/storage)                 | Storage Flint Dart to production                |
| [🚢 Deployment](https://www.flintdart.eulogia.net/docs/deployment)           | Deploy Flint Dart to production                 |
| [📖 API Docs](https://www.flintdart.eulogia.net/docs/swagger-docs)           | Best-in-class API documentation with Swagger UI |

---

## ✨ Features

* 🧱 Simple and intuitive routing
* 🛡️ Middleware support
* 🔐 Built-in JWT authentication
* 🔒 Secure password hashing
* ♻️ Hot reload support for rapid development
* 🧪 Modular structure for scalable projects
* 💡 Clean API design inspired by Flutter's widget philosophy
* ORM for MySQL/Postgres
* CLI for migrations, models, etc.
* Swagger docs

---

## 🚀 Getting Started

### 1. Install as a Global Package

```bash
dart pub global activate flint_dart
```

```bash
flint create new_app   # Create a new Flint project
flint run              # Run the project
```

### 2. Add as a Project Dependency

```bash
dart pub add flint_dart
```

```dart
import 'package:flint_dart/flint_dart.dart';

void main() {
  final app = Flint();

  app.get('/', (req, res) async {
    return res.send('Welcome to Flint Dart!');
  });

  app.listen(3000);
}
```

### 3. Run with Hot Reload

```dart
app.get('/hello', (req, res) async {
  return res.json({'message': 'Hello, world!'});
});
```

---

## Middleware

```dart
import 'package:flint_dart/flint_dart.dart';

class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      final token = req.bearerToken;
      if (token == null || token != "expected_token") {
        return res.status(401).send("Unauthorized");
      }
      return await next(req, res);
    };
  }
}
```

```dart
app.put('/:id', AuthMiddleware().handle(controller.update));
```

---

## JWT Authentication

```dart
final token = JwtUtil.generateToken({'userId': 123});
final payload = JwtUtil.verifyToken(token);
```

---

## Password Hashing

```dart
final hash = Hashing.hashPassword('mySecret');
final isValid = Hashing.verifyPassword('mySecret', hash);
```

---

## 🧩 WebSocket System

### 🔁 Socket.IO–like API

```dart
app.ws('/chat', (socket, params) {
  socket.on('message', (data) {
    Log.debug('💬 ${socket.id} says: $data');
    socket.broadcastToRoom('chat', {'event': 'message', 'data': data});
  });
});
```

Client-side:

```dart
final ws = FlintWebSocketClient("wss://api.example.com/chat");
ws.on('message', (data) => Log.debug("📩 $data"));
ws.emit('message', {'text': 'Hello World'});
```

---

## 💬 Core Features

* **`.emit(event, data)`** → Send named events easily
* **`.on(event, callback)`** → Listen for specific events
* **`.onMessage()`** and **`.onJsonMessage()`** remain supported for backward compatibility
* **`.join(room)`** and **`.leave(room)`** for group messaging
* **`.broadcast()`** and **`.broadcastToRoom()`** for real-time updates
* Auto Reconnect on the client when connection drops
* JWT Support using the same middleware chain as HTTP routes
* Auth Middleware now works for WebSockets too

---

## 📁 Project Structure

```bash
lib/
├── main.dart
├── src/
│   ├── app.dart
│   ├── router.dart
│   ├── request.dart
│   ├── response.dart
│   ├── middleware.dart
│   └── security/
│       ├── jwt_util.dart
│       └── hashing.dart
```

---

## 📮 Contact & Support

🌐 Website: [flintdart.eulogia.net](https://flintdart.eulogia.net)
📧 Email: [eulogiatechnologies@gmail.com](mailto:eulogiatechnologies@gmail.com)
🐙 GitHub: [github.com/eulogiatechnologies/flint_dart](https://github.com/eulogiatechnologies/flint_dart)

---

## 🛠 Contributing

We welcome contributions! To get started:

```bash
git clone https://github.com/eulogiatechnologies/flint_dart.git
cd flint_dart
dart pub get
```

Then feel free to submit issues or pull requests.

---

## 👥 Contributors

<a href="https://github.com/flint-dart/flint_dart/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=flint-dart/flint_dart" />
</a>

Made with ❤️ by the Flint Dart community.


## Contributors ✨

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center">
      <a href="https://github.com/Dee-08">
        <img src="https://github.com/Dee-08.png" width="100;" alt="Daniel DAVID"/><br />
        <sub><b>Daniel DAVID</b></sub>
      </a><br />
      <sub>🖥️📖</sub>
    </td>
    <td align="center">
      <a href="https://github.com/EulogiaTechnologies">
        <img src="https://github.com/EulogiaTechnologies.png" width="100;" alt="Eulogia Technologies"/><br />
        <sub><b>Eulogia Technologies</b></sub>
      </a><br />
      <sub>⚙️🖥️</sub>
    </td>
    <td align="center">
      <a href="https://github.com/Hybiekay">
        <img src="https://github.com/Hybiekay.png" width="100;" alt="Samuel Adeoye"/><br />
        <sub><b>Samuel Adeoye</b></sub>
      </a><br />
      <sub>🖥️📖⚙️</sub>
    </td>
  </tr>
</table>
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->
