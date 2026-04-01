#!/bin/bash
# Test completo del flujo npx (simula lo que haría un usuario real)
set -e

TEST_DIR=$(mktemp -d)
echo "📁 Directorio temporal: $TEST_DIR"
echo ""

# Limpiar cualquier instalación previa en ~/.claude
if [ -d "$HOME/.claude/session-topics" ]; then
    echo "🧹 Limpiando instalación previa..."
    rm -rf "$HOME/.claude/session-topics"
fi

# Crear un proyecto vacío
cd "$TEST_DIR"
npm init -y > /dev/null 2>&1

echo "📦 Paso 1: Instalando paquete local..."
npm install /Users/mac/dev/skill-dev/claude-session-topics/alexismunozdev-claude-session-topics-2.8.0.tgz --no-save

echo ""
echo "🚀 Paso 2: Ejecutando 'npx @alexismunozdev/claude-session-topics'..."
echo "   (Esto es EXACTAMENTE lo que haría un usuario al instalar)"
echo ""
npx @alexismunozdev/claude-session-topics

echo ""
echo "✅ Test completado exitosamente!"
echo ""
echo "📝 Resumen de lo que se instaló:"
echo "   - ~/.claude/session-topics/"
echo "   - ~/.claude/skills/auto-topic/"
echo "   - ~/.claude/skills/set-topic/"
echo ""

# Limpiar directorio temporal
cd /
rm -rf "$TEST_DIR"
