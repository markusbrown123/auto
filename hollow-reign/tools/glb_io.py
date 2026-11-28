"""Minimal GLB reader/writer for the rigged Tripo characters (one mesh, one primitive, one skin).

Reads the arrays a rewrite needs (positions, normals, uvs, joints, weights, indices) and writes the file back
with those arrays replaced, keeping every other chunk (images, materials, nodes, skin) byte for byte.
Used by tools/fix_rigged_glb.py. No third-party packages beyond numpy.
"""
import json
import struct

import numpy as np

_CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        b = open(path, "rb").read()
        magic, _ver, _total = struct.unpack("<III", b[:12])
        assert magic == 0x46546C67, "not a GLB"
        off = 12
        self.json = None
        self.bin = b""
        while off < len(b):
            ln, kind = struct.unpack("<II", b[off:off + 8])
            data = b[off + 8:off + 8 + ln]
            if kind == 0x4E4F534A:
                self.json = json.loads(data)
            elif kind == 0x004E4942:
                self.bin = bytes(data)
            off += 8 + ln

    def accessor(self, i):
        a = self.json["accessors"][i]
        bv = self.json["bufferViews"][a["bufferView"]]
        dt = _CT[a["componentType"]]
        n = _NC[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0)
        item = np.dtype(dt).itemsize * n
        if stride and stride != item:
            raw = np.frombuffer(self.bin, np.uint8, count=stride * a["count"], offset=start).reshape(a["count"], stride)
            arr = raw[:, :item].copy().view(dt).reshape(a["count"], n)
        else:
            arr = np.frombuffer(self.bin, dt, count=a["count"] * n, offset=start).reshape(a["count"], n).copy()
        if a.get("normalized") and dt != np.float32:
            arr = arr.astype(np.float32) / np.iinfo(dt).max
        return arr if n > 1 else arr.reshape(-1)

    def prim(self):
        return self.json["meshes"][0]["primitives"][0]

    def arrays(self):
        p = self.prim()
        out = {k: self.accessor(v) for k, v in p["attributes"].items()}
        out["indices"] = self.accessor(p["indices"])
        return out

    def save(self, path, arrays):
        """Writes the file with the primitive's attributes and indices replaced by `arrays` (same keys as arrays())."""
        j = json.loads(json.dumps(self.json))
        p = j["meshes"][0]["primitives"][0]
        # keep every buffer view not owned by this primitive, then append the new attribute data
        owned = {j["accessors"][a]["bufferView"] for a in list(p["attributes"].values()) + [p["indices"]]}
        chunks = []
        remap = {}
        cur = 0
        for i, bv in enumerate(j["bufferViews"]):
            if i in owned:
                continue
            data = self.bin[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
            pad = (-cur) % 4
            chunks.append(b"\0" * pad)
            cur += pad
            nbv = dict(bv)
            nbv["byteOffset"] = cur
            chunks.append(data)
            cur += len(data)
            remap[i] = nbv
        views = []
        old_to_new = {}
        for i in sorted(k for k in remap):
            old_to_new[i] = len(views)
            views.append(remap[i])
        for a in j["accessors"] + j.get("images", []):
            if a.get("bufferView") in old_to_new:
                a["bufferView"] = old_to_new[a["bufferView"]]

        def add(arr, ctype, typ, target, minmax=False):
            nonlocal cur
            raw = np.ascontiguousarray(arr.astype(_CT[ctype])).tobytes()
            pad = (-cur) % 4
            chunks.append(b"\0" * pad)
            cur += pad
            views.append({"buffer": 0, "byteOffset": cur, "byteLength": len(raw), "target": target})
            chunks.append(raw)
            cur += len(raw)
            acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
            if minmax:
                acc["min"] = [float(x) for x in arr.min(axis=0)]
                acc["max"] = [float(x) for x in arr.max(axis=0)]
            j["accessors"].append(acc)
            return len(j["accessors"]) - 1

        spec = {"POSITION": (5126, "VEC3", True), "NORMAL": (5126, "VEC3", False), "TEXCOORD_0": (5126, "VEC2", False),
                "JOINTS_0": (5123, "VEC4", False), "WEIGHTS_0": (5126, "VEC4", False)}
        attrs = {}
        for k in p["attributes"]:
            ct, typ, mm = spec[k]
            attrs[k] = add(arrays[k], ct, typ, 34962, mm)
        idx = add(arrays["indices"].reshape(-1), 5125, "SCALAR", 34963)
        p["attributes"] = attrs
        p["indices"] = idx
        j["bufferViews"] = views
        binb = b"".join(chunks)
        binb += b"\0" * ((-len(binb)) % 4)
        j["buffers"] = [{"byteLength": len(binb)}]
        # accessors the old primitive used are left unreferenced; drop them so the file stays clean
        used = set(attrs.values()) | {idx}
        for s in j.get("skins", []):
            used.add(s.get("inverseBindMatrices"))
        for an in j.get("animations", []):
            for smp in an["samplers"]:
                used.add(smp["input"])
                used.add(smp["output"])
        keep = [i for i in range(len(j["accessors"])) if i in used]
        newi = {o: n for n, o in enumerate(keep)}
        j["accessors"] = [j["accessors"][i] for i in keep]
        p["attributes"] = {k: newi[v] for k, v in attrs.items()}
        p["indices"] = newi[idx]
        for s in j.get("skins", []):
            if "inverseBindMatrices" in s:
                s["inverseBindMatrices"] = newi[s["inverseBindMatrices"]]
        for an in j.get("animations", []):
            for smp in an["samplers"]:
                smp["input"] = newi[smp["input"]]
                smp["output"] = newi[smp["output"]]
        # drop buffer views nothing points at any more (the old attribute data was never copied)
        js = json.dumps(j, separators=(",", ":")).encode()
        js += b" " * ((-len(js)) % 4)
        total = 12 + 8 + len(js) + 8 + len(binb)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(binb), 0x004E4942))
            f.write(binb)

    def joint_names(self):
        sk = self.json["skins"][0]
        return [self.json["nodes"][n]["name"].split(":")[-1] for n in sk["joints"]]

    def bind_positions(self):
        """Each joint's position in mesh space, from the inverse bind matrices."""
        sk = self.json["skins"][0]
        ibm = self.accessor(sk["inverseBindMatrices"]).reshape(-1, 4, 4)
        out = []
        for m in ibm:
            mat = m.T          # glTF stores column-major
            out.append(np.linalg.inv(mat)[:3, 3])
        return np.array(out)
