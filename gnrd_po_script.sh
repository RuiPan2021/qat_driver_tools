#!/bin/bash

PF(){
	#test sym and dc
	cp 420xx_template.conf.sym /etc/420xx_dev.conf
	./adf_ctl restart
	./testCli -ue asym_user_tests.txt | tee asym_user_tests
	./testCli -ue asym_ci_user_tests.txt | tee asym_ci_user_tests

	#test sym and dc
	cp 420xx_template.conf.sym /etc/420xx_dev.conf
	./adf_ctl restart
	./testCli -ue sym_user_tests.txt | tee sym_user_tests
	./testCli -ue sym_ci_user_tests.txt | tee sym_ci_user_tests
	./testCli -ue integ_wireless_mix_dp_user_tests.txt | tee integ_wireless_mix_dp_user_tests
	./testCli -ue integ_wireless_mix_user_tests.txt | tee integ_wireless_mix_user_tests
	./testCli -ue dc_user_tests.txt | tee dc_user_tests
	./testCli -ue dc_user_tests.txt | tee dc_user_tests
	./testCli -ue dc_dp_user_tests.txt | tee dc_dp_user_tests
	./testCli -ue dc_user_hist_buffer_tests.txt | tee dc_user_hist_buffer_tests
	./testCli -ue dc_user_e2e_async_tests.txt | tee dc_user_e2e_async_tests
	./testCli -ue integ_config_file_user_tests.txt | tee integ_config_file_user_tests
	./testCli -ue dc_user_e2e_data_integrity_tests.txt | tee dc_user_e2e_data_integrity_tests
	./testCli -ue cnv_dc_user_tests.txt | tee cnv_dc_user_tests
	./testCli -ue cnv_user_tests.txt | tee cnv_user_tests
	./testCli -ue cnvTrue_perf_user_tests.txt | tee cnvTrue_perf_user_tests
	./testCli -ue cnvFalse_perf_user_tests.txt | tee cnvFalse_perf_user_tests
	./testCli -ue cnv_dc_dp_user_tests.txt | tee cnv_dc_dp_user_tests
	./testCli -ue cnvnr_dc_user_tests.txt | tee cnvnr_dc_user_tests
	./testCli -ue cnv_ns_dc_user_tests.txt | tee cnv_ns_dc_user_tests
	./testCli -ue dc_ns_user_e2e_data_integrity_tests.txt | tee dc_ns_user_e2e_data_integrity_tests
	./testCli -ue cnv_ns_ei_dc_user_tests.txt | tee cnv_ns_ei_dc_user_tests
	./testCli -ue dc_ns_user_tests.txt | tee dc_ns_user_tests
	./testCli -ue dc_ci_user_tests.txt | tee dc_ci_user_tests

	cp 420xx_dev0.conf_epoll /etc/420xx_dev.conf
	./adf_ctl restart
	./testCli -ue epoll_user_tests.txt | tee epoll_user_tests
}



SVM(){
	cp 420xx_dev0.conf_svm /etc/420xx_dev.conf
	./adf_ctl restart
	./testCli -ue svm_dc_user_tests.txt | tee svm_dc_user_tests
	./testCli -ue svm_sym_user_tests.txt | tee svm_sym_user_tests
	./testCli -ue svm_sym_ci_user_tests.txt | tee svm_sym_ci_user_tests

	cp 420xx_dev0.conf_svm.asym /etc/420xx_dev.conf
	./adf_ctl restart
	./testCli -ue svm_asym_user_tests.txt | tee svm_asym_user_tests
}

RAS(){

}

sample_code(){
	cpa_sample_code runTests=1
}
