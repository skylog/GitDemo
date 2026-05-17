# Finom Drift & Travel

Браузерная сетевая аркадная гонка на офисных креслах. До 8 игроков, каждый со своего ПК, 3 круга по офисному треку.

## Быстрый старт

### Требования

- **Godot 4.3-stable** — для редактирования и Web Export
- **Node.js 20+** — для relay-сервера
- **Браузер** — Chrome / Firefox (WebGL2 + WASM)

---

### 1. Запуск relay-сервера (на машине ведущего)

```bash
cd relay
npm install
node relay.js
```

Relay слушает на порту `8080`. Проверь, что порт открыт в файрволе:

- **macOS**: разреши входящие в System Settings → Firewall
- **Windows**: `netsh advfirewall firewall add rule name="relay" dir=in action=allow protocol=TCP localport=8080`
- **Linux**: `sudo ufw allow 8080/tcp`

Узнай свой LAN IP:

```bash
# macOS / Linux
hostname -I   # или ifconfig

# Windows
ipconfig      # ищи "IPv4 Address"
```

### 2. Web Export (один раз)

1. Открой `project.godot` в Godot 4.3.
2. **Project → Export → Add → Web**.
3. Нажми **Export Project** → папка `build/web/`.

### 3. Раздача клиентам

На машине ведущего запусти HTTP-сервер из папки `build/web/`:

```bash
cd build/web
python -m http.server 8000
# или
npx serve .
```

Клиенты открывают в браузере: `http://YOUR-LAN-IP:8000`

### 4. Игра

1. Ведущий жмёт **Create Room** → получает 4-символьный код (например, `K7QX`).
2. Остальные вводят `ws://YOUR-LAN-IP:8080` как Relay Address, код комнаты → **Join Room**.
3. Когда все зашли — ведущий жмёт **Start**.
4. WASD — движение, Space — дрифт.
5. F1 (только ведущий) — Physics Panel; F2/F3 — пресеты.

---

### Вне LAN (ngrok)

```bash
ngrok tcp 8080
```

ngrok выдаст `tcp://0.tcp.ngrok.io:XXXXX` — клиенты вводят как Relay Address: `ws://0.tcp.ngrok.io:XXXXX`.

> ⚠️ Страница должна раздаваться по `http://`, не `https://` — иначе браузер заблокирует `ws://` mixed-content.

---

## Управление

| Клавиша | Действие |
|---------|----------|
| W / ↑ | Газ |
| S / ↓ | Тормоз / задний ход |
| A / D | Руль |
| Space | Дрифт |
| R | Restart (в Results) |
| F1 | Physics Panel (только host) |
| F2 | Пресет Mario Kart (только host) |
| F3 | Пресет Kart Kraft (только host) |

---

## Структура репозитория

```
drift-and-travel/
├── project.godot        # Godot 4.3 проект
├── README.md            # этот файл
├── relay/               # Node.js relay-сервер
│   ├── relay.js
│   └── package.json
├── scenes/              # Godot сцены и скрипты
├── scripts/             # Autoload скрипты (GameManager, RaceManager, NetworkManager…)
├── resources/           # KartConfig + пресеты
└── docs/                # PRD + GDD + статус спринтов
```

## Известные ограничения Beta

- Relay без TLS — только LAN или ngrok.
- Без аудио, частиц, реальной офисной геометрии.
- Host migration при дисконнекте хоста не реализован (клиенты возвращаются в меню).
