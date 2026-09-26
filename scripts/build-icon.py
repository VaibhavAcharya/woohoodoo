from pathlib import Path
from struct import pack
from sys import argv

iconset = Path(argv[1])
output = Path(argv[2])
images = [
    (b"icp4", "icon_16x16.png"),
    (b"icp5", "icon_32x32.png"),
    (b"icp6", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
]
chunks = []
for kind, filename in images:
    data = (iconset / filename).read_bytes()
    chunks.append(kind + pack(">I", len(data) + 8) + data)
body = b"".join(chunks)
output.write_bytes(b"icns" + pack(">I", len(body) + 8) + body)
