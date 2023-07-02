#!/bin/bash

#setup env variables
export ICP_ROOT=`pwd`
export ICP_BUILDSYSTEM_PATH=$ICP_ROOT/build_system
export ICP_ENV_DIR=$ICP_ROOT/sal/me_acceleration_layer/release_files/tlm/env_files
export ICP_TOOLS_TARGET=accelcomp
export ICP_CORE=ia
export ICP_OS=linux_2.6
export ARCH=x86_64
export TEAM_NAME=Extended_Acceleration
export INTEG_BUILD_OUTPUT=$ICP_ROOT/CRB_integ_modules
export ICP_BUILD_OUTPUT=$ICP_ROOT/CRB_modules
export ICP_OSCFLAG=linux
export ICP_OS_MAKEFILE_SUFFIX=.linux
export IA_DRIVER_PATH=$ICP_ROOT/sal/me_acceleration_layer/release_files/tlm
export KERNEL_SOURCE_DIR=/lib/modules/`uname -r`/source
export QAT_LEGACY_ALGORITHMS=y
export ICP_DEBUG=y
export http_proxy=http://proxy-prc.intel.com:913
export https_proxy=http://proxy-prc.intel.com:913
export DEVICE=420xx
export INTEG_FOLDER=/automation
export DEV_BRANCH=qat_2.0_lin_protected_dev_2304
export HAPS_80=1

#build utf driver
cd $ICP_ROOT/adf/misc/qat_utf
set +u
sed -i -e "s/git apply  misc/patch -p1 < misc/g" Makefile
sed -i -e "s/git apply -R misc/patch -p1 -R < misc/g" Makefile
set -u
make clean
make
#Revert the modification after use
cd $ICP_ROOT/adf/misc/qat_utf
set +u
sed -i -e "s/patch -p1 < misc/git apply  misc/g" Makefile
sed -i -e "s/patch -p1 -R < misc/git apply -R misc/g" Makefile
set -u
#build adf_ctl
cd $ICP_ROOT/adf_ctl;
make KERNEL_SOURCE_DIR=$ICP_ROOT/adf/linux;
#build_usdm
cd $ICP_ROOT/usdm;
make clean && make -j;

#install qat driver
rmmod qat_utf
rmmod qat_420xx
rmmod qat_420xxvf
rmmod usdm_drv
rmmod intel_qat
modprobe uio && modprobe authenc && modprobe dh_generic && modprobe vfio && modprobe dh_generic && modprobe mdev;
insmod $ICP_ROOT/adf/linux/drivers/crypto/qat/qat_common/intel_qat.ko
insmod $ICP_ROOT/adf/linux/drivers/crypto/qat/qat_420xx/qat_420xx.ko
insmod $ICP_ROOT/adf/misc/qat_utf/qat_utf.ko
insmod $ICP_ROOT/usdm/usdm_drv.ko

#build the sample_code
if [[ ! -d $ICP_ROOT/pkg_sample_code ]]; then
	mkdir -p $ICP_ROOT/pkg_sample_code;
	cd $ICP_ROOT/pkg_sample_code;
	wget https://af01p-ir.devtools.intel.com/artifactory/scb-local/QAT_packages/QAT22/QAT22_2304.0.0/QAT22.L.2304.0.0-00039/STV_Validation/sample_code.tar.gz
	tar zxf sample_code.tar.gz
	./build.sh
fi

#test RAS feature
	cd $ICP_ROOT/pkg_sample_code/quad
	echo "**********SYM and DC related RAS**********"
#241788: SSM soft error injection for cipher slice
	yes | cp $ICP_ROOT/adf_ctl/conf_files/420xx_template.conf.dc.sym /etc/420xx_dev0.conf
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	BDF=$($ICP_ROOT/adf_ctl/adf_ctl  status|awk 'FNR == 3 {print $10}'|cut -d ',' -f1) 
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt 
	echo 'load ./libqat_s.so' >> ./testSteps.txt 
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt 
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt 
	echo 'qaeMemInit()' >> ./testSteps.txt 
	echo 'setReliability(1)' >> ./testSteps.txt 
	echo 'enableStopTests(1)' >> ./testSteps.txt 
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt 
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt 
	echo 'ras_ssm_soft_error_update(0, 0x1, 1)' >> ./testSteps.txt 
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt 
	echo 'megaTestAll("0x1")' >> ./testSteps.txt 
	echo 'ras_ssm_soft_error_clear(0, 0x1, 1)' >> ./testSteps.txt 
	echo 'megaTestAll("0x1")' >> ./testSteps.txt 
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt 
	echo 'icp_sal_userStop()' >> ./testSteps.txt 
	echo 'exit' >> ./testSteps.txt 
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_1.txt 2>&1
	dmesg > ./dmesglog_6_1_1.txt 

	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241788 Expected counter values - OK
	else
		echo 241788 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

