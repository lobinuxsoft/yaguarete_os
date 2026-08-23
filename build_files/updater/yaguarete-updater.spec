# YaguareteOS build of rfrench3/bazzite-updater.
#
# Why we build it instead of taking Terra's binary: everything the rebrand
# needs to change -- window title, drawer entry, About page -- is compiled
# into the executable as UTF-16 inside the precompiled QML. /etc reaches the
# RSS feed and the OS about data and nothing else.
#
# Why the package is renamed while the files are not: keeping upstream's
# Name would let the next Terra release win the version comparison and
# replace this package on a rebuild, reverting the rebrand with nothing in
# the build log to show for it. Obsoletes pins the swap in one direction.
# The paths stay as upstream ships them so the /etc overrides and the
# .desktop override keep applying unchanged.

# No debuginfo: build.sh installs /rpms/yaguarete-updater-*.rpm, and the
# debuginfo/debugsource subpackages match that glob. They would ship ~40 MB
# of symbols into every variant for an app nobody debugs on the device.
%global debug_package %{nil}

%global appid   io.github.rfrench3.bazzite-updater
%global upname  bazzite-updater
%global commit  cc04ce1ecb2d721a88d8ab25f5c731e451f8d9d7

Name:           yaguarete-updater
Version:        0.9.4
Release:        1%{?dist}
Summary:        Update your YaguareteOS system

License:        GPL-2.0-or-later
URL:            https://github.com/rfrench3/bazzite-updater
Source0:        %{upname}-%{version}.tar.gz

Patch0:         0001-rebrand-for-yaguarete-os.patch

# Replaces Terra's package. `Provides` keeps anything that depends on the
# upstream name resolvable; `Obsoletes` is what makes dnf swap it out.
Provides:       %{upname} = %{version}-%{release}
Obsoletes:      %{upname} < 999

BuildRequires:  binutils
BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib
BuildRequires:  systemd-rpm-macros

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  kf6-rpm-macros
BuildRequires:  cmake(SDL3)
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6Gui)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6QuickControls2)
BuildRequires:  cmake(Qt6Svg)
BuildRequires:  cmake(Qt6Test)
BuildRequires:  cmake(Qt6Widgets)

BuildRequires:  cmake(KF6Kirigami)
BuildRequires:  cmake(KF6CoreAddons)
BuildRequires:  cmake(KF6Config)
BuildRequires:  cmake(KF6ColorScheme)
BuildRequires:  cmake(KF6I18n)
BuildRequires:  cmake(KF6IconThemes)
BuildRequires:  cmake(KF6KirigamiAddons)

Requires:       kf6-kirigami%{?_isa}
Requires:       kf6-kirigami-addons%{?_isa}
Requires:       kf6-qqc2-desktop-style%{?_isa}
Requires:       qt6-controllable%{?_isa}

%description
Graphical front end for updating and rebasing YaguareteOS, with full
controller, touchscreen and keyboard support.

This is a rebranded build of bazzite-updater by Robert French. Only the
user-visible product name and its description differ from upstream; the
source is otherwise unmodified.

%prep
%autosetup -n %{upname}-%{version} -p1

%build
%cmake
%cmake_build

%install
%cmake_install

%check
appstream-util validate-relax --nonet %{buildroot}%{_kf6_metainfodir}/%{appid}.*.xml || :
desktop-file-validate %{buildroot}%{_kf6_datadir}/applications/%{appid}.desktop
# The whole point of the package. If the rebrand ever stops landing, fail
# here rather than shipping an image that says Bazzite on every screen.
! strings -a -e l %{buildroot}%{_kf6_bindir}/%{upname} | grep -q 'Bazzite Updater'

%files
%license LICENSES/{BSD-3-Clause.txt,CC0-1.0.txt,GPL-2.0-or-later.txt,FSFAP.txt}
%doc README.md
%{_kf6_bindir}/%{upname}
%{_kf6_datadir}/applications/%{appid}.desktop
%{_kf6_metainfodir}/%{appid}.*.xml
%{_kf6_datadir}/icons/hicolor/scalable/apps/%{appid}.svg
%{_sysconfdir}/%{upname}/

%changelog
* Sat Aug 22 2026 lobinuxsoft - 0.9.4-1
- Rebranded build of bazzite-updater 0.9.4 (upstream commit cc04ce1)
