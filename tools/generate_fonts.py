"""Regenerate OSD fonts into build/fonts; --update also updates FPGA ROM files."""
from pathlib import Path
import argparse,json
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--chinese-font',default='C:/Windows/Fonts/simhei.ttf')
p.add_argument('--ascii-font',default='C:/Windows/Fonts/consola.ttf')
p.add_argument('--update',action='store_true');a=p.parse_args()
out=R/'build/fonts';out.mkdir(parents=True,exist_ok=True)
styles=json.loads((R/'styles.json').read_text(encoding='utf-8'))
names=['原图']+['风格：'+s['display_name'] for s in styles]
font=ImageFont.truetype(a.chinese_font,16);bits=[]
for name in names:
    im=Image.new('L',(128,16));box=font.getbbox(name)
    ImageDraw.Draw(im).text((0,-box[1]),name,font=font,fill=255)
    bits.extend(int(im.getpixel((x,y))>=100) for y in range(16) for x in range(128))
bits.extend([0]*(16384-len(bits)));title=''.join(f'{b:x}\n' for b in bits)
(out/'title-font.hex').write_text(title,encoding='ascii')
font=ImageFont.truetype(a.ascii_font,13);rows=[]
for c in range(128):
    im=Image.new('1',(8,16));ImageDraw.Draw(im).text((0,0),chr(c) if c>=32 else ' ',font=font,fill=1)
    rows.extend(sum(im.getpixel((x,y))<<(7-x) for x in range(8)) for y in range(16))
capture=''.join(f'{v:02x}\n' for v in rows);(out/'capture-font.hex').write_text(capture,encoding='ascii')
for path,text in [(R/'fpga/title-font.hex',title),(R/'autoboot/fpga/title-font.hex',title),(R/'line-demo/fpga/capture-font.hex',capture)]:
    if a.update:path.write_text(text,encoding='ascii')
    elif path.read_text().split()!=text.split():raise ValueError('Font differs from '+str(path))
print('OSD font generation passed: '+', '.join(names))
