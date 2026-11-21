"""Verificações estáticas do artefato; não substituem testes no Roblox."""
import importlib.util
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BuildTests(unittest.TestCase):
    def test_generated_file_matches_sources(self):
        spec = importlib.util.spec_from_file_location('build', ROOT / 'build.py')
        build = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(build)
        expected = build.HEADER + ''.join((ROOT / 'src' / name).read_text(encoding='utf-8') for name in build.MODULES)
        self.assertEqual((ROOT / 'BBC_HUB.luau').read_text(encoding='utf-8'), expected)

    def test_direct_roblox_enums_and_instance_classes_against_snapshot(self):
        # Snapshot parcial de API versionada; não cobre nomes dinâmicos ou runtime.
        snapshot = json.loads((ROOT / 'tests' / 'roblox_api_snapshot.json').read_text(encoding='utf-8'))
        for path in sorted((ROOT / 'src').glob('*.luau')):
            for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                for category, item in re.findall(r'\bEnum\.([A-Za-z_]\w*)\.([A-Za-z_]\w*)', line):
                    self.assertIn(category, snapshot['enums'], f'{path.name}:{line_no}')
                    self.assertIn(item, snapshot['enums'][category], f'{path.name}:{line_no} Enum.{category}.{item}')
                for class_name in re.findall(r"\b(?:Instance\.new|create|mk|mkFx|new)\(\s*[\"']([A-Za-z][A-Za-z0-9_]*)[\"']", line):
                    self.assertIn(class_name, snapshot['constructible_classes'], f'{path.name}:{line_no}')

    def test_environment_effect_property_contract(self):
        snapshot = json.loads((ROOT / 'tests' / 'roblox_api_snapshot.json').read_text(encoding='utf-8'))
        for name in ('Cover', 'Enabled'):
            self.assertIn(name, snapshot['properties']['Clouds'])
        self.assertNotIn('Enabled', snapshot['properties']['Atmosphere'])
        self.assertNotIn('Enabled', snapshot['properties']['Sky'])

    def test_literal_gui_constructor_properties_against_snapshot(self):
        # Examina nomes literais no primeiro nível das tabelas de propriedades.
        # Não interpreta nomes calculados, setters posteriores ou chamadas dinâmicas.
        snapshot = json.loads((ROOT / 'tests' / 'roblox_api_snapshot.json').read_text(encoding='utf-8'))
        tokens = re.compile(r"""--\[(=*)\[.*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\[(=*)\[.*?\]\2\]|[A-Za-z_]\w*|==|~=|<=|>=|[^\s]""", re.S)
        for path in sorted((ROOT / 'src').glob('*.luau')):
            text = path.read_text(encoding='utf-8')
            ts = [(m.group(), m.start()) for m in tokens.finditer(text) if not m.group().startswith('--')]
            for i, (token, _) in enumerate(ts):
                if token not in ('create', 'mk', 'new') or i + 4 >= len(ts):
                    continue
                if ts[i+1][0] != '(' or ts[i+3][0] != ',' or ts[i+4][0] != '{':
                    continue
                literal = ts[i+2][0]
                if not literal.startswith(('"', "'")):
                    continue
                class_name = literal[1:-1]
                self.assertIn(class_name, snapshot['properties'], path.name)
                depth, k = 1, i + 5
                while k < len(ts) and depth:
                    word, pos = ts[k]
                    if word == '{': depth += 1
                    elif word == '}': depth -= 1
                    elif depth == 1 and re.fullmatch(r'[A-Za-z_]\w*', word) and k + 1 < len(ts) and ts[k+1][0] == '=':
                        self.assertIn(word, snapshot['properties'][class_name],
                                      f'{path.name}:{text.count(chr(10), 0, pos)+1} {class_name}.{word}')
                    k += 1

    def test_terrain_material_mapping_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = actions[actions.index('    local TERRAIN_MATS ='):actions.index('    -- folhas / troncos')]
        setup = (ROOT / 'tests' / 'terrain_material_spec.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'terrain_material_assert.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'terrain.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_effects_created_disabled_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    local FX = {}'):source.index('    -- Reutiliza as nuvens do jogo')]
        setup = (ROOT / 'tests' / 'effect_init_spec.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'effect_init_assert.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'effect_init.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_cloud_reuse_and_restoration_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        properties = source[source.index('    Actions.originals ='):source.index('    local function onCleanup')]
        clouds = source[source.index('    local cloudTarget'):source.index('    local function applyLighting()')]
        setup = (ROOT / 'tests' / 'clouds_spec.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'clouds_assert.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'clouds.luau'
            path.write_text(setup + properties + clouds + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_hook_primitives_are_not_used_in_source(self):
        # Este teste só verifica o código local, não dependências ou executor.
        code = '\n'.join(p.read_text(encoding='utf-8') for p in (ROOT / 'src').glob('*.luau'))
        for primitive in ('hookmetamethod', 'getnamecallmethod', 'hookfunction'):
            self.assertNotIn(primitive, code)

    def test_connections_use_guard_helpers(self):
        # Conexões diretas só existem nas duas implementações de guarda.
        for path in (ROOT / 'src').glob('*.luau'):
            count = len(re.findall(r':Connect\s*\(', path.read_text(encoding='utf-8')))
            expected = 1 if path.name in {'00_head.luau', '26_guard.luau'} else 0
            self.assertEqual(count, expected, path.name)

    def test_high_risk_action_boundaries_are_guarded(self):
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        for group in ('PLAYER_ACTIONS', 'WORLD_ACTIONS', 'EXTRA_ACTIONS', 'CHAR_ACTIONS', 'LOCALFX_ACTIONS', 'COMBAT_ACTIONS'):
            self.assertIn('Library.Safety:guardActions(' + group, source)
        for name in ('Saque automático', 'Recarga automática', 'Abastecer cargadores', 'Atravessar porta', 'MIRA', 'Aura letal', 'Anti AFK'):
            self.assertIn('Library.Safety:allow("' + name + '", true)', source)

    def test_remote_actions_are_guarded(self):
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        reload_code = source[source.index('    local function doReload()'):source.index('    local function doRefill()')]
        self.assertIn('Library.OperationGuard:resolveRemote', reload_code)
        self.assertIn('Library.OperationGuard:take("reload", os.clock())', reload_code)
        self.assertNotIn('GetDescendants', reload_code)
        self.assertIn('Library.OperationGuard:take("loot", os.clock())', source)
        self.assertIn('dist <= prompt.MaxActivationDistance', source)

    def test_loot_and_streaming_guardrails(self):
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        loot = actions[actions.index('    function Actions.getLootConfig()'):actions.index('    -- ===== campo de visão')]
        self.assertIn('LootPlaceId', loot)
        self.assertIn('LootPromptPaths', loot)
        self.assertIn('resolvePrompt(Workspace, path)', loot)
        self.assertNotIn('GetDescendants', loot)
        self.assertIn('Actions.lootToken == token', loot)
        self.assertIn('LP.CharacterRemoving', actions)
        self.assertIn('Library.Safety:disableTracked()', actions)
        self.assertIn('Actions.soundToolConns[tool]', actions)
        self.assertIn('if not ok then\n            if not Actions.raycastWarned', actions)
        self.assertIn('return res.Instance ~= nil and res.Instance:IsDescendantOf(target.m)', actions)
        engine = (ROOT / 'src' / '60_engine.luau').read_text(encoding='utf-8')
        self.assertIn('Workspace.DescendantRemoving', engine)
        self.assertIn('itemCounts[kind] < 2048', engine)
        self.assertIn('candCount < 2048', engine)

    def test_header_configuration_preserves_safe_management(self):
        ui = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        tabs = (ROOT / 'src' / '50_tabs.luau').read_text(encoding='utf-8')
        self.assertIn('local cfgBar =', ui)
        self.assertIn('self:RequestSaveConfig(cfgBox.Text)', ui)
        self.assertIn('self:StageConfigPreview(name)', ui)
        self.assertIn('self:ConfirmConfigPreview(name)', ui)
        self.assertIn('Salvar configuração', tabs)
        self.assertIn('Revisar configuração', tabs)
        self.assertIn('Confirmar carregamento', tabs)
        self.assertIn('NoPersist = true', tabs)
        self.assertIn('Window._cfgBox = name.Box', tabs)
        self.assertIn('self._autoSaveBlocked = true', ui)

    def test_existing_menu_categories_remain_in_order(self):
        tabs = (ROOT / 'src' / '50_tabs.luau').read_text(encoding='utf-8')
        names = re.findall(r'Window:Tab\(\{ Name = "([^"]+)"', tabs)
        self.assertEqual(names, ['VISUAIS', 'JOGADOR', 'COMBATE', 'MUNDO', 'EXTRAS', 'BUSCAR SAQUE', 'SERVIDORES', 'SKINS', 'MISSÕES', 'COMERCIANTES', 'CONFIGURAÇÕES'])
        for name in ('Mochila personalizada', 'Mochila', 'Barra rápida', 'Hack de velocidade', 'Voar', 'Saque automático'):
            self.assertIn('"' + name + '"', tabs)
        menu = (ROOT / 'src' / '40_menu.luau').read_text(encoding='utf-8')
        for name in ('Mochila personalizada', 'Mochila', 'Mira falsa', 'Trocar personagem'):
            self.assertIn('"' + name + '"', menu)

    def test_icons_do_not_execute_remote_code(self):
        source = (ROOT / 'src' / '00_head.luau').read_text(encoding='utf-8')
        icons = source[source.index('-- ---------- Ícones'):source.index('-- ---------- Servidores')]
        self.assertNotIn('loadstring', icons)
        self.assertNotIn('HttpGet', icons)
        self.assertNotIn('readfile', icons)
        self.assertIn('GLYPHS', icons)

    def run_luau_spec(self, module, spec):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / module).read_text(encoding='utf-8')
        test = (ROOT / 'tests' / spec).read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test.luau'
            path.write_text('local Library = {Registry = {}}\n' + source + '\n' + test, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_favorites_with_luau_if_available(self):
        self.run_luau_spec('29_favorites.luau', 'favorites_spec.luau')

    def test_safety_policy_with_luau_if_available(self):
        self.run_luau_spec('25_security.luau', 'safety_spec.luau')

    def test_operations_with_luau_if_available(self):
        self.run_luau_spec('28_operations.luau', 'operations_spec.luau')

    def test_profiles_with_luau_if_available(self):
        self.run_luau_spec('27_profiles.luau', 'profiles_spec.luau')

    def test_reload_integration_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = actions[actions.index('    local function equippedTool()'):actions.index('    local function doRefill()')]
        module = (ROOT / 'src' / '28_operations.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'reload_integration_spec.luau').read_text(encoding='utf-8')
        setup = """local Library = { Safety = {} }
local Actions, COMBAT, LP = {alive = true}, {}, {}
local enabled, now, BBC_CONFIG = true, 0, {}
local os = {clock = function() return now end}
local function getgenv() return {BBC_CONFIG = BBC_CONFIG} end
local function tr(text) return text end
local function say(text) end
local function warn(text) end
function Library.Safety:allow(name, value) return not enabled end
function Library.Safety:disable(name) end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'reload.luau'
            path.write_text(setup + module + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_gui_parent_fallback_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '00_head.luau').read_text(encoding='utf-8')
        helper = source[source.index('-- ---------- Raiz da interface ----------'):source.index('-- ---------- Notificações ----------')]
        spec = (ROOT / 'tests' / 'gui_parent_spec.luau').read_text(encoding='utf-8')
        setup = """local Library = {GuiProtection = {}}
local gethui, coreValue, playerValue, createdGui, unprotected
local game = {}
function game:GetService(name) assert(name == "CoreGui"); return coreValue end
local LocalPlayer = {}
function LocalPlayer:FindFirstChildOfClass(name) return playerValue end
function LocalPlayer:WaitForChild(name, timeout) return playerValue end
function Library:UnprotectGui(gui) unprotected = gui end
local function create(class, props) return createdGui end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'gui_parent.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_gui_protection_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '00_head.luau').read_text(encoding='utf-8')
        helper = source[source.index('-- Algumas bibliotecas usam uma API opcional'):source.index('local function corner(')]
        spec = (ROOT / 'tests' / 'gui_protection_spec.luau').read_text(encoding='utf-8')
        setup = """local Library = {}
local protectgui, unprotectgui, syn
local warnings = {}
local function warn(message) warnings[#warnings + 1] = message end
local function safeConnect(signal, callback) signal.fire = callback end
local Instance = {}
function Instance.new(class) return {ClassName = class, Destroying = {}} end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'gui_protection.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_direct_gui_creation_uses_protection(self):
        tabs = (ROOT / 'src' / '50_tabs.luau').read_text(encoding='utf-8')
        engine = (ROOT / 'src' / '60_engine.luau').read_text(encoding='utf-8')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        self.assertIn('Library:ProtectGui(overlay)', tabs)
        self.assertIn('Library:ProtectGui(espGui)', engine)
        self.assertIn('then Library:ProtectGui(i) end', engine)
        self.assertIn('Library:ProtectGui(gui)', actions)

    def test_ui_filter_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('function Window:_filter(q)'):source.index('function Window:Destroy()')]
        spec = (ROOT / 'tests' / 'ui_filter_spec.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'filter.luau'
            path.write_text('local Window, Library = {}, { Tr = function(s) return s end }\n' + (ROOT / 'src' / '05_ui_support.luau').read_text(encoding='utf-8') + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_appearance_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '23_appearance.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'appearance_spec.luau').read_text(encoding='utf-8')
        setup = """local files, decoded = {}, nil
local Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end,
    fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
local Library = {ThemePresets = {Orange = {Accent = Color3.new(1, 0.5, 0)}}, Theme = {}, Registry = {}, _bindings = {}, _themeListeners = {}}
Library.MakeTheme = function(c) return {Accent = c} end
local warn = function() end
local isfile = function(path) return files[path] ~= nil end
local readfile = function(path) assert(files[path]); return files[path] end
local writefile = function(path, data) files[path] = data end
local isfolder = function() return true end
local game = {GetService = function() return {JSONDecode = function() assert(decoded); return decoded end, JSONEncode = function() return "encoded" end} end}
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'appearance.luau'
            path.write_text(setup + source + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_intro_uses_actual_loading_and_no_remote_icon_wait(self):
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        intro = source[source.index('function Window:_startIntro'):source.index('function Window:SetScaleFactor')]
        self.assertIn('if not self._loaded then', intro)
        self.assertIn('Montagem ainda em andamento', intro)
        self.assertIn('safeConnect(skip.MouseButton1Click, cleanup)', intro)
        self.assertNotIn('while not lucide', intro)

    def test_hotbar_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    -- Barra local genérica'):source.index('    local function toggleInv()')]
        spec = (ROOT / 'tests' / 'hotbar_spec.luau').read_text(encoding='utf-8')
        setup = """local Actions, Library = {alive = true, getAdjustment = function() return 8 end}, {Panic = false}
local cleanup
local function onCleanup(f) cleanup = f end
local function signal() return {callbacks = {}} end
local function fire(s) for _, f in ipairs(s.callbacks) do f() end end
function Actions.connect(s, f)
    table.insert(s.callbacks, f)
    return {Disconnect = function() end}
end
local task = {defer = function(f) f() end}
local Enum = {ScrollingDirection = {X=1}, FillDirection = {Horizontal=1}}
local Vector2 = {new = function() return {} end}
local UDim = {new = function() return {} end}
local UDim2 = {new = function() return {} end, fromOffset = function() return {} end}
local Color3 = {new = function() return {} end, fromRGB = function() return {} end}
local Instance = {new = function(class) return {MouseButton1Click = signal()} end}
function Library:CreateRootGui() return {Destroy = function(self) self.destroyed = true end} end
local equipped, unequipped
local hum = {EquipTool = function(self, tool) equipped = tool end, UnequipTools = function() unequipped = true end}
local character = {ChildAdded=signal(), ChildRemoved=signal()}
local backpack = {ChildAdded=signal(), ChildRemoved=signal()}
local axe = {Name='Axe', Parent=backpack, IsA=function(self, name) return name == 'Tool' end}
local sword = {Name='Sword', Parent=backpack, IsA=function(self, name) return name == 'Tool' end}
function character:GetChildren() return {} end
function character:FindFirstChildOfClass(n) return hum end
function backpack:GetChildren() return {sword, axe} end
local LP = {Character=character, CharacterAdded=signal(), ChildAdded=signal(), ChildRemoved=signal()}
function LP:FindFirstChildOfClass(n) return backpack end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'hotbar.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_original_controls_return_without_faking_statistics(self):
        menu = (ROOT / 'src' / '40_menu.luau').read_text(encoding='utf-8')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        tabs = (ROOT / 'src' / '50_tabs.luau').read_text(encoding='utf-8')
        engine = (ROOT / 'src' / '60_engine.luau').read_text(encoding='utf-8')
        self.assertNotIn('Callback = function(v) end', menu)
        self.assertIn('vRep.Text = "—"', actions)
        self.assertIn('vKD.Text = string.format', actions)
        self.assertIn('["Avisos de denúncias"] = true', menu)
        self.assertIn('["Tiro por paredes"] = true', menu)
        self.assertIn('Options = { "Silencioso", "Fixar", "Agressivo" }', tabs)
        self.assertIn('if v == "Fixar" then return true end', tabs)
        self.assertIn('Name = "K/D", Disabled = true', tabs)
        self.assertIn('Name = "Denúncias", Disabled = true', tabs)
        self.assertNotRegex(engine, r'\bd\.near\b')
        self.assertIn('["Barra rápida"] = function(v) applyHotbar(v) end', actions)
        self.assertNotIn('Actions.WEAPON.spread', tabs)
        self.assertNotIn('Actions.WEAPON.gap', tabs)

    def test_no_preventive_mode_in_menu_or_profile_load(self):
        tabs = (ROOT / 'src' / '50_tabs.luau').read_text(encoding='utf-8')
        ui = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        safety = (ROOT / 'src' / '25_security.luau').read_text(encoding='utf-8')
        self.assertNotIn('Name = "Bloqueio preventivo"', tabs)
        self.assertNotIn('policy.enabled', ui)
        self.assertNotIn('function Library.Safety:setEnabled', safety)
        self.assertIn('(policy and policy.panic) and policy.blocked or {}', ui)
        self.assertIn('Library.Safety:disableTracked()', (ROOT / 'src' / '40_menu.luau').read_text(encoding='utf-8'))

    def test_esp_preview_builds_and_updates_with_luau(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        tabs = (ROOT / 'src' / '50_tabs.luau').read_text(encoding='utf-8')
        panel = tabs[tabs.index('local function buildEspPanel'):tabs.index('MODALS["Jogador"]')]
        spec = (ROOT / 'tests' / 'esp_preview_spec.luau').read_text(encoding='utf-8')
        parts = spec.split('-- INSERT IMPLEMENTATION HERE')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'esp_preview.luau'
            path.write_text(parts[0] + panel + parts[1], encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_esp_draw_with_luau(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        engine = (ROOT / 'src' / '60_engine.luau').read_text(encoding='utf-8')
        drawing = engine[engine.index('    local function characterOffsets'):engine.index('    local function gather(')]
        spec = (ROOT / 'tests' / 'esp_draw_spec.luau').read_text(encoding='utf-8')
        parts = spec.split('-- INSERT IMPLEMENTATION HERE')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'esp_draw.luau'
            path.write_text(parts[0] + drawing + parts[1], encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_esp_rig_offsets_and_render_caching_with_luau(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        engine = (ROOT / 'src' / '60_engine.luau').read_text(encoding='utf-8')
        offsets = engine[engine.index('    local function characterOffsets'):engine.index('    local function drawTarget')]
        process = engine[engine.index('    local selectedTargets, vis'):engine.index('    -- ---------- radar')]
        spec = (ROOT / 'tests' / 'esp_stability_spec.luau').read_text(encoding='utf-8')
        parts = spec.split('-- INSERT IMPLEMENTATION HERE')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'esp_stability.luau'
            path.write_text(parts[0] + offsets + process + parts[1], encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)
        self.assertIn('Enum.RenderPriority.Camera.Value + 1', engine)
        self.assertIn('RunService:UnbindFromRenderStep(renderName)', engine)
        render = engine[engine.index('    local function renderEngine'):engine.index('    local renderName')]
        self.assertIn('processKind(kind, Library.ESP and Library.ESP[kind], c, vp, slowTick)', render)
        self.assertIn('if slowTick then', render)
        self.assertNotIn('if elapsed <', render)

    def test_lucide_icons_are_static_and_licensed(self):
        head = (ROOT / 'src' / '00_head.luau').read_text(encoding='utf-8')
        for name in ('crosshair', 'lock', 'flame', 'save', 'settings', 'navigation-2'):
            self.assertRegex(head, r'\["' + name + r'"\] = "rbxassetid://\d+"')
        self.assertIn('Copyright (c) 2025 Footages', head)
        self.assertIn('Permission is hereby granted', head)
        self.assertTrue((ROOT / 'THIRD_PARTY_LICENSES' / 'Footagesus-Icons-MIT.txt').exists())

    def test_animation_selection_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    local function playAnim()'):source.index('    local CHAR_ACTIONS =')]
        setup = """local CHAR = {anim='Swish', speed=2, weight=70, repeating=false}
local LP, selected, played, message = {}, nil, nil, nil
local function say(s) message = s end
local swish = {Name='Swish', AnimationId='rbxassetid://1', IsA=function(self, c) return c == 'Animation' end}
local idleAnim = {Name='Animation1', AnimationId='rbxassetid://2', IsA=function(self, c) return c == 'Animation' end}
local idle = {GetDescendants = function() return {idleAnim} end}
local animate = {FindFirstChild = function(self, n) if n == 'idle' then return idle end end}
local hum = {LoadAnimation = function(self, anim)
    selected = anim
    return {Stop = function() end, Play = function(self, fade, weight, speed) played = {fade, weight, speed} end}
end}
local char = {GetDescendants = function() return {swish, idleAnim} end,
    FindFirstChild = function(self, n) if n == 'Animate' then return animate end end,
    FindFirstChildOfClass = function(self, n) return hum end}
LP.Character = char
local Actions = {}
"""
        spec = """playAnim()
assert(selected == swish and played[2] == 0.7 and played[3] == 2)
CHAR.anim = 'Padrão'; playAnim(); assert(selected == idleAnim)
CHAR.anim = 'Swish'; swish.AnimationId = ''; selected = nil; playAnim()
assert(selected == nil and message ~= nil)
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'animation.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_settings_integration_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        adjustments = actions[actions.index('    -- Ajustes limitados'):actions.index('    -- ---------- Movimento / jogador')]
        menu = (ROOT / 'src' / '40_menu.luau').read_text(encoding='utf-8')
        settings = menu[menu.index('-- Engrenagens históricas'):menu.index('local PREMIUM =')]
        spec = (ROOT / 'tests' / 'settings_spec.luau').read_text(encoding='utf-8')
        setup = """local Actions = {}
local Library = {Internal = {tipFor = function(name) return name end}}
local function tr(s) return s end
local soundName, soundValue
function Actions.setSoundVolume(name, value) soundName, soundValue = name, value end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'settings.luau'
            path.write_text(setup + adjustments + settings + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_lighting_adjustments_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        adjustments = actions[actions.index('    -- Ajustes limitados'):actions.index('    -- ---------- Movimento / jogador')]
        lighting = actions[actions.index('    local function applyLighting()'):actions.index('    -- terreno: cores de material')]
        spec = (ROOT / 'tests' / 'lighting_settings_spec.luau').read_text(encoding='utf-8')
        setup = """local Actions, WORLD = {}, {}
local Lighting, Workspace = {}, {}
local Color3 = {fromRGB = function(...) return {...} end, new = function(...) return {...} end}
local FX = { BBC_Atmosfera={}, BBC_Ceu={}, BBC_Nuvens={}, BBC_Bloom={}, BBC_Blur={}, BBC_CorAjuste={}, BBC_CorTon={}, BBC_Profundidade={}, BBC_Raios={} }
function Actions.setProperty(obj, prop, value) obj[prop] = value end
function Actions.restoreProperty(obj, prop) obj[prop] = nil end
local function applyClouds(enabled, cover) FX.BBC_Nuvens.Enabled = enabled; FX.BBC_Nuvens.Cover = cover end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'lighting_settings.luau'
            path.write_text(setup + adjustments + lighting + 'Actions.refreshAdjustment = function() applyLighting() end\n' + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_sound_volume_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        sound = actions[actions.index('    local SOUND_TOGGLES ='):actions.index('    local SOUND_NAMES =')]
        spec = """assert(Actions.setSoundVolume('Disparo', 0))
assert(soundVolumes.Disparo == 0)
soundObjs.Disparo = {}
assert(Actions.setSoundVolume('Disparo', 120) and soundObjs.Disparo.Volume == 1)
assert(not Actions.setSoundVolume('nao existe', 30))
assert(not Actions.setSoundVolume('Disparo', 0/0))
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'sound_volume.luau'
            path.write_text('local Actions = {}\n' + sound + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_settings_paths_are_stable_and_local_effect_paths_preserved(self):
        head = (ROOT / 'src' / '00_head.luau').read_text(encoding='utf-8')
        menu = (ROOT / 'src' / '40_menu.luau').read_text(encoding='utf-8')
        self.assertIn('subPanel(self, outer, 2, opts.SettingsPath)', head)
        self.assertIn('"/settings/" .. stableName', head)
        self.assertIn('o.SettingsPath = name', menu)
        for name in ('Aura', 'Auréola', 'Círculo de salto', 'Rastro estelar'):
            self.assertIn('name ~= "' + name + '"', menu)

    def test_dynamic_fov_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    local function aimRadius(cam)'):source.index('    local function pickTarget(cam, vp)')]
        spec = """local cam = {FieldOfView=70}
assert(math.abs(aimRadius(cam) - 70) < 0.0001)
cam.FieldOfView = 35; assert(aimRadius(cam) > 70)
COMBAT.fovDyn = false; assert(aimRadius(cam) == 70)
cam.FieldOfView = 0; COMBAT.fovDyn = true; assert(aimRadius(cam) <= 2000)
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fov.luau'
            path.write_text('local COMBAT = {fovDyn = true, radius = 70}\n' + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_local_effect_settings_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    function Actions.setLocalFxIntensity'):source.index('    local function ensureLocalFx()')]
        spec = (ROOT / 'tests' / 'local_fx_spec.luau').read_text(encoding='utf-8')
        setup = 'local Actions = {}\nlocal LOCALFX = { intensity = {aura=50, halo=50, trail=50, circle=50} }\nlocal fx = {aura={}, halo={}, trail={}}\n'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'local_fx.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_local_effect_integration_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    local LOCALFX ='):source.index('    -- A Home conserva seu estado')]
        spec = (ROOT / 'tests' / 'local_fx_integration_spec.luau').read_text(encoding='utf-8')
        setup = """local Actions = {alive = true, connections = {}}
local Library = { Panic = false }
local callbacks, clock = {}, 0
local os = {clock = function() return clock end}
local task = {spawn = function(f) f() end, defer = function(f) f() end}
local function signal() return {} end
local RunService = {Heartbeat = signal()}
function Actions.connect(sig, fn) callbacks[sig] = fn; return {Disconnect = function() callbacks[sig] = nil end} end
function Actions.trackConn(c) return c end
local hum = {StateChanged = signal()}
function hum:IsA(name) return name == "Humanoid" end
local vmt = {__sub = function() return {} end}
local pos = setmetatable({}, vmt)
local hrp, head = {Position = pos}, {}
local char = {}
function char:FindFirstChild(name) if name == "HumanoidRootPart" then return hrp elseif name == "Head" then return head end end
function char:FindFirstChildOfClass(name) return hum end
function char:WaitForChild(name, timeout) return hum end
local LP = {Character = char, CharacterAdded = signal()}
local Workspace = {}
local Instance = {}
function Instance.new(class) return {} end
local Color3 = {fromRGB = function(...) return {} end}
local Vector3 = {new = function(...) return {} end}
local NumberSequence = {new = function(...) return {} end}
local ColorSequence = {new = function(...) return {} end}
local cf = setmetatable({}, {__mul = function() return {} end})
local CFrame = {new = function(...) return cf end, Angles = function(...) return cf end}
local Enum = {Material = {Neon = 1}, PartType = {Cylinder = 2}, HumanoidStateType = {Jumping = 3}}
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'local_fx_integration.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_emergency_stop_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    function Actions.stopRiskyWork()'):source.index('    Library.Safety:trackStopper(Actions.stopRiskyWork)')]
        spec = (ROOT / 'tests' / 'risk_stop_spec.luau').read_text(encoding='utf-8')
        setup = """local Actions = {swapToken = 2, lootToken = 3}
local MV = { speed=true, sprint=true, jumps=true, air=true, fly=true, noFall=true, ground=true, jesus=true, spider=true, noDrown=true, antiAfk=true, respawn=true }
local COMBAT = {on=true, reload=true, refill=true, aura=true, antiAim=true, underGround=true, peek=true, throwLine=true}
local WORLD = {grama=true, minas=true, jogadores=true}
local preFallHealth, swapOn, autoLoot = 100, true, true
local calls = {}
local function hit(key) calls[key] = (calls[key] or 0) + 1 end
local function stopFly() error("simulated") end
function Actions.restoreWalk() hit("restoreWalk") end
function Actions.restoreSwim() hit("restoreSwim") end
local function stopOffset() hit("stopOffset") end
local function applyAimState() hit("aim") end
local function applyAntiAim(v) assert(v == false); hit("antiAim") end
local function applyUnderGround(v) assert(v == false); hit("under") end
local function applyPeek(v) assert(v == false); hit("peek") end
local function applyThrowLine(v) assert(v == false); hit("throw") end
local function applyGrama(v) assert(v == false); hit("grass") end
local function applyMinas(v) assert(v == false); hit("mines") end
local function removeEffects(v) assert(v == false); hit("effects") end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'risk_stop.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_ui_profile_integration_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('local CFG_FOLDER ='):source.index('function Window:StartAutoSave()')]
        profile = (ROOT / 'src' / '27_profiles.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'ui_profiles_spec.luau').read_text(encoding='utf-8')
        setup = """local Library = { Registry = {} }
local Window = {}
function Library:Notify(opts) end
local function warn(...) end
local writeAttempts, writeFails, decodeAttempts = 0, false, 0
local mockDecoded, rawFile, exists, writes = {}, "profile", false, {}
local HttpService = {}
function HttpService:JSONDecode(text) decodeAttempts += 1; return mockDecoded end
function HttpService:JSONEncode(data) return "json" end
local function writefile(path, text)
    writeAttempts += 1
    if writeFails then error("falha") end
    writes[path] = text
    if path == "BBC_HUB/configs/default.json" then exists = true end
end
local function readfile(path) return rawFile end
local function isfile(path) return exists end
local function isfolder(path) return true end
local function makefolder(path) end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ui_profiles.luau'
            path.write_text(setup + profile + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_named_marker_cancellation_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = actions[actions.index('    local function clearHigh(list)'):actions.index('    local function applyChefes(v)')]
        setup = """local Actions={alive=true}
function Actions.getAdjustment(key) return 60 end
local Workspace={}
local Enum={HighlightDepthMode={AlwaysOnTop='AlwaysOnTop'}}
local Color3={fromRGB=function(...) return {...} end}
local task={jobs={}}
function task.spawn(fn) table.insert(task.jobs,fn) end
local Instance={new=function(class)
    local obj={}
    function obj:Destroy() self.destroyed=true end
    return obj
end}
local Library={Panic=false, StreamScan={}}
function Library:Notify(opts) self.last=opts.Content end
function Library.StreamScan.run(root,alive,visit)
    for i=1,120 do
        if not alive() then break end
        local d={Name='boss'..i}
        function d:IsDescendantOf(root) return true end
        function d:IsA(class) return class=='Model' end
        visit(d)
    end
end
"""
        spec = """local list={}
Actions.scanNamedMarks(true,list,{'boss'},'orange','bossOpacity','bossToken','chefes')
Actions.scanNamedMarks(false,list,{'boss'},'orange','bossOpacity','bossToken','chefes')
task.jobs[1](); assert(#list==0 and Library.last==nil)
Library.Panic=true
Actions.scanNamedMarks(true,list,{'boss'},'orange','bossOpacity','bossToken','chefes')
task.jobs[2](); assert(#list==100 and list[1].Enabled==false and Library.last==nil)
local prior=list[1]
Actions.scanNamedMarks(false,list,{'boss'},'orange','bossOpacity','bossToken','chefes')
assert(#list==0 and prior.destroyed)
print('named markers cancellation, panic and cap OK')
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'named_markers.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_loot_marker_uses_separate_instance_references(self):
        engine = (ROOT / 'src' / '60_engine.luau').read_text(encoding='utf-8')
        self.assertNotIn('b.Label =', engine)
        self.assertIn('b = { gui = gui, label = mk(', engine)
        self.assertIn('b.gui.Adornee = it.part', engine)
        self.assertIn('b.label.Text =', engine)
        self.assertIn('marks[i].gui.Enabled = false', engine)

    def test_loot_marker_creation_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        engine = (ROOT / 'src' / '60_engine.luau').read_text(encoding='utf-8')
        helper = engine[engine.index('    local marks = {}'):engine.index('    local lootClock, shown')]
        setup = """local holder, FONT = {}, 'font'
local UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local Vector3={new=function(...) return {...} end}
local Color3={new=function(...) return {...} end}
local count=0
local function mk(class, props, parent)
    count += 1
    local obj={class=class, props=props, parent=parent}
    return setmetatable(obj,{__newindex=function() error('unknown Instance property') end})
end
"""
        spec = """local item=mark(1)
assert(item.gui.class=='BillboardGui' and item.label.class=='TextLabel' and item.label.parent==item.gui)
assert(mark(1)==item and count==2)
assert(mark(2)~=item and count==4)
print('loot marker instance references OK')
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'marker_instance.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_only_four_historical_gears_remain_pending(self):
        menu = (ROOT / 'src' / '40_menu.luau').read_text(encoding='utf-8')
        gear_section = menu[menu.index('for _, name in ipairs({'):menu.index('}) do GEARS[name] = true end')]
        gears = set(re.findall(r'"([^"\n]+)"', gear_section))
        settings = menu[menu.index('local SETTINGS = {'):menu.index('GEARS["Troca rápida"]')]
        implemented = set(re.findall(r'\["([^"\n]+)"\]\s*=', settings))
        implemented.update(('Aura', 'Auréola', 'Círculo de salto', 'Rastro estelar', 'Jump', 'Pegadas', 'Pouso', 'Capacete', 'Tiro na cabeça', 'Tiro no corpo', 'Abate', 'Disparo', 'Acerto com sangue'))
        self.assertEqual(gears - implemented, {'Mira falsa', 'Mochila', 'Mochila personalizada', 'Trocar personagem', 'Tiro por paredes', 'Avisos de denúncias'})

    def test_hit_marker_timer_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = actions[actions.index('    local function flashMark()'):actions.index('    local function spawnDmg(')]
        setup = """local Actions={alive=true}; local Library={Panic=false}; local COMBAT={hitMark=true}; local AIM={}
function Actions.getAdjustment(k) return 0.2 end
local pending={}
local task={delay=function(_,fn) table.insert(pending,fn) end}
local function ensureAimGui() AIM.mark=AIM.mark or {Visible=false} end
"""
        spec = """flashMark(); assert(AIM.mark.Visible)
flashMark(); assert(#pending==2)
pending[1](); assert(AIM.mark.Visible) -- evento antigo não apaga a marca nova
pending[2](); assert(not AIM.mark.Visible)
Library.Panic=true; flashMark(); assert(#pending==2)
print('hit marker token OK')
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'marker.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_first_person_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = actions[actions.index('    local function applyFirst(v)'):actions.index('    local function playAnim()')]
        spec = (ROOT / 'tests' / 'first_person_spec.luau').read_text(encoding='utf-8')
        setup = """local function signal()
    local s = {conns={}}
    function s:Connect(fn)
        local c={Connected=true, fn=fn}; function c:Disconnect() self.Connected=false end
        table.insert(self.conns,c); return c
    end
    return s
end
local function fire(s, ...) for _, c in ipairs(s.conns) do if c.Connected then c.fn(...) end end end
local Library, Actions, CHAR = {Panic=false}, {alive=true}, {}
local RunService = {RenderStepped=signal()}
local character = {ChildAdded=signal()}
local function part(name, parent)
    local p={Name=name,Parent=parent,LocalTransparencyModifier=0.75}
    function p:IsA(class) return class == 'BasePart' end
    return p
end
local torso=part('UpperTorso', character)
local arm=part('LeftUpperArm', character)
local head=part('Head', character)
local accessoryPart=part('LeftHand', {})
function character:GetChildren() return {torso,arm,head,accessoryPart} end
local LP={Character=character,CharacterAdded=signal(),CameraMode='normal'}
local Enum={CameraMode={LockFirstPerson='first'}}
local saved={}
function Actions.setProperty(o,p,v) saved[o]=saved[o] or {}; if saved[o][p]==nil then saved[o][p]=o[p] end; o[p]=v end
function Actions.restoreProperty(o,p) if saved[o] and saved[o][p]~=nil then o[p]=saved[o][p]; saved[o][p]=nil end end
function Actions.connect(sig,cb) return sig:Connect(cb) end
function Actions.getAdjustment(key) assert(key=='firstPersonTransparency'); return 0.25 end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'first_person.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_hit_effects_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        actions = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = actions[actions.index('    Actions.hitFxObjects = {}'):actions.index('    -- acerto/eliminação:')]
        spec = (ROOT / 'tests' / 'hit_effect_spec.luau').read_text(encoding='utf-8')
        setup = """local Actions = {alive=true}
local Library, COMBAT = {Panic=false}, {hitFx=true}
local values = {hitFxTransparency=0.4,hitFxDuration=0.3}
function Actions.getAdjustment(k) return values[k] end
local objects, pending, created = {}, {}, 0
local task = {delay=function(delay,callback) table.insert(pending,{delay=delay,callback=callback}) end}
local Enum = {HighlightDepthMode={Occluded='Occluded'}}
local Color3 = {fromRGB=function(...) return {...} end}
local Instance = {new=function(class)
    assert(class == 'Highlight')
    created += 1
    local o = {}
    function o:Destroy() self.destroyed=true end
    table.insert(objects,o)
    return o
end}
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'hit_effects.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_runtime_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        runtime = (ROOT / 'src' / '24_runtime.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'runtime_spec.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'runtime.luau'
            path.write_text('local Library = {}\nlocal task = {}\n' + runtime + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_recovery_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('local CFG_FOLDER ='):source.index('function Window:StartAutoSave()')]
        profile = (ROOT / 'src' / '27_profiles.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'recovery_spec.luau').read_text(encoding='utf-8')
        setup = """local Library = { Registry = {} }
local Window = {}
function Library:Notify(opts) end
local function warn(...) end
local files, failWrite = {}, false
local HttpService = {}
function HttpService:JSONDecode(text)
    if text == 'valid-backup' then return {v=2, data={flag=true, ancient=42}} end
    error('invalid json')
end
function HttpService:JSONEncode(value) return 'json' end
local function isfile(path) return files[path] ~= nil end
local function readfile(path) assert(files[path]); return files[path] end
local function writefile(path, text) if failWrite then error('write failed') end; files[path] = text end
local function isfolder(path) return true end
local function makefolder(path) end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'recovery.luau'
            path.write_text(setup + profile + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_ui_support_with_luau_if_available(self):
        self.run_luau_spec('05_ui_support.luau', 'ui_support_spec.luau')

    def test_profile_preview_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('local CFG_FOLDER ='):source.index('function Window:StartAutoSave()')]
        profile = (ROOT / 'src' / '27_profiles.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'profile_preview_spec.luau').read_text(encoding='utf-8')
        setup = """local Library = { Registry = {} }
local Window = {}
function Library:Notify(opts) end
local function warn(...) end
local files = {}
local HttpService = {}
function HttpService:JSONDecode(text)
    if text == 'valid-backup' then return {v=2, data={flag=true, ancient=42}} end
    error('invalid json')
end
function HttpService:JSONEncode(value) return 'json' end
local function isfile(path) return files[path] ~= nil end
local function readfile(path) assert(files[path]); return files[path] end
local function writefile(path, text) files[path] = text end
local function isfolder(path) return true end
local function makefolder(path) end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'preview.luau'
            path.write_text(setup + profile + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_profile_history_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('local CFG_FOLDER ='):source.index('function Window:StartAutoSave()')]
        profile = (ROOT / 'src' / '27_profiles.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'profile_history_spec.luau').read_text(encoding='utf-8')
        setup = """local Library = {Registry = {}, Tr = function(s) return s end}
local Window = {}
function Library:Notify(opts) end
local function warn(...) end
local files = {}
local HttpService = {}
function HttpService:JSONDecode(text)
    if text == 'valid-backup' then return {v=2, data={flag=true}} end
    error('invalid json')
end
function HttpService:JSONEncode(value) return 'json' end
local function isfile(path) return files[path] ~= nil end
local function readfile(path) assert(files[path]); return files[path] end
local failedWrite = nil
local function writefile(path, text) if path == failedWrite then return false end; files[path] = text end
local function isfolder(path) return true end
local function makefolder(path) end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'history.luau'
            path.write_text(setup + profile + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_incremental_hidden_scan_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    Actions.hidden = { grass'):source.index('    local function applyJogadores(v)')]
        setup = (ROOT / 'tests' / 'hidden_scan_spec.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'hidden_scan_assert.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'scan.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_finish_loading_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('function Window:FinishLoading()'):source.index('function Window:_startIntro')]
        spec = (ROOT / 'tests' / 'finish_loading_spec.luau').read_text(encoding='utf-8')
        setup = """local Window = {}
local now, onWait = 0, nil
local os = {clock = function() return now end}
local task = {spawn = function(fn) fn() end, wait = function(t) now += 1; if onWait then onWait() end end}
local Library = {Diagnostics = {record = function() end}, Tr = function(s) return s end}
function Library:Notify(opts) end
local function canFS() return false end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'finish.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_search_navigation_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('function Window:_openSearchResult'):source.index('function Window:SetHideUnavailable')]
        spec = (ROOT / 'tests' / 'navigation_spec.luau').read_text(encoding='utf-8')
        setup = """local Window = {}
local Library = {Tr = function(s) return s end, Notify = function() end}
local task = {defer = function(f) f() end, wait = function() end}
local Vector2 = {new = function(x, y) return {X=x, Y=y} end}
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'navigation.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_compact_column_reflow_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '10_ui.luau').read_text(encoding='utf-8')
        helper = source[source.index('function Tab:_layoutColumns'):source.index('function Tab:Groupbox')]
        support = (ROOT / 'src' / '05_ui_support.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'column_layout_spec.luau').read_text(encoding='utf-8')
        setup = """local Tab, Library = {}, {}
local UserInputService = {TouchEnabled = true}
local UDim2 = {fromScale = function() return {mode='scale'} end, new = function() return {mode='new'} end}
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'columns.luau'
            path.write_text(setup + support + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_effects_scan_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    local EFFECT_CLASSES ='):source.index('    -- ===== avisos de entrada')]
        setup = (ROOT / 'tests' / 'effects_scan_spec.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'effects_scan_assert.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'effects_scan.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_guards_with_luau_if_available(self):
        self.run_luau_spec('26_guard.luau', 'guards_spec.luau')

    def test_core_events_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '00_head.luau').read_text(encoding='utf-8')
        helper = source[source.index('local function safeConnect('):source.index('function Library:_kbChanged()')]
        spec = (ROOT / 'tests' / 'core_events_spec.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events.luau'
            path.write_text('local Library = { _running = true, _uiConnections = {} }\nlocal function warn(...) end\n' + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_property_restoration_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    Actions.originals ='):source.index('    local function onCleanup')]
        spec = (ROOT / 'tests' / 'properties_spec.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'properties.luau'
            path.write_text('local Actions = {}\n' + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_actions_initializer_with_strict_enums_if_luau_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[:source.index('-- ============================================================\n--  SERVIDORES')]
        setup = (ROOT / 'tests' / 'actions_init_spec.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'actions_init_assert.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'actions_init.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_existing_actions_with_real_panic_guard(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[:source.index('-- ============================================================\n--  SERVIDORES')]
        setup = (ROOT / 'tests' / 'actions_init_spec.luau').read_text(encoding='utf-8')
        safety = (ROOT / 'src' / '25_security.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'actions_preserved_spec.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'actions_preserved.luau'
            path.write_text(setup + safety + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_profile_initialization_closures_with_luau_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para executar os testes de Luau.')
        source = (ROOT / 'src' / '30_actions.luau').read_text(encoding='utf-8')
        helper = source[source.index('    local function initializeProfile()'):source.index('    -- Expor somente as referências')]
        setup = (ROOT / 'tests' / 'profile_init_spec.luau').read_text(encoding='utf-8')
        spec = (ROOT / 'tests' / 'profile_init_assert.luau').read_text(encoding='utf-8')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'profile_init.luau'
            path.write_text(setup + helper + spec, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)

    def test_luau_compiler_if_available(self):
        compiler = os.environ.get('LUAU_COMPILE')
        if not compiler:
            self.skipTest('Defina LUAU_COMPILE para validar com o compilador oficial.')
        # -O0 é essencial: loadstring de executores pode compilar sem otimizar e
        # manter mais variáveis em registros do que o padrão do luau-compile.
        for level in (0, 1, 2):
            with self.subTest(optimization=level):
                subprocess.run([compiler, f'-O{level}', '--null', str(ROOT / 'BBC_HUB.luau')],
                               stdout=subprocess.DEVNULL, check=True)

    def test_generated_hub_loadstring_compiles_if_available(self):
        runner = os.environ.get('LUAU_BIN')
        if not runner:
            self.skipTest('Defina LUAU_BIN para testar loadstring sem executar o hub.')
        source = (ROOT / 'BBC_HUB.luau').read_text(encoding='utf-8')
        equals = '='
        while ']' + equals + ']' in source:
            equals += '='
        script = ('local source = [' + equals + '[' + source + ']' + equals + ']\n'
                  'local fn, err = loadstring(source)\n'
                  'assert(type(fn) == "function", tostring(err))\n')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'loadstring_compile.luau'
            path.write_text(script, encoding='utf-8')
            subprocess.run([runner, str(path)], check=True, capture_output=True, text=True)


if __name__ == '__main__':
    unittest.main()
