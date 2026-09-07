#!/usr/bin/env python3
"""Register the GGUF roster as pointer models in the MLflow model registry, and
set the champion/challenger slot aliases from docs/reference/model-slots.yaml.

Reference architecture (docs/reference/EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md §6):

  * One LoggedModel-equivalent per **GGUF x runtime build x flags x host** -- that
    tuple is the join key across MLflow and the lake. Here it becomes one model
    VERSION per (gguf_file x runtime_build x host) under a registered model named
    for the GGUF's canonical model_key.
  * **Pointer models, not copies.** The registered artifact is a small model_card.json
    holding the manifest row + the on-node path. No GGUF bytes flow through MLflow.
  * **The MLflow registry is the alias/tag authority** (champion/challenger per slot).
    Unity Catalog OSS holds the governed three-level name and is a *mirror* step only,
    because UC OSS has no aliases or tags (see --uc).

Identity conventions are deliberately copied from scripts/utils/log_sweep_to_mlflow.py
so that a registered version JOINS to the sweep runs that produced its evidence:

    quant       parsed by the same QUANT_RE, case preserved verbatim from the filename
    model_key   "<hf_repo_id>#<quant>"
    gguf_sha256 read from the HF download metadata sidecar, never a 30 GB rehash

Anything that cannot be resolved from where this runs degrades to the literal string
"unavailable" and can be filled in later with --refresh from a host that has
/mnt/ai-models mounted.

Usage
-----
    # plan only, touches nothing
    python scripts/utils/register_models.py --dry-run

    # register against the live server
    python scripts/utils/register_models.py

    # on the Framework, with the model store mounted: fill in sha256/size
    python scripts/utils/register_models.py --refresh --models-root /mnt/ai-models

    # attempt the Unity Catalog OSS mirror
    python scripts/utils/register_models.py --uc http://192.168.7.241:8080
"""

import argparse
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request

DEFAULT_TRACKING_URI = "http://192.168.7.241:5000"
DEFAULT_MODELS_ROOT = "/mnt/ai-models"
DEFAULT_RUNTIME_BUILD = "10687"
DEFAULT_HOST = "kalman9-framework-01"
DEFAULT_ARCH = "gfx1151"
DEFAULT_STUDIO_VERSION = "unsloth 2026.8.22"
EXPERIMENT = "hwbench/model-registry"
# The deployed UC OSS instance holds catalog `vvc` / schema `evidence`; there is no
# `hwbench` catalog and this script does NOT create one (catalog/schema creation is an
# infra change, not a registration step). `vvc.evidence.<name>` is also the governed
# three-level name the reference architecture §6 specifies. Override with --uc-catalog
# / --uc-schema.
UC_CATALOG = "vvc"
UC_SCHEMA = "evidence"

UNAVAILABLE = "unavailable"
TAG_MAX = 4500

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))

# Identical to log_sweep_to_mlflow.QUANT_RE -- do not "improve" independently.
QUANT_RE = re.compile(
    r"(?i)-((?:UD-)?(?:I?Q\d+(?:_[A-Z0-9]+)*)|F16|BF16|F32|MXFP4)"
    r"(?:-\d{5}-of-\d{5})?\.gguf$")
QUANT_DIR_RE = re.compile(
    r"(?i)^((?:UD-)?(?:I?Q\d+(?:_[A-Z0-9]+)*)|F16|BF16|F32|MXFP4)$")
SHA256_RE = re.compile(r"\b[0-9a-f]{64}\b")

# "-30B" / "-235B" but not the active-param "A3B"
PARAMS_TOTAL_RE = re.compile(r"(?<![A-Za-z0-9])(\d+(?:\.\d+)?)B(?![A-Za-z0-9])")
PARAMS_ACTIVE_RE = re.compile(r"(?<![A-Za-z0-9])A(\d+(?:\.\d+)?)B(?![A-Za-z0-9])")

INVENTORY_SECTIONS = ("light_models", "default_models", "all_models")


# --------------------------------------------------------------------------- #
# small helpers
# --------------------------------------------------------------------------- #
def die(msg):
    print("ERROR: " + msg, file=sys.stderr)
    raise SystemExit(2)


def warn(msg):
    print("WARN: " + msg, file=sys.stderr)


