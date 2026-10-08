"use strict";

const childProcess = require("child_process");
const fs = require("fs");

const LEGACY_ARTIFACT = "linux";
const ARTIFACTS = new Set([
    LEGACY_ARTIFACT,
    "linux-ubuntu-24.04",
    "linux-ubuntu-26.04",
    "linux-debian-13",
    "linux-el9",
    "linux-el10",
]);

const UBUNTU_ARTIFACTS = {
    "ubuntu:24.04": "linux-ubuntu-24.04",
    "ubuntu:26.04": "linux-ubuntu-26.04",
};

const EL_IDS = new Set(["rhel", "rocky", "almalinux", "ol"]);
const EL_ARTIFACTS = {
    9: "linux-el9",
    10: "linux-el10",
};

function parseOsRelease(contents) {
    const values = {};

    for (const line of contents.split(/\r?\n/)) {
        if (!line || line.startsWith("#")) continue;

        const separator = line.indexOf("=");
        if (separator === -1) continue;

        const key = line.slice(0, separator);
        let value = line.slice(separator + 1).trim();
        if (value.startsWith('"') && value.endsWith('"')) {
            value = value.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, "\\");
        }
        values[key] = value;
    }

    return values;
}

function detectLinuxArtifact(osRelease) {
    const id = (osRelease.ID || "").toLowerCase();
    const version = osRelease.VERSION_ID || "";
    const majorVersion = version.split(".")[0];

    if (id === "ubuntu") return UBUNTU_ARTIFACTS[`${id}:${version}`];
    if (id === "debian" && majorVersion === "13") return "linux-debian-13";
    if (EL_IDS.has(id)) return EL_ARTIFACTS[majorVersion];

    const idLike = (osRelease.ID_LIKE || "").toLowerCase().split(/\s+/);
    if (idLike.includes("rhel")) return EL_ARTIFACTS[majorVersion];
}

function readOsRelease() {
    for (const file of ["/etc/os-release", "/usr/lib/os-release"]) {
        try {
            return parseOsRelease(fs.readFileSync(file, "utf8"));
        } catch (error) {
            if (error.code !== "ENOENT") throw error;
        }
    }
    return {};
}

function selectArtifact(platform, osRelease, override) {
    if (platform !== "linux") return undefined;

    if (override) {
        if (!ARTIFACTS.has(override)) {
            throw new Error(`Unsupported MAPLIBRE_NATIVE_ARTIFACT: ${override}`);
        }
        return override;
    }

    const artifact = detectLinuxArtifact(osRelease);
    if (artifact) return artifact;

    const id = osRelease.ID || "unknown";
    const version = osRelease.VERSION_ID || "unknown";
    throw new Error(
        `Unsupported Linux distribution: ${id} ${version}. ` +
        "Set MAPLIBRE_NATIVE_ARTIFACT to a supported target if you have a compatible prebuild."
    );
}

function selectedArtifact() {
    if (process.platform !== "linux") return undefined;
    return selectArtifact(process.platform, readOsRelease(), process.env.MAPLIBRE_NATIVE_ARTIFACT);
}

function install() {
    const artifact = selectedArtifact();
    const args = ["install", "--fallback-to-build=false"];

    if (artifact) {
        args.push(`--target_platform=${artifact}`);
        if (artifact === LEGACY_ARTIFACT) {
            console.warn("Using the requested deprecated generic Linux prebuild.");
        }
    }

    const nodePreGyp = require.resolve("@acalcutt/node-pre-gyp/bin/node-pre-gyp");
    const result = childProcess.spawnSync(process.execPath, [nodePreGyp, ...args], { stdio: "inherit" });

    if (result.error) throw result.error;
    process.exitCode = result.status === null ? 1 : result.status;
}

if (require.main === module) install();

module.exports = { detectLinuxArtifact, parseOsRelease, selectArtifact, selectedArtifact };
