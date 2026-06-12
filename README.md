```
   ███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
   ██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
   █████╗  ███████║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝
   ██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝
   ██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║
   ╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝
        m c p   t o o l s   ·   MCPs on-demand para Droid
```

# factory-mcp-tools

> Gestión on-demand de MCPs para [Factory Droid](https://factory.ai) — mantené el budget de contexto bajo control habilitando MCPs sólo cuando los necesitás.

Un toolkit chiquito que convierte el roster de MCPs de Factory en un recurso **pay-as-you-go**, en lugar de un impuesto permanente sobre tu ventana de contexto.

Incluye:

- **`toggle-mcp.sh`** — list / enable / disable de servidores MCP en `~/.factory/mcp.json` con backups y estimación de costo en tokens.
- **Skill `mcp-orchestrator`** — una skill de Factory que le enseña a Droid a detectar cuándo un MCP ayudaría, chequear si está habilitado, hacer fallback al CLI cuando es posible, y decirte exactamente cómo levantar un MCP (`toggle-mcp.sh enable <name>` + `droid -r`).

---

## ¿Por qué?

Por default, cada servidor MCP que configurás en `~/.factory/mcp.json` se carga en la sesión al startup. Cada uno cuesta tokens de contexto por el schema de sus tools:

| MCP | Tokens aprox |
|---|---|
| playwright | ~3.500 |
| docker | ~2.800 |
| github | ~2.000 |
| neon-admin | ~1.500 |
| notion | ~1.500 |
| linear | ~1.200 |
| sentry | ~1.000 |
| postgres-* | ~80 cada uno |

Si tenés 8-10 MCPs configurados "por las dudas", son fácil **10-15k tokens** de contexto perdidos antes de escribir un solo prompt. La mayoría de las sesiones sólo necesitan 1-2 de ellos.

Este toolkit te deja tener los MCPs **configurados pero deshabilitados**, y traerlos online sólo para la tarea del momento.

---

## Instalación

```bash
git clone https://github.com/Jcibernet/factory-mcp-tools.git
cd factory-mcp-tools

# 1) Instalar el script de toggle
mkdir -p ~/.factory/bin
cp bin/toggle-mcp.sh ~/.factory/bin/
chmod +x ~/.factory/bin/toggle-mcp.sh

# 2) (Opcional) instalar la skill globalmente
mkdir -p ~/.factory/skills/mcp-orchestrator
cp skills/mcp-orchestrator/SKILL.md ~/.factory/skills/mcp-orchestrator/

# 3) Agregar ~/.factory/bin al PATH (opcional pero recomendado)
echo 'export PATH="$HOME/.factory/bin:$PATH"' >> ~/.bashrc   # o ~/.zshrc
```

---

## Uso

```bash
# Inspeccionar
toggle-mcp.sh list                       # todos los MCPs + enabled/disabled + tipo
toggle-mcp.sh status                     # set habilitado + costo estimado de contexto

# Toggle (uno o varios)
toggle-mcp.sh enable docker
toggle-mcp.sh disable playwright notion linear
toggle-mcp.sh on docker                  # alias
toggle-mcp.sh off playwright             # alias
```

Cada toggle hace un backup con timestamp de `~/.factory/mcp.json` en `~/.factory/mcp.json.bak-<epoch>` antes de escribir.

### Aplicar los cambios

Los MCPs se cargan al startup del CLI de Droid, así que los toggles aplican en la **próxima** sesión:

```bash
toggle-mcp.sh enable docker
exit          # salir de la sesión actual de droid
droid -r      # reanudar la misma sesión con el nuevo set de MCPs cargados
```

El estado de la sesión (mensajes, specs, historial de tools) lo persiste Droid, así que el ciclo restart-and-resume es no-destructivo.

### Output de ejemplo

```
$ toggle-mcp.sh status
Enabled  (3): playwright, postgres-felzbooks-dev, finaudit-prod-postgres
Disabled (6): sentry, notion, github, linear, neon-admin, docker
Estimated context cost of enabled MCPs: ~3660 tokens
```

---

## La skill `mcp-orchestrator`

Una skill de Factory que le enseña a Droid la **política** alrededor de los MCPs on-demand.

Qué hace, en castellano llano:

1. Detecta cuando un pedido del usuario se beneficiaría de un MCP (ej. "listame mis containers" → docker).
2. Corre `toggle-mcp.sh status` para ver qué está cargado actualmente.
3. Si el MCP ya está habilitado → lo usa.
4. Si está deshabilitado pero hay un fallback de CLI lo suficientemente bueno → usa el CLI silenciosamente (ej. `docker ps` via Execute).
5. Si está deshabilitado y el fallback es pobre → imprime el comando exacto de toggle + restart + resume y se detiene.
6. Nunca edita `mcp.json` directamente (siempre vía `toggle-mcp.sh` para que se generen los backups).
7. Nunca afirma que un toggle aplica en la sesión actual.

Instalar:

```bash
mkdir -p ~/.factory/skills/mcp-orchestrator
cp skills/mcp-orchestrator/SKILL.md ~/.factory/skills/mcp-orchestrator/
```

La skill queda disponible en tu próxima sesión de Droid y se auto-invoca cuando aplica.

---

## Cómo decide los costos en tokens `toggle-mcp.sh`

Las estimaciones son intencionalmente aproximadas — viven como una tabla estática dentro del script. La idea es darte un orden de magnitud "esto es ~3.5k vs 80", no un budget exacto. Ajustá la tabla a tus propias mediciones si te importa la precisión.

```bash
# dentro de toggle-mcp.sh
declare -A TOKENS=(
  [playwright]=3500
  [docker]=2800
  [github]=2000
  ...
)
```

---

## Herramienta complementaria

Si principalmente usás Playwright MCP para **debug visual one-shot** (screenshot + console + network + a11y + perf), revisá [**visual-debug**](https://github.com/Jcibernet/visual-debug) — un CLI de un solo archivo que le da al agente la misma visibilidad del navegador con **cero costo de contexto MCP**. Combinalos:

- Mantené Playwright MCP **deshabilitado** por default.
- Para inspección one-shot: `visual-debug http://localhost:3000` via Execute.
- Sólo habilitá Playwright MCP cuando necesites flujos interactivos multi-step.

---

## Contribuir

PRs bienvenidas. Mantené el script de toggle como bash POSIX-leaning + Python (ya viene instalado en todo lugar donde corre Droid). Mantené el prompt de la skill por debajo de las 200 líneas.

---

## Licencia

MIT © Juan Cibernet