def s(value):
    """Tag/param-safe string. MLflow rejects None and long values."""
    text = UNAVAILABLE if value is None else str(value)
    return text[:TAG_MAX]


def safe_model_name(model_key):
    """model_key -> MLflow registered-model name. Only "/" and "#" are replaced."""
    return model_key.replace("/", "__").replace("#", "__")


def safe_alias(alias):
    """MLflow alias names accept word characters and dashes only."""
    return re.sub(r"[^\w\-]", "-", alias)


def uc_model_name(registered_name):
    """UC OSS rejects "Name cannot contain a period, space, forward-slash, or control
    characters" (verified against 0.6.0), so `Qwen3.8` must become `Qwen3_8` in the
    governed three-level name. The MLflow name is left untouched; the mapping is
    recorded in the UC model's comment so the two can be joined back up."""
    return re.sub(r"[.\s/]", "_", registered_name)


def split_quant(basename):
    m = QUANT_RE.search(basename)
    return m.group(1) if m else None


def repo_from_path(rel_path):
    """`<org>/<repo>` implied by the on-disk layout, climbing a quant subdir.

    This is what log_sweep_to_mlflow derives from the served path, and it is NOT always
    the HF repo id (e.g. Qwen3-235B lives under Qwen/qwen3-235b-a22b on disk but comes
    from unsloth/Qwen3-235B-A22B-Instruct-GGUF). Both are recorded so either join works.
    """
    parts = [x for x in str(rel_path).replace("\\", "/").split("/") if x]
    if len(parts) < 2:
        return None
    dirs = parts[:-1]
    if len(dirs) >= 2 and QUANT_DIR_RE.match(dirs[-1]):
        dirs = dirs[:-1]
    if len(dirs) < 2:
        return "/".join(dirs)
    return dirs[-2] + "/" + dirs[-1]


def gguf_sha256(model_path):
    """sha256 from the HF download metadata sidecar (never a rehash of 30-180 GB)."""
    p = str(model_path).replace("\\", "/")
    d = os.path.dirname(p)
    base = os.path.basename(p)
    cands = [os.path.join(d, ".cache", "huggingface", "download", base + ".metadata")]
    parent = os.path.dirname(d)
    if parent:
        cands.append(os.path.join(parent, ".cache", "huggingface", "download",
                                  os.path.basename(d), base + ".metadata"))
    for c in cands:
        if os.path.exists(c):
            try:
                with open(c, encoding="utf-8", errors="replace") as f:
                    text = f.read()
            except OSError:
                continue
            m = SHA256_RE.search(text)
            if m:
                return m.group(0)
    return UNAVAILABLE


def derive_params(*texts):
    total = active = UNAVAILABLE
    for t in texts:
        if not t:
            continue
        if total == UNAVAILABLE:
            m = PARAMS_TOTAL_RE.search(str(t))
            if m:
                total = m.group(1) + "B"
        if active == UNAVAILABLE:
            m = PARAMS_ACTIVE_RE.search(str(t))
            if m:
                active = m.group(1) + "B"
    return total, active


# --------------------------------------------------------------------------- #
# inventory -> model cards
# --------------------------------------------------------------------------- #
def load_yaml(path, what):
    try:
        import yaml
    except ImportError:
        die("pyyaml is required: pip install 'mlflow>=2.19' pyyaml")
    if not os.path.exists(path):
        die(what + " not found: " + path)
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def scan_results(repo_root, names):
    """Sweep dirs whose manifest mentions this model. Best-effort evidence pointer."""
    root = os.path.join(repo_root, "results", "sweeps")
    if not os.path.isdir(root):
        return UNAVAILABLE
    needles = [n.lower() for n in names if n]
    hits = []
    for d in sorted(os.listdir(root)):
        man = os.path.join(root, d, "manifest.yaml")
        if not os.path.exists(man):
            continue
        try:
            with open(man, encoding="utf-8", errors="replace") as f:
                text = f.read().lower()
        except OSError:
            continue
        if any(n in text for n in needles):
            hits.append("results/sweeps/" + d)
    return ",".join(hits) if hits else UNAVAILABLE


