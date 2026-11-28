#!/usr/bin/env python3
"""Clean-ups for the rigged Tripo characters, applied to the untouched originals in art/models/.

  monarch: art/models/monarch_v2.glb -> assets/models/forgotten_monarch.glb
    - the concept's thin sword is part of the mesh (one separate piece standing on the floor, skinned to the hands);
      it is removed, because the game puts the Monarch's own blade (w_monarch) in his hand in every duel and scene.
    - the crimson cloak was skinned to the upper arms, so it swung out sideways with every arm movement; it is bound
      again to the trunk: the collar to the shoulder bones and the spine, the rest down the spine to the hips by height.
      Rags and tatters hanging well away from the arm get the same treatment; the sleeves themselves keep their weights.

Usage: python3 tools/fix_rigged_glb.py monarch
"""
import os
import sys

import numpy as np
import scipy.sparse as sp
from scipy.sparse.csgraph import connected_components

sys.path.insert(0, os.path.dirname(__file__))
from glb_io import Glb  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")


def pieces(P, I):
    """Connected pieces of the mesh, welding vertices that share a position (UV seams split them)."""
    key = np.round(P * 1e4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    e = np.concatenate([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]])
    e = inv[e]
    n = inv.max() + 1
    _, lab = connected_components(sp.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)), directed=False)
    return lab[inv]


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def trunk_weights(P, names, bp, lateral_axis):
    """Weights (N x len(names)) binding each point to the trunk: shoulders at the collar, then spine to hips by height."""
    W = np.zeros((len(P), len(names)), np.float32)
    chain = ["Hips", "Spine", "Spine1", "Spine2"]
    ys = np.array([bp[names.index(c)][1] for c in chain])
    y = P[:, 1]
    # piecewise-linear down the spine; below the hips all hips, above Spine2 all Spine2
    for i, c in enumerate(chain):
        lo = ys[i - 1] if i > 0 else None
        hi = ys[i + 1] if i + 1 < len(chain) else None
        w = np.zeros(len(P))
        if lo is None:
            w = np.where(y <= ys[i], 1.0, 0.0)
        else:
            w = np.where((y > lo) & (y <= ys[i]), (y - lo) / (ys[i] - lo), w)
        if hi is None:
            w = np.where(y > ys[i], 1.0, w)
        else:
            w = np.where((y > ys[i]) & (y < hi), (hi - y) / (hi - ys[i]), w)
        W[:, names.index(c)] = w
    # the collar: up near the shoulders half of the weight goes to that side's shoulder (clavicle) bone
    top = smooth(ys[3] - 0.02, ys[3] + 0.05, y) * 0.5
    left = P[:, lateral_axis] < bp[names.index("Hips")][lateral_axis]
    sh_l = names.index("LeftShoulder")
    sh_r = names.index("RightShoulder")
    W *= (1.0 - top)[:, None]
    W[left, sh_l] += top[left]
    W[~left, sh_r] += top[~left]
    return W


def to_dense(J, Wt, nj):
    D = np.zeros((len(J), nj), np.float32)
    for k in range(4):
        np.add.at(D, (np.arange(len(J)), J[:, k]), Wt[:, k])
    return D


def to_top4(D):
    J = np.argsort(-D, axis=1)[:, :4]
    W = np.take_along_axis(D, J, axis=1)
    W = W / np.maximum(W.sum(axis=1, keepdims=True), 1e-8)
    return J.astype(np.uint16), W.astype(np.float32)


def monarch():
    src = os.path.join(ROOT, "art/models/monarch_v2.glb")
    dst = os.path.join(ROOT, "assets/models/forgotten_monarch.glb")
    g = Glb(src)
    a = g.arrays()
    P = a["POSITION"]
    I = a["indices"].reshape(-1, 3)
    names = g.joint_names()
    bp = g.bind_positions()
    lab = pieces(P, I)
    D = to_dense(a["JOINTS_0"], a["WEIGHTS_0"], len(names))
    hand_ids = [i for i, n in enumerate(names) if "Hand" in n]
    # forward is +X in this file (the hands stand out that way), sideways is Z
    lateral = 2

    # 1. the baked sword: a long thin separate piece in front of the body, from the floor up to the hands, on the hands
    sword = None
    for c in np.unique(lab):
        m = lab == c
        if m.sum() < 100:
            continue
        lo, hi = P[m].min(0), P[m].max(0)
        size = hi - lo
        on_hands = D[m][:, hand_ids].sum(1).mean()
        if size[1] > 0.45 and size[0] < 0.05 and lo[1] < 0.05 and on_hands > 0.6:
            sword = c
    assert sword is not None, "sword piece not found"
    drop = lab == sword
    print("sword piece: %d vertices, height %.3f" % (drop.sum(), P[drop][:, 1].max()))

    # 2. the cloak and its rags: off the arms, onto the trunk
    arm = np.zeros(len(P), np.float32)
    dist = np.full(len(P), 9.0)
    for side in ["Left", "Right"]:
        A, F, H = [bp[names.index(side + x)] for x in ["Arm", "ForeArm", "Hand"]]
        dist = np.minimum(dist, np.minimum(seg_dist(P, A, F), seg_dist(P, F, H)))
        arm += D[:, [names.index(side + "Arm"), names.index(side + "ForeArm")]].sum(1)
    # the cloak is the largest piece that is mostly carried by the upper arms
    best, cloak = 0, None
    for c in np.unique(lab):
        m = lab == c
        if m.sum() > best and arm[m].mean() > 0.4 and np.percentile(dist[m], 50) > 0.2:
            best, cloak = m.sum(), c
    assert cloak is not None, "cloak piece not found"
    f = smooth(0.10, 0.16, dist) * (arm > 0.05)
    f[lab == cloak] = 1.0
    print("cloak piece: %d vertices; %d other vertices rebound" % ((lab == cloak).sum(), ((f > 0) & (lab != cloak)).sum()))
    T = trunk_weights(P, names, bp, lateral)
    D = D * (1.0 - f)[:, None] + T * f[:, None]
    J, W = to_top4(D)

    # rebuild the triangle list without the sword, and compact the vertices
    keep_tri = ~drop[I].any(axis=1)
    I2 = I[keep_tri]
    used = np.zeros(len(P), bool)
    used[I2.reshape(-1)] = True
    newi = np.cumsum(used) - 1
    out = {k: v[used] for k, v in a.items() if k != "indices"}
    out["JOINTS_0"] = J[used]
    out["WEIGHTS_0"] = W[used]
    out["indices"] = newi[I2].astype(np.uint32)
    g.save(dst, out)
    print("wrote %s: %d vertices, %d triangles (was %d, %d)" % (dst, used.sum(), len(I2), len(P), len(I)))


if __name__ == "__main__":
    {"monarch": monarch}[sys.argv[1]]()
