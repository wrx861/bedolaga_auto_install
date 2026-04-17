<div align="center">

# ⚡ Bedolaga Auto Install

**Интерактивный установщик Bedolaga Bot / Cabinet / Remnawave с запуском одной командой**

[![Platform](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu-blue)](#-что-делает-эта-команда)
[![Runtime](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](#-что-умеет)
[![Mode](https://img.shields.io/badge/Modes-Bot%20%7C%20Cabinet%20%7C%20Full-success)](#-что-умеет)

</div>

---

## 🚀 Одна команда

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wrx861/bedolaga_auto_install/main/install.sh)
```

## 🧭 Что делает эта команда

Эта команда:

1. ставит установщик в:
   ```bash
   /opt/bedolaga-stack-installer
   ```
2. сразу открывает меню установщика
3. создаёт глобальную команду:
   ```bash
   bot
   ```

После этого из любого места в системе можно просто писать:

```bash
bot
```

И снова откроется установщик.

---

## ✨ Что умеет

В меню установщика доступны действия:

- `Установить Бота`
- `Установить Кабинет`
- `Установить Бот + Кабину`
- `Обновить Бота`
- `Обновить Кабину`
- `Проверить обновления`
- `Показать текущее состояние`

---

## 🔄 Обновления

### Обновить Бота
Кнопка обновления бота выполняет:

```bash
git pull
docker compose down && docker compose up -d --build
```

### Обновить Кабину
Кнопка обновления кабинета выполняет:

```bash
git pull origin main
docker builder prune -a -f && docker compose down && docker compose build --no-cache && docker compose up -d
```

Если возникает ошибка — установщик показывает пользователю сам текст ошибки.

---

## 🧱 Что уже учтено

- раздельные директории для бота и кабинета
- автоматическая подготовка окружения
- определение существующего Remnawave
- режим `подключить Remnawave позже`
- live-проверка текущего состояния
- update-кнопки с реальной рабочей логикой
- глобальный вызов установщика через `bot`

---

## 📁 Куда ставится

Основной установщик живёт здесь:

```bash
/opt/bedolaga-stack-installer
```

Глобальная команда живёт здесь:

```bash
/usr/local/bin/bot
```

Если ты находишься, например, здесь:

```bash
root@nodehost:/opt/bedolaga-stack-installer#
```

или вообще в любой другой директории,
всё равно можно просто выполнить:

```bash
bot
```

---

## 📍 Статус проекта

Это новый Bedolaga installer, который уже прошёл живые проверки по основным сценариям и продолжает допиливаться до чистого production UX.
