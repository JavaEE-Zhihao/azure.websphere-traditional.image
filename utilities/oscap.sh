#!/bin/sh

#      Copyright (c) Microsoft Corporation.
#      Copyright (c) IBM Corporation. 
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# VM administrator
admin=$1

# Install openscap-scanner and security policies
yum install openscap-scanner -y -q
yum install scap-security-guide -y -q

# Peform a SCAP compliance scan 
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis_workstation_l1 --fetch-remote-resources \
    --results scan_results_before.xml /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Peform a SCAP compliance remediation with two skipping rules which conflict with Azure Linux Agent (waagent)
oscap xccdf eval --remediate --profile xccdf_org.ssgproject.content_profile_cis_workstation_l1 --fetch-remote-resources \
    --skip-rule xccdf_org.ssgproject.content_rule_kernel_module_udf_disabled \
    --skip-rule xccdf_org.ssgproject.content_rule_mount_option_var_noexec \
    /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
# Peform a SCAP compliance scan agin after remediation
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis_workstation_l1 --fetch-remote-resources \
    --results scan_results_after.xml /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Generate reports in HTML format by applying the workaround from:
# https://forums.almalinux.org/t/oscap-xccdf-invocation-will-segfault-maybe-due-to-libxslt-patch/5790
rpm -e --nodeps libxslt
dnf install -y libxslt-1.1.34-9.el9_5.1
oscap xccdf generate report scan_results_before.xml > scan_report_before.html
oscap xccdf generate report scan_results_after.xml > scan_report_after.html

# Copy the reports to the admin home directory
cp scan_report_* /home/${admin}/

# Remove openscap-scanner and security policies
dnf remove -y libxslt-1.1.34-9.el9_5.1
yum remove scap-security-guide -y -q
yum remove openscap-scanner -y -q

# Enable sudo for admin, which is required by the remaining steps of the pipeline
usermod -aG wheel ${admin}

# Disable SWAP
swapoff -a
sed -i "s/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g" /etc/waagent.conf