def build_cards(inv, args):
    """One card per unique (hf_repo, hf_file) across every inventory section."""
    cards = []
    seen = {}
    for section in INVENTORY_SECTIONS:
        for entry in (inv.get(section) or []):
            if not isinstance(entry, dict):
                continue
            repo = str(entry.get("hf_repo") or "").strip()
            hf_file = str(entry.get("hf_file") or "").strip()
            if not repo or not hf_file:
                warn("inventory row without hf_repo/hf_file, skipped: "
                     + str(entry.get("name")))
                continue
            dedupe = repo + "/" + hf_file
            if dedupe in seen:
                seen[dedupe]["inventory_sections"].append(section)
                continue

            base = os.path.basename(hf_file.replace("\\", "/"))
            quant = split_quant(base) or UNAVAILABLE
            model_key = repo + "#" + quant
            rel = str(entry.get("path") or (repo + "/" + hf_file))
            abs_path = args.models_root.rstrip("/") + "/" + rel.lstrip("/")

            if os.path.exists(abs_path):
                try:
                    size = str(os.path.getsize(abs_path))
                except OSError:
                    size = UNAVAILABLE
                sha = gguf_sha256(abs_path)
            else:
                size = UNAVAILABLE
                sha = UNAVAILABLE

            name = str(entry.get("name") or "")
            total, active = derive_params(name, entry.get("use_case"))
            results = (UNAVAILABLE if args.no_scan_results
                       else scan_results(REPO_ROOT, [name, base[:-5] if base.endswith(".gguf") else base]))

            card = {
                "model_key": model_key,
                "registered_name": safe_model_name(model_key),
                "hf_repo_id": repo,
                "hf_repo_dir": repo_from_path(rel) or UNAVAILABLE,
                "gguf_file": base,
                "gguf_relpath": rel,
                "model_path": abs_path,
                "quant": quant,
                "gguf_sha256": sha,
                "gguf_size_bytes": size,
                "runtime_build": args.runtime_build,
                "studio_version": args.studio_version,
                "host": args.host,
                "arch": args.arch,
                "flags": str(entry.get("required_flags") or UNAVAILABLE),
                "params_total": total,
                "params_active": active,
                "params_source": ("derived-from-name" if total != UNAVAILABLE
                                  else UNAVAILABLE),
                "context_len": str(entry.get("context_len") or UNAVAILABLE),
                "license": str(entry.get("license") or UNAVAILABLE),
                "inventory_name": name or UNAVAILABLE,
                "inventory_sections": [section],
                "size_gb": str(entry.get("size_gb") or UNAVAILABLE),
                "parts": str(entry.get("parts") or UNAVAILABLE),
                "test_strategy": str(entry.get("test_strategy") or UNAVAILABLE),
                "use_case": str(entry.get("use_case") or UNAVAILABLE),
                "source_results": results,
                "models_root": args.models_root,
                "pointer_only": "true",
            }
            seen[dedupe] = card
            cards.append(card)
    for c in cards:
        c["inventory_sections"] = ",".join(c["inventory_sections"])
    return cards


VERSION_TAG_KEYS = (
    "model_key", "hf_repo_id", "hf_repo_dir", "gguf_file", "gguf_relpath",
    "model_path", "quant", "gguf_sha256", "gguf_size_bytes", "runtime_build",
    "studio_version", "host", "arch", "flags", "params_total", "params_active",
    "params_source", "context_len", "license", "inventory_name",
    "inventory_sections", "size_gb", "parts", "test_strategy", "source_results",
    "models_root", "pointer_only",
)

# tags a --refresh is allowed to fill in once a host can actually see the file
REFRESHABLE = ("gguf_sha256", "gguf_size_bytes", "params_total", "params_active",
               "params_source", "context_len", "license", "source_results", "flags")


def version_tags(card):
    return {k: s(card.get(k)) for k in VERSION_TAG_KEYS}


# --------------------------------------------------------------------------- #
# slots
# --------------------------------------------------------------------------- #
def slot_aliases(slots):
    """-> [(alias, model_key_or_None, slot, role, note)] in file order."""
    out = []
    for slot, body in (slots.get("slots") or {}).items():
        if not isinstance(body, dict):
            continue
        for role in ("champion", "challenger"):
            entry = body.get(role)
            if not isinstance(entry, dict):
                continue
            key = entry.get("model_key")
            note = ""
            if not key:
                note = (str(entry.get("candidate") or "?") + ": "
                        + " ".join(str(entry.get("blocked_by") or
                                       entry.get("status") or "no model_key").split()))
            out.append((safe_alias(role + "-" + str(slot)), key, slot, role, note))
    return out


