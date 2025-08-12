# Flint Dart 🔥

**Flint Dart** is a minimal, expressive, and extensible server-side framework built with Dart. Inspired by the simplicity of Express.js and Laravel, Flint provides an elegant developer experience for building RESTful APIs and backend services with Dart.

Developed and maintained by **[Eulogia Technologies](https://flintdart.eulogia.net)**.

---

## ✨ Features

- 🧱 Simple and intuitive routing
- 🛡️ Middleware support
- 🔐 Built-in JWT authentication
- 🔒 Secure password hashing
- ♻️ Hot reload support for rapid development
- 🧪 Modular structure for scalable projects
- 💡 Clean API design inspired by Flutter's widget philosophy

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
    res.send('Welcome to Flint Dart!');
  });

  app.listen(3000);
}
```
### 3. Run with hot reload
```bash


app.get('/hello', (req, res) async {
  res.json({'message': 'Hello, world!'});
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
        res.status(401).send("Unauthorized");
        return;
      }
      await next(req, res);
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
Then feel free to submit issues or pull requests.