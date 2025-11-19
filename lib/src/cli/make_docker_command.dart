import 'dart:io';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:path/path.dart' as path;

class MakeDockerCommand extends FlintCommand {
  MakeDockerCommand()
      : super('make:docker', 'Creates Docker configuration for the project');

  @override
  Future<void> execute(List<String> args) async {
    final outputDir = args.isNotEmpty ? args.first : 'docker';

    print('🐳 Creating Docker configuration...');

    // Create docker directory
    final dockerDir = Directory(outputDir);
    if (dockerDir.existsSync()) {
      print('📁 Docker directory already exists. Overwriting files...');
    } else {
      dockerDir.createSync(recursive: true);
    }

    // Load existing environment variables
    final envVars = _loadEnvVars();

    // Get project name from pubspec.yaml
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final nameMatch = RegExp(r'name:\s*(\S+)').firstMatch(pubspec);
    final projectName = nameMatch?.group(1) ?? 'flint_app';

    // Create Dockerfile
    _createDockerfile(outputDir, projectName);

    // Create docker-compose.yml with actual environment values
    _createDockerCompose(outputDir, projectName, envVars);

    // Create nginx configuration
    _createNginxConfig(outputDir, projectName);

    // Create deployment script
    _createDeployScript(outputDir);

    // Create .dockerignore
    _createDockerIgnore(outputDir);

    // Copy existing .env file to docker directory
    _copyExistingEnv(outputDir);

    print('✅ Docker configuration created successfully!');
    print('📁 Files created in: $outputDir/');
    print('🚀 To deploy: cd $outputDir && ./deploy.sh');
    print('💡 Using your existing .env configuration');
  }

  Map<String, String> _loadEnvVars() {
    final envVars = <String, String>{};

    try {
      // Try to use FlintEnv if available
      envVars['DB_CONNECTION'] = FlintEnv.get('DB_CONNECTION', 'postgres');
      envVars['DB_HOST'] = FlintEnv.get('DB_HOST', 'localhost');
      envVars['DB_PORT'] = FlintEnv.get('DB_PORT', '5432');
      envVars['DB_USER'] = FlintEnv.get('DB_USER', "postgres");
      envVars['DB_PASSWORD'] = FlintEnv.get('DB_PASSWORD', "password");
      envVars['DB_NAME'] = FlintEnv.get('DB_NAME', "flint");
      envVars['DB_SECURE'] = FlintEnv.get('DB_SECURE', "false");

      envVars['PORT'] = FlintEnv.get('PORT', '3000');
      envVars['APP_ENV'] = FlintEnv.get('APP_ENV', 'production');
      envVars['APP_DEBUG'] = FlintEnv.get('APP_DEBUG', 'false');
      envVars['APP_KEY'] = FlintEnv.get('APP_KEY', 'your-secret-key-here');

      envVars['JWT_SECRET'] =
          FlintEnv.get('JWT_SECRET', 'your-jwt-secret-here');

      envVars['MAIL_PROVIDER'] = FlintEnv.get('MAIL_PROVIDER', 'smtp');
      envVars['MAIL_HOST'] =
          FlintEnv.get('MAIL_HOST', 'sandbox.smtp.mailtrap.io');
      envVars['MAIL_PORT'] = FlintEnv.get('MAIL_PORT', '2525');
      envVars['MAIL_USERNAME'] =
          FlintEnv.get('MAIL_USERNAME', "d7d14d51ba77d1");
      envVars['MAIL_PASSWORD'] =
          FlintEnv.get('MAIL_PASSWORD', "95257a44ac422f");
      envVars['MAIL_FROM_ADDRESS'] =
          FlintEnv.get('MAIL_FROM_ADDRESS', 'youremail@gmail.com');
      envVars['MAIL_FROM_NAME'] =
          FlintEnv.get('MAIL_FROM_NAME', 'Eulogia Technologies');

      envVars['REDIS_URL'] = FlintEnv.get('REDIS_URL', 'redis://redis:6379');
      envVars['CORS_ORIGIN'] =
          FlintEnv.get('CORS_ORIGIN', 'http://localhost:3000');
    } catch (e) {
      print('⚠️  Could not load FlintEnv, using defaults: $e');
      // Set defaults
      envVars.addAll({
        'DB_CONNECTION': 'postgres',
        'DB_HOST': 'localhost',
        'DB_PORT': '5432',
        'DB_USER': 'postgres',
        'DB_PASSWORD': 'password',
        'DB_NAME': 'flint',
        'DB_SECURE': 'false',
        'PORT': '3000',
        'APP_ENV': 'production',
        'APP_DEBUG': 'false',
        'APP_KEY': 'your-secret-key-here',
        'JWT_SECRET': 'your-jwt-secret-here',
      });
    }

    return envVars;
  }

  void _createDockerfile(String outputDir, String projectName) {
    final content = '''FROM dart:stable AS builder

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe lib/main.dart -o /app/$projectName

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \\
    ca-certificates \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/$projectName /app/

# Copy environment file and other assets
COPY .env /app/.env
COPY config/ /app/config/
COPY views/ /app/views/
COPY public/ /app/public/

# Create a non-root user
RUN useradd -m -u 1000 flint && chown -R flint:flint /app
USER flint

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \\\\
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["/app/$projectName"]
''';

    File(path.join(outputDir, 'Dockerfile')).writeAsStringSync(content);
  }

