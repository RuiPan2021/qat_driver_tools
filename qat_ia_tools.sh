#!/bin/bash

#set the env
config_env_varibles(){
	echo "------set env varibles------"
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
	export CNV_STRICT_MODE=1
	export ICP_DEBUG=y
	export http_proxy=http://proxy-prc.intel.com:913
	export https_proxy=http://proxy-prc.intel.com:913
}

#global variables
DEVICE='420xx'
INTEG_FOLDER='/automation'
DEV_BRANCH='qat_2.0_lin_protected_dev_2304'

#set integ tests env
config_integ_env(){
	echo "------setting up integration test environment------"
	#create the destination folder
	if [ ! -d "${INTEG_FOLDER}" ];then
		mkdir ${INTEG_FOLDER};
	else
		echo "${INTEG_FOLDER} already exits."
	fi

	#build_adf
	cd $ICP_ROOT/adf/;
	make clean && make modules HAPS_80=1 -j
	/bin/cp -f $ICP_ROOT/adf/fw/*.bin /lib/firmware/;
	/bin/cp -f linux/drivers/crypto/qat/qat_common/intel_qat.ko linux/drivers/crypto/qat/qat_${DEVICE}/qat_${DEVICE}.ko linux/drivers/crypto/qat/qat_common/intel_qat.ko linux/drivers/crypto/qat/qat_${DEVICE}vf/qat_${DEVICE}vf.ko ${INTEG_FOLDER};

	#build_adf_ctl
	cd $ICP_ROOT/adf_ctl;
	make KERNEL_SOURCE_DIR=$ICP_ROOT/adf/linux;
	/bin/cp -f ./adf_ctl ${INTEG_FOLDER};
	/bin/cp -f ./conf_files/${DEVICE}* ${INTEG_FOLDER};

	#build_sal
	cd $ICP_ROOT/sal/me_acceleration_layer/release_files/tlm;
	make clean && make -j;
	/bin/cp -rf $ICP_BUILD_OUTPUT/* ${INTEG_FOLDER};

	#build_osal
	cd $ICP_ROOT/osal/
	make clean && make -j;

	#build_integ_tests
	cd $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test;
	make -f Makefile.user clean && make -f Makefile.user ICP_OS_LEVEL=user_space -j;
	yes | /bin/cp -f $INTEG_BUILD_OUTPUT/* ${INTEG_FOLDER};

	#re-install_driver
	insm_qat integ;
}
#copy integ files
cp_integ_materials(){
	#copy_integ_test_file
	echo "------copying integration test files------"

	echo "------copying integration test files [calgary]------"
	/bin/cp -f $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test/compression_corpus_files/calgary/* ${INTEG_FOLDER};

	echo "------copying integration test files [canterbury]------"
	/bin/cp -f $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test/compression_corpus_files/canterbury/* ${INTEG_FOLDER};

	echo "------copying integration test files [silesia]------"
	/bin/cp -f $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test/compression_corpus_files/silesia/* ${INTEG_FOLDER};

	echo "------copying integration test files [AdditionalCompressionInputFiles]------"
	/bin/cp -f $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test/AdditionalCompressionInputFiles/* ${INTEG_FOLDER};

	echo "------copying integration test files [test_lists]------"
	/bin/cp -f $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test/test_lists/*.txt ${INTEG_FOLDER};

	echo "------copying integration test files [scripts]------"
	/bin/cp -rf $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test/scripts/* ${INTEG_FOLDER};

	echo "------copying integration test files [test_config_files]------"
	/bin/find /integ_build/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test/test_config_files -type f -exec /bin/cp -f {} ${INTEG_FOLDER}/ \;

	echo "------copying integration test files [fw/driver]------"
	/bin/cp -f $ICP_ROOT/adf/fw/*.bin ${INTEG_FOLDER};

	#unzip_file
	echo "------unziping integration test files------"
	cd ${INTEG_FOLDER}
	unzip -o -q AdditionalCompressionInputFiles.zip
	echo AdditionalCompressionInputFiles/files_eth1/* AdditionalCompressionInputFiles/files_eth1_short/* AdditionalCompressionInputFiles/files_gmdesk/* AdditionalCompressionInputFiles/files_gmdesk_short/* | xargs /bin/cp -rft .
	echo AdditionalCompressionInputFiles/html/* AdditionalCompressionInputFiles/*.gz | xargs /bin/cp -rft .
	unzip -o -q ibm_files_64.zip;
	unzip -o -q ibm_files_71.zip;
	unzip -o -q ibm_files_72.zip;
}
#run integ_test
run_test(){
	${INTEG_FOLDER}/testCli -ue  $1_tests.txt | tee $1_tests.log;
}

#build adf
build_adf(){
	cd $ICP_ROOT/adf/;
	make clean && make out_of_tree HAPS_80=1 -j
	/bin/cp -f $ICP_ROOT/adf/fw/*.bin /lib/firmware/;
}
#build adf_ctl
build_adf_ctl(){
	cd $ICP_ROOT/adf_ctl;
	make KERNEL_SOURCE_DIR=$ICP_ROOT/adf/linux;
}
#build usdm
build_usdm(){
	cd $ICP_ROOT/usdm
	make clean && make -j
}
#build sal
build_sal(){
	cd $ICP_ROOT/sal/me_acceleration_layer/release_files/tlm;
	make clean && make -j;
}
#build integ_test
build_integ(){
	cd $ICP_ROOT/sal/me_acceleration_layer/access_layer/look_aside_acceleration/integ_test;
	make -f Makefile.user clean && make -f Makefile.user ICP_OS_LEVEL=user_space -j;
}
#build_osal
build_osal(){
	cd $ICP_ROOT/osal/
	make clean && make -j;
}
#build_qat_repos
build_qat(){
	if [[ $OPTARG == 'adf' ]]; then
		build_adf;
	elif [[ $OPTARG == 'ctl' ]]; then
		build_adf_ctl;
	elif [[ $OPTARG == 'sal' ]]; then
		build_sal;
	elif [[ $OPTARG == 'osal' ]]; then
		build_osal;
	elif [[ $OPTARG == 'integ' ]]; then
		build_integ;
	elif [[ $OPTARG == 'usdm' ]]; then
		build_usdm;
	elif [[ $OPTARG == 'all' ]]; then
		build_adf;
		build_adf_ctl;
		build_usdm;
		build_osal;
		build_sal;
		build_integ;
	else
		echo "Invalid argument $OPTARG"
	fi
}

#remove qat driver
rm_qat(){
	echo "------Removing qat driver ${DEVICE}------"
	rmmod qat_${DEVICE};
	rmmod qat_${DEVICE}vf;
	rmmod usdm_drv;
	rmmod intel_qat;
}
#install qat driver
insm_qat(){
	# 1 for adf driver installation
	# 2 for integ driver installation
	# 3 for local driver installation
	# 4 for removing driver
	if [[ $OPTARG == adf ]]; then
		rm_qat;
		build_adf;
		echo "------Insmoding qat driver ${DEVICE} in adf folder------"
		modprobe uio && modprobe authenc && modprobe dh_generic && modprobe vfio && modprobe dh_generic && modprobe mdev;
		insmod `find ./ -name intel_qat.ko`;
		insmod `find ./ -name qat_${DEVICE}.ko`;
		insmod `find ./ -name qat_${DEVICE}vf.ko`;
	elif [[ $OPTARG == integ ]]; then
		rm_qat;
		echo "------Insmoding qat driver ${DEVICE} for integration tests------"
		modprobe uio && modprobe authenc && modprobe dh_generic && modprobe vfio && modprobe dh_generic && modprobe mdev;
		insmod ${INTEG_FOLDER}/intel_qat.ko;
		insmod ${INTEG_FOLDER}/qat_${DEVICE}.ko;
		insmod ${INTEG_FOLDER}/qat_${DEVICE}vf.ko;
		cd ${INTEG_FOLDER}
		./adf_ctl down;
		yes | cp -fv ${INTEG_FOLDER}/420xx_template.conf /etc/420xx_dev0.conf;
		./adf_ctl up;
		insmod ${INTEG_FOLDER}/usdm_drv.ko;
	elif [[ $OPTARG == local ]]; then
		rm_qat;
		echo "------Insmoding qat driver ${DEVICE} in local folder------"
		insmod intel_qat.ko;
		insmod qat_${DEVICE}.ko;
		insmod qat_${DEVICE}vf.ko;
	elif [[ $OPTARG == rm ]]; then
		rm_qat;
	else
		echo "Invalid argument $OPTARG"
	fi
}

#QAT PKG dependency
pkg_dependencies(){

	echo "------Installing PKG dependencies------"
	array=(pciutils libudev-devel readline-devel libxml2-devel boost-devel elfutils-libelf-devel
	python3 libnl3-devel kernel-devel-$(uname -r) gcc gcc-c++ yasm openssl-devel make
	vim git git-lfs)

	for i in ${array[@]}
	do
		result=$(rpm -qa |grep ${i})
		if [ "$result" = '' ]
		then
			echo $i
			dnf install ${i} -y;
		fi
	done
}
#generate package
generate_pkg()
{
	rel_scripts='./build_system/release_scripts/sbin/release_packager.pl'
	rel_config="./release-files/bom/Rel_linux.cfg"
	versionfile=`grep -n 'VERSIONFILE' $rel_config | awk -F : '{print $3}'`

	echo "------Checking the prerequisites------"
	#Check unifdef package is installed, which is required for PKG generation perl script
	#to extra specific code in one text file.
	result=$(dnf list installed unifdef | awk '/unifdef.x86_64/{print$1}')
	if [ "$result" = unifdef.x86_64 ]
	then
	echo "unifdef check PASSED"
	else
	echo "unifdef check, installing unifdef package"
		source /etc/os-release
		case $ID in
		debian|ubuntu|devuan)
		sudo apt-get install -y  unifdef
		;;
		fedora|rhel)
		sudo dnf install -y unifdef
		;;
		centos)
		wget https://dotat.at/prog/unifdef/unifdef-2.12.tar.gz
		tar -zxf unifdef-2.12.tar.gz
		cd unifdef-2.12 && make && cp unifdef /usr/local/bin
		cd .. && rm -rf unifdef-2.12*
		;;
		*)
		exit 1
		;;
		esac
	fi

	#Check perl package is installed, which is required for PKG generation perl script
	#to extra specific code in one text file.
	result=$(dnf list installed perl | awk '/perl.x86_64/{print$1}')
	if [ "$result" = perl.x86_64 ]
	then
	echo "perl check PASSED"
	else
	echo "perl check, installing perl package"
	dnf install -y perl
	cpan -i App::cpanminus
	cpanm XML::Parser XML::Xpath MIME::Lite XML:: Writer Switch JSON
	fi

	#Check the versionfile
	if [ ! -f ${versionfile} ]; then
		dir=$(dirname ${versionfile})
		mkdir -p $dir
		echo "PACKAGE_TYPE=QAT22" | tee ${versionfile}
		echo "PACKAGE_OS=L" | tee -a ${versionfile}
		echo "PACKAGE_VERSION_MAJOR_NUMBER=2210" | tee -a ${versionfile}
		echo "PACKAGE_VERSION_MINOR_NUMBER=0" | tee -a ${versionfile}
		echo "PACKAGE_VERSION_PATCH_NUMBER=0" | tee -a ${versionfile}
		echo "PACKAGE_VERSION_BUILD_NUMBER=1" | tee -a ${versionfile}
	fi

	#build PKG
	cd $ICP_ROOT/adf && make out_of_tree && cd -;
	perl ${rel_scripts} -no_web -cfg ${rel_config} -bu SWF_QAT -debug;
	#remove redundant files
	rm -rf PKG_QAT22_* successlist* failurelist* releaseNote.html BOM_XML.list JSON no_copyright_tag_list.txt *CommitLog.txt
}

#clone repos
clone_repos()
{
	echo "------Cloning repos------"
	cd $ICP_ROOT
	if [ ! -e 'adf' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.adf.git adf
	cd $ICP_ROOT/adf; git checkout ${DEV_BRANCH}; cd $ICP_ROOT;
	fi
	if [ ! -e 'adf_ctl' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.adf-ctl.git adf_ctl
	cd $ICP_ROOT/adf_ctl; git checkout ${DEV_BRANCH}; cd $ICP_ROOT;
	fi
	if [ ! -e 'sal' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.sal.git sal
	cd $ICP_ROOT/sal; git checkout ${DEV_BRANCH}; cd $ICP_ROOT
	fi
	if [ ! -e 'inline' ]; then
	git clone https://github.com/intel-restricted/drivers.qat.inline.inline.git inline
	cd $ICP_ROOT/inline; git checkout ${DEV_BRANCH}; cd $ICP_ROOT
	fi
	if [ ! -e 'release-files' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.release-files/ release-files
	cd $ICP_ROOT/inline; git checkout qat_2.2_lin_main; cd $ICP_ROOT
	fi
	if [ ! -e 'build_system' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.build-system.git build_system
	fi
	if [ ! -e 'api' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.api.api.git api
	fi
	if [ ! -e 'osal' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.osal.git  osal
	fi
	if [ ! -e 'sample_code' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.sample-code.git sample_code
	fi
	if [ ! -e 'usdm' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.usdm.git usdm
	fi
	if [ ! -e 'system_test' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.validation.system-test.git system-test
	fi
	if [ ! -e 'swfconfig' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.common.swfconfig.git swfconfig
	fi
	if [ ! -e 'verify-tools' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.automation.verify-tools verify-tools
	fi
	if [ ! -e 'automation' ]; then
	git clone https://github.com/intel-innersource/drivers.qat.automation.linux-env/ automation
	fi
	if [ ! -e 'csk' ]; then
	git clone https://github.com/intel-innersource/firmware.qat.tools.csk.git csk
	fi
	if [ ! -e 'qat_driver_tools' ]; then
	git clone https://github.com/RuiPan2021/qat_driver_tools.git qat_driver_tools
	fi
}
#fetch remote repos
update_repos(){
	echo "------Updating repos------"
	repos="adf sal inline adf_ctl osal usdm build_system sample_code api system_test automation qat_driver_tools csk verify-tools release-files swfconfig"
	cd $ICP_ROOT
	for dir in ${repos[@]}
	do
		echo $dir
		cd $dir
		git fetch --all 2>&1;
		cd $ICP_ROOT
	done
}

#configure git environment
config_git_env(){
	yum install git git-lfs -y
	#configure git
	git config --global user.name "Rui Pan"
	git config --global user.email rui.pan@intel.com
	unset https_proxy
	curl -fkL https://goto.intel.com/getdt | sh
	./dt setup
	rm -rf ./dt
}
#configure_proxy
configure_proxy(){
	sed -i '$a export http_proxy=http://proxy-prc.intel.com:913' /etc/profile
	sed -i '$a export https_proxy=http://proxy-prc.intel.com:913' /etc/profile
}
#configure zsh and tmux
configure_tools(){
	echo "export PATH="${ICP_ROOT}/qat_driver_tools:$PATH"" >> ~/.zshrc
	echo 'setopt nonomatch' >> ~/.zshrc
	echo 'alias tnew="tmux -f ~/.tmux.conf new-session \; split-window -h \; split-window -v \; attach"' >> ~/.zshrc
	sed -i 's/^ZSH_THEME.*$/ZSH_THEME="clean"/' ~/.zshrc
	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
	sed -i 's/^plugins.*$/plugins=(git z zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc
	source ~/.zshrc

	#configure tmux
	echo "------Configuring tmux------"
	if [ ! -f "~/.tmux.conf" ]; then
		touch ~/.tmux.conf
	fi
	echo 'set -g default-shell /bin/zsh' >> ~/.tmux.conf
	echo 'set -g mouse on' >> ~/.tmux.conf
	echo 'set -g default-terminal "screen-256color"' >> ~/.tmux.conf
}
#install and configure zsh and tmux
install_tools(){
	echo "------Installing Develop tools------"
	array=(tmux zsh)

	for i in ${array[@]}
	do
		result=$(rpm -qa |grep ${i})
		if [ "$result" = '' ]
		then
			echo $i
			dnf install ${i} -y;
		fi
	done

	#install ohMyZsh
	if [ ! -d ~/.oh-my-zs ]; then
		echo "------Configuring zsh------"
		export http_proxy=http://proxy-prc.intel.com:913
		export https_proxy=http://proxy-prc.intel.com:913
		wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
		chmod 777 ./install.sh
		sh ./install.sh
		rm ./install.sh
	fi
}
#setup development environment
set_env(){
	if [[ $OPTARG == 'dev' ]]; then
		configure_proxy;
		config_git_env;
		pkg_dependencies;
		clone_repos;
		install_tools;
		configure_tools;
	elif [[ $OPTARG == 'integ' ]]; then
		config_integ_env;
		cp_integ_materials;
	elif [[ $OPTARG == 'build_integ' ]]; then
		config_integ_env;
	elif [[ $OPTARG == 'cp_integ' ]]; then
		cp_integ_materials;
	else
		echo "Invalid argument $OPTARG"
	fi
}

#print the help list
print_help_list(){
	echo "-h print this list"
	echo "-d qat driver: ins-insmod rmd-rmmod"
	echo "-s Set up the env: val-variables, dev-development, integ-integration, cp-integ=copy integ files"
	echo "-r Run the specific integ_test case"
	echo "-c Clone repos"
	echo "-u update repos"
	echo "-p Generate local PKG"
	echo "-b build repos"
}

while getopts "d:pb:chus:r:" opt
do
	config_env_varibles;
	case $opt in
		b)
			build_qat
			;;
		d)
			insm_qat
			;;
		p)
			generate_pkg
			;;
		s)
			set_env
			;;
		c)
			clone_repos
			;;
		u)
			update_repos
			;;
		h)
			print_help_list
			;;
		r)
			run_test  $OPTARG
			;;
		?)
			echo "Invalid argument $OPTARG"
			exit 1;;
	esac
done
