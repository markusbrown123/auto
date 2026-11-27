# sheet.py <video> <out.jpg> <cols> <width> t1 t2 ...   (frames at exact times, labelled)
import sys, subprocess, os, tempfile
from PIL import Image, ImageDraw, ImageFont
vid, out, cols, w = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
ts = [float(t) for t in sys.argv[5:]]
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
tiles = []
d = tempfile.mkdtemp()
for i, t in enumerate(ts):
    p = os.path.join(d, "f%d.png" % i)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % t, "-i", vid, "-frames:v", "1", p], check=True)
    im = Image.open(p).convert("RGB")
    im = im.resize((w, int(im.height * w / im.width)))
    dr = ImageDraw.Draw(im)
    dr.rectangle([0, 0, 92, 26], fill=(0, 0, 0))
    dr.text((5, 3), "t=%.2f" % t, fill=(255, 255, 0), font=font)
    tiles.append(im)
rows = (len(tiles) + cols - 1) // cols
th = tiles[0].height
sheet = Image.new("RGB", (cols * w, rows * th), (20, 20, 20))
for i, im in enumerate(tiles):
    sheet.paste(im, ((i % cols) * w, (i // cols) * th))
sheet.save(out, quality=85)
print(out, sheet.size)
