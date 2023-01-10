Summary: NethServer FlashStart integration
Name: nethserver-flashstart-hybrid
Version: 0.0.0
Release: 1%{?dist}
License: GPL
URL: %{url_prefix}/%{name}
Source0: %{name}-%{version}.tar.gz
# Execute prep-sources to create Source1
Source1: %{name}-cockpit.tar.gz
BuildArch: noarch

Requires: nethserver-squid, nethserver-unbound
Requires: perl-List-MoreUtils

BuildRequires: perl, php-soap
BuildRequires: nethserver-devtools

%description
NethServer FlashStart Hybrid integration.
See: http://www.flashstart.it/

%prep
%setup

%build
%{makedocs}
%{__install} -d root%{perl_vendorlib}
cp -av lib/perl/FlashStartHybrid root%{perl_vendorlib}
perl createlinks
for _nsdb in flashstart; do
   mkdir -p root/%{_nsdbconfdir}/${_nsdb}/{migrate,force,defaults}
done

%install
rm -rf %{buildroot}
(cd root; find . -depth -print | cpio -dump %{buildroot})

mkdir -p %{buildroot}/usr/share/cockpit/%{name}/
mkdir -p %{buildroot}/usr/share/cockpit/nethserver/applications/
mkdir -p %{buildroot}/usr/libexec/nethserver/api/%{name}/

tar xvf %{SOURCE1} -C %{buildroot}/usr/share/cockpit/%{name}/

cp -a %{name}.json %{buildroot}/usr/share/cockpit/nethserver/applications/
cp -a api/* %{buildroot}/usr/libexec/nethserver/api/%{name}/
chmod +x %{buildroot}/usr/libexec/nethserver/api/%{name}/*

%{genfilelist} %{buildroot} > %{name}-%{version}-filelist

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)
%dir %{_nseventsdir}/%{name}-update
%dir %{_nsdbconfdir}/flashstart
%doc COPYING

%changelog