# --------------------------------------------------------------------------- #
# MLflow
# --------------------------------------------------------------------------- #
def mlflow_client(uri):
    try:
        import mlflow
        from mlflow.tracking import MlflowClient
    except ImportError:
        die("mlflow is required: pip install 'mlflow>=2.19' pyyaml")
    mlflow.set_tracking_uri(uri)
    mlflow.set_registry_uri(uri)
    return mlflow, MlflowClient()


def existing_versions(client, name):
    try:
        return list(client.search_model_versions("name = '" + name + "'"))
    except Exception:                                    # model does not exist yet
        return []


def match_version(versions, card):
    for mv in versions:
        t = mv.tags or {}
        if (t.get("gguf_file") == card["gguf_file"]
                and t.get("runtime_build") == card["runtime_build"]
                and t.get("host") == card["host"]):
            return mv
    return None


def ensure_registered_model(client, card, created_names):
    name = card["registered_name"]
    tags = {"model_key": s(card["model_key"]),
            "hf_repo_id": s(card["hf_repo_id"]),
            "quant": s(card["quant"]),
            "inventory_name": s(card["inventory_name"]),
            "pointer_only": "true"}
    try:
        rm = client.get_registered_model(name)
        for k, v in tags.items():
            if (rm.tags or {}).get(k) != v:
                client.set_registered_model_tag(name, k, v)
        return False
    except Exception:
        client.create_registered_model(
            name, tags=tags,
            description=("Pointer model for " + card["model_key"]
                         + ". Artifacts are a model_card.json manifest row, not GGUF "
                           "bytes; weights live under " + card["models_root"] + "."))
        created_names.append(name)
        return True


def create_version(mlflow, client, exp_id, card):
    tags = version_tags(card)
    run_name = "register/" + card["model_key"]
    with mlflow.start_run(experiment_id=exp_id, run_name=run_name) as run:
        run_id = run.info.run_id
        mlflow.set_tags(dict(tags, **{"hwbench.kind": "model-registration"}))
        tmp = tempfile.mkdtemp(prefix="modelcard-")
        card_path = os.path.join(tmp, "model_card.json")
        with open(card_path, "w", encoding="utf-8") as f:
            json.dump(card, f, indent=2, sort_keys=True)
        mlflow.log_artifact(card_path, artifact_path="model_card")
    mv = client.create_model_version(
        name=card["registered_name"],
        source="runs:/" + run_id + "/model_card",
        run_id=run_id,
        tags=tags,
        description=(card["model_key"] + " on runtime " + card["runtime_build"]
                     + " @ " + card["host"]))
    return mv


def refresh_version(client, card, mv):
    changed = []
    t = mv.tags or {}
    for k in REFRESHABLE:
        new = s(card.get(k))
        if t.get(k) in (None, UNAVAILABLE) and new != UNAVAILABLE:
            client.set_model_version_tag(card["registered_name"], mv.version, k, new)
            changed.append(k)
    return changed


# --------------------------------------------------------------------------- #
# Unity Catalog OSS mirror (best effort, never faked)
# --------------------------------------------------------------------------- #
def uc_call(base, path, method="GET", body=None, timeout=20):
    url = base.rstrip("/") + path
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8", "replace")[:600]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:600]
    except Exception as e:                                     # noqa: BLE001
        return None, type(e).__name__ + ": " + str(e)[:400]


