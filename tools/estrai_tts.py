"""Estrae la grafica di Cascadia dal modulo di Tabletop Simulator (.ttsmod già scompattato).

Uso: python3 tools/estrai_tts.py <cartella Mods del modulo> <cartella del progetto>
Scrive assets/tiles, assets/start, assets/cards, assets/tokens. I dati delle tessere (habitat
per lato e fauna) stanno in data/tiles.json: ricavati dai colori delle immagini e corretti a mano.
"""
import json, math, os, re, sys
from PIL import Image, ImageDraw

M, OUT = sys.argv[1], sys.argv[2]
d = json.load(open(os.path.join(M, 'Workshop/3554313311.json')))
imgs = os.listdir(os.path.join(M, 'Images'))

def loc(u):
    k = re.sub(r'[^A-Za-z0-9]', '', u)
    for f in imgs:
        if f.rsplit('.', 1)[0] == k:
            return os.path.join(M, 'Images', f)

def save(im, rel, width=None, q=86):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if width and im.width != width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    im.save(p, 'WEBP', quality=q, method=5)

def hexmask(size):
    w, h = size
    m = Image.new('L', size, 0)
    R = h / 2
    ImageDraw.Draw(m).polygon([(w / 2 + R * math.cos(math.radians(-90 + 60 * k)) * 0.995,
                                h / 2 + R * math.sin(math.radians(-90 + 60 * k)) * 0.995) for k in range(6)], fill=255)
    return m

HAB = {'Forests': 'foresta', 'Mountains': 'montagna', 'Prairies': 'prateria', 'Wetlands': 'zona_umida', 'Rivers': 'fiume'}
ANI = {'Bears': 'orso', 'Elks': 'alce', 'Salmons': 'salmone', 'Hawks': 'falco', 'Foxes': 'volpe'}
TOK = {'Bear': 'orso', 'Elk': 'alce', 'Salmon': 'salmone', 'Hawk': 'falco', 'Fox': 'volpe'}
TILE_W = 300  # larghezza di una tessera esagonale (punta in alto)

for o in d['ObjectStates']:
    nm = o.get('Nickname')
    if nm == 'Habitat Tiles':
        for i, c in enumerate(o['ContainedObjects']):
            im = Image.open(loc(c['CustomImage']['ImageURL'])).convert('RGBA')
            bb = im.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
            im = im.crop(bb)
            h = round(TILE_W * 2 / math.sqrt(3))
            im = im.resize((TILE_W, h), Image.LANCZOS)
            im.putalpha(Image.fromarray(__import__('numpy').minimum(
                __import__('numpy').array(im.getchannel('A')), __import__('numpy').array(hexmask(im.size)))))
            save(im, f'assets/tiles/H{i:03d}.webp')
    elif nm == 'Starting Tiles':
        for i, c in enumerate(o['ContainedObjects']):
            im = Image.open(loc(c['CustomImage']['ImageURL'])).convert('RGBA')
            W, H = im.size
            w = W / 2; R = w / math.sqrt(3)
            for j, (cx, cy) in enumerate([(W / 2, R), (W / 4, 2.5 * R), (3 * W / 4, 2.5 * R)]):
                t = im.crop((int(cx - w / 2), int(cy - R), int(cx + w / 2), int(cy + R)))
                t = t.resize((TILE_W, round(TILE_W * 2 / math.sqrt(3))), Image.LANCZOS)
                t.putalpha(hexmask(t.size))
                save(t, f'assets/start/S{i:03d}_{j}.webp')
    elif o['Name'] == 'Deck' and (nm in HAB or nm in ANI):
        cd = o['CustomDeck']
        cache = {}
        for c in o['ContainedObjects']:
            letter = c['Nickname']
            if len(letter) != 1:
                continue  # carte promozionali: non usate
            cid = c['CardID']; v = cd[str(cid // 100)]; i = cid % 100
            p = loc(v['FaceURL'])
            sheet = cache.setdefault(p, Image.open(p).convert('RGB'))
            cw = sheet.width / v['NumWidth']; ch = sheet.height / v['NumHeight']
            x, y = i % v['NumWidth'], i // v['NumWidth']
            card = sheet.crop((int(x * cw), int(y * ch), int((x + 1) * cw), int((y + 1) * ch)))
            if nm in ANI:
                save(card, f'assets/cards/fauna/{ANI[nm]}_{letter}.webp', 420)
            else:
                save(card, f'assets/cards/landmark/{HAB[nm]}_{letter}.webp', 420)
    elif nm == 'Wildlife Tokens':
        done = set()
        for c in o['ContainedObjects']:
            k = TOK[c['Nickname']]
            if k in done:
                continue
            done.add(k)
            save(Image.open(loc(c['CustomImage']['ImageURL'])).convert('RGBA'), f'assets/tokens/{k}.webp', 200)
    elif nm == 'Nature Tokens' and not os.path.exists(os.path.join(OUT, 'assets/tokens/natura.webp')):
        save(Image.open(loc(o['CustomImage']['ImageURL'])).convert('RGBA'), 'assets/tokens/natura.webp', 160)
    elif o['Name'] == 'Custom_Model_Infinite_Bag' and nm in HAB:
        c = o['ContainedObjects'][0]
        save(Image.open(loc(c['CustomImage']['ImageURL'])).convert('RGBA'), f'assets/tokens/lm_{HAB[nm]}.webp', 200)
print('fatto')
