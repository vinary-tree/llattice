#!/usr/bin/env python3
"""Generate llattice's C/Raku provider ABI from one reviewed contract."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import NoReturn

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "bindings" / "raku" / "provider-api.json"
HEADER_PATH = ROOT / "bindings" / "raku" / "cbits" / "llattice_raku_provider.h"
RAKU_PATH = (
    ROOT / "bindings" / "raku" / "lib" / "LLattice" / "GeneratedProviderAbi.rakumod"
)

C_RETURN_TYPES = {"void", "VtStatus", "uint32_t", "uint64_t", "size_t"}
RAKU_RETURN_TYPES: dict[str, str | None] = {
    "void": None,
    "VtStatus": "int32",
    "uint32_t": "uint32",
    "uint64_t": "uint64",
    "size_t": "size_t",
}
RAKU_PARAMETER_TYPES = {
    "const VtInterfaceId*": "Vinary::Tree::Interop::InterfaceId",
    "const VtResource*": "Vinary::Tree::Interop::RawResource",
    "VtResource*": "Vinary::Tree::Interop::RawResource",
    "uint64_t": "uint64",
    "size_t": "size_t",
    "void*": "Pointer",
    "void**": "Pointer",
}


def abort(message: str) -> NoReturn:
    raise SystemExit(f"generate-raku-provider-abi: {message}")


def load_model() -> dict:
    try:
        model = json.loads(MODEL_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        abort(f"cannot read {MODEL_PATH.relative_to(ROOT)}: {error}")
    if not isinstance(model, dict):
        abort("provider-api.json must contain a JSON object")
    return model


def validate_parameter(owner: str, parameter: object) -> None:
    if not isinstance(parameter, dict):
        abort(f"{owner} has a non-object parameter")
    name = parameter.get("name")
    if not isinstance(name, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", name):
        abort(f"{owner} has an invalid parameter name")
    c_type = parameter.get("cType")
    if not isinstance(c_type, str) or not c_type:
        abort(f"{owner}.{name}.cType must be non-empty")
    if parameter.get("direction") not in {"in", "out", "inout"}:
        abort(f"{owner}.{name}.direction is invalid")
    for field in ("ownership", "nullability"):
        if not isinstance(parameter.get(field), str) or not parameter[field]:
            abort(f"{owner}.{name}.{field} must be non-empty")


def validate_model(model: dict) -> None:
    if model.get("callingConvention") != "cdecl":
        abort("callingConvention must be cdecl")
    for field in ("headerGuard", "exportMacro", "interopHeader"):
        if not isinstance(model.get(field), str) or not model[field]:
            abort(f"{field} must be non-empty")
    abi = model.get("abiVersion")
    api = model.get("apiRevision")
    if not isinstance(abi, int) or abi < 1:
        abort("abiVersion must be a positive integer")
    if not isinstance(api, int) or api < 1:
        abort("apiRevision must be a positive integer")

    capabilities = model.get("capabilities")
    if not isinstance(capabilities, dict) or not capabilities:
        abort("capabilities must be a non-empty object")
    used_bits = 0
    for name, value in capabilities.items():
        if not isinstance(name, str) or not re.fullmatch(r"[A-Z][A-Z0-9_]*", name):
            abort(f"invalid capability name {name!r}")
        if (
            not isinstance(value, int)
            or value <= 0
            or value >= 2**64
            or value & (value - 1)
        ):
            abort(f"capability {name} must be one unique uint64 bit")
        if used_bits & value:
            abort(f"capability {name} overlaps another bit")
        used_bits |= value

    types = model.get("types")
    if not isinstance(types, dict) or not types:
        abort("types must be a non-empty object")
    for name, item in types.items():
        if not isinstance(item, dict):
            abort(f"types.{name} must be an object")
        for field in ("kind", "rakuType", "ownership", "sizeProbe"):
            if not isinstance(item.get(field), str) or not item[field]:
                abort(f"types.{name}.{field} must be non-empty")

    callbacks = model.get("callbacks")
    if not isinstance(callbacks, list) or not callbacks:
        abort("callbacks must be a non-empty array")
    callback_by_name: dict[str, dict] = {}
    for callback in callbacks:
        if not isinstance(callback, dict):
            abort("callbacks contains a non-object")
        name = callback.get("name")
        if not isinstance(name, str) or not re.fullmatch(
            r"LlatticeRaku[A-Z][A-Za-z0-9]*", name
        ):
            abort("callback has an invalid name")
        if name in callback_by_name:
            abort(f"duplicate callback {name}")
        if callback.get("returnType") not in C_RETURN_TYPES:
            abort(f"{name} has an unsupported return type")
        parameters = callback.get("parameters")
        if not isinstance(parameters, list):
            abort(f"{name}.parameters must be an array")
        parameter_names: set[str] = set()
        for parameter in parameters:
            validate_parameter(name, parameter)
            parameter_name = parameter["name"]
            if parameter_name in parameter_names:
                abort(f"{name} has duplicate parameter {parameter_name}")
            parameter_names.add(parameter_name)
            raku_parameter_type(parameter, {})
        callback_by_name[name] = callback

    functions = model.get("functions")
    if not isinstance(functions, list) or not functions:
        abort("functions must be a non-empty array")
    function_by_name: dict[str, dict] = {}
    for function in functions:
        if not isinstance(function, dict):
            abort("functions contains a non-object")
        name = function.get("name")
        if not isinstance(name, str) or not re.fullmatch(
            r"llattice_raku_provider_[a-z0-9_]+", name
        ):
            abort("function has an invalid name")
        if name in function_by_name:
            abort(f"duplicate function {name}")
        raku_name = function.get("rakuName")
        if not isinstance(raku_name, str) or not re.fullmatch(
            r"[a-z][a-z0-9-]*", raku_name
        ):
            abort(f"{name}.rakuName is invalid")
        since = function.get("sinceApiRevision")
        if not isinstance(since, int) or not 1 <= since <= api:
            abort(f"{name}.sinceApiRevision must be within 1..{api}")
        if function.get("returnType") not in C_RETURN_TYPES:
            abort(f"{name} has an unsupported return type")
        parameters = function.get("parameters")
        if not isinstance(parameters, list):
            abort(f"{name}.parameters must be an array")
        parameter_names: set[str] = set()
        for parameter in parameters:
            validate_parameter(name, parameter)
            parameter_name = parameter["name"]
            if parameter_name in parameter_names:
                abort(f"{name} has duplicate parameter {parameter_name}")
            parameter_names.add(parameter_name)
            raku_parameter_type(parameter, callback_by_name)
        function_by_name[name] = function

    required_functions = {
        "llattice_raku_provider_abi_version",
        "llattice_raku_provider_api_revision",
        "llattice_raku_provider_capabilities",
        "llattice_raku_provider_configure",
        "llattice_raku_provider_create",
        "llattice_raku_provider_host_context",
        "llattice_raku_provider_host_context_at",
    }
    required_functions.update(item["sizeProbe"] for item in types.values())
    missing = required_functions - set(function_by_name)
    if missing:
        abort(f"required provider functions are missing: {sorted(missing)}")
    configure = function_by_name["llattice_raku_provider_configure"]
    configured_callbacks = [item["cType"] for item in configure["parameters"]]
    if list(dict.fromkeys(configured_callbacks)) != list(callback_by_name):
        abort("configure callback types must first appear in declaration order")


def raku_parameter_type(parameter: dict, callbacks: dict[str, dict]) -> str:
    if "rakuType" in parameter:
        value = parameter["rakuType"]
        if not isinstance(value, str) or not value:
            abort(f"{parameter.get('name', '?')}.rakuType must be non-empty")
        return value
    c_type = parameter["cType"]
    if c_type in callbacks:
        return callback_raku_signature(parameter["name"], callbacks[c_type], callbacks)
    try:
        return RAKU_PARAMETER_TYPES[c_type]
    except KeyError:
        abort(f"no Raku parameter mapping for {c_type}")


def callback_raku_signature(
    parameter_name: str, callback: dict, callbacks: dict[str, dict]
) -> str:
    parameters = [
        raku_parameter_type(parameter, callbacks)
        for parameter in callback["parameters"]
    ]
    returned = RAKU_RETURN_TYPES[callback["returnType"]]
    signature = ", ".join(parameters)
    if returned is not None:
        signature = f"{signature} --> {returned}" if signature else f"--> {returned}"
    return f"&{parameter_name.replace('_', '-')} ({signature})"


def c_parameter(parameter: dict) -> str:
    return f"{parameter['cType']} {parameter['name']}"


def c_prototype(function: dict, export_macro: str) -> str:
    parameters = ", ".join(c_parameter(item) for item in function["parameters"])
    return (
        f"{export_macro} {function['returnType']} {function['name']}"
        f"({parameters or 'void'});"
    )


def render_c_header(model: dict) -> str:
    guard = model["headerGuard"]
    export = model["exportMacro"]
    capability_names = list(model["capabilities"])
    lines = [
        "/* Code generated by scripts/generate-raku-provider-abi.py; DO NOT EDIT. */",
        f"#ifndef {guard}",
        f"#define {guard}",
        "",
        "#include <stddef.h>",
        "#include <stdint.h>",
        f'#include "{model["interopHeader"]}"',
        "",
        "#if defined(_WIN32) || defined(__CYGWIN__)",
        f"#define {export} __declspec(dllexport)",
        "#elif defined(__GNUC__) || defined(__clang__)",
        f'#define {export} __attribute__((visibility("default")))',
        "#else",
        f"#define {export}",
        "#endif",
        "",
        f"#define LLATTICE_RAKU_PROVIDER_ABI_VERSION {model['abiVersion']}u",
        f"#define LLATTICE_RAKU_PROVIDER_API_REVISION {model['apiRevision']}u",
    ]
    for name, value in model["capabilities"].items():
        lines.append(
            f"#define LLATTICE_RAKU_PROVIDER_CAPABILITY_{name} UINT64_C({value})"
        )
    expression = " | ".join(
        f"LLATTICE_RAKU_PROVIDER_CAPABILITY_{name}" for name in capability_names
    )
    lines.extend(
        [
            "#define LLATTICE_RAKU_PROVIDER_CAPABILITIES " + chr(92),
            f"    ({expression})",
            "",
            "#ifdef __cplusplus",
            'extern "C" {',
            "#endif",
            "",
        ]
    )
    for callback in model["callbacks"]:
        parameters = callback["parameters"]
        if not parameters:
            lines.append(
                f"typedef {callback['returnType']} (*{callback['name']})(void);"
            )
        else:
            lines.append(f"typedef {callback['returnType']} (*{callback['name']})(")
            for index, parameter in enumerate(parameters):
                suffix = "," if index + 1 < len(parameters) else ");"
                lines.append(f"    {c_parameter(parameter)}{suffix}")
        lines.append("")
    for function in model["functions"]:
        parameters = function["parameters"]
        if not parameters:
            lines.append(f"{export} {function['returnType']} {function['name']}(void);")
        else:
            lines.append(f"{export} {function['returnType']} {function['name']}(")
            for index, parameter in enumerate(parameters):
                suffix = "," if index + 1 < len(parameters) else ");"
                lines.append(f"    {c_parameter(parameter)}{suffix}")
        lines.append("")
    lines.extend(
        [
            "#ifdef __cplusplus",
            "}",
            "#endif",
            "",
            f"#endif /* {guard} */",
            "",
        ]
    )
    return "\n".join(lines)


def raku_quote(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def append_map(
    lines: list[str], name: str, entries: list[tuple[str, str | int]]
) -> None:
    lines.append(f"our constant {name} is export = Map.new(")
    for key, value in entries:
        rendered = str(value) if isinstance(value, int) else raku_quote(value)
        lines.append(f"    {raku_quote(key)} => {rendered},")
    lines.extend([");", ""])


def render_raku(model: dict) -> str:
    capabilities = model["capabilities"]
    required = sum(capabilities.values())
    lines = [
        "unit module LLattice::GeneratedProviderAbi;",
        "",
        "use NativeCall;",
        "need Vinary::Tree::Interop;",
        "",
        "# Code generated by scripts/generate-raku-provider-abi.py from",
        "# bindings/raku/provider-api.json; DO NOT EDIT.",
        f"our constant PROVIDER-ABI-VERSION is export = {model['abiVersion']};",
        f"our constant PROVIDER-API-REVISION is export = {model['apiRevision']};",
        f"our constant PROVIDER-REQUIRED-CAPABILITIES is export = {required};",
        f"our constant PROVIDER-CALLING-CONVENTION is export = {raku_quote(model['callingConvention'])};",
    ]
    for name, value in capabilities.items():
        lines.append(
            f"our constant PROVIDER-CAPABILITY-{name.replace('_', '-')} is export = {value};"
        )
    lines.append("")

    append_map(
        lines,
        "TYPE-RAKU-REPRESENTATIONS",
        [(name, item["rakuType"]) for name, item in model["types"].items()],
    )
    append_map(
        lines,
        "TYPE-OWNERSHIP",
        [(name, item["ownership"]) for name, item in model["types"].items()],
    )
    append_map(
        lines,
        "C-SIGNATURES",
        [
            (function["name"], c_prototype(function, model["exportMacro"]))
            for function in model["functions"]
        ],
    )
    append_map(
        lines,
        "FUNCTION-SINCE-API-REVISION",
        [
            (function["name"], function["sinceApiRevision"])
            for function in model["functions"]
        ],
    )
    ownership: list[tuple[str, str]] = []
    nullability: list[tuple[str, str]] = []
    for collection_name in ("callbacks", "functions"):
        for item in model[collection_name]:
            for parameter in item["parameters"]:
                key = f"{item['name']}:{parameter['name']}"
                ownership.append((key, parameter["ownership"]))
                nullability.append((key, parameter["nullability"]))
    append_map(lines, "PARAMETER-OWNERSHIP", ownership)
    append_map(lines, "PARAMETER-NULLABILITY", nullability)

    lines.extend(
        [
            "sub provider-library(--> Str:D) {",
            "    state $library = %*ENV<LLATTICE_RAKU_PROVIDER_LIB>",
            "        // %?RESOURCES<libraries/llattice_raku_provider>.IO.Str;",
            "    $library",
            "}",
            "",
        ]
    )
    callbacks = {item["name"]: item for item in model["callbacks"]}
    for function in model["functions"]:
        parameters = []
        for parameter in function["parameters"]:
            rendered = raku_parameter_type(parameter, callbacks)
            if parameter["cType"] == "void**":
                rendered += " is rw"
            parameters.append(rendered)
        returned = RAKU_RETURN_TYPES[function["returnType"]]
        parts = parameters[:]
        if returned is not None:
            parts.append(f"--> {returned}")
        if parts:
            lines.append(f"our sub {function['rakuName']}(")
            lines.append("    " + ",\n    ".join(parts))
            lines.append(")")
        else:
            lines.append(f"our sub {function['rakuName']}()")
        lines.extend(
            [
                "    is native(&provider-library)",
                f"    is symbol({raku_quote(function['name'])})",
                "    is export(:native)",
                "{ * }",
                "",
            ]
        )

    lines.extend(
        [
            "our sub validate-provider-abi(--> Nil) is export(:native) {",
            "    my $abi = provider-abi-version();",
            '    die "llattice Raku provider ABI mismatch: native $abi / "',
            '        ~ "facade {PROVIDER-ABI-VERSION}"',
            "        unless $abi == PROVIDER-ABI-VERSION;",
            "    my $api = provider-api-revision();",
            '    die "llattice Raku provider API revision $api is older than "',
            "        ~ PROVIDER-API-REVISION",
            "        unless $api >= PROVIDER-API-REVISION;",
            "    my $capabilities = provider-capabilities();",
            '    die "llattice Raku provider capabilities are incomplete"',
            "        unless ($capabilities +& PROVIDER-REQUIRED-CAPABILITIES)",
            "            == PROVIDER-REQUIRED-CAPABILITIES;",
            '    die "llattice Raku provider VtInterfaceId layout mismatch"',
            "        unless provider-sizeof-interface-id()",
            "            == nativesizeof(Vinary::Tree::Interop::InterfaceId);",
            '    die "llattice Raku provider VtResource layout mismatch"',
            "        unless provider-sizeof-resource()",
            "            == nativesizeof(Vinary::Tree::Interop::RawResource);",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def write_outputs(outputs: dict[Path, str]) -> None:
    for path, source in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
        print(f"wrote {path.relative_to(ROOT)}")


def check_outputs(outputs: dict[Path, str]) -> int:
    stale = []
    for path, expected in outputs.items():
        try:
            actual = path.read_text(encoding="utf-8")
        except OSError:
            actual = ""
        if actual != expected:
            stale.append(str(path.relative_to(ROOT)))
    if stale:
        print(
            "generated provider ABI is stale: "
            + ", ".join(stale)
            + "; run python3 scripts/generate-raku-provider-abi.py --write",
            file=sys.stderr,
        )
        return 1
    print("llattice provider model, C header, and Raku NativeCall ABI agree")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="verify generated output")
    mode.add_argument("--write", action="store_true", help="rewrite generated output")
    args = parser.parse_args()

    model = load_model()
    validate_model(model)
    outputs = {
        HEADER_PATH: render_c_header(model),
        RAKU_PATH: render_raku(model),
    }
    if args.write:
        write_outputs(outputs)
        return 0
    return check_outputs(outputs)


if __name__ == "__main__":
    raise SystemExit(main())
