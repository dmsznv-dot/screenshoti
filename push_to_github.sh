#!/bin/bash
set -e

REPO_URL="https://github.com/dmsznv-dot/screenshoti.git"

echo "🚀 1/4: Проверка Git в текущей папке..."
if [ ! -d ".git" ]; then
    git init
fi

git branch -M main

if git remote | grep -q "^origin$"; then
    git remote set-url origin "$REPO_URL"
else
    git remote add origin "$REPO_URL"
fi

echo "📝 2/4: Добавление всех файлов проекта в индекс..."
git add -A
git commit -m "feat: Screenshoti macOS native app + DMG installer builder" || echo "ℹ️ Нет новых изменений для коммита"

echo "🔄 3/4: Синхронизация с удаленным репозиторием (если там уже есть README или коммиты)..."
git pull origin main --allow-unrelated-histories --no-edit || echo "ℹ️ Удаленная ветка пуста или будет перезаписана"

echo "📤 4/4: Отправка кода в $REPO_URL ..."
git push -u origin main --force

echo "✅ Успешно! Весь проект загружен в https://github.com/dmsznv-dot/screenshoti"
