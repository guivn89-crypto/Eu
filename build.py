#!/usr/bin/env python3
"""
BBC HUB - build script.

Concatena os módulos de src/ em um único arquivo Lua (dist/menu_bundle.lua),
na ordem de dependência: utils -> ui -> features -> main.

Cada módulo é encapsulado em uma função e registrado em BBC.Modules, o que
mantém o bundle 100% single-file (sem require/module) e compatível com
executores como o Delta.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
DIST = ROOT / "dist"
OUTPUT = DIST / "menu_bundle.lua"

# A ordem importa: cada camada depende apenas das anteriores.
MODULES = [
    ("utils/security.lua", "utils.security"),
    ("utils/drawing.lua", "utils.drawing"),
    ("ui/theme.lua", "ui.theme"),
    ("ui/components.lua", "ui.components"),
    ("ui/window.lua", "ui.window"),
    ("features/visuals.lua", "features.visuals"),
    ("features/player.lua", "features.player"),
    ("features/combat.lua", "features.combat"),
    ("features/world.lua", "features.world"),
    ("main.lua", "main"),
]

HEADER = """--!nocheck
--[[
    BBC HUB - menu_bundle.lua
    Arquivo gerado automaticamente por build.py. NÃO EDITE DIRETAMENTE.
    Edite os módulos em src/ e rode: python3 build.py

    Ordem de carga: utils -> ui -> features -> main.
    Single-file: não usa require(), module() nem dependências locais.
]]

local BBC = {
    Modules = {},
    Utils = {},
    UI = {},
    Features = {},
    State = {},
}

local function __module(name, loader)
    local ok, result = pcall(loader, BBC)
    if not ok then
        warn(string.format("[BBC] falha ao carregar o módulo '%s': %s", name, tostring(result)))
        return nil
    end
    BBC.Modules[name] = result
    return result
end

"""

FOOTER = """
return BBC
"""


def read_module(relative_path: str) -> str:
    path = SRC / relative_path
    if not path.is_file():
        raise FileNotFoundError(f"módulo não encontrado: {path}")
    source = path.read_text(encoding="utf-8")
    if "require(" in source:
        raise ValueError(
            f"{relative_path}: require() não é permitido no bundle single-file"
        )
    return source.rstrip() + "\n"


def build() -> Path:
    if not SRC.is_dir():
        raise FileNotFoundError(f"pasta src/ não encontrada em {SRC}")

    parts = [HEADER]
    for relative_path, module_name in MODULES:
        source = read_module(relative_path)
        parts.append(f"-- ============================================================\n")
        parts.append(f"-- módulo: {module_name}  ({relative_path})\n")
        parts.append(f"-- ============================================================\n")
        parts.append(f'__module("{module_name}", function(BBC)\n')
        parts.append(source)
        parts.append("\nend)\n\n")

    parts.append(FOOTER)
    bundle = "".join(parts)

    DIST.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(bundle, encoding="utf-8")
    return OUTPUT


def main() -> int:
    try:
        output = build()
    except Exception as error:  # noqa: BLE001 - CLI precisa reportar qualquer falha
        print(f"[build] erro: {error}", file=sys.stderr)
        return 1

    lines = output.read_text(encoding="utf-8").count("\n") + 1
    size = output.stat().st_size
    print(f"[build] ok: {output.relative_to(ROOT)} ({lines} linhas, {size} bytes)")
    print("[build] módulos:", " -> ".join(name for _, name in MODULES))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
