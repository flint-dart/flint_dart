import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:path/path.dart' as path;

class MakeDockerCommand extends FlintCommand {
  MakeDockerCommand()
      : super('--make-docker', 'Creates Docker configuration for the project');

  @override
  Future<void> execute(List<String> args) async {
    final outputDir = args.isNotEmpty ? args.first : 'docker';

    Log.debug('🐳 Creating Docker configuration...');

    // Create docker directory
    final dockerDir = Directory(outputDir);
    if (await dockerDir.exists()) {
      Log.debug('📁 Docker directory already exists. Overwriting files...');
    } else {
      dockerDir.createSync(recursive: true);
    }

    // Load existing environment variables
    final envVars = _loadEnvVars();

    // Get project name from pubspec.yaml
    final pubspec = await File('pubspec.yaml').readAsString();
    final nameMatch = RegExp(r'name:\s*(\S+)').firstMatch(pubspec);
    final projectName = nameMatch?.group(1) ?? 'flint_app';

    final port = envVars['PORT'] ?? '3000';

    // Create Dockerfile
    _createDockerfile(outputDir, projectName, port);

    // Create docker-compose.yml with actual environment values
    _createDockerCompose(outputDir, projectName, envVars);

    // Create deployment script
    _createDeployScript(outputDir, port);

    // Create .dockerignore
    _createDockerIgnore(outputDir);

    // Copy existing .env file to docker directory
    _copyExistingEnv(outputDir);

    Log.info('✅ Docker configuration created successfully!');
    Log.info('📁 Files created in: $outputDir/');
    Log.info('🚀 To deploy: cd $outputDir && ./deploy.sh');
    Log.info('💡 Using your existing .env configuration');
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
      Log.debug('⚠️  Could not load FlintEnv, using defaults: $e');
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

  void _createDockerfile(String outputDir, String projectName, String port) {
    final content = '''FROM dart:stable

WORKDIR /app

# Install project dependencies.
# If dependency_overrides contains local path entries, remove that block so
# docker builds resolve package versions from pub instead of local filesystem.
COPY pubspec.* ./
RUN if grep -q "^dependency_overrides:" pubspec.yaml; then \\
      awk 'BEGIN{skip=0} /^dependency_overrides:/ {skip=1; next} skip && /^[^[:space:]]/ {skip=0} !skip {print}' pubspec.yaml > pubspec.docker.yaml && \\
      mv pubspec.docker.yaml pubspec.yaml; \\
    fi
RUN dart pub get

# Copy app source and refresh lock-resolved dependencies
COPY . .
RUN dart pub get --offline

ENV FLINT_HOT=0
ARG APP_PORT=$port
ENV PORT=\$APP_PORT
EXPOSE \$APP_PORT

CMD ["dart", "run", "lib/main.dart"]
''';

    File(path.join(outputDir, 'Dockerfile')).writeAsStringSync(content);
  }

  void _createDockerCompose(
      String outputDir, String projectName, Map<String, String> envVars) {
    final port = envVars['PORT'] ?? '3000';

    final content = '''version: '3.8'

services:
  $projectName:
    build: 
      context: ..
      dockerfile: $outputDir/Dockerfile
      args:
        APP_PORT: $port
    ports:
      - "$port:$port"
    env_file:
      - .env
    environment:
      - FLINT_HOT=0
      - PORT=$port
    restart: unless-stopped
''';

    File(path.join(outputDir, 'docker-compose.yml')).writeAsStringSync(content);
  }

  void _createDeployScript(String outputDir, String port) {
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

APP_PORT=\$(grep -E '^PORT=' .env | tail -n 1 | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
if [ -z "\$APP_PORT" ]; then
    APP_PORT="$port"
fi

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
    echo -e "   • API: http://localhost:\$APP_PORT"
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
    final ignoreOutputDir =
        outputDir == '.' || outputDir == './' ? '' : '$outputDir/\n';
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
$ignoreOutputDir''';

    File(path.join(outputDir, '.dockerignore')).writeAsStringSync(content);
  }

  void _copyExistingEnv(String outputDir) async {
    final envFile = File('.env');
    if (await envFile.exists()) {
      Log.debug('📄 Copying your existing .env file to docker directory...');
      envFile.copySync(path.join(outputDir, '.env'));
    } else {
      Log.debug('⚠️  No .env file found. Please create one before deployment.');
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
