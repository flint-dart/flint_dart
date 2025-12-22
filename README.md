# Flint Dart 🔥

### 🚀 **Flint Dart**

**Flint Dart** is a high-performance, expressive, and extensible server-side framework built entirely with Dart.
Designed for developers who demand speed and simplicity, it delivers everything you need to build RESTful APIs, authentication systems, and scalable backend services — all with clean, modern syntax and hot-reload precision.

> ⚡ **Build fast. Scale effortlessly.**
> Flint Dart gives you the freedom to create powerful applications without the limits of rigid frameworks.

Developed and maintained by **[Eulogia Technologies](https://flintdart.eulogia.net)**.

---



## 📚 Table of Contents

| Topic | Description |
|-------|-------------|
| [🚀 Getting Started](https://www.flintdart.eulogia.net/docs/getting-started) | Set up Flint in your project |
| [🛣️ Routing](https://www.flintdart.eulogia.net/docs/routing) | Define routes for your Flint Dart app |
| [🛡 Middleware](https://www.flintdart.eulogia.net/docs/middleware) | Protect and modify requests with middleware |
| [🗄 ORM & Models](https://www.flintdart.eulogia.net/docs/orm) | Work with databases using Flint Dart ORM |
| [💾 Database & Migrations](https://www.flintdart.eulogia.net/docs/database) | Manage your database schema and migrations |
| [🔑 Authentication](https://www.flintdart.eulogia.net/docs/auth) | Built-in authentication and Google Auth support |
| [✅ Validation](https://www.flintdart.eulogia.net/docs/validation) | Validate input like Laravel |
| [♻️ Hot Reload](https://www.flintdart.eulogia.net/docs/hot-reload) | Instant feedback while developing |
| [💾 Storage](https://www.flintdart.eulogia.net/docs/storage) | Storage Flint Dart to production |
| [🚢 Deployment](https://www.flintdart.eulogia.net/docs/deployment) | Deploy Flint Dart to production |
| [📖 API Docs](https://www.flintdart.eulogia.net/docs/swagger-docs) | Best-in-class API documentation with Swagger UI |
---

## ✨ Features

- 🧱 Simple and intuitive routing
- 🛡️ Middleware support
- 🔐 Built-in JWT authentication
- 🔒 Secure password hashing
- ♻️ Hot reload support for rapid development
- 🧪 Modular structure for scalable projects
- 💡 Clean API design inspired by Flutter's widget philosophy
- ORM for MySQL/Postgres  
- CLI for migrations, models, etc.  
- Swagger docs
---

## 🚀 Getting Started

### 1.  Install as a Global Package
If you want to quickly create and run apps without adding Flint as a dependency, install it globally:


```bash
dart pub global activate flint_dart
 ```

```bash
flint create new_app   # Create a new Flint project
flint run              # Run the project
 ```

### 2. Add as a Project Dependency
If you prefer Flint to be part of your project’s dependencies:


```bash
dart pub add flint_dart
 ```


 ```bash 
 dart run 
 ``` 

```bash 
import 'package:flint_dart/flint_dart.dart';

void main() {
  final app = Flint();

  app.get('/', (req, res) async {
    return res.send('Welcome to Flint Dart!');
  });

  app.listen(3000);
}
```
### 3. Run with hot reload
```bash


app.get('/hello', (req, res) async {
  return res.json({'message': 'Hello, world!'});
});

```

### Middleware

```bash

import 'package:flint_dart/flint_dart.dart';

class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      final token = req.bearerToken;
      if (token == null || token != "expected_token") {
      return  res.status(401).send("Unauthorized");
      }
   return await next(req, res);
    };
  }
```


```bash

  app.put('/:id', AuthMiddleware().handle(controller.update));
```
### JWT Authentication
```bash
final token = JwtUtil.generateToken({'userId': 123});
final payload = JwtUtil.verifyToken(token);

```
### Password Hashing
```bash
final hash = Hashing.hashPassword('mySecret');
final isValid = Hashing.verifyPassword('mySecret', hash);




## 🧩 WebSocket System (Major Upgrade)

### 🔁 Socket.IO–like API
Flint now ships with an easy-to-use WebSocket engine with event-based communication:

```dart
app.ws('/chat', (socket, params) {
  socket.on('message', (data) {
    print('💬 ${socket.id} says: $data');
    socket.broadcastToRoom('chat', {'event': 'message', 'data': data});
  });
});
````

Client-side:

```dart
final ws = FlintWebSocketClient("wss://api.example.com/chat");
ws.on('message', (data) => print("📩 $data"));
ws.emit('message', {'text': 'Hello World'});
```

---

### 💬 Core Features

* **`.emit(event, data)`** → Send named events easily
* **`.on(event, callback)`** → Listen for specific events
* **`.onMessage()`** and **`.onJsonMessage()`** remain supported for backward compatibility
* **`.join(room)`** and **`.leave(room)`** for group messaging
* **`.broadcast()`** and **`.broadcastToRoom()`** for real-time updates
* **Auto Reconnect** on the client when connection drops
* **JWT Support** using the same middleware chain as HTTP routes
* **Auth Middleware** can now 
```
  ### 📁 Project Structure

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
📮 Contact & Support
🌐 Website: flintdart.eulogia.net

📧 Email: eulogiatechnologies@gmail.com

🐙 GitHub: github.com/eulogiatechnologies/flint_dart

🛠 Contributing
We welcome contributions! To get started:

```bash
git clone https://github.com/eulogiatechnologies/flint_dart.git
cd flint_dart
dart pub get
```

## 👥 Core Contributors

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/hybiekay">
        <img src="https://avatars.githubusercontent.com/u/YOUR_ID?v=4" width="100px;" />
        <br />
        <sub><b>Ademola Ibukunoluwa</b></sub>
      </a>
      <br />
      <a href="https://github.com/flint-dart/flint_dart">📦 Repo</a>
    </td>
    <td align="center">
      <a href="https://github.com/anotherContributor">
        <img src="https://avatars.githubusercontent.com/u/ANOTHER_ID?v=4" width="100px;" />
        <br />
        <sub><b>Contributor Name</b></sub>
      </a>
      <br />
      <a href="https://github.com/flint-dart/flint_dart">📦 Repo</a>
    </td>
  </tr>
</table>

Then feel free to submit issues or pull requests.