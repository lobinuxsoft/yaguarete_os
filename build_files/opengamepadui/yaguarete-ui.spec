# YaguareteOS build of lobinuxsoft/yaguarete-ui, a fork of ShadowBlip/OpenGamepadUI
# adding Steam session switching (overlay mode <-> standalone) and Goldberg/
# Aurelia-based standalone launching. Everything else — the Godot project, the
# Rust GDExtension core, the install layout — is unmodified upstream OGUI, so
# this spec is a near-verbatim copy of upstream's own package/rpm/opengamepadui.spec
# (the same file `make dist-rpm` in that repo builds from), not a rewrite.
#
# Why the package is renamed while the files are not: keeping upstream's Name
# would let the next opengamepadui release from the COPR this base image pulls
# from win the version comparison on a rebuild, silently reverting to stock
# OGUI with nothing in the build log to show for it. Obsoletes pins the swap
# in one direction, same pattern as yaguarete-updater.spec's swap of
# bazzite-updater. The paths stay as upstream ships them (this fork touches
# no install paths) so nothing else that references them — the .desktop
# entry, the gamescope-session-plus CLIENTCMD, the polkit actions — needs to
# change.

%global forkname yaguarete-ui
%global commit   74f03006a9e3aabb3989d3c35210b80f876e1327

Name:           yaguarete-ui
Version:        0.46.1
Release:        1%{?dist}
Summary:        A free and open source game launcher and overlay written using the Godot Game Engine 4 designed with a gamepad native experience in mind

License:        GPL-3.0-only
URL:            https://github.com/lobinuxsoft/yaguarete-ui

# Built from source in build-opengamepadui.sh (git clone at the pinned tag,
# commit asserted against %{commit}), which produces this exact tarball via
# `make dist/opengamepadui-x86_64.tar.gz` — the same Makefile target
# upstream's own spec consumes, just pointed at this fork's checkout instead
# of a downloaded release asset.
Source0:        opengamepadui-x86_64.tar.gz

# Replaces the base image's own opengamepadui package. `Provides` keeps
# anything that depends on the upstream name resolvable; `Obsoletes` is what
# makes dnf swap it out regardless of that package's own version.
Provides:       opengamepadui = %{version}-%{release}
Obsoletes:      opengamepadui < 999

Requires:       gamescope

BuildRequires:  make
BuildRequires:  systemd-rpm-macros

%description
A free and open source game launcher and overlay written using the Godot
Game Engine 4 designed with a gamepad native experience in mind.

This is lobinuxsoft/yaguarete-ui, a fork of ShadowBlip/OpenGamepadUI adding
Steam session switching and Goldberg/Aurelia-based standalone launching.

%define debug_package %{nil}
%define _build_id_links none
%define __os_install_post %{nil}

%prep
%autosetup -p1 -n opengamepadui

%install
make install PREFIX=%{buildroot}%{_prefix} INSTALL_PREFIX=%{_prefix} ARCH=%{_arch}

%files
/usr/bin/opengamepadui
/usr/share/opengamepadui/*.so
/usr/share/opengamepadui/reaper
/usr/share/opengamepadui/scripts/*
/usr/share/opengamepadui/opengamepad-ui.%{_arch}
/usr/share/opengamepadui/opengamepad-ui.pck
/usr/share/applications/opengamepadui.desktop
/usr/share/icons/hicolor/scalable/apps/opengamepadui.svg
/usr/share/polkit-1/actions/*
/usr/lib/systemd/user/*

%changelog
* Mon Sep 07 2026 lobinuxsoft - 0.46.1-1
- Initial YaguareteOS build, pinned to yaguarete-ui commit 74f03006
