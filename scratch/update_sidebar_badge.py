# -*- coding: utf-8 -*-
from pathlib import Path

sb_path = Path("app/templates/components/sidebar.html")
content = sb_path.read_text(encoding="utf-8")

old_tag = '<span class="font-code-sm text-[9px] bg-emerald-500/20 text-emerald-400 px-1.5 py-0.5 rounded font-semibold">SQLite</span>'
new_tag = '<span class="font-code-sm text-[9px] bg-emerald-500/20 text-emerald-400 px-1.5 py-0.5 rounded font-semibold">Neon SQL</span>'

if old_tag in content:
    content = content.replace(old_tag, new_tag)
    sb_path.write_text(content, encoding="utf-8")
    print("OK: Sidebar actualizado a Neon SQL.")
else:
    print("No se encontro old_tag en sidebar.")
