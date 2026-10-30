"""Controlla che ogni carattere scritto negli script e nei dati esista nei font del gioco.

Uso: python3 tools/controlla_glifi.py   (esce con errore se trova caratteri che apparirebbero come quadratini)
"""
import glob, re, sys
from fontTools.ttLib import TTFont

FONTS = ["assets/fonts/Jost.ttf", "assets/fonts/Lora-Variable.ttf", "assets/fonts/Lora-Italic-Variable.ttf"]
cmaps = [set(TTFont(f).getBestCmap().keys()) for f in FONTS]
jost = cmaps[0]
bad = {}
for f in glob.glob("scripts/**/*.gd", recursive=True):
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        code = line.split("#", 1)[0] if not line.lstrip().startswith("##") else ""
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
            for ch in s:
                if ord(ch) > 126 and ord(ch) not in jost:
                    bad.setdefault(ch, []).append("%s:%d" % (f, n))
for ch, where in bad.items():
    print("MANCA %r U+%04X in Jost: %s" % (ch, ord(ch), ", ".join(where[:5])))
print("glifi ok" if not bad else "%d caratteri non disponibili" % len(bad))
sys.exit(1 if bad else 0)