def uc_mirror(uc_url, cards, dry_run, catalog, schema):
    """Best-effort mirror of the registered-model NAMES into Unity Catalog OSS.

    UC OSS has no aliases and no tags, so this is a name/governance mirror only -- the
    champion/challenger authority stays in the MLflow registry (ref-arch §6). Nothing
    here is faked: every call's status and body are printed, and a failure skips.
    """
    print("")
    print("UNITY CATALOG OSS MIRROR  " + uc_url
          + "  (catalog=" + catalog + " schema=" + schema + ")")
    base = uc_url.rstrip("/") + "/api/2.1/unity-catalog"
    for label, path in (("catalogs/" + catalog, "/catalogs/" + catalog),
                        ("schemas/" + catalog + "." + schema,
                         "/schemas/" + catalog + "." + schema),
                        ("models (list)", "/models?catalog_name=" + catalog
                         + "&schema_name=" + schema)):
        st, body = uc_call(base, path)
        print("  GET " + label + " -> " + str(st) + " " + body.replace("\n", " ")[:220])
        if st != 200:
            print("  RESULT: SKIPPED -- " + label + " is not usable on this UC OSS "
                  "deployment. Nothing was mirrored. (This script does not create "
                  "catalogs or schemas; that is an infra change.)")
            return
    if dry_run:
        print("  RESULT: dry-run, would POST " + str(len(cards)) + " registered models")
        return
    ok = exists = fail = 0
    for c in cards:
        uc_name = uc_model_name(c["registered_name"])
        st, body = uc_call(base, "/models", method="POST", body={
            "name": uc_name,
            "catalog_name": catalog,
            "schema_name": schema,
            "comment": ("pointer model for " + c["model_key"]
                        + " | mlflow_registered_name=" + c["registered_name"]),
        })
        if st in (200, 201):
            ok += 1
        elif st == 409 or "ALREADY_EXISTS" in body:
            exists += 1
        else:
            fail += 1
            if fail <= 3:
                print("  POST /models " + uc_name + " -> " + str(st)
                      + " " + body.replace("\n", " ")[:220])
    print("  RESULT: created=" + str(ok) + " already_present=" + str(exists)
          + " failed=" + str(fail)
          + "  (names only -- UC OSS has no aliases/tags; MLflow stays the alias authority)")


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def parse_args(argv):
    p = argparse.ArgumentParser(
        description="Register the GGUF roster as MLflow pointer models and set slot aliases.")
    p.add_argument("--tracking-uri",
                   default=os.environ.get("MLFLOW_TRACKING_URI", DEFAULT_TRACKING_URI),
                   help="flag > MLFLOW_TRACKING_URI > " + DEFAULT_TRACKING_URI)
    p.add_argument("--inventory",
                   default=os.path.join(REPO_ROOT, "models-inventory.yaml"))
    p.add_argument("--slots",
                   default=os.path.join(REPO_ROOT, "docs", "reference", "model-slots.yaml"))
    p.add_argument("--models-root", default=DEFAULT_MODELS_ROOT)
    p.add_argument("--runtime-build", default=DEFAULT_RUNTIME_BUILD)
    p.add_argument("--host", default=DEFAULT_HOST)
    p.add_argument("--arch", default=DEFAULT_ARCH)
    p.add_argument("--studio-version", default=DEFAULT_STUDIO_VERSION)
    p.add_argument("--experiment", default=EXPERIMENT)
    p.add_argument("--dry-run", action="store_true",
                   help="print the full plan and touch nothing")
    p.add_argument("--refresh", action="store_true",
                   help="update 'unavailable' tags on versions that already exist")
    p.add_argument("--uc", metavar="URL",
                   help="also try to mirror registered models into Unity Catalog OSS")
    p.add_argument("--uc-catalog", default=UC_CATALOG)
    p.add_argument("--uc-schema", default=UC_SCHEMA)
    p.add_argument("--no-scan-results", action="store_true",
                   help="skip the results/sweeps manifest scan for source_results")
    p.add_argument("--no-aliases", action="store_true")
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    inv = load_yaml(args.inventory, "inventory")
    slots = load_yaml(args.slots, "slots file")
    cards = build_cards(inv, args)
    if not cards:
        die("no GGUF rows found in " + args.inventory)
    aliases = slot_aliases(slots)
    by_key = {c["model_key"]: c for c in cards}

    mode = "DRY-RUN PLAN" if args.dry_run else "REGISTER"
    print(mode + "  tracking_uri=" + args.tracking_uri)
    print("  experiment=" + args.experiment + "  runtime_build=" + args.runtime_build
          + "  host=" + args.host + "  arch=" + args.arch)
    print("  inventory=" + args.inventory)
    print("  slots=" + args.slots)
    print("  models_root=" + args.models_root
          + ("  (present)" if os.path.isdir(args.models_root) else "  (NOT MOUNTED here"
             " -- gguf_sha256/gguf_size_bytes will be 'unavailable'; re-run with"
             " --refresh from a host that has it)"))
    print("  unique GGUFs: " + str(len(cards)))

    mlflow = client = None
    exp_id = None
    reachable = True
    try:
        mlflow, client = mlflow_client(args.tracking_uri)
        if args.dry_run:
            from mlflow.exceptions import MlflowException  # noqa: F401
            exp = mlflow.get_experiment_by_name(args.experiment)
            exp_id = exp.experiment_id if exp else None
        else:
            exp_id = mlflow.set_experiment(args.experiment).experiment_id
    except Exception as e:                                     # noqa: BLE001
        reachable = False
        warn("tracking server not reachable (" + type(e).__name__ + ": "
             + str(e)[:200] + "); plan will show existing state as 'unknown'")

    created_models = []
    created_versions = 0
    skipped_versions = 0
    refreshed = 0

    print("")
    print("MODELS / VERSIONS")
    for c in cards:
        name = c["registered_name"]
        versions = existing_versions(client, name) if reachable else []
        mv = match_version(versions, c) if versions else None
        model_state = "exists" if versions else ("new" if reachable else "unknown")
        detail = ("sha256=" + c["gguf_sha256"][:12] + (".." if c["gguf_sha256"] != UNAVAILABLE else "")
                  + " size=" + c["gguf_size_bytes"])
        if args.dry_run:
            act = "skip  " if mv else "create"
            print("  [" + act + "] " + name)
            print("           key=" + c["model_key"] + "  model=" + model_state
                  + "  gguf=" + c["gguf_file"])
            print("           " + detail
                  + ("  (existing v" + str(mv.version) + ")" if mv else ""))
            if mv:
                skipped_versions += 1
                if args.refresh:
                    would = [k for k in REFRESHABLE
                             if (mv.tags or {}).get(k) in (None, UNAVAILABLE)
                             and s(c.get(k)) != UNAVAILABLE]
                    if would:
                        print("           refresh would set: " + ",".join(would))
            else:
                created_versions += 1
            continue

        if not reachable:
            die("cannot register: tracking server unreachable at " + args.tracking_uri)
        ensure_registered_model(client, c, created_models)
        if mv:
            skipped_versions += 1
            note = ""
            if args.refresh:
                ch = refresh_version(client, c, mv)
                if ch:
                    refreshed += 1
                    note = "  refreshed: " + ",".join(ch)
            print("  [skip  ] " + name + "  v" + str(mv.version) + note)
        else:
            new = create_version(mlflow, client, exp_id, c)
            created_versions += 1
            print("  [create] " + name + "  v" + str(new.version) + "  " + detail)

    print("")
    print("ALIASES")
    alias_set = alias_skipped = 0
    for alias, key, slot, role, note in aliases:
        if not key:
            alias_skipped += 1
            print("  [skip  ] " + alias + " -> UNREGISTERABLE  " + note[:180])
            continue
        card = by_key.get(key)
        if card is None:
            alias_skipped += 1
            print("  [skip  ] " + alias + " -> " + key
                  + "  NOT IN INVENTORY (no registered model to alias)")
            continue
        name = card["registered_name"]
        if args.dry_run or args.no_aliases:
            print("  [set   ] " + alias + " -> " + name + "  (latest version)")
            alias_set += 1
            continue
        versions = existing_versions(client, name)
        if not versions:
            alias_skipped += 1
            print("  [skip  ] " + alias + " -> " + name + "  no versions exist")
            continue
        latest = max(versions, key=lambda m: int(m.version))
        client.set_registered_model_alias(name, alias, latest.version)
        alias_set += 1
        print("  [set   ] " + alias + " -> " + name + " v" + str(latest.version))

    print("")
    print("SUMMARY  models_created=" + str(len(created_models))
          + "  versions_created=" + str(created_versions)
          + "  versions_skipped=" + str(skipped_versions)
          + "  versions_refreshed=" + str(refreshed)
          + "  aliases_set=" + str(alias_set)
          + "  aliases_skipped=" + str(alias_skipped)
          + ("  (DRY RUN -- nothing written)" if args.dry_run else ""))

    if args.uc:
        uc_mirror(args.uc, cards, args.dry_run, args.uc_catalog, args.uc_schema)
    return 0


if __name__ == "__main__":
    sys.exit(main())
