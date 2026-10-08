"use strict";

const test = require("tape");
const resolver = require("../../scripts/install-native");

function osRelease(id, version, idLike) {
    return resolver.parseOsRelease([
        `ID=${id}`,
        `VERSION_ID=${version}`,
        idLike && `ID_LIKE=\"${idLike}\"`,
    ].filter(Boolean).join("\n"));
}

test("selects Linux prebuilds from os-release", (t) => {
    const cases = [
        ["Ubuntu 24.04", osRelease("ubuntu", "24.04"), "linux-ubuntu-24.04"],
        ["Ubuntu 26.04", osRelease("ubuntu", "26.04"), "linux-ubuntu-26.04"],
        ["Debian 13", osRelease("debian", "13.1"), "linux-debian-13"],
        ["Rocky 9.6", osRelease("rocky", "9.6"), "linux-el9"],
        ["Rocky 10.2", osRelease("rocky", "10.2"), "linux-el10"],
        ["AlmaLinux 9", osRelease("almalinux", "9.5"), "linux-el9"],
        ["Oracle Linux 10", osRelease("ol", "10.0"), "linux-el10"],
        ["RHEL-compatible derivative", osRelease("custom", "9.4", "rhel fedora"), "linux-el9"],
    ];

    for (const [name, release, artifact] of cases) {
        t.equal(resolver.selectArtifact("linux", release), artifact, name);
    }
    t.end();
});

test("requires an explicit artifact for unsupported Linux distributions", (t) => {
    const unsupported = osRelease("debian", "12");

    t.throws(() => resolver.selectArtifact("linux", unsupported), /Unsupported Linux distribution/);
    t.equal(resolver.selectArtifact("linux", unsupported, "linux"), "linux");
    t.equal(resolver.selectArtifact("darwin", unsupported, "linux-el9"), undefined);
    t.end();
});