# #241789: SSM soft error injection for Authentication Hashing slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt 
	echo 'load ./libqat_s.so' >> ./testSteps.txt 
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt 
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt 
	echo 'qaeMemInit()' >> ./testSteps.txt 
	echo 'setReliability(1)' >> ./testSteps.txt 
	echo 'enableStopTests(1)' >> ./testSteps.txt 
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt 
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt 
	echo 'ras_ssm_soft_error_update(0, 0x1, 2)' >> ./testSteps.txt 
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt 
	echo 'megaTestAll("0x2")' >> ./testSteps.txt 
	echo 'ras_ssm_soft_error_clear(0, 0x1, 2)' >> ./testSteps.txt 
	echo 'megaTestAll("0x2")' >> ./testSteps.txt 
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt 
	echo 'icp_sal_userStop()' >> ./testSteps.txt 
	echo 'exit' >> ./testSteps.txt 
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_2.txt  2>&1
	dmesg > ./dmesglog_6_1_2.txt 
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241789 Expected counter values - OK 
	else
		echo 241789 Expected counter values - NOT OK 
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241790: SSM soft error injection for Compression slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 8)' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x38")' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_cntl_error_clear(0, 0x1, 1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 8)' >> ./testSteps.txt
	echo 'megaTestAll("0x38")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_3.txt 2>&1
	dmesg > ./dmesglog_6_1_3.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241790 Expected counter values - OK
	else
		echo 241790 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

# #241791: SSM soft error injection for UCS slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x20)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x200")' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x20)' >> ./testSteps.txt
	echo 'megaTestAll("0x200")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_4.txt 2>&1
	dmesg > ./dmesglog_6_1_4.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241791 Expected counter values - OK
	else
		echo 241791 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241793: SSM soft error injecton for Authentication Hashing Slice is not impacting cipher Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo  >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x2)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x2)' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_5.txt 2>&1
	dmesg > ./dmesglog_6_1_5.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241793 Expected counter values - OK
	else
		echo 241793 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241794: SSM soft error injection for Cipher slice is not impacting Authentication hashing Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x2")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 1)' >> ./testSteps.txt
	echo 'megaTestAll("0x2")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_6.txt 2>&1
	dmesg > ./dmesglog_6_1_6.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241794 Expected counter values - OK
	else
		echo 241794 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241795: SSM soft error injection for Compression slice is not impacting XLT Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 8)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x1C0")' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 8)' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_7.txt 2>&1
	dmesg > ./dmesglog_6_1_7.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241795 Expected counter values - OK
	else
		echo 241795 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241796: SSM soft error injection for XLT slice is not impacting Compression Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x38")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x10)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_8.txt 2>&1
	dmesg > ./dmesglog_6_1_8.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241796 Expected counter values - OK
	else
		echo 241796 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241797: SSM soft error injection for Decompression slice is not impacting UCS Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x40)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x200")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x40)' >> ./testSteps.txt
	echo 'megaTestAll("0x200")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_9.txt 2>&1
	dmesg > ./dmesglog_6_1_9.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241797 Expected counter values - OK
	else
		echo 241797 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"


#241798: SSM soft error injection for UCS slice is not impacting Decompression Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x20)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x1C00")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x20)' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_10.txt 2>&1
	dmesg > ./dmesglog_6_1_10.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241798 Expected counter values - OK
	else
		echo 241798 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"


#241799: SSM soft error injection for PKE slice is not impacting cipher Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 4)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 4)' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_11.txt 2>&1
	dmesg > ./dmesglog_6_1_11.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241799 Expected counter values - OK
	else
		echo 241799 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"


#241802: SSM Watch Dog Timer induced slice hang for cipher slice、
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_12.txt 2>&1
	dmesg > ./dmesglog_6_1_12.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241802 Expected counter values - OK
	else
		echo 241802 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241803: SSM Watch Dog Timer induced slice hang for hash slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x2")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x2")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_13.txt 2>&1
	dmesg > ./dmesglog_6_1_13.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241803 Expected counter values - OK
	else
		echo 241803 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241804: SSM Watch Dog Timer induced slice hang for compression slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x38")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x38")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_14.txt 2>&1
	dmesg > ./dmesglog_6_1_14.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241804 Expected counter values - OK
	else
		echo 241804 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241805: SSM Watch Dog Timer induced slice hang for UCS slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x200")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x200")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_15.txt 2>&1
	dmesg > ./dmesglogi_6_1_15.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241805 Expected counter values - OK
	else
		echo 241805 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241806: SSM Watch Dog Timer induced slice hang for PKE slice is not impacting cipher test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 2, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 3, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 2, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 3, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_24.txt 2>&1
	dmesg > ./dmesglog_6_1_24.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241806 Expected counter values - OK
	else
		echo 241806 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241808: SSM soft error injection for wireless cipher slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x80)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x4000")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x80)' >> ./testSteps.txt
	echo 'megaTestAll("0x4000")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_17.txt 2>&1
	dmesg > ./dmesglog_6_1_17.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241808 Expected counter values - OK
	else
		echo 241808 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241809: SSM soft error injection for Authentication wireless Hashing Slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x100)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x8000")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x100)' >> ./testSteps.txt
	echo 'megaTestAll("0x8000")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_18.txt 2>&1
	dmesg > ./dmesglog_6_1_18.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241809 Expected counter values - OK
	else
		echo 241809 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241810: SSM soft error injection for Authentication wireless Hashing Slice is not impacting wireless cipher Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo  >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x100)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x4000")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x100)' >> ./testSteps.txt
	echo 'megaTestAll("0x1")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_19.txt 2>&1
	dmesg > ./dmesglog_6_1_19.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241810 Expected counter values - OK
	else
		echo 241810 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241811: SSM soft error injection for wireless Cipher slice is not impacting Authentication wireless hashing Test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 0x80)' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x8000")' >> ./testSteps.txt
	echo 'sleep(10)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 0x80)' >> ./testSteps.txt
	echo 'megaTestAll("0x2")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_20.txt 2>&1
	dmesg > ./dmesglog_6_1_20.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241811 Expected counter values - OK
	else
		echo 241811 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241812: SSM Watch Dog Timer induced slice hang for wireless cipher slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x4000")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x4000")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_21.txt 2>&1
	dmesg > ./dmesglog_6_1_21.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241812 Expected counter values - OK
	else
		echo 241812 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241813: SSM Watch Dog Timer induced slice hang for wireless hash slice
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x8000")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x8000")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_22.txt 2>&1
	dmesg > ./dmesglog_6_1_22.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241813 Expected counter values - OK
	else
		echo 241813 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"


