#!/usr/bin/env python3
"""Monta o BBC_HUB.luau a partir dos módulos em src/.

O hub é distribuído como um único arquivo (o executor carrega um loadstring só),
mas o código-fonte fica separado em módulos para facilitar a manutenção.

    python3 build.py

Reconstroi BBC_HUB.luau na ordem dos módulos. Os módulos não são scripts
independentes: eles se assumem em ordem, como fatias do mesmo arquivo.
"""
import os
import sys

MODULES = [
    "00_head.luau",
    "05_ui_support.luau",
    "10_ui.luau",
    "20_config.luau",
    "23_appearance.luau",
    "24_runtime.luau",
    "25_security.luau",
    "26_guard.luau",
    "27_profiles.luau",
    "28_operations.luau",
    "29_favorites.luau",
    "30_actions.luau",
    "40_menu.luau",
    "50_tabs.luau",
    "60_engine.luau",
]

HEADER = """-- ============================================================
--  BBC_HUB.luau - GERADO por build.py (nao edite este arquivo)
--  Fonte: src/  ·  Reconstrua com:  python3 build.py
-- ============================================================
"""

ROOT = os.path.dirname(os.path.abspath(__file__))


def main():
    src = os.path.join(ROOT, "src")
    partes = []
    for nome in MODULES:
        caminho = os.path.join(src, nome)
        if not os.path.isfile(caminho):
            sys.exit("falta o modulo: " + caminho)
        with open(caminho, "r", encoding="utf-8") as f:
            partes.append(f.read())
    saida = os.path.join(ROOT, "BBC_HUB.luau")
    with open(saida, "w", encoding="utf-8") as f:
        f.write(HEADER + "".join(partes))
    print("BBC_HUB.luau montado: %d modulos, %d linhas" % (
        len(MODULES), sum(p.count("\n") for p in partes)))


if __name__ == "__main__":
    main()
