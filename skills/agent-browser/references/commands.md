# agent-browser Command Reference

## Navigation

| Command | Description |
|---------|-------------|
| `open <url>` | Navigate to URL |
| `back` | Go back in history |
| `forward` | Go forward in history |
| `reload` | Reload current page |

## Page Inspection

| Command | Description |
|---------|-------------|
| `snapshot` | Get accessibility tree (AI optimized) |
| `snapshot -i` | Interactive elements only |
| `snapshot -c` | Compact output |
| `snapshot -d <n>` | Limit tree depth |
| `snapshot -s "<selector>"` | Scope to CSS selector |
| `screenshot [path]` | Capture screenshot |

## Element Interaction

| Command | Description |
|---------|-------------|
| `click <selector>` | Click element |
| `fill <selector> <text>` | Fill input field |
| `select <selector> <value>` | Select dropdown option |
| `hover <selector>` | Hover over element |
| `focus <selector>` | Focus element |

## Semantic Locators (find)

| Command | Description |
|---------|-------------|
| `find role <role> click` | Find by ARIA role |
| `find text "<text>" click` | Find by visible text |
| `find label "<label>" fill "<value>"` | Find by label |
| `find first "<selector>" click` | Find first matching |
| `find nth <n> "<selector>" click` | Find nth element |

## Data Extraction

| Command | Description |
|---------|-------------|
| `get text <selector>` | Get text content |
| `get html <selector>` | Get innerHTML |
| `get value <selector>` | Get input value |
| `get url` | Get current URL |
| `get title` | Get page title |

## State Checks

| Command | Description |
|---------|-------------|
| `is visible <selector>` | Check visibility |
| `is enabled <selector>` | Check if enabled |
| `is checked <selector>` | Check checkbox state |

## Waiting

| Command | Description |
|---------|-------------|
| `wait <selector>` | Wait for element |
| `wait <ms>` | Wait milliseconds |
| `wait --text "<text>"` | Wait for text |
| `wait --load networkidle` | Wait for network idle |
| `wait --load domcontentloaded` | Wait for DOM ready |

## Session Management

| Command | Description |
|---------|-------------|
| `--session <name>` | Use named session (flag) |
| `session list` | List active sessions |
| `session close <name>` | Close session |

Environment variable: `AGENT_BROWSER_SESSION=<name>`

## Tab/Window Management

| Command | Description |
|---------|-------------|
| `tab` | List all tabs |
| `tab new [url]` | Open new tab |
| `tab <n>` | Switch to tab n |
| `tab close` | Close current tab |
| `window new` | Open new window |

## Cookies & Storage

| Command | Description |
|---------|-------------|
| `cookies` | List all cookies |
| `cookies get <name>` | Get cookie value |
| `cookies set <name> <value>` | Set cookie |
| `cookies delete <name>` | Delete cookie |
| `storage local` | Get localStorage |
| `storage local get <key>` | Get localStorage item |
| `storage local set <key> <value>` | Set localStorage item |
| `storage session` | Get sessionStorage |

## Network Control

| Command | Description |
|---------|-------------|
| `network route <url>` | Intercept requests |
| `network route <url> --abort` | Block requests |
| `network route <url> --body <json>` | Mock response |

## Browser Settings

| Command | Description |
|---------|-------------|
| `set viewport <width> <height>` | Set viewport size |
| `set device "<name>"` | Emulate device |
| `set geo <lat> <long>` | Set geolocation |
| `set offline on/off` | Toggle offline mode |
| `set media dark/light` | Set color scheme |

## Debugging

| Command | Description |
|---------|-------------|
| `trace start [path]` | Start trace recording |
| `trace stop` | Stop trace |
| `console` | Show console messages |
| `errors` | Show page errors |
| `highlight <selector>` | Highlight element |
| `state save <path>` | Save auth state |
| `state load <path>` | Load auth state |
