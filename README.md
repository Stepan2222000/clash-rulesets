# clash-rulesets

Авто-сконвертированный список заблокированных в РФ доменов из [runetfreedom/russia-blocked-geosite](https://github.com/runetfreedom/russia-blocked-geosite) в формате Clash/Stash/mihomo `rule-provider` (`behavior: domain`, `format: yaml`).

Файл живёт по адресу:
```
https://raw.githubusercontent.com/Stepan2222000/clash-rulesets/main/ru-blocked-domain-provider.yaml
```

GitHub Action раз в 6 часов скачивает свежий `ru-blocked.txt` из upstream-репо, конвертирует и коммитит сюда. Stash на iOS и Clash Verge на macOS подхватывают свежую версию по своему `interval`.

---

## Зачем

`runetfreedom` публикует geosite в v2ray-формате (`domain:example.com`, `full:example.com`, `regexp:...`) — он подходит для xray/v2ray/sing-box, но **Clash/Stash/mihomo с `behavior: domain` его не матчат напрямую**. Этот репо берёт upstream-список и переводит в payload-формат Clash YAML.

Альтернативы, которые НЕ подходят:
- указать Stash напрямую на `runetfreedom/.../ru-blocked.txt` с `format: text` — провайдер загружается без ошибок, но правила не срабатывают (формат `domain:` не понимается)
- использовать `geosite.dat` через `geox-url` — работает в Clash Premium / mihomo, но не в Stash на iOS

Поэтому нужен посредник, который держит конвертированную копию.

---

## Цепочка обновления

```
runetfreedom/russia-blocked-geosite (release branch)
       │   обновляется upstream'ом каждые ~6ч
       ▼
GitHub Action (cron "17 */6 * * *", workflow_dispatch, push to scripts/)
       │   1. curl  ru-blocked.txt
       │   2. awk   → '+.example.com' / 'example.com'
       │   3. sort -u
       │   4. git diff --quiet || git commit && git push
       ▼
этот репо: ru-blocked-domain-provider.yaml
       │   raw.githubusercontent.com отдаёт с Cache-Control: max-age=300
       ▼
Stash / Clash Verge (interval: 21600 = 6ч)
```

Минимальная задержка от upstream-апдейта до устройства: **~5 мин кэш raw + до 6 ч interval клиента = до ~6 ч**.

---

## Что делает конвертер

См. [`scripts/build.sh`](scripts/build.sh).

1. `curl` с `release` ветки `runetfreedom/russia-blocked-geosite/ru-blocked.txt` (~1.7 МБ).
2. `awk` парсит строки:
   - `domain:example.com` → пишет **две** строки в payload: `'+.example.com'`
   - `full:example.com` → пишет одну строку: `'example.com'`
   - `regexp:...` — игнорируем (mihomo `behavior: domain` regex не поддерживает; они есть только для v2ray)
3. `sort -u` — удалить дубли, отсортировать.
4. Заголовок YAML с источником и SHA коммита runetfreedom для аудита.
5. Запись в `ru-blocked-domain-provider.yaml`.

### Про синтаксис `+.example.com`

В исходниках mihomo (`component/trie/domain.go`):

```go
const (
    wildcard        = "*"
    dotWildcard     = ""
    complexWildcard = "+"
    domainStep      = "."
)
```

`'+.example.com'` — это «complex wildcard»: одна запись, которая внутри trie раскрывается в два узла — `example.com` (apex) и `*.example.com` (любой поддомен). Это canonical-вариант: его использует Loyalsoldier и сама документация mihomo.

Альтернатива «две строки на каждый домен» (`'example.com'` + `'.example.com'`) тоже работает, но раздувает файл вдвое (3.4 МБ vs 1.8 МБ) при идентичной семантике.

### Детерминированный вывод

Билд-скрипт **не пишет timestamp** в файл. Только source-SHA. Это значит:
- если upstream не обновился, выход байт-в-байт совпадает с предыдущим
- workflow видит `git diff --quiet` и **не делает лишний коммит**
- история репо отражает только реальные обновления upstream'а

Когда нужно посмотреть «когда сгенерировано» — есть git-метаданные (`git log ru-blocked-domain-provider.yaml`).

---

## Использование

### Минимальный конфиг

```yaml
rule-providers:
  ru-blocked:
    type: http
    behavior: domain
    format: yaml
    url: https://raw.githubusercontent.com/Stepan2222000/clash-rulesets/main/ru-blocked-domain-provider.yaml
    path: ./ruleset/ru-blocked-domain-provider.yaml
    interval: 21600

rules:
  - RULE-SET,ru-blocked,PROXY
  - MATCH,DIRECT
```

### JSDelivr-зеркало

Если `raw.githubusercontent.com` тормозит / блокируется:
```
https://cdn.jsdelivr.net/gh/Stepan2222000/clash-rulesets@main/ru-blocked-domain-provider.yaml
```

### Чего НЕТ в `ru-blocked`

`ru-blocked` от runetfreedom — только домены, **которые блокирует РКН**. Это значит, что некоторые сервисы туда **не входят** и должны быть прописаны явно:

- `anthropic.com`, `claude.com` — Anthropic не блокирует РКН, но сам Anthropic блокирует RU-IP. Прокси нужен; домены — добавлять руками.
- `claudeusercontent.com`, `anthropicusercontent.com` — то же самое.
- `*.openai.com`, `*.chatgpt.com`, `*.oaistatic.com` — **есть** в `ru-blocked` (РКН блокирует).
- Telegram-домены (`telegram.org`, `t.me`, `telegra.ph`, `cdn-telegram.org`, `tdesktop.com`, `fragment.com` и др.) — **есть**.
- Telegram MTProto IP-ranges — отдельный rule-provider (рекомендую `https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt`).

### Пример полного routing-блока

```yaml
rules:
  # Anthropic / Claude (не в ru-blocked)
  - DOMAIN-SUFFIX,anthropic.com,PROXY
  - DOMAIN-SUFFIX,claude.com,PROXY
  - DOMAIN-SUFFIX,claude.ai,PROXY
  - DOMAIN-SUFFIX,claudeusercontent.com,PROXY
  - DOMAIN-SUFFIX,anthropicusercontent.com,PROXY

  # Telegram (домены частично в ru-blocked, но дублируем для надёжности)
  - DOMAIN-SUFFIX,telegram.org,PROXY
  - DOMAIN-SUFFIX,t.me,PROXY
  - DOMAIN-SUFFIX,telegra.ph,PROXY
  - DOMAIN-SUFFIX,fragment.com,PROXY
  - RULE-SET,telegram-cidr,PROXY,no-resolve

  # OpenAI / Codex (всё уже в ru-blocked, но явное чтение конфига приятнее)
  - DOMAIN-SUFFIX,openai.com,PROXY
  - DOMAIN-SUFFIX,chatgpt.com,PROXY

  # Catch-all из runetfreedom — всё остальное заблокированное РКН
  - RULE-SET,ru-blocked,PROXY

  # Всё прочее — direct
  - MATCH,DIRECT
```

---

## Workflow

[`.github/workflows/update.yml`](.github/workflows/update.yml):

| Триггер | Когда срабатывает |
|---|---|
| `schedule: cron "17 */6 * * *"` | каждые 6 часов, на 17-й минуте (минута выбрана не на пике, чтобы не попасть в очередь GH-крона) |
| `workflow_dispatch` | ручной запуск из Actions UI или `gh workflow run`. Также страховка от 60-day inactivity disable публичных репо |
| `push: paths: scripts/**` | при правке скрипта пересобрать и закоммитить новый payload |

Permissions: `contents: write` — `GITHUB_TOKEN` пушит обратно в репо. Push от bot'а **не триггерит** workflow повторно (защита от циклов в GitHub Actions).

---

## Manual rebuild

```bash
./scripts/build.sh
```

Делает то же самое, что Action: качает upstream, конвертирует, перезаписывает `ru-blocked-domain-provider.yaml`. Полезно если хочется проверить локально или собрать с правками скрипта до пуша.

---

## Источники

- [runetfreedom/russia-blocked-geosite](https://github.com/runetfreedom/russia-blocked-geosite) — upstream-список (auto-update каждые 6ч)
- [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) — pre-converted Clash YAML rule-providers (включая `telegramcidr.txt`)
- [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) — geosite-категории, на основе которых строится runetfreedom
- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) — реализация Clash core, документация по rule-providers и trie-семантике
