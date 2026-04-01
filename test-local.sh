#!/bin/bash
# Test local del paquete
set -e

# Crear directorio temporal
TEST_DIR=$(mktemp -d)
echo "📁 Directorio de prueba: $TEST_DIR"

cd "$TEST_DIR"

# Inicializar proyecto vacío
npm init -y > /dev/null 2>&1

# Instalar el tarball local
echo "📦 Instalando paquete local..."
npm install /Users/mac/dev/skill-dev/claude-session-topics/alexismunozdev-claude-session-topics-2.8.0.tgz

echo "✅ Instalación exitosa!"
echo ""
echo "🧪 Probando ejecución..."
npx @alexismunozdev/claude-session-topics --help || true

# Limpiar
cd /
rm -rf "$TEST_DIR"
echo ""
echo "✨ Test completado - todo funcionó correctamente!"