  void _createDockerCompose(
      String outputDir, String projectName, Map<String, String> envVars) {
    final dbConnection = envVars['DB_CONNECTION'] ?? 'postgres';
    final dbName = envVars['DB_NAME'] ?? 'flint';
    final dbUser = envVars['DB_USER'] ?? 'postgres';
    final dbPassword = envVars['DB_PASSWORD'] ?? 'password';
    final port = envVars['PORT'] ?? '3000';

    final content = '''version: '3.8'

services:
  $projectName:
    build: 
      context: ..
      dockerfile: $outputDir/Dockerfile
    ports:
      - "$port:$port"
    env_file:
      - .env
    environment:
      - DB_HOST=$dbConnection
      - FLINT_HOT=0
      - PORT=$port
    depends_on:
      - $dbConnection
      - redis
    restart: unless-stopped
    volumes:
      - uploads:/app/uploads

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: $dbName
      POSTGRES_USER: $dbUser
      POSTGRES_PASSWORD: $dbPassword
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: $dbName
      MYSQL_USER: $dbUser
      MYSQL_PASSWORD: $dbPassword
      MYSQL_ROOT_PASSWORD: \${DB_ROOT_PASSWORD:-root_password}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init-mysql.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped
    command: --default-authentication-plugin=mysql_native_password

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - $projectName
    restart: unless-stopped

volumes:
  postgres_data:
  mysql_data:
  uploads:
''';

    File(path.join(outputDir, 'docker-compose.yml')).writeAsStringSync(content);
  }

  void _createNginxConfig(String outputDir, String projectName) {
    final content = '''events {
    worker_connections 1024;
}

http {
    upstream flint_backend {
        server $projectName:3000;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://flint_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # WebSocket support
        location /ws {
            proxy_pass http://flint_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
        }

        # Health check endpoint
        location /health {
            proxy_pass http://flint_backend;
            access_log off;
        }
    }
}
''';

    File(path.join(outputDir, 'nginx.conf')).writeAsStringSync(content);
  }

  void _createDeployScript(String outputDir) {
    final content = '''#!/bin/bash

set -e

echo "🚀 Deploying Flint Application with Docker..."

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "\${RED}❌ ERROR: .env file not found\${NC}"
    echo -e "\${YELLOW}Please make sure you have an .env file in the project root\${NC}"
    exit 1
fi

echo -e "\${GREEN}📁 Using your existing .env configuration\${NC}"

# Stop existing containers
echo -e "\${YELLOW}🛑 Stopping existing services...\${NC}"
docker-compose down

# Build and start
echo -e "\${YELLOW}🐳 Building and starting services...\${NC}"
docker-compose up -d --build

# Wait for services to be healthy
echo -e "\${YELLOW}⏳ Waiting for services to be ready...\${NC}"
sleep 15

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo -e "\${GREEN}✅ Deployment successful!\${NC}"
    echo ""
    echo -e "\${GREEN}🌐 Your application is running at:\${NC}"
    echo -e "   • Frontend: http://localhost"
    echo -e "   • API: http://localhost:3000"
    echo -e "   • PostgreSQL: localhost:5432"
    echo -e "   • Redis: localhost:6379"
    echo ""
    echo -e "\${YELLOW}🔍 View logs: \${NC}docker-compose logs -f"
    echo -e "\${YELLOW}🛑 Stop services: \${NC}docker-compose down"
else
    echo -e "\${RED}❌ Some services failed to start\${NC}"
    echo -e "\${YELLOW}🔍 Check logs: \${NC}docker-compose logs"
    exit 1
fi
''';

    final scriptFile = File(path.join(outputDir, 'deploy.sh'))
      ..writeAsStringSync(content);

    // Make script executable (Unix-like systems)
    if (Platform.isLinux || Platform.isMacOS) {
      Process.run('chmod', ['+x', scriptFile.path]);
    }
  }

  void _createDockerIgnore(String outputDir) {
    final content = '''.git
.gitignore
README.md
Dockerfile
docker-compose.yml
.env
*.log
build/
.dart_tool/
.packages
pubspec.lock
$outputDir/
''';

    File(path.join(outputDir, '.dockerignore')).writeAsStringSync(content);
  }

  void _copyExistingEnv(String outputDir) {
    final envFile = File('.env');
    if (envFile.existsSync()) {
      print('📄 Copying your existing .env file to docker directory...');
      envFile.copySync(path.join(outputDir, '.env'));
    } else {
      print('⚠️  No .env file found. Please create one before deployment.');
      // Create a basic .env template
      _createEnvTemplate(outputDir);
    }
  }

  void _createEnvTemplate(String outputDir) {
    final content = '''# Database Configuration
DB_CONNECTION=postgres
DB_HOST=postgres
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=flint
DB_SECURE=false

# Application Settings
APP_ENV=production
APP_DEBUG=false
APP_KEY=your-secret-key-here
JWT_SECRET=your-jwt-secret-here
PORT=3000

# CORS Settings
CORS_ORIGIN=http://localhost:3000

# Email Configuration
MAIL_PROVIDER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=d7d14d51ba77d1
MAIL_PASSWORD=95257a44ac422f
MAIL_FROM_ADDRESS=youremail@gmail.com
MAIL_FROM_NAME=Eulogia Technologies

# Redis
REDIS_URL=redis://redis:6379
''';

    File(path.join(outputDir, '.env.template')).writeAsStringSync(content);
  }
}