echo "**********PKE related RAS**********"
#241792: SSM soft error injection for PKE slice
	yes | cp $ICP_ROOT/adf_ctl/conf_files/420xx_template.conf.asym /etc/420xx_dev0.conf
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_update(0, 0x1, 4)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'ras_ssm_soft_error_clear(0, 0x1, 4)' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_23.txt 2>&1
	dmesg > ./dmesglog_6_1_23.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241792 Expected counter values - OK
	else
		echo 241792 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241807: SSM Watch Dog Timer induced slice hang for None PKE slice is not impacting PKE test
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0x10)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0x00)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 0, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'ras_ssm_watchdog_timer(0, 0x1, 1, 0xFFFFFFFF)' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_16.txt 2>&1
	dmesg > ./dmesglog_6_1_16.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241807 Expected counter values - OK
	else
		echo 241807 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241800: SSM SPP parity error injecting push bus data error
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_spp_parity_enable_error_update(0)' >> ./testSteps.txt
	echo 'ras_ssm_spp_parity_error_update(0, 0x1, 1)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'ras_ssm_spp_parity_error_clear(0, 0x1, 1)' >> ./testSteps.txt
	echo 'ras_ssm_spp_parity_enable_error_clear(0)' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_25.txt 2>&1
	dmesg > ./dmesglog_6_1_25.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241800 Expected counter values - OK
	else	
		echo 241800 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

#241801: SSM SPP parity error injecting pull bus data error
	$ICP_ROOT/adf_ctl/adf_ctl restart > /dev/null
	echo 'load ./libusdm_drv_s.so' > ./testSteps.txt
	echo 'load ./libqat_s.so' >> ./testSteps.txt
	echo 'load ./cpa_sample_code_s.so' >> ./testSteps.txt
	echo 'load ./stv_test_code_s.so' >> ./testSteps.txt
	echo 'qaeMemInit()' >> ./testSteps.txt
	echo 'setReliability(1)' >> ./testSteps.txt
	echo 'enableStopTests(1)' >> ./testSteps.txt
	echo 'icp_sal_userStartMultiProcess("SSL")' >> ./testSteps.txt
	echo 'setDeviceID(0x4946)' >> ./testSteps.txt
	echo 'ras_ssm_spp_parity_enable_error_update(0)' >> ./testSteps.txt
	echo 'ras_ssm_spp_parity_error_update(0, 0x1, 4)' >> ./testSteps.txt
	echo 'readThreadInfo("QAT22_RAS_TRAD.csv")' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'ras_ssm_spp_parity_error_clear(0, 0x1, 4)' >> ./testSteps.txt
	echo 'megaTestAll("0x4")' >> ./testSteps.txt
	echo 'setExitLoopFlag(1)' >> ./testSteps.txt
	echo 'icp_sal_userStop()' >> ./testSteps.txt
	echo 'exit' >> ./testSteps.txt
	./testCli -u -e ./testSteps.txt > ./ExectiontestCli_6_1_26.txt 2>&1
	dmesg > ./dmesglog_6_1_26.txt
	if [[ "$(< /sys/bus/pci/devices/$BDF/ras_uncorrectable )" -gt 0 && "$(< /sys/bus/pci/devices/$BDF/ras_correctable )" -eq 0 && "$(< /sys/bus/pci/devices/$BDF/ras_fatal )" -eq 0 ]]; then
		echo 241801 Expected counter values - OK
	else
		echo 241801 Expected counter values - NOT OK
	fi
	echo "ras_uncorrectable = $(< /sys/bus/pci/devices/$BDF/ras_uncorrectable ), ras_correctable = $(< /sys/bus/pci/devices/$BDF/ras_correctable ), ras_fatal = $(< /sys/bus/pci/devices/$BDF/ras_fatal )"

