# Third-party notices

Threadly builds on the components below. Each entry names where the
component enters the shipped artifacts and the license it is distributed
under; consult the upstream license files for full terms. The Rivet
toolchain is a first-party TurLamAI project consumed as a pinned package —
not third-party code — so it is not listed here. Release builds also
generate `THIRD_PARTY_NOTICES.txt` and a CycloneDX `sbom.cdx.json` in the
build `dist/` from the toolchain's fail-closed license audit; this file is
the grouped overview of what actually ships.

## Racket CS runtime

Every platform host embeds the statically linked Racket CS runtime
([racket/racket](https://github.com/racket/racket), 9.x). Racket is
distributed under the MIT license and the Apache License 2.0, at your
option; the Racket CS runtime system additionally embeds Chez Scheme,
distributed under the Apache License 2.0 (per Racket's `LICENSE.txt`).

## crypto (Racket package)

The update channel verifies Ed25519 signatures through the Racket
[crypto](https://github.com/rmculpepper/crypto) package (compiled into
the embedded runtime image through Rivet's distribution layer, pinned to
the libcrypto provider), distributed under the Apache License 2.0.

## GTK 4, libadwaita and WebKitGTK (Linux host)

The Linux host is a GTK 4 application built against libadwaita and
WebKitGTK; these libraries are licensed under the GNU Lesser General
Public License, version 2.1 or later. The `.AppImage` bundles the GTK
dependency closure it needs, staged by the Rivet toolchain from the build
distribution's packages (same LGPL-2.1-or-later terms); the deb, rpm,
tar.gz and portable zip shapes rely on the distribution's libraries.

## Windows App SDK and C++/WinRT (Windows host)

The Windows workbench builds against the NuGet packages
`Microsoft.WindowsAppSDK` and `Microsoft.Windows.CppWinRT` (both
MIT-licensed, see `windows/RivetHost.vcxproj`). Release builds deploy the
Windows App SDK runtime self-contained inside the app
(`WindowsAppSDKSelfContained=true`), so its runtime files ship with the
MSI and portable zip under Microsoft's MIT license.

## AppImageKit runtime (`.AppImage` artifacts)

`.AppImage` release artifacts contain the type-2 AppImage runtime from
[AppImage/AppImageKit](https://github.com/AppImage/AppImageKit), licensed
MIT, built with the checksum-verified official `appimagetool` fetched by
the Rivet toolchain. AppImageKit's license does not apply to the contents
of the AppImage: those are Threadly's AGPL-3.0 payload plus the entries
above.
