%define version %(cat version.txt)
%define release %{getenv:BUILD_NUMBER}
%global __os_install_post %(echo '%{__os_install_post}' | sed -e 's!/usr/lib[^[:space:]]*/brp-python-bytecompile[[:space:]].*$!!g')

Name:      ingress-customer-bastion-manager
Version:   %{version}
Release:   1
BuildArch: noarch
License:   BSD
Summary:   Manages external users and ssh keys on a bastion host
Requires:  python3 firewalld fail2ban
Source0:   %{name}-%{version}.tar.gz

%description
A python script that provides a utility to create a consistent bastion user that can be monitored and maintained outside of normal userspace

%pre
python3 -m pip install -r setuptools_rust
python3 -m pip install -r cryptography
mkdir -p rpmbuild/BUILD
mkdir -p rpmbuild/RPMS
mkdir -p rpmbuild/SOURCES
mkdir -p rpmbuild/SPECS
mkdir -p rpmbuild/SRPMS 
exit 0

%build
tar -czvf %{name}-%{version}.tar.gz %{name}.py wfs-add-bastion-user
cp %{name} rpmbuild/SOURCES/

%prep
%setup -q
mkdir -p $RPM_BUILD_ROOT/usr/lib
mkdir -p $RPM_BUILD_ROOT/usr/bin

%install
mkdir -p $RPM_BUILD_ROOT/usr/lib
mkdir -p $RPM_BUILD_ROOT/usr/bin
install -m 755 ingress-customer-bastion-manager.py $RPM_BUILD_ROOT/usr/lib/persistent-bastion.py
install -m 755 add-bastion-user $RPM_BUILD_ROOT/usr/bin/add-bastion-user

%post


%files
%defattr(0755, root,root)
/usr/lib/ingress-customer-bastion-manager.py
/usr/bin/wfs-add-bastion-user